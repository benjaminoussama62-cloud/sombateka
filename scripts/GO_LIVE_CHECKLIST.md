# Checklist lancement SombaTeka — ce que le code fait vs ce que VOUS devez faire

## Déjà fait dans le code (déployer pour activer)

| Élément | Fichier / action |
|--------|------------------|
| Inscription sans OTP e-mail | `auth.py`, `auth_screen.dart` |
| Vérification compte (Paramètres) | `users.py`, `settings_screen.dart` |
| Badge Compte vérifié / non vérifié | profils, chat, annonces |
| Bannière accueil « Compte non vérifié » | `account_verification_banner.dart`, `home_screen.dart` |
| CGU + confidentialité (web + app) | `website/terms.html`, `privacy.html`, `legal_content.dart` |
| Health check API (DB + Redis) | `GET /healthz` → `{ ok, db, redis }` |
| Smoke test prod (+ headers / 404 secrets) | `scripts/smoke-test-prod.ps1` |
| Headers HSTS/X-Frame sur PWA | `nginx/snippets/security-headers.conf` |
| Deny `/.env` `/.git` | `nginx/conf.d/30-unified-webapp.conf` |
| Rate-limit IP non spoofable | `proxy-backend.conf` + `middleware.py` |
| Redis password + celery-beat env | `docker-compose.prod.yml` |
| WS auth avant accept + ACL | `app/routers/ws.py` |
| Admin IP allowlist optionnelle | `ADMIN_IP_ALLOWLIST` dans `.env.production` |
| Backup DB | `scripts/backup-db-vps.ps1` + `install-vps-backup-cron.sh` |
| Fix inscription prod (password_hash) | `models.py`, `fix-register-prod.ps1` |

### Déployer maintenant

```powershell
cd "C:\Users\ADMIN\DevAlpha org\SombaTeka"
.\scripts\deploy-all.ps1
.\scripts\smoke-test-prod.ps1
```

Si seulement le backend change :

```powershell
.\scripts\fix-register-prod.ps1
.\scripts\smoke-test-prod.ps1
```

---

## VOUS devez faire à 100 % (humain — impossible à coder)

### 1. Infrastructure et sécurité VPS

- [ ] **Clé SSH** : une fois, `.\scripts\setup-ssh-key-vps.ps1` (mot de passe root une dernière fois)
- [ ] **Backup automatique** : sur le VPS, une fois :
  ```bash
  bash ~/SombaTeka/scripts/install-vps-backup-cron.sh
  ```
  Puis tester : `.\scripts\backup-db-vps.ps1`
- [ ] **Télécharger une sauvegarde** hors VPS (Google Drive / rclone `sombateka-offsite`) au moins 1×/semaine
- [ ] **Firewall** : ports 80/443/22 seulement (`scripts/lock-vps-firewall.sh` si pas fait)
- [ ] **Sentry** (alerting erreurs) : créer un projet → coller `SENTRY_DSN=...` dans `.env.production` → redeploy
- [ ] **Uptime** : Healthchecks.io / UptimeRobot sur `https://sombatekaonline.com/healthz`
- [ ] **Admin IP** (recommandé) : `ADMIN_IP_ALLOWLIST=TON_IP` dans `.env.production`

### 2. E-mails (vérification compte)

Sans ça, « Vérifier mon compte » n'envoie rien.

- [ ] Créer compte [Resend](https://resend.com)
- [ ] Vérifier le domaine `sombatekaonline.com` (DNS SPF/DKIM)
- [ ] Sur le VPS, dans `~/SombaTeka/backend/.env.production` :
  ```
  EMAIL_PROVIDER=resend
  RESEND_API_KEY=re_...
  EMAIL_FROM=noreply@sombatekaonline.com
  ```
- [ ] Redémarrer backend : `docker compose -f docker-compose.prod.yml up -d --force-recreate backend`
- [ ] Tester : inscription → Paramètres → Vérifier mon compte → recevoir le code

### 3. Google / Apple (connexion sociale)

- [ ] **Google Cloud Console** : origines autorisées = `https://sombatekaonline.com` (+ localhost dev)
- [ ] **Firebase** : SHA-1 Android release dans la console Firebase
- [ ] **Apple Sign-In** (iOS) : identifiants + domaine si vous publiez sur App Store

Docs : `mobile/docs/SOCIAL_AUTH_SETUP.md`, `mobile/docs/GOOGLE_PWA_ORIGINS.md`

### 4. Play Store (Android)

- [ ] Build AAB : `.\scripts\deploy-all.ps1 -BuildAndroid`
- [ ] Uploader `mobile\build\app\outputs\bundle\release\app-release.aab` sur Play Console
- [ ] Remplir fiche store (captures, description, catégorie)
- [ ] URLs obligatoires : CGU, confidentialité, suppression compte (déjà sur le site)
- [ ] Test interne / fermé avec 10–20 personnes avant « production » ouverte

Checklist : `mobile/store/play/PLAY_STORE_CHECKLIST.md`

### 5. Paiements Mobile Money (vendeurs officiels)

L'app affiche les flux ; l'argent réel dépend de vos clés opérateur.

- [ ] Tester MTN / Orange en **sandbox puis prod** avec de vrais petits montants
- [ ] Documenter procédure remboursement litige
- [ ] Ne pas promettre « paiement garanti in-app » pour les annonces C2C (paiement hors app = normal)

Doc : `backend/docs/CLES_MOBILE_MONEY_DEMAIN.md`

### 6. Modération et support (sinon flop garanti)

- [ ] **WhatsApp / e-mail support** visible (ex. dans Paramètres ou site)
- [ ] **Admin panel** : vérifier signalements 1×/jour minimum au lancement
- [ ] Processus : annonce frauduleuse → masquer → bannir utilisateur si récidive
- [ ] Répondre aux avis Play Store sous 48 h

### 7. Lancement progressif (marketing)

- [ ] **Ne pas** lancer national d'un coup (pas de pub Facebook massive jour 1)
- [ ] Beta **50–500 utilisateurs** (quartier, école, groupe WhatsApp)
- [ ] Après chaque deploy : `.\scripts\smoke-test-prod.ps1` → tout vert
- [ ] Surveiller logs : `ssh sombateka-vps "docker logs sombateka-backend-prod --tail 100"`
- [ ] Configurer **Sentry** (`SENTRY_DSN` dans `.env.production`) pour erreurs app

### 8. Juridique et confiance

- [ ] Lire CGU / privacy publiées — elles décrivent C2C, vérification compte, signalements
- [ ] Numéro d'identification entreprise si requis localement
- [ ] Politique de réponse aux demandes suppression de compte (délai 30 j max recommandé)

---

## Ordre recommandé cette semaine

1. `deploy-all.ps1` + `smoke-test-prod.ps1`
2. Resend + test e-mail vérification
3. Backup cron sur VPS
4. Play Store test interne (20 testeurs)
5. Semaine beta WhatsApp — corriger bugs remontés
6. Seulement ensuite : pub plus large

---

## En cas de problème

| Symptôme | Action |
|----------|--------|
| Inscription 500 | `.\scripts\diagnose-register-prod.ps1` puis `fix-register-prod.ps1` |
| healthz db=false | `docker ps` sur VPS, redémarrer db + backend |
| Icônes PWA cassées | rebuild web + vérifier font MaterialIcons (smoke test) |
| E-mail non reçu | vérifier Resend + spam + DNS domaine |
