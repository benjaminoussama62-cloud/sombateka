# Connexion Google & Apple — SombaTeka

Guide pour activer **Continuer avec Google** (Gmail) et **Continuer avec Apple** (iCloud) en production.

> **Je ne peux pas tout activer à ta place** : Google et Apple exigent des comptes développeur, des empreintes SHA de ton keystore release, et des fichiers secrets (`google-services.json`, clés Apple). Le **code est prêt** ; tu complètes la configuration console ci-dessous.

---

## Ce qui est déjà dans le code

| Couche | Détail |
|--------|--------|
| Mobile | Packages `google_sign_in`, `sign_in_with_apple` |
| Mobile | Vérification statut API `/auth/social/status` |
| Backend | Vérification **id_token** Google + Apple (pas de confiance aveugle) |
| Backend | Route prod `/api/auth/social/login` (plus limitée au dev) |

Activation au build APK/AAB :

```powershell
flutter build appbundle --release `
  --dart-define=ST_API_BASE_URL=https://164-90-214-206.sslip.io `
  --dart-define=ST_SOCIAL_AUTH_ENABLED=true `
  --dart-define=ST_GOOGLE_WEB_CLIENT_ID=XXXX.apps.googleusercontent.com `
  --dart-define=ST_APPLE_SIGNIN_ENABLED=true
```

---

## A. Google (Gmail) — Android + iOS

### 1. Firebase / Google Cloud

1. [Firebase Console](https://console.firebase.google.com/) → projet **SombaTeka**
2. Ajouter app **Android** `com.sombateka.st`
3. Ajouter app **iOS** `com.sombateka.st`
4. Télécharger :
   - `google-services.json` → `mobile/android/app/google-services.json`
   - `GoogleService-Info.plist` → `mobile/ios/Runner/GoogleService-Info.plist`

### 2. Empreintes SHA (Android — obligatoire)

Sur ton PC, après keystore release :

```powershell
cd mobile
keytool -list -v -keystore android\app\sombateka-release.jks -alias sombateka
```

Copier **SHA-1** et **SHA-256** dans Firebase → Paramètres projet → App Android.

Sans ça → Google Sign-In échoue en release.

### 3. Client OAuth Web (obligatoire pour id_token Android **et PWA**)

1. [Google Cloud Console](https://console.cloud.google.com/) → APIs & Services → Credentials
2. Créer **OAuth client ID** type **Web application**
3. Copier le **Client ID** (…apps.googleusercontent.com)
4. **Origines JavaScript autorisées** (obligatoire pour PWA / Safari) :

```
https://164-90-214-206.sslip.io
https://sombateka.cd
```

> Erreur `origin_mismatch` ? → voir **`mobile/docs/GOOGLE_PWA_ORIGINS.md`**

5. L'utiliser comme :
   - `ST_GOOGLE_WEB_CLIENT_ID` dans le build Flutter
   - Première entrée de `GOOGLE_OAUTH_CLIENT_IDS` sur le serveur

### 4. Backend VPS (`.env.production`)

```env
ENABLE_SOCIAL_LOGIN=true
GOOGLE_OAUTH_CLIENT_IDS=WEB_CLIENT_ID.apps.googleusercontent.com,ANDROID_CLIENT_ID.apps.googleusercontent.com,IOS_CLIENT_ID.apps.googleusercontent.com
```

Puis rebuild :

```bash
cd ~/SombaTeka/backend
export DB_PASSWORD="$(grep '^DB_PASSWORD=' .env.production | cut -d= -f2-)"
docker compose -f docker-compose.prod.yml up -d --build backend
```

Vérifier :

```bash
curl -sk https://164-90-214-206.sslip.io/api/auth/social/status
# {"enabled":true,"google":true,"apple":...}
```

### 5. iOS — URL scheme Google

Dans `ios/Runner/Info.plist`, ajouter `CFBundleURLTypes` avec le `REVERSED_CLIENT_ID` de `GoogleService-Info.plist` (voir doc Firebase iOS).

---

## B. Apple (iCloud) — iPhone / iPad

### Prérequis

| Exigence | Coût |
|----------|------|
| **Apple Developer Program** | 99 USD / an |
| App iOS `com.sombateka.st` | Inclus |

> **Règle App Store** : si tu proposes Google, tu dois aussi proposer **Sign in with Apple** sur iOS.

### 1. Apple Developer

1. [developer.apple.com](https://developer.apple.com/) → **Certificates, Identifiers & Profiles**
2. **Identifiers** → App ID `com.sombateka.st`
3. Activer capability **Sign In with Apple** → Save

### 2. Xcode

1. Ouvrir `mobile/ios/Runner.xcworkspace`
2. Target Runner → **Signing & Capabilities** → **+ Capability** → Sign In with Apple
3. Team = ton compte Apple Developer

### 3. Backend

```env
ENABLE_SOCIAL_LOGIN=true
APPLE_OAUTH_CLIENT_ID=com.sombateka.st
```

(`APPLE_OAUTH_CLIENT_ID` = **Bundle ID**, pas Service ID, pour app native)

### 4. Build iOS

```powershell
flutter build ipa --release `
  --dart-define=ST_API_BASE_URL=https://164-90-214-206.sslip.io `
  --dart-define=ST_SOCIAL_AUTH_ENABLED=true `
  --dart-define=ST_APPLE_SIGNIN_ENABLED=true `
  --dart-define=ST_GOOGLE_WEB_CLIENT_ID=...
```

---

## C. Email OTP (sans Google/Apple)

Déjà fonctionnel : onglet **Email** dans l'app → OTP par mail.

Config prod : SMTP ou Resend dans `.env.production` (`EMAIL_PROVIDER`, `SMTP_*`).

---

## D. Test rapide

1. `curl …/api/auth/social/status` → `enabled: true`
2. Build avec `ST_SOCIAL_AUTH_ENABLED=true`
3. Écran connexion → **Continuer avec Google** / **Apple**
4. Compte créé → profil avec email vérifié

---

## Dépannage

| Problème | Cause probable |
|----------|----------------|
| Google « jeton manquant » | SHA-256 release absent dans Firebase |
| Google 401 serveur | `GOOGLE_OAUTH_CLIENT_IDS` incorrect |
| Google `origin_mismatch` (PWA) | Origine JS absente dans Google Cloud Console — voir `GOOGLE_PWA_ORIGINS.md` |
| Google erreur 500 après connexion | Redéployer backend (`social_oauth.py` manquant sur VPS) + vérifier `GOOGLE_OAUTH_CLIENT_IDS` |
| Apple annulé | Normal si utilisateur ferme la feuille |
| Boutons invisibles | `ST_SOCIAL_AUTH_ENABLED` absent au build |
| 503 non disponible | `ENABLE_SOCIAL_LOGIN=false` sur VPS |
