import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// ============================================================
// EDGE FUNCTION : notifier-statut-veterinaire
// (nom conservé pour compatibilité, gère TOUS les rôles :
// éleveur ET vétérinaire, la validation admin s'appliquant aux deux.)
// Envoi d'email via l'API Brevo (au lieu de Resend, limité en mode test).
// ============================================================

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const FROM_EMAIL = 'saidouba.camara@etu.ussein.edu.sn'
const FROM_NAME = 'JUR GUI'
const APP_NAME = 'Jur-Gui'

function libelleRole(role: string): string {
  return role === 'veterinaire' ? 'vétérinaire' : 'éleveur'
}

function htmlInscription(nom: string, role: string): string {
  const rle = libelleRole(role)
  return `<div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto;">
      <h2 style="color:#1B5E20;">${APP_NAME}</h2>
      <p>Bonjour ${nom},</p>
      <p>Merci pour votre inscription en tant que <strong>${rle}</strong> sur ${APP_NAME}.</p>
      <p>Votre dossier est en cours de vérification. Ce contrôle peut prendre jusqu'à <strong>72 heures</strong>.</p>
      <p>Vous recevrez un email et une notification dès que votre compte sera validé.</p>
    </div>`
}

function htmlApproved(nom: string, role: string): string {
  const rle = libelleRole(role)
  return `<div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto;">
      <h2 style="color:#1B5E20;">${APP_NAME}</h2>
      <p>Bonjour ${nom},</p>
      <p>Bonne nouvelle : votre compte <strong>${rle}</strong> a été vérifié et validé ✅</p>
      <p>Vous pouvez dès maintenant vous connecter à l'application.</p>
    </div>`
}

function htmlRejected(nom: string, motif: string | null, role: string): string {
  const rle = libelleRole(role)
  return `<div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto;">
      <h2 style="color:#1B5E20;">${APP_NAME}</h2>
      <p>Bonjour ${nom},</p>
      <p>Après vérification, nous ne sommes pas en mesure de valider votre compte ${rle} pour le moment.</p>
      ${motif ? `<p><strong>Motif :</strong> ${motif}</p>` : ''}
    </div>`
}

async function sendEmailBrevo(apiKey: string, to: string, subject: string, html: string) {
  const resp = await fetch('https://api.brevo.com/v3/smtp/email', {
    method: 'POST',
    headers: {
      'api-key': apiKey,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    body: JSON.stringify({
      sender: { name: FROM_NAME, email: FROM_EMAIL },
      to: [{ email: to }],
      subject,
      htmlContent: html,
    }),
  })
  const result = await resp.json()
  if (!resp.ok) {
    console.error('[DIAG] Erreur envoi email Brevo:', JSON.stringify(result))
  } else {
    console.log('[DIAG] Email accepté par Brevo, messageId:', result?.messageId)
  }
  return { ok: resp.ok, status: resp.status, result }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    })
  }

  try {
    const authHeader = req.headers.get('Authorization') ?? ''
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

    const body = await req.json()
    const { user_id, event, motif } = body as {
      user_id: string
      event: 'inscription' | 'approved' | 'rejected'
      motif?: string
    }

    if (!user_id || !event) {
      return new Response(JSON.stringify({ error: 'user_id et event sont requis' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    const token = authHeader.replace('Bearer ', '')

    if (event === 'inscription') {
      const { data: callerData, error: callerErr } = await supabase.auth.getUser(token)
      if (callerErr || !callerData?.user || callerData.user.id !== user_id) {
        return new Response(JSON.stringify({ error: 'Non autorisé' }), {
          status: 403,
          headers: { 'Content-Type': 'application/json' },
        })
      }
    } else {
      if (token !== SUPABASE_SERVICE_KEY) {
        return new Response(JSON.stringify({ error: 'Réservé à l\'administration' }), {
          status: 403,
          headers: { 'Content-Type': 'application/json' },
        })
      }
    }

    const { data: user, error: userErr } = await supabase
      .from('users')
      .select('nom, prenom, email, role, statut')
      .eq('id', user_id)
      .maybeSingle()

    if (userErr || !user) {
      return new Response(JSON.stringify({ error: 'Utilisateur introuvable' }), {
        status: 404,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    const role = (user.role as string) ?? 'eleveur'
    const nomComplet = `${user.prenom ?? ''} ${user.nom ?? ''}`.trim() || 'Utilisateur'

    let subject = ''
    let html = ''
    if (event === 'inscription') {
      subject = `${APP_NAME} — Votre inscription est en cours de vérification`
      html = htmlInscription(nomComplet, role)
    } else if (event === 'approved') {
      subject = `${APP_NAME} — Votre compte a été validé ✅`
      html = htmlApproved(nomComplet, role)
    } else if (event === 'rejected') {
      subject = `${APP_NAME} — Mise à jour de votre dossier`
      html = htmlRejected(nomComplet, motif ?? null, role)
    }

    const { data: brevoKey, error: keyErr } = await supabase.rpc('get_brevo_api_key')
    if (keyErr || !brevoKey) {
      throw new Error(`Clé Brevo indisponible: ${keyErr?.message}`)
    }

    const emailResult = await sendEmailBrevo(brevoKey as string, user.email, subject, html)

    let pushResult: unknown = null
    if (event === 'approved' || event === 'rejected') {
      const pushTitle = event === 'approved' ? 'Compte validé ✅' : 'Mise à jour de votre dossier'
      const rle = libelleRole(role)
      const pushBody =
        event === 'approved'
          ? `Votre compte ${rle} a été validé. Vous pouvez vous connecter.`
          : `Votre dossier ${rle} nécessite une action. Consultez votre email.`

      const pushResp = await fetch(`${SUPABASE_URL}/functions/v1/send-push-notification`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
        },
        body: JSON.stringify({
          user_id,
          title: pushTitle,
          body: pushBody,
          type: 'validation_compte',
          channel: 'alerte_channel',
        }),
      })
      pushResult = await pushResp.json()
    }

    return new Response(
      JSON.stringify({ success: true, email: emailResult, push: pushResult }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('[DIAG] EXCEPTION non gérée:', error instanceof Error ? error.message : String(error))
    return new Response(JSON.stringify({ error: String(error) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
Au caractère Ligne:1 : 1
+ import { createClient } from 'https://esm.sh/@supabase/supabase-js@ ...
+ ~~~~~~
Le terme «import» n'est pas reconnu comme nom d'applet de commande, fonction, fichier de script ou programme exécutable. Vérifiez le nom, ou si un chemin d'accès existe, vérifiez que le chemin d'accès est indiqué correctement, puis réexécutant.
Au caractère Ligne:130 : 5
+ }
+ ~
Jeton inattendu « } » dans l’expression ou l’instruction.
    + CategoryInfo          : ParserError: (:) [], ParentContainsError_diagnos
    + FullyQualifiedErrorId : MixedEndParenthesisImatch...
    Name                    : PS
</document>