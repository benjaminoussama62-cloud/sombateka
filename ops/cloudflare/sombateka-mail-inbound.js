/**
 * Worker Email Cloudflare — sombateka-mail-inbound
 *
 * Achemine tout mail entrant *@sombatekaonline.com vers le helpdesk du panneau
 * admin SombaTeka (POST /api/mail/inbound, MIME brut + secret partagé).
 *
 * Variables d'environnement du worker (Cloudflare > Workers > Settings > Variables) :
 *   INBOUND_URL          = https://sombatekaonline.com/api/mail/inbound
 *   MAIL_INBOUND_SECRET  = <secret partagé, même valeur que MAIL_INBOUND_SECRET côté backend>
 *   FALLBACK_ADDR        = boîte de secours si le backend est en échec (optionnel)
 *
 * Routage : Cloudflare Email Routing > sombatekaonline.com > Catch-all
 *           → "Send to a Worker" → sombateka-mail-inbound
 */
export default {
  async email(message, env, ctx) {
    try {
      const raw = await new Response(message.raw).arrayBuffer();
      const resp = await fetch(env.INBOUND_URL, {
        method: "POST",
        headers: {
          "content-type": "application/octet-stream",
          "x-mail-secret": env.MAIL_INBOUND_SECRET,
          "x-mail-from": message.from,
          "x-mail-to": message.to,
        },
        body: raw,
      });
      if (!resp.ok) {
        console.error(`inbound POST failed: ${resp.status}`);
        if (env.FALLBACK_ADDR) await message.forward(env.FALLBACK_ADDR);
        message.setReject(`Backend error ${resp.status}`);
      }
    } catch (e) {
      console.error(`inbound error: ${e}`);
      if (env.FALLBACK_ADDR) await message.forward(env.FALLBACK_ADDR);
      message.setReject("Backend unreachable");
    }
  },
};
