# Publication Play Store — SombaTeka

## Commande unique (recommandée)

```powershell
cd mobile
.\scripts\publish-play-store.ps1
```

Produit : `build/app/outputs/bundle/release/app-release.aab`

## Pipeline complet

| Étape | Script / doc |
|-------|----------------|
| 1. Assets (icône, bannière) | `python scripts/generate_store_assets.py` |
| 2. Signature Android | `scripts/setup-android-signing.ps1` |
| 3. Firebase réel | `scripts/setup-firebase.ps1` + `docs/FIREBASE_SETUP.md` |
| 4. Build AAB | `scripts/publish-play-store.ps1` |
| 5. Captures écran | `scripts/capture-screenshots.ps1` + `store/play/SCREENSHOTS.md` |
| 6. Upload Play Console | `store/play/PLAY_STORE_CHECKLIST.md` |

## Ce qui est inclus

| Élément | Statut |
|---------|--------|
| Keystore + `key.properties` | Script `setup-android-signing.ps1` |
| Icône + splash | Auto-générés |
| Feature graphic 1024×500 | `store/play/graphics/feature_graphic.png` |
| Fiche store (FR) | `store/play/listing-fr.md` |
| Data Safety | `store/play/data-safety.md` |
| Checklist complète | `store/play/PLAY_STORE_CHECKLIST.md` |
| Suppression compte in-app | Paramètres → Supprimer mon compte |
| Pages web légales | `website/` (terms, privacy, account-deletion) |
| API prod | `https://api.sombateka.cd` |
| CI release | `.github/workflows/release-android.yml` |

## Pages légales (à héberger)

Déployer via nginx (voir `DEPLOYMENT.md` et `scripts/deploy-prod.sh`).

URLs requises Play Store :
- https://sombateka.cd/terms
- https://sombateka.cd/privacy
- https://sombateka.cd/account-deletion

## Encore requis manuellement

1. **Compte Google Play Developer** (25 USD)
2. **Captures d'écran** — `store/play/SCREENSHOTS.md`
3. **Firebase réel** — `docs/FIREBASE_SETUP.md`
4. **Backend production** — `../scripts/deploy-prod.ps1`
5. **SMS prod** — `../backend/docs/SMS_SETUP.md`
6. **Clés Mobile Money** — `../backend/docs/PAYMENTS_RUNBOOK.md`

## iOS

Voir [IOS_RELEASE.md](IOS_RELEASE.md)

## Identifiants stores

| Plateforme | Valeur |
|------------|--------|
| Android `applicationId` | `com.sombateka.st` |
| iOS bundle | `com.sombateka.st` |
| Version | `1.0.0+1` |

## Checklist maître

Voir [../PRODUCTION_CHECKLIST.md](../PRODUCTION_CHECKLIST.md)
