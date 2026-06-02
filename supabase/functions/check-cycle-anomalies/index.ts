// ============================================================
// EDGE FUNCTION — check-cycle-anomalies
// Fichier: supabase/functions/check-cycle-anomalies/index.ts
//
// Appelée toutes les heures par pg_cron
// → Détecte les brebis sans chaleur depuis > 21 jours
// → Crée une alerte et programme un push
// ============================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SEUIL_ABSENCE_JOURS = 21;
const SEUIL_INTERVALLE_MIN = 14;
const SEUIL_INTERVALLE_MAX = 21;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: { "Access-Control-Allow-Origin": "*" }
    });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const maintenant = new Date();
    const dateSeuil = new Date(maintenant);
    dateSeuil.setDate(dateSeuil.getDate() - SEUIL_ABSENCE_JOURS);

    console.log(`🔍 Vérification absences chaleurs (seuil: ${SEUIL_ABSENCE_JOURS}j)`);

    // 1. Récupérer toutes les brebis avec leurs dernières chaleurs
    const { data: dernieresChaleurs, error } = await supabase.rpc(
      'get_brebis_derniere_chaleur'
    );

    // Si la fonction RPC n'existe pas, utiliser une requête SQL directe
    let brebisAVerifier: any[] = [];

    if (error || !dernieresChaleurs) {
      // Requête alternative directe
      const { data: chaleurs } = await supabase
        .from('chaleurs')
        .select('animal_id, source, user_id, date_chaleur')
        .order('date_chaleur', { ascending: false });

      if (chaleurs) {
        // Grouper par animal_id pour garder seulement la dernière chaleur
        const map = new Map<string, any>();
        for (const c of chaleurs) {
          const key = `${c.animal_id}_${c.source}`;
          if (!map.has(key)) {
            map.set(key, c);
          }
        }
        brebisAVerifier = Array.from(map.values());
      }
    } else {
      brebisAVerifier = dernieresChaleurs;
    }

    let alertesCreees = 0;
    const dateSeuil3Jours = new Date(maintenant);
    dateSeuil3Jours.setDate(dateSeuil3Jours.getDate() - 3);

    for (const brebis of brebisAVerifier) {
      const dateDerniereChaleur = new Date(brebis.date_chaleur);
      const joursDepuis = Math.floor(
        (maintenant.getTime() - dateDerniereChaleur.getTime()) / (1000 * 60 * 60 * 24)
      );

      if (joursDepuis <= SEUIL_ABSENCE_JOURS) continue;

      // Vérifier si en gestation
      const { data: gestation } = await supabase
        .from('accouplements')
        .select('id')
        .eq('brebis_id', brebis.animal_id)
        .eq('source_brebis', brebis.source)
        .is('date_mise_bas', null)
        .limit(1)
        .maybeSingle();

      if (gestation) continue;

      // Vérifier alerte récente (éviter doublons)
      const { data: alerteRecente } = await supabase
        .from('alertes_cycle')
        .select('id')
        .eq('animal_id', String(brebis.animal_id))
        .eq('type_alerte', 'absence_chaleurs')
        .eq('statut', 'active')
        .gte('created_at', dateSeuil3Jours.toISOString())
        .maybeSingle();

      if (alerteRecente) continue;

      // Déterminer type (anœstrus saisonnier juin-août)
      const mois = maintenant.getMonth() + 1;
      const estAnoestrus = mois >= 6 && mois <= 8;
      const typeAlerte = estAnoestrus ? 'anoestrus' : 'absence_chaleurs';

      const message = estAnoestrus
        ? `🌡️ Anœstrus saisonnier : pas de chaleur depuis ${joursDepuis} jours`
        : `🚨 Absence de chaleurs depuis ${joursDepuis} jours (seuil : ${SEUIL_ABSENCE_JOURS} jours)`;

      const suggestion = estAnoestrus
        ? "L'anœstrus saisonnier est normal en période estivale. Si cela persiste après septembre, consultez votre vétérinaire."
        : "L'absence prolongée de chaleurs peut indiquer une gestation non détectée, un problème ovarien ou un déficit nutritionnel. Consultez votre vétérinaire.";

      // Créer alerte en BD
      await supabase.from('alertes_cycle').insert({
        user_id         : brebis.user_id,
        animal_id       : String(brebis.animal_id),
        source          : brebis.source,
        nom_animal      : brebis.animal_id,
        type_alerte     : typeAlerte,
        intervalle_jours: joursDepuis,
        message         : message,
        suggestion      : suggestion,
        statut          : 'active',
        date_alerte     : maintenant.toISOString(),
      });

      // Programmer push dans 5 minutes
      const dateEnvoi = new Date(maintenant.getTime() + 5 * 60 * 1000);
      await supabase.from('notifications_programmees').insert({
        user_id   : brebis.user_id,
        animal_id : String(brebis.animal_id),
        source    : brebis.source,
        nom_animal: String(brebis.animal_id),
        type      : typeAlerte,
        titre     : estAnoestrus
          ? `🌡️ Anœstrus saisonnier`
          : `🚨 Absence de chaleurs`,
        corps     : `${message}\n\n💡 ${suggestion}`,
        date_envoi: dateEnvoi.toISOString(),
        statut    : 'planifie',
        metadata  : {
          animal_id : String(brebis.animal_id),
          source    : brebis.source,
          priorite  : estAnoestrus ? 'normale' : 'haute',
        },
      });

      alertesCreees++;
      console.log(`✅ Alerte créée: ${typeAlerte} → animal ${brebis.animal_id} (${joursDepuis}j)`);
    }

    const resume = {
      brebis_verifiees: brebisAVerifier.length,
      alertes_creees  : alertesCreees,
      timestamp       : maintenant.toISOString(),
    };

    console.log("📊 Résumé:", resume);
    return new Response(JSON.stringify(resume), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });

  } catch (err) {
    console.error("❌ Erreur:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});