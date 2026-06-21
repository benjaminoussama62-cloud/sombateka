# SombaTeka — Déploiement production



Guide complet pour mettre SombaTeka en ligne (API, site légal, stores mobile).



## Architecture



| Composant | Technologie |

|-----------|-------------|

| API | FastAPI + Gunicorn (4 workers) |

| DB | PostgreSQL 16 |

| Cache / rate limit | Redis |

| Jobs | Celery worker + beat (reversements T+1, escrow) |

| Edge | Nginx (TLS, 2 vhosts) |

| Site | Pages statiques `website/` |

| Mobile | Flutter → `https://api.sombateka.cd` |



## DNS requis



| Enregistrement | Type | Cible |

|----------------|------|-------|

| `sombateka.cd` | A / AAAA | IP serveur production |

| `www.sombateka.cd` | CNAME | `sombateka.cd` |

| `api.sombateka.cd` | A / AAAA | IP serveur production |



## Prérequis serveur



- Ubuntu 22.04+ ou Debian 12+

- Docker + Docker Compose v2

- Ports 80 et 443 ouverts

- 2 Go RAM minimum (4 Go recommandé)



## Déploiement en 5 étapes



### 1. Secrets production



```bash

cp backend/.env.production.example backend/.env.production

# Éditer et remplir : JWT_SECRET, DB_PASSWORD, ADMIN_PANEL_PASSWORD, SMS, email

openssl rand -hex 32   # pour JWT_SECRET

```



Variables **obligatoires** avant lancement public :



- `JWT_SECRET`, `DB_PASSWORD`, `ADMIN_PANEL_PASSWORD`

- `SMS_PROVIDER` + credentials (Africa's Talking ou Twilio)

- `EMAIL_PROVIDER` + SMTP ou Resend

- `CORS_ORIGINS`



Variables **paiements** (vendeurs officiels) : voir [backend/docs/PAYMENTS_RUNBOOK.md](backend/docs/PAYMENTS_RUNBOOK.md)



### 2. Certificats TLS



```bash

# Voir nginx/ssl/README.md

./scripts/setup-tls.sh

```



### 3. Lancer la stack



```bash

export DB_PASSWORD='votre-mot-de-passe-fort'

./scripts/deploy-prod.sh

```



Windows :



```powershell

$env:DB_PASSWORD = 'votre-mot-de-passe'

.\scripts\deploy-prod.ps1

```



Services : `db`, `redis`, `backend`, `celery-worker`, `celery-beat`, `nginx`



### 4. Vérifier



```bash

curl -s https://api.sombateka.cd/healthz

curl -sI https://sombateka.cd/privacy

curl -sI https://sombateka.cd/terms

curl -sI https://sombateka.cd/account-deletion

```



### 5. Créer un administrateur



```bash

docker compose -f backend/docker-compose.prod.yml exec backend python scripts/ensure-admin.py

```



Panneau modération : `https://api.sombateka.cd/admin/`



## URLs production



| Service | URL |

|---------|-----|

| API health | `https://api.sombateka.cd/healthz` |

| Swagger | `https://api.sombateka.cd/docs` |

| Admin | `https://api.sombateka.cd/admin/` |

| CGU | `https://sombateka.cd/terms` |

| Confidentialité | `https://sombateka.cd/privacy` |

| Suppression compte | `https://sombateka.cd/account-deletion` |

| Webhook MTN | `https://api.sombateka.cd/api/webhooks/mtn` |

| Webhook Orange | `https://api.sombateka.cd/api/webhooks/orange` |



## Mobile (build release)



```bash

cd mobile

./scripts/publish-play-store.ps1

```



Voir [mobile/STORE_RELEASE.md](mobile/STORE_RELEASE.md) et [mobile/IOS_RELEASE.md](mobile/IOS_RELEASE.md).



## Sauvegardes



```bash

./scripts/backup-postgres.sh

# Cron quotidien recommandé : 0 2 * * * /path/to/scripts/backup-postgres.sh

```



## Monitoring



- Sentry : `SENTRY_DSN` dans `.env.production` + dart-define mobile

- Logs : `docker compose -f backend/docker-compose.prod.yml logs -f backend`



## Checklist complète



Voir [PRODUCTION_CHECKLIST.md](PRODUCTION_CHECKLIST.md) à la racine du dépôt.


