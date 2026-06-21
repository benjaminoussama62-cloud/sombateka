# Phase 1 — Deploiement beta (APK mondial)

Guide pas a pas pour tester SombaTeka avec des utilisateurs Android **sans Play Store**.

**Ta situation :** pas de VPS, pas de domaine, pas de SMS → on fait tout dans l'ordre.

---

## Vue d'ensemble (2-3 heures)

```
[1] Louer VPS          ~15 min
[2] SMS Africa's Talking ~20 min
[3] Domaine gratuit     ~10 min  (sslip.io — pas besoin d'acheter sombateka.cd)
[4] Deployer serveur    ~30 min
[5] Build APK           ~10 min
[6] Envoyer aux testeurs
```

---

## Etape 1 — Louer un VPS

**Recommande pour l'Afrique / Europe :**

| Hebergeur | Prix | Lien |
|-----------|------|------|
| Hetzner | ~4 EUR/mois | hetzner.com/cloud |
| Contabo | ~5 EUR/mois | contabo.com |
| DigitalOcean | ~6 USD/mois | digitalocean.com |

**Configuration minimale :** Ubuntu 22.04, 2 Go RAM, 1 vCPU, 20 Go disque.

Apres creation, note :
- **IP du serveur** (ex. `123.45.67.89`)
- **Mot de passe root** ou cle SSH

---

## Etape 2 — SMS (Africa's Talking)

Indispensable pour que les testeurs recoivent le code OTP sur leur telephone.

1. Creer un compte : https://account.africastalking.com/auth/register
2. Dashboard → **Settings → API Key** → copier la cle
3. En sandbox (gratuit pour tester) :
   - `SMS_USERNAME=sandbox`
   - `SMS_API_KEY=votre_cle`
   - Ajouter les numeros testeurs dans **Sandbox → Phone numbers**

4. Sur ton PC, edite `backend/.env.production` :

```env
SMS_PROVIDER=africas_talking
SMS_API_KEY=votre_cle_api
SMS_USERNAME=sandbox
SMS_SENDER_ID=SombaTeka
```

> **Mode beta sans SMS configure :** le template beta expose l'OTP dans la reponse API (`EXPOSE_OTP_IN_RESPONSE=true`). Utile pour 2-3 testeurs seulement — desactive avant le public.

Guide detaille : `backend/docs/SMS_SETUP.md`

---

## Etape 3 — Domaine HTTPS gratuit (sans acheter sombateka.cd)

Ton app Android exige **HTTPS**. Sans domaine achete, utilise **sslip.io** :

Si ton VPS a l'IP `123.45.67.89`, ton domaine gratuit est :

```
123-45-67-89.sslip.io
```

(tirets `-` a la place des points `.`)

Ce domaine pointe automatiquement vers ton IP — **aucune config DNS**.

Tu utiliseras : `https://123-45-67-89.sslip.io` comme URL API.

---

## Etape 4 — Generer les secrets (sur ton PC Windows)

```powershell
cd "C:\Users\ADMIN\DevAlpha org\SombaTeka"
.\scripts\setup-beta-secrets.ps1 -ApplyBetaTemplate
```

Cela cree :
- `backend/.env.production` (secrets JWT, DB, admin)
- `backend/secrets-beta.local.txt` (garde-le precieusement)

Edite ensuite `backend/.env.production` :
- Colle tes cles SMS Africa's Talking
- Remplace `PUBLIC_BASE_URL=https://VOTRE-IP-sslip.io` par ton vrai sslip.io

---

## Etape 5 — Envoyer le projet sur le VPS

**Option A — WinSCP / FileZilla :**
1. Connecte-toi en SFTP a `root@123.45.67.89`
2. Upload tout le dossier `SombaTeka` vers `/root/SombaTeka`

**Option B — Git (si repo GitHub) :**
```bash
ssh root@123.45.67.89
git clone https://github.com/VOTRE-COMPTE/SombaTeka.git
```

**Option C — SCP depuis PowerShell :**
```powershell
scp -r "C:\Users\ADMIN\DevAlpha org\SombaTeka" root@123.45.67.89:/root/
```

---

## Etape 6 — Deployer sur le VPS

Connecte-toi en SSH :

```bash
ssh root@123.45.67.89
cd /root/SombaTeka
chmod +x scripts/deploy-vps.sh
sudo bash scripts/deploy-vps.sh --domain 123-45-67-89.sslip.io --skip-clone
```

(Remplace par ton IP sslip.io reelle)

Le script installe Docker, obtient le certificat TLS, demarre l'API.

**Verifier :**
```bash
curl https://123-45-67-89.sslip.io/healthz
```

Reponse attendue : `{"status":"ok",...}`

---

## Etape 7 — Build APK beta (ton PC)

```powershell
cd "C:\Users\ADMIN\DevAlpha org\SombaTeka\mobile"
.\scripts\build-apk-beta.ps1 -ApiUrl "https://123-45-67-89.sslip.io"
```

APK produit : `mobile/build/app/outputs/flutter-apk/app-release.apk`

---

## Etape 8 — Distribuer aux testeurs

1. Envoie `app-release.apk` via WhatsApp, Telegram, Google Drive, etc.
2. Dis aux testeurs :
   - Autoriser **installation depuis sources inconnues**
   - Installer l'APK
   - S'inscrire avec leur numero +243...
   - Entrer le code OTP recu par SMS

---

## Depannage

| Probleme | Solution |
|----------|----------|
| OTP non recu | Verifier SMS Africa's Talking + numero dans sandbox |
| App ne se connecte pas | Verifier URL dans APK = URL du serveur |
| `healthz` ne repond pas | `docker compose -f backend/docker-compose.prod.yml logs backend` |
| Certificat TLS echoue | Port 80 ouvert ? IP correcte dans sslip.io ? |

---

## Quand passer au Play Store ?

Quand 10-20 testeurs utilisent l'app sans crash pendant 1-2 semaines :
1. Acheter le domaine `sombateka.cd`
2. Desactiver `EXPOSE_OTP_IN_RESPONSE` dans `.env.production`
3. `.\scripts\publish-play-store.ps1`

Checklist complete : `PRODUCTION_CHECKLIST.md`
