# Lancement Play Store ce soir — SombaTeka

Checklist complète (hors achat domaine `.com` / `.cd`).

---

## Déjà OK sur ton VPS

- [x] API `https://164-90-214-206.sslip.io/healthz`
- [x] PostgreSQL + nginx + SSL Let's Encrypt
- [x] Profil vendeur public (`/api/users/{id}/public`)
- [x] Données vendeur sur fiche annonce

---

## Ce soir — Play Console

### Captures (min. 2, recommandé 6)

1. Accueil (grille annonces)
2. Détail produit + vendeur
3. Recherche / filtres prix
4. Publication annonce
5. Messagerie
6. Profil utilisateur

→ `mobile/store/play/SCREENSHOTS.md`

### Textes

→ `mobile/store/play/listing-fr.md`

### URLs légales (sslip.io temporaire)

| Page | URL |
|------|-----|
| Confidentialité | https://164-90-214-206.sslip.io/privacy |
| CGU | https://164-90-214-206.sslip.io/terms |
| Suppression compte | https://164-90-214-206.sslip.io/account-deletion |

### Formulaires Play Console

- **Data Safety** → `mobile/store/play/data-safety.md`
- **Classification** : 18+, UGC, achats in-app
- **Catégorie** : Shopping

### Build & upload

```powershell
cd mobile
.\scripts\publish-play-store-beta.ps1
```

Fichier : `build/app/outputs/bundle/release/app-release.aab`

---

## Connexion Google / Apple

**Code prêt** — activation manuelle requise :

| Provider | Ce qu'il te faut |
|----------|------------------|
| **Google (Gmail)** | Firebase + SHA-256 keystore release + Client OAuth Web |
| **Apple (iCloud)** | Apple Developer 99 USD/an + capability Sign In with Apple |

Guide détaillé : **`mobile/docs/SOCIAL_AUTH_SETUP.md`**

Sans config → les utilisateurs s'inscrivent via **téléphone OTP** ou **email OTP** (déjà en place).

---

## Vers 15h — Mobile Money

→ `backend/docs/PAYMENTS_RUNBOOK.md`

Variables `.env.production` + webhooks MTN/Orange + rebuild backend.

---

## Avant 1 000+ utilisateurs

| Priorité | Action |
|----------|--------|
| P0 | Keystore Android sauvegardé (USB + cloud) |
| P0 | SMS prod (Africa's Talking / Twilio) |
| P0 | Firebase réel + `google-services.json` |
| P0 | Upgrade VPS → **2–4 Go RAM** |
| P1 | Sauvegardes Postgres (cron) |
| P1 | Sentry (crash monitoring) |
| P1 | E-mail support actif |
| P2 | Domaine sombateka.cd / .com |
| P2 | Google/Apple Sign-In (voir guide) |

---

## QA 30 min avant soumission

- [ ] OTP SMS réel
- [ ] Publier annonce + photos
- [ ] Messagerie
- [ ] Profil vendeur public
- [ ] Suppression compte
- [ ] (15h) Paiement vendeur officiel

---

## Commandes VPS utiles

```bash
# Mot de passe DB (toujours avant docker compose)
export DB_PASSWORD="$(grep '^DB_PASSWORD=' .env.production | cut -d= -f2-)"
echo "DB_PASSWORD=$DB_PASSWORD" > .env

# Déployer nouveau backend
docker compose -f docker-compose.prod.yml up -d --build backend

# Santé
curl -sk https://164-90-214-206.sslip.io/healthz
curl -sk https://164-90-214-206.sslip.io/api/auth/social/status
```
