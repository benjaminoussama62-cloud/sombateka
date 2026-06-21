# Configuration Firebase — SombaTeka

Guide pour remplacer les fichiers placeholder par une configuration production.

## 1. Créer le projet Firebase

1. [Firebase Console](https://console.firebase.google.com/) → **Ajouter un projet**
2. Nom suggéré : `sombateka-rdc`
3. Activer **Google Analytics** (recommandé pour crashs/usage)

## 2. Application Android

1. Firebase → **Ajouter une application** → Android
2. Package : `com.sombateka.st`
3. Télécharger `google-services.json`
4. Remplacer : `mobile/android/app/google-services.json`

### Empreinte SHA release (obligatoire pour Auth/FCM)

```powershell
cd mobile
keytool -list -v -keystore android\sombateka-upload.jks -alias upload
```

Copier **SHA-256** dans Firebase → Paramètres projet → Vos applications → Android → Empreintes.

Mettre à jour `website/.well-known/assetlinks.json` avec le même SHA-256.

## 3. Application iOS

1. Firebase → **Ajouter une application** → iOS
2. Bundle ID : `com.sombateka.st`
3. Télécharger `GoogleService-Info.plist`
4. Remplacer : `mobile/ios/Runner/GoogleService-Info.plist`

### APNs (notifications push iOS)

1. [Apple Developer](https://developer.apple.com/) → Keys → **Apple Push Notifications service (APNs)**
2. Télécharger la clé `.p8`
3. Firebase → Paramètres → Cloud Messaging → **Clé APNs** → upload

## 4. Cloud Messaging

1. Firebase Console → **Cloud Messaging**
2. Vérifier que l'API FCM est activée (Google Cloud Console)

L'app mobile utilise `firebase_messaging` ; l'initialisation échoue gracieusement si la config est invalide (mode dev).

## 5. (Optionnel) FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
cd mobile
flutterfire configure --project=sombateka-rdc
```

Génère `lib/firebase_options.dart` — optionnel car le projet lit déjà les fichiers natifs.

## 6. Vérification

```powershell
cd mobile
flutter run --release
# Accepter les permissions notifications → vérifier token FCM dans les logs debug
```

## Fichiers exemple (structure)

- `mobile/android/app/google-services.json.example`
- `mobile/ios/Runner/GoogleService-Info.plist.example`

> **Ne jamais committer** les vrais fichiers avec clés API en dépôt public. Utilisez CI secrets ou déploiement local.

## Script d'aide

```powershell
cd mobile
.\scripts\setup-firebase.ps1
```
