import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SYSTEM_PROMPT = `Tu es LadoumCopilot, un assistant expert en élevage ovin 
spécialisé dans la race Ladoum du Sénégal.
Tu as accès aux données réelles du troupeau de l'éleveur.
Réponds toujours en français, de façon concise et pratique.
Utilise les données fournies pour des recommandations précises et chiffrées.
Si une donnée manque, dis-le clairement.

Connaissance métier :
- Cycle moyen brebis Ladoum : 17 jours (min 14, max 25)
- Durée gestation : 150 jours
- Saison active reproduction : septembre à février
- Anœstrus saisonnier (chaleurs rares) : juin à août
- Âge minimum reproduction : 8 mois
- Taux fertilité normal : 75 à 90%`;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Content-Type": "application/json",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Non authentifié" }),
        { status: 401, headers: corsHeaders }
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error } = await supabase.auth.getUser();
    if (error || !user) {
      return new Response(
        JSON.stringify({ error: "Session invalide" }),
        { status: 401, headers: corsHeaders }
      );
    }

    const { messages, contexte_troupeau } = await req.json();

    const systemComplet = `${SYSTEM_PROMPT}

═══════════════════════════════════
DONNÉES RÉELLES DU TROUPEAU
═══════════════════════════════════
${contexte_troupeau}
═══════════════════════════════════

Réponds uniquement à partir de ces données. Sois précis et donne des noms d'animaux réels.`;

    const groqResponse = await fetch(
      "https://api.groq.com/openai/v1/chat/completions",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${Deno.env.get("GROQ_API_KEY")}`,
        },
        body: JSON.stringify({
          model: "llama3-8b-8192",
          max_tokens: 1024,
          temperature: 0.7,
          messages: [
            { role: "system", content: systemComplet },
            ...messages,
          ],
        }),
      }
    );

    if (!groqResponse.ok) {
      const errTexte = await groqResponse.text();
      console.error("Groq error:", errTexte);
      throw new Error(`Groq API error: ${groqResponse.status}`);
    }

    const groqData = await groqResponse.json();
    const reponse = groqData.choices?.[0]?.message?.content ?? 
      "Je n'ai pas pu générer de réponse.";

    await supabase.from("copilot_conversations").insert({
      user_id: user.id,
      question: messages[messages.length - 1]?.content ?? "",
      reponse,
      created_at: new Date().toISOString(),
    }).then(() => {}).catch(() => {});

    return new Response(
      JSON.stringify({ reponse }),
      { headers: corsHeaders }
    );

  } catch (err) {
    console.error("Copilot error:", err);
    return new Response(
      JSON.stringify({ error: "Erreur du copilot. Réessayez." }),
      { status: 500, headers: corsHeaders }
    );
  }
});