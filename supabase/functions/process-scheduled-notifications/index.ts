import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

async function getAccessToken(clientEmail: string, privateKey: string): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: clientEmail, sub: clientEmail,
    aud: "https://oauth2.googleapis.com/token",
    iat: now, exp: now + 3600,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  };
  const encode = (obj: unknown) =>
    btoa(JSON.stringify(obj)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  const signingInput = `${encode(header)}.${encode(payload)}`;
  const cleanKey = privateKey
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\\n/g, "").replace(/\n/g, "").trim();
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
      headers: { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Methods": "POST" }
    });
  }
  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );
    const maintenant = new Date().toISOString();
    const { data: notifications, error } = await supabase
      .from("notifications_programmees")
      .select("*")
      .eq("statut", "planifie")
      .lte("date_envoi", maintenant)
      .limit(50);
    if (error) {
      return new Response(JSON.stringify({ error: error.message }), { status: 500 });
    }
    if (!notifications || notifications.length === 0) {
      console.log("Aucune notification a envoyer");
      return new Response(JSON.stringify({ message: "Rien a envoyer", count: 0 }), { status: 200 });
    }
    console.log(`${notifications.length} notifications a envoyer`);
    const clientEmail = Deno.env.get("FCM_CLIENT_EMAIL") ?? "";
    const privateKey  = Deno.env.get("FCM_PRIVATE_KEY") ?? "";
    const projectId   = Deno.env.get("FCM_PROJECT_ID") ?? "";
    const accessToken = await getAccessToken(clientEmail, privateKey);
    let envoyes = 0;
    let erreurs = 0;
    for (const notif of notifications) {
      try {
        const { data: tokenData } = await supabase
          .from("user_fcm_tokens")
          .select("fcm_token, platform")
          .eq("user_id", notif.user_id)
          .single();
        if (!tokenData?.fcm_token || tokenData.fcm_token.startsWith("token_")) {
          await supabase.from("notifications_programmees")
            .update({ statut: "annule" }).eq("id", notif.id);
          continue;
        }
        const fcmPayload = {
          message: {
            token: tokenData.fcm_token,
            notification: { title: notif.titre, body: notif.corps },
            android: {
              priority: "high",
              notification: { channel_id: "reproduction_channel", sound: "default" },
            },
            apns: { payload: { aps: { sound: "default", badge: 1 } } },
            data: {
              type: notif.type,
              animal_id: notif.animal_id,
              source: notif.source,
              ...(notif.metadata ?? {}),
            },
          },
        };
        const response = await fetch(
          `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
          {
            method: "POST",
            headers: { "Content-Type": "application/json", Authorization: `Bearer ${accessToken}` },
            body: JSON.stringify(fcmPayload),
          }
        );
        const result = await response.json();
        if (!result.error) {
          await supabase.from("notifications_programmees")
            .update({ statut: "envoye" }).eq("id", notif.id);
          envoyes++;
          console.log(`Push envoye: ${notif.type} pour ${notif.nom_animal}`);
        } else {
          erreurs++;
        }
      } catch (err) {
        console.error(`Erreur notification ${notif.id}:`, err);
        erreurs++;
      }
    }
    const dateExpiration = new Date();
    dateExpiration.setDate(dateExpiration.getDate() - 7);
    await supabase.from("notifications_programmees")
      .update({ statut: "expire" })
      .eq("statut", "planifie")
      .lt("date_envoi", dateExpiration.toISOString());
    const resume = { envoyes, erreurs, total: notifications.length };
    console.log("Resume:", resume);
    return new Response(JSON.stringify(resume), { status: 200 });
  } catch (err) {
    console.error("Erreur generale:", err);
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 });
  }
});