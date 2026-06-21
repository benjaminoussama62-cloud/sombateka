# Publication App Store — SombaTeka

Guide complet pour soumettre SombaTeka sur l'App Store (TestFlight puis production).

## Prérequis

| Élément | Coût / détail |
|---------|---------------|
| Apple Developer Program | 99 USD / an |
| Mac avec Xcode 15+ | Obligatoire pour archive & upload |
| Compte App Store Connect | Lié au Developer Program |
| Firebase iOS réel | `GoogleService-Info.plist` — voir `docs/FIREBASE_SETUP.md` |
| Backend production | `https://api.sombateka.cd` |

## Identifiants

| Champ | Valeur |
|-------|--------|
| Bundle ID | `com.sombateka.st` |
| SKU | `sombateka-rdc` |
| Version | `1.0.0` (build `1`) |

## Étape 1 — Certificats & profils

1. [Apple Developer](https://developer.apple.com/account) → **Certificates, Identifiers & Profiles**
2. **App ID** : créer `com.sombateka.st` avec Push Notifications
3. **Distribution Certificate** : Apple Distribution
4. **Provisioning Profile** : App Store distribution pour `com.sombateka.st`

Dans Xcode (`ios/Runner.xcworkspace`) :

- Signing & Capabilities → Team = votre équipe
- Bundle Identifier = `com.sombateka.st`
- Automatically manage signing (ou profil manuel App Store)

## Étape 2 — Build release

Sur Mac :

```bash
cd mobile
./scripts/build-ios-release.sh https://api.sombateka.cd
```

Windows (préparation sans signature) :

```powershell
.\scripts\build-ios-release.ps1 -ApiUrl https://api.sombateka.cd
```

Puis sur Mac : ouvrir `ios/Runner.xcworkspace` → **Product → Archive**.

## Étape 3 — Export IPA

Utiliser `ios/ExportOptions.plist` (méthode `app-store`) :

```bash
xcodebuild -exportArchive \
  -archivePath build/Runner.xcarchive \
  -exportPath build/ipa \
  -exportOptionsPlist ios/ExportOptions.plist
```

Ou Xcode → Organizer → Distribute App → App Store Connect.

## Étape 4 — App Store Connect

1. [App Store Connect](https://appstoreconnect.apple.com/) → **My Apps** → **+** Nouvelle app
2. Remplir métadonnées : voir `store/ios/listing-fr.md`
3. **App Privacy** : aligné sur `store/ios/app-privacy.md`
4. Captures : voir `store/ios/SCREENSHOTS.md`
5. URL support : `https://sombateka.cd`
6. URL confidentialité : `https://sombateka.cd/privacy`

## Étape 5 — TestFlight

1. Upload IPA via Transporter ou Xcode
2. Attendre traitement (~15–30 min)
3. Inviter testeurs internes
4. QA : OTP, annonces, chat, suppression compte

## Étape 6 — Soumission review

- Classification : 17+ si achats intégrés / UGC
- Notes pour le reviewer : compte test + OTP (fournir numéro de test si possible)
- Délai review : 24–48 h en moyenne

## Checklist

Voir `store/ios/APP_STORE_CHECKLIST.md`.

## Script Windows (préparation)

```powershell
.\scripts\publish-app-store.ps1 -ApiUrl https://api.sombateka.cd
```

> L'upload final vers App Store Connect nécessite un Mac.
