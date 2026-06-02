import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Génère un JWT signé pour l'API FCM V1
async function getAccessToken(clientEmail: string, privateKey: string): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: clientEmail,
    sub: clientEmail,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  };

  const encode = (obj: unknown) =>
    btoa(JSON.stringify(obj)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

  const signingInput = `${encode(header)}.${encode(payload)}`;

  const cleanKey = privateKey
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\\n/g, "")
    .replace(/\n/g, "")
    .trim();

  const binaryKey = Uint8Array.from(atob(cleanKey), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8", binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false, ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5", cryptoKey,
    new TextEncoder().encode(signingInput)
  );

  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

  const jwt = `${signingInput}.${sigB64}`;

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const tokenData = await tokenRes.json();
  return tokenData.access_token;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
      },
    });
  }

  try {
    const payload = await req.json();
    console.log("Push recu:", JSON.stringify(payload));

    if (!payload.user_id || !payload.title || !payload.body) {
      return new Response(JSON.stringify({ error: "Champs manquants" }), {
        status: 400, headers: { "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const { data: tokens, error: tokenError } = await supabase
      .from("user_fcm_tokens")
      .select("fcm_token, platform")
      .eq("user_id", payload.user_id);

    if (tokenError) {
      return new Response(JSON.stringify({ error: tokenError.message }), {
        status: 500, headers: { "Content-Type": "application/json" },
      });
    }

    if (!tokens || tokens.length === 0) {
      return new Response(JSON.stringify({ warning: "Aucun token FCM" }), {
        status: 200, headers: { "Content-Type": "application/json" },
      });
    }

    const clientEmail = Deno.env.get("FCM_CLIENT_EMAIL") ?? "";
    const privateKey  = Deno.env.get("FCM_PRIVATE_KEY") ?? "";
    const projectId   = Deno.env.get("FCM_PROJECT_ID") ?? "";
    const accessToken = await getAccessToken(clientEmail, privateKey);
    const results = [];

    for (const tokenRow of tokens) {
      if (tokenRow.fcm_token.startsWith("token_")) {
        console.log("Token temporaire — push simule");
        results.push({ success: true, token: tokenRow.fcm_token, simule: true });
        continue;
      }
      try {
        const fcmPayload = {
          message: {
            token: tokenRow.fcm_token,
            notification: { title: payload.title, body: payload.body },
            android: {
              priority: "high",
              notification: { channel_id: "reproduction_channel", sound: "default" },
            },
            apns: {
              payload: { aps: { sound: "default", badge: 1 } },
            },
            data: { type: payload.type, ...(payload.data ?? {}) },
          },
        };

        const response = await fetch(
          `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${accessToken}`,
            },
            body: JSON.stringify(fcmPayload),
          }
        );

        const result = await response.json();
        console.log("FCM V1 response:", JSON.stringify(result));
        results.push({ success: !result.error, token: tokenRow.fcm_token });
      } catch (err) {
        results.push({ success: false, token: tokenRow.fcm_token, error: String(err) });
      }
    }

    await supabase.from("notification_logs").insert({
      user_id: payload.user_id,
      type: payload.type,
      title: payload.title,
      body: payload.body,
      success: results.every((r) => r.success),
      sent_at: new Date().toISOString(),
    });

    return new Response(JSON.stringify({ success: true, results }), {
      status: 200,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });
  } catch (err) {
    console.error("Erreur:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500, headers: { "Content-Type": "application/json" },
    });
  }
});