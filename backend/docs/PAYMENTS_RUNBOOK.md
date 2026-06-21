# SombaTeka — Runbook paiements Mobile Money

Guide opérationnel pour passer du sandbox à la production (MTN MoMo + Orange Money).

## Architecture

```
Acheteur → App mobile → POST /api/orders/{id}/pay
                              ↓
                    MTN / Orange API (collection)
                              ↓
                    Webhook → POST /api/webhooks/mtn|orange
                              ↓
                    Escrow (séquestre) → Livraison QR → Reversement T+1 (Celery)
```

## URLs production à enregistrer

| Opérateur | Webhook |
|-----------|---------|
| MTN MoMo | `https://api.sombateka.cd/api/webhooks/mtn` |
| Orange Money | `https://api.sombateka.cd/api/webhooks/orange` |

## Variables `.env.production`

### MTN MoMo (Collection API)

| Variable | Description |
|----------|-------------|
| `MTN_MONEY_API_URL` | Base URL API (ex. sandbox vs prod selon contrat) |
| `MTN_MONEY_API_KEY` | Bearer token / OAuth |
| `MTN_MONEY_SUBSCRIPTION_KEY` | Header `Ocp-Apim-Subscription-Key` |
| `MTN_MONEY_CALLBACK_SECRET` | Secret HMAC pour vérifier les webhooks |

### Orange Money

| Variable | Description |
|----------|-------------|
| `ORANGE_MONEY_API_URL` | Base URL merchant API |
| `ORANGE_MONEY_API_KEY` | Token d'authentification |
| `ORANGE_MONEY_MERCHANT_ID` | ID marchand |
| `ORANGE_MONEY_CALLBACK_SECRET` | Secret signature webhook |

### Mode sandbox

- Dev : `PAYMENT_SANDBOX_MODE=true` (simule les paiements)
- Prod : `PAYMENT_SANDBOX_MODE=false` (forcé automatiquement si `ENVIRONMENT=production`)

## Checklist activation

- [ ] Contrat marchand MTN / Orange signé
- [ ] Clés API production reçues
- [ ] Webhooks enregistrés et testés (curl + signature)
- [ ] `PAYMENT_SANDBOX_MODE=false` en production
- [ ] Celery worker + beat actifs (reversements T+1)
- [ ] Test E2E : commande → paiement → séquestre → remise → reversement
- [ ] Alertes Sentry configurées sur échecs webhook

## Test webhook (staging)

```bash
# MTN — exemple (adapter signature selon doc opérateur)
curl -X POST https://api.sombateka.cd/api/webhooks/mtn \
  -H "Content-Type: application/json" \
  -H "X-Signature: <hmac>" \
  -d '{"externalId":"ST-123-abc","status":"SUCCESSFUL"}'
```

## Litiges & escrow

- Délai séquestre : `ESCROW_DELIVERY_HOURS` (défaut 48 h)
- Reversement vendeur : `PAYOUT_DELAY_HOURS` après livraison confirmée (défaut 24 h)
- Commission plateforme : `PLATFORM_COMMISSION_PERCENT` (défaut 5 %)

## Rollback

En cas d'incident paiement :

1. Mettre `PAYMENT_SANDBOX_MODE=true` temporairement (bloque les vrais prélèvements)
2. Désactiver les vendeurs officiels via admin panel
3. Investiguer logs : `docker compose -f docker-compose.prod.yml logs backend celery-worker`

## Support

- Email : support@sombateka.cd
- Logs transactions : table `payment_transactions` + `raw_response`
