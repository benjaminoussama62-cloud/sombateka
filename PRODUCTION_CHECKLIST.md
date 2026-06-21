# SombaTeka — Checklist publication production

Checklist maître : infrastructure, intégrations, stores mobile.

## Légende

- ✅ Fait dans le dépôt (code / docs / scripts)
- 🔧 Action manuelle requise (comptes externes, secrets, déploiement serveur)

---

## 1. Infrastructure & DNS 🔧

- [ ] Serveur VPS provisionné (2–4 Go RAM)
- [ ] DNS `sombateka.cd`, `www`, `api.sombateka.cd` → IP serveur
- [ ] Certificats TLS (`scripts/setup-tls.sh` ou `nginx/ssl/README.md`)
- [ ] `backend/.env.production` rempli depuis `.env.production.example`
- [ ] `./scripts/deploy-prod.sh` exécuté avec succès
- [ ] `curl https://api.sombateka.cd/healthz` → 200
- [ ] Pages légales accessibles (terms, privacy, account-deletion)
- [ ] Cron sauvegarde Postgres (`scripts/backup-postgres.sh`)
- [ ] Sentry DSN configuré (backend + mobile)

## 2. Authentification & communications 🔧

- [ ] Africa's Talking ou Twilio : compte + crédits SMS
- [ ] `SMS_PROVIDER`, `SMS_API_KEY`, `SMS_USERNAME` en prod
- [ ] Test OTP réel depuis l'app
- [ ] SMTP ou Resend pour emails admin (KYC, signalements)

## 3. Firebase & notifications push 🔧

- [ ] Projet Firebase Console créé (`sombateka-rdc` ou nom définitif)
- [ ] App Android `com.sombateka.st` enregistrée
- [ ] App iOS `com.sombateka.st` enregistrée
- [ ] Remplacer `mobile/android/app/google-services.json`
- [ ] Remplacer `mobile/ios/Runner/GoogleService-Info.plist`
- [ ] Clé APNs uploadée (iOS)
- [ ] SHA-256 release Android ajouté dans Firebase
- [ ] Guide : `mobile/docs/FIREBASE_SETUP.md`

## 4. Paiements Mobile Money 🔧

- [ ] Contrats marchands MTN / Orange
- [ ] Clés API + webhooks enregistrés
- [ ] Runbook : `backend/docs/PAYMENTS_RUNBOOK.md`
- [ ] Test E2E commande officielle

## 5. Google Play Store

### Code & build ✅

- [x] Script `mobile/scripts/publish-play-store.ps1`
- [x] Signing Android (`setup-android-signing.ps1`)
- [x] Suppression compte in-app
- [x] Fiche store FR (`store/play/listing-fr.md`)
- [x] Data Safety (`store/play/data-safety.md`)

### Assets 🔧

- [x] Icône 512×512 (`assets/icon/app_icon.png` — générer via script)
- [x] Feature graphic 1024×500 (`store/play/graphics/`)
- [ ] Captures écran téléphone (min. 2) — `mobile/store/play/SCREENSHOTS.md`

### Console 🔧

- [ ] Compte Google Play Developer (25 USD)
- [ ] Upload AAB piste **Test interne**
- [ ] Questionnaire classification contenu (UGC, achats)
- [ ] Data safety formulaire rempli
- [ ] Testeurs invités + QA complète
- [ ] Promotion en **Production**

## 6. Apple App Store

### Code ✅

- [x] Projet iOS Flutter
- [x] Privacy manifest (`PrivacyInfo.xcprivacy`)
- [x] Guide `mobile/IOS_RELEASE.md`
- [x] Checklist `mobile/store/ios/APP_STORE_CHECKLIST.md`

### Compte & signing 🔧

- [ ] Apple Developer Program (99 USD/an)
- [ ] Certificats + provisioning profiles
- [ ] `DEVELOPMENT_TEAM` dans Xcode
- [ ] TestFlight → App Store Review

## 7. QA finale 🔧

- [ ] Inscription + OTP prod
- [ ] Publier annonce + photos
- [ ] Chat acheteur/vendeur
- [ ] Favoris, recherche, notifications
- [ ] Suppression compte
- [ ] Vendeur officiel + KYC (si activé)
- [ ] Mode offline / reconnexion

---

## Commandes rapides

```powershell
# Assets store
cd mobile
pip install -r scripts/requirements.txt
python scripts/generate_store_assets.py

# Build Play Store
.\scripts\publish-play-store.ps1

# Déploiement backend
cd ..
.\scripts\deploy-prod.ps1
```

**Estimation après complétion manuelle : prêt pour publication publique.**

