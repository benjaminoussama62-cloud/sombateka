# SombaTeka — Application Web (Flutter)

**Même app que Android/iOS**, dans le navigateur — même code, même design, mêmes écrans.

Pas besoin de réécrire le site en React/HTML : SombaTeka est déjà une app **Flutter** compilée pour le Web.

---

## Fonctionnalités Web (identiques à l'app)

| Fonction | Web |
|----------|-----|
| Accueil, annonces, carrousel photos | Oui |
| Recherche, filtres, photo similaire | Oui |
| Publication annonce + photos | Oui (galerie) |
| Messagerie | Oui |
| Profil, paramètres, suppression compte | Oui |
| Vendeur officiel + paiement MM | Oui (redirect opérateur) |
| Notifications push | Non (navigateur) |
| Google / Apple Sign-In | Non (OTP téléphone/email) |

---

## Build sur ton PC

```powershell
cd mobile
.\scripts\build-web-prod.ps1
```

Produit le dossier **`web-dist/`** à la racine du repo (app + pages légales).

---

## Déploiement VPS

```powershell
# Depuis la racine du repo
.\scripts\deploy-web-vps.ps1
```

Puis **une fois sur le VPS** :

```bash
cd ~/SombaTeka/backend

# Éviter conflit nginx (2 blocs server_name identiques)
mv ~/SombaTeka/nginx/conf.d/10-api.conf ~/SombaTeka/nginx/conf.d/10-api.conf.bak 2>/dev/null || true
mv ~/SombaTeka/nginx/conf.d/20-web.conf ~/SombaTeka/nginx/conf.d/20-web.conf.bak 2>/dev/null || true

export DB_PASSWORD="$(grep '^DB_PASSWORD=' .env.production | cut -d= -f2-)"
docker compose -f docker-compose.prod.yml up -d nginx
```

**URL utilisateurs :** https://164-90-214-206.sslip.io/  
(Pas de téléchargement — l'app s'ouvre directement.)

---

## Capacité VPS avec Web statique

Servir Flutter en **fichiers statiques** (nginx) est **beaucoup plus léger** que `flutter run` :

| Ressource | Impact |
|-----------|--------|
| Fichiers JS/WASM | Servis par nginx (cache) |
| API / DB | Même backend qu'avant |

Le goulot reste l'**API + PostgreSQL**, pas le front. Même estimations qu'avant (~200–400 DAU sur 1 Go), mais le web scale mieux côté front.

---

## PWA (installer sur écran d'accueil)

L'app inclut `manifest.json` — sur Chrome mobile : **Ajouter à l'écran d'accueil**.

---

## Domaine sombateka.cd

Quand le domaine est acheté :

1. Rebuild avec `-Domain sombateka.cd -ApiUrl https://api.sombateka.cd` (ou même domaine unifié)
2. Mettre à jour `30-unified-webapp.conf` → `server_name`
3. Certificat Let's Encrypt pour le nouveau domaine

---

## Play Store

Tu peux **garder l'APK** pour ceux qui préfèrent l'app native, **et** promouvoir le site web pour les autres — même compte, même API.
