# Checklist publication Play Store — SombaTeka

## Avant upload

- [ ] Compte [Google Play Console](https://play.google.com/console) créé (25 USD)
- [ ] Keystore généré : `.\scripts\setup-android-signing.ps1`
- [ ] Identifiants sauvegardés : `android/signing-credentials.local.txt`
- [ ] AAB buildé : `.\scripts\publish-play-store.ps1`
- [ ] Backend prod en ligne : `https://api.sombateka.cd/healthz`
- [ ] Pages légales en ligne :
  - [ ] https://sombateka.cd/terms
  - [ ] https://sombateka.cd/privacy
  - [ ] https://sombateka.cd/account-deletion
- [ ] Firebase réel : voir `docs/FIREBASE_SETUP.md` + `scripts/setup-firebase.ps1`
- [ ] SMS prod : voir `../../backend/docs/SMS_SETUP.md`
- [ ] Clés Mobile Money : voir `../../backend/docs/PAYMENTS_RUNBOOK.md`

## Assets (generes automatiquement)

- [x] Icône 512×512 : `assets/icon/app_icon.png` — `python scripts/generate_store_assets.py`
- [x] Feature graphic 1024×500 : `store/play/graphics/feature_graphic.png`
- [ ] Captures écran téléphone (min. 2) — `store/play/SCREENSHOTS.md` + `scripts/capture-screenshots.ps1`

## Play Console — Fiche store

- [ ] Nom : **SombaTeka**
- [ ] Description : voir `store/play/listing-fr.md`
- [ ] Icône 512×512 (depuis `assets/icon/app_icon.png`)
- [ ] Feature graphic 1024×500 : `store/play/graphics/feature_graphic.png`
- [ ] Captures écran téléphone (min. 2)
- [ ] E-mail : support@sombateka.cd
- [ ] Catégorie : Shopping
- [ ] Classification contenu : questionnaire rempli (UGC, achats)
- [ ] Data safety : voir `store/play/data-safety.md`
- [ ] Public cible : 18+

## Tests avant production

- [ ] Piste **Test interne** : upload AAB + testeurs
- [ ] Inscription OTP fonctionne en prod
- [ ] Publication annonce + messagerie
- [ ] Suppression de compte (Paramètres)
- [ ] Paiement vendeur officiel (si activé)

## Fichiers produits

| Fichier | Chemin |
|---------|--------|
| App Bundle | `build/app/outputs/bundle/release/app-release.aab` |
| APK (test sideload) | `build/app/outputs/flutter-apk/app-release.apk` |

## Commandes rapides

```powershell
# Pipeline complet (depuis la racine du depot)
..\scripts\init-production.ps1 -SkipDeploy

# Ou depuis mobile/
cd mobile
.\scripts\publish-play-store.ps1
.\scripts\capture-screenshots.ps1
flutter doctor --android-licenses
```

## CI GitHub

Tag `v1.0.0` ou workflow manuel : `.github/workflows/release-android.yml`
(Secrets requis : `ANDROID_KEYSTORE_BASE64`, mots de passe keystore, `SENTRY_DSN_MOBILE`)
