# SMS OTP production — SombaTeka

Configuration des envois OTP par SMS en production.

## Providers supportés

| Provider | Variable | Région |
|----------|----------|--------|
| `log` | — | Dev uniquement (console) |
| `africas_talking` | Recommandé RDC | Afrique |
| `twilio` | Alternative | International |

## Africa's Talking (recommandé RDC)

1. Créer un compte : https://africastalking.com/
2. Obtenir **API Key** et **Username**
3. Configurer un sender ID approuvé : `SombaTeka`

### Sandbox (tests beta)

- **Username** : toujours `sandbox` (visible sur le dashboard)
- **API Key** : Settings → API Key (app Sandbox)
- **Numéros de test** : menu **SMS** → enregistrer chaque numéro `+243…` qui recevra les OTP (le sandbox n'envoie qu'aux numéros listés)
- L'API utilise automatiquement `api.sandbox.africastalking.com` quand `SMS_USERNAME=sandbox`

```env
SMS_PROVIDER=africas_talking
SMS_API_KEY=votre_cle_sandbox
SMS_USERNAME=sandbox
SMS_SENDER_ID=SombaTeka
```

### Production (vrais utilisateurs)

Après crédit du compte live, créer une app **Production** et utiliser le username de cette app (pas `sandbox`).

```env
SMS_PROVIDER=africas_talking
SMS_API_KEY=votre_api_key
SMS_USERNAME=votre_username
SMS_SENDER_ID=SombaTeka
```

## Twilio

```env
SMS_PROVIDER=twilio
SMS_API_KEY=votre_auth_token
SMS_USERNAME=votre_account_sid
SMS_SENDER_ID=+243XXXXXXXXX
```

## Test production

```bash
curl -X POST https://api.sombateka.cd/api/auth/request-otp \
  -H "Content-Type: application/json" \
  -d '{"phone_e164":"+243XXXXXXXXX"}'
```

> En production `EXPOSE_OTP_IN_RESPONSE=false` — l'OTP n'apparaît pas dans la réponse API.

## Rate limiting

- Global : `RATE_LIMIT_PER_MINUTE` (défaut 60)
- Redis requis : `USE_REDIS_RATE_LIMIT=true`

## Dépannage

| Symptôme | Cause probable |
|----------|----------------|
| OTP jamais reçu | Crédits SMS épuisés, sender ID non approuvé |
| 429 Too Many Requests | Rate limit — attendre ou ajuster Redis |
| Logs "SMS log" en prod | `SMS_PROVIDER=log` — corriger `.env.production` |
