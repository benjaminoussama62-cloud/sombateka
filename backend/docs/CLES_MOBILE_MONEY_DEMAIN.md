# Clés Mobile Money — procédure demain (VPS beta / prod)

Quand vous recevez les clés MTN et Orange, suivez cette checklist sur le serveur.

## 1. Éditer l'environnement

```bash
nano /root/env-backup.production
```

Remplir (exemple — adapter aux vraies valeurs du contrat) :

```env
PAYMENT_SANDBOX_MODE=false

MTN_MONEY_API_URL=https://...
MTN_MONEY_API_KEY=
MTN_MONEY_API_SECRET=
MTN_MONEY_SUBSCRIPTION_KEY=
MTN_MONEY_CALLBACK_SECRET=

ORANGE_MONEY_API_URL=https://...
ORANGE_MONEY_API_KEY=
ORANGE_MONEY_API_SECRET=
ORANGE_MONEY_MERCHANT_ID=
ORANGE_MONEY_CALLBACK_SECRET=
```

**Moov** : pas encore implémenté côté backend — laisser l'UI « bientôt disponible ».

## 2. Webhooks à enregistrer chez les opérateurs

| Opérateur | URL (adapter le domaine si sslip.io) |
|-----------|----------------------------------------|
| MTN | `https://164-90-214-206.sslip.io/api/webhooks/mtn` |
| Orange | `https://164-90-214-206.sslip.io/api/webhooks/orange` |

Les secrets webhook = `MTN_MONEY_CALLBACK_SECRET` / `ORANGE_MONEY_CALLBACK_SECRET`.

## 3. Redéployer

```bash
cp /root/env-backup.production /root/SombaTeka/backend/.env.production
cd /root/SombaTeka/backend
docker compose -f docker-compose.prod.yml -f docker-compose.beta.yml up -d --build backend
docker compose -f docker-compose.prod.yml -f docker-compose.beta.yml ps
```

Vérifier que **celery-worker** et **celery-beat** tournent (reversements T+1).

## 4. Test E2E minimal

1. Compte vendeur officiel + annonce active  
2. Acheteur → panier → paiement MTN ou Orange  
3. Valider sur le téléphone (plus de sandbox auto)  
4. Vérifier webhook dans les logs : `docker compose ... logs backend --tail 100`  
5. Statut commande → `sequestre` dans admin → Litiges & séquestre  

## 5. Rollback urgence

Si incident : `PAYMENT_SANDBOX_MODE=true` dans `.env.production`, redémarrer backend (bloque les vrais prélèvements).

## Fichiers code concernés

- `backend/app/services/payments/mtn.py`
- `backend/app/services/payments/orange.py`
- `backend/app/routers/webhooks.py`
- `backend/.env.production.example` (modèle complet)
