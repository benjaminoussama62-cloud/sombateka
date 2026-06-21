## SombaTeka (RDC) — Marketplace C2C + Officiel (certifié)

Application mobile **Android + iOS** pour achat/vente en RDC:
- **C2C (compte ordinaire)**: annonces + recherche + chat + sécurité (paiement hors-app entre utilisateurs).
- **Officiel (compte certifié)**: **commande + paiement Mobile Money in-app**, commission plateforme, remise main propre (QR/Code), reversement vendeur **T+1** (si pas de litige/risque).
- Conçue pour la réalité EDC: **mauvaise connexion**, data chère, téléphones modestes → **offline-first**, sync robuste, app légère.

## Dossiers
- `backend/`: API (FastAPI) + Postgres, auth/KYC, annonces, commandes, paiements, modération, anti-fraude.
- `mobile/`: App Flutter (offline-first) + UI pro.
- `backend/admin-panel/`: Panneau web admin (modération, KYC, signalements) — **hors app mobile**, servi sur `/admin`.
- `infra/`: docker-compose Postgres + scripts.

## Démarrage (Windows)
### Prérequis
- Python 3.11+
- Docker Desktop (optionnel, pour Postgres)
- Flutter (pour l’app)

### 1) Base de données
Dans un terminal à la racine:

```bash
docker compose -f infra/docker-compose.yml up -d
```

Si Docker n’est pas disponible, le backend démarre en **SQLite** par défaut (aucune DB externe).

### 2) Backend
```bash
cd backend
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --reload --port 8000
```

### Voir l’app sur iPhone (sans Android Studio)
1) Lance le backend comme ci-dessus (`--host 0.0.0.0`).
2) Lance Flutter Web accessible sur le réseau (dans `mobile/`) :

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```

3) Sur ton iPhone (même Wi‑Fi / hotspot), ouvre Safari sur :
- `http://<IP_DE_TON_PC>:8080`

Si ça ne charge pas, ouvre le pare-feu Windows pour **TCP 8080** et **TCP 8000** (sinon le téléphone ne peut pas joindre ton PC).

API: `http://localhost:8000`  
Docs Swagger: `http://localhost:8000/docs`  
**Admin (modération):** `http://localhost:8000/admin/` — voir [backend/admin-panel/README.md](backend/admin-panel/README.md)

### 3) Mobile
```bash
cd mobile
flutter pub get
flutter run
```

## Sécurité (résumé)
- OTP téléphone + SMS (Africa's Talking / Twilio) + OTP email (SMTP / Resend) + rate limit Redis.
- Officiel: KYC/KYB + validation admin, ledger, reversement T+1 (Celery).
- Paiement: MTN / Orange Money + webhooks signés, idempotency, sandbox/prod.
- Modération: signalements + panel admin, ban utilisateurs.
- Mobile: API Dio + JWT sécurisé + cache offline Hive + Sentry (optionnel).

## Production
Voir [DEPLOYMENT.md](DEPLOYMENT.md) pour Docker, Nginx, Celery et clés Mobile Money.
Checklist complète : [PRODUCTION_CHECKLIST.md](PRODUCTION_CHECKLIST.md)

## Phase 1 beta (APK test)

Guide pas a pas : **[BETA_PHASE1.md](BETA_PHASE1.md)** — VPS, SMS, APK sans Play Store.

```powershell
.\scripts\setup-beta-secrets.ps1 -ApplyBetaTemplate
```

### Mobile (Play Store / App Store)
- Android : [mobile/STORE_RELEASE.md](mobile/STORE_RELEASE.md)
- iOS : [mobile/IOS_RELEASE.md](mobile/IOS_RELEASE.md)

