# Google Sign-In PWA — corriger `origin_mismatch`

Erreur typique sur iPhone / Safari / PWA :

> **Erreur 400 : origin_mismatch**  
> Enregistrez l'origine JavaScript dans la Google Cloud Console.

Le code SombaTeka est correct. **Google bloque** tant que l'URL du site n'est pas autorisée sur le **Client OAuth Web**.

---

## Client OAuth à modifier

| Champ | Valeur |
|-------|--------|
| Client ID (Web) | `508328631175-2gpdu705sfbqa8anhj71m42tsf9dpk5p.apps.googleusercontent.com` |
| Console | [Google Cloud → Credentials](https://console.cloud.google.com/apis/credentials) |

Projet Firebase : **SombaTeka** (même projet Google Cloud).

---

## Étapes (5 min)

1. Ouvrir **Google Cloud Console** → **APIs & Services** → **Credentials**
2. Cliquer sur le client **Web application** (celui dont l'ID se termine par `…dpk5p.apps.googleusercontent.com`)
3. Section **Authorized JavaScript origins** → **+ ADD URI** :

```
https://sombatekaonline.com
https://www.sombatekaonline.com
```

4. Section **Authorized redirect URIs** — pour `google_sign_in` web, ajouter si absent :

```
https://sombatekaonline.com
https://sombatekaonline.com/
https://www.sombatekaonline.com
https://www.sombatekaonline.com/
```

5. **Save** — attendre **1 à 5 minutes** (propagation Google)

6. Sur iPhone : fermer Safari → rouvrir le site → retester **Continuer avec Google**

---

## Vérification

- PWA / Safari : bouton Google ouvre le compte Gmail sans erreur 400
- Android app : SHA-256 release dans Firebase (voir `SOCIAL_AUTH_SETUP.md`)
- Backend : `curl -sk https://sombatekaonline.com/api/auth/social/status` → `"google":true`

---

## Apple Sign-In

| Plateforme | Support |
|------------|---------|
| App iOS native (TestFlight / App Store) | Oui |
| PWA Safari iPhone | **Non** (limitation Apple) |
| Android | Non |

Sur PWA iPhone, seuls **téléphone OTP**, **email OTP** et **Google** fonctionnent.

---

## Dépannage

| Symptôme | Action |
|----------|--------|
| Toujours `origin_mismatch` | Vérifier l'URL exacte (https, pas de slash en trop dans *origins*) |
| Google OK mais 401 API | Vérifier `GOOGLE_OAUTH_CLIENT_IDS` dans `.env.production` VPS |
| Bouton Google invisible | Rebuild PWA avec `ST_GOOGLE_WEB_CLIENT_ID` (script `build-web-prod.ps1`) |
