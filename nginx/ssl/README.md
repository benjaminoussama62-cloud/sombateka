# Certificats TLS — SombaTeka

Nginx attend ces fichiers dans ce dossier :

| Fichier | Description |
|---------|-------------|
| `cert.pem` | Certificat (chaîne complète) |
| `key.pem` | Clé privée |

## Option A — Let's Encrypt (recommandé)

Sur le serveur de production (Ubuntu/Debian), avec DNS pointant vers le serveur :

```bash
# Depuis la racine du dépôt
sudo apt install certbot
sudo mkdir -p /var/www/certbot nginx/ssl

# Obtenir le certificat (nginx doit être arrêté ou en mode HTTP seulement)
sudo certbot certonly --webroot \
  -w /var/www/certbot \
  -d sombateka.cd \
  -d www.sombateka.cd \
  -d api.sombateka.cd \
  --email support@sombateka.cd \
  --agree-tos

# Copier vers le dossier monté par Docker
sudo cp /etc/letsencrypt/live/sombateka.cd/fullchain.pem nginx/ssl/cert.pem
sudo cp /etc/letsencrypt/live/sombateka.cd/privkey.pem nginx/ssl/key.pem
sudo chmod 644 nginx/ssl/cert.pem
sudo chmod 600 nginx/ssl/key.pem
```

Renouvellement automatique (cron) :

```bash
0 3 * * * certbot renew --quiet && cp /etc/letsencrypt/live/sombateka.cd/fullchain.pem /path/to/SombaTeka/nginx/ssl/cert.pem && cp /etc/letsencrypt/live/sombateka.cd/privkey.pem /path/to/SombaTeka/nginx/ssl/key.pem && docker compose -f /path/to/SombaTeka/backend/docker-compose.prod.yml exec nginx nginx -s reload
```

Script fourni : `scripts/setup-tls.sh`

## Option B — Certificat commercial

Placer `fullchain.pem` → `cert.pem` et `private.key` → `key.pem`.

## Développement local (auto-signé)

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/ssl/key.pem \
  -out nginx/ssl/cert.pem \
  -subj "/CN=localhost"
```

> Les navigateurs afficheront un avertissement — réservé aux tests locaux.

## Vérification

```bash
curl -I https://api.sombateka.cd/healthz
curl -I https://sombateka.cd/privacy
```
