# Google Merchant Center — SombaTeka (listings Shopping gratuits)

Objectif : faire apparaître **tous les produits** dans Google (onglet Shopping / résultats produits), **sans Google Ads**.

## Architecture SombaTeka (déjà en prod)

| Couche | URL / mécanisme | Rôle |
|--------|-----------------|------|
| Feed XML | `https://sombatekaonline.com/feeds/google-merchant.xml` | Source principale Merchant Center |
| Feed TSV | `https://sombatekaonline.com/feeds/google-merchant.tsv` | Alternative (souvent plus stable) |
| Pages produit SEO | `/annonce/{id}-slug` | Landing crawlable + schema Product |
| Sync publication | auto à chaque publish/update/delete | IndexNow + Content API (si clés) |
| Sync batch | Celery toutes les 6 h | Re-pousse le catalogue via Content API |

## Étape 1 — Créer Merchant Center (toi, 15–20 min)

1. Va sur [https://merchants.google.com](https://merchants.google.com)
2. Crée un compte avec l’email Google de SombaTeka
3. Ajoute le site : `https://sombatekaonline.com`
4. Vérifie le domaine (balise HTML Search Console ou DNS — déjà vérifié Search Console = OK souvent)
5. Pays cible : **Congo-Kinshasa (CD)** si proposé ; sinon le pays le plus proche accepté + devise CDF
6. Active **Listings gratuits** / **Free listings** (pas de campagne Ads)

## Étape 2 — Ajouter le flux produits

Dans Merchant Center → **Produits** → **Flux** → Ajouter un flux :

- Nom : `SombaTeka catalogue`
- Mode : **Scheduled fetch** (récupération planifiée)
- URL du fichier :
  - recommandé : `https://sombatekaonline.com/feeds/google-merchant.tsv`
  - ou : `https://sombatekaonline.com/feeds/google-merchant.xml`
- Fréquence : **horaire** (ou quotidien au minimum)
- Langue : français
- Pays : CD

Google récupère le flux → valide → les produits éligibles apparaissent progressivement (souvent 24–72 h pour les premiers).

## Étape 3 — Content API temps réel (optionnel, niveau pro)

Pour pousser un produit **dès la publication** (sans attendre le prochain fetch) :

1. Google Cloud Console → projet → activer **Content API for Shopping**
2. Créer un **compte de service** → clé JSON
3. Dans Merchant Center → Paramètres → Accès et utilisateurs → ajouter l’email du service account (Admin)
4. Sur le VPS, dans `.env.production` :

```env
GOOGLE_MERCHANT_ENABLED=true
GOOGLE_MERCHANT_ID=123456789
GOOGLE_MERCHANT_TARGET_COUNTRY=CD
GOOGLE_MERCHANT_SERVICE_ACCOUNT_FILE=/run/secrets/google-merchant.json
# OU
# GOOGLE_MERCHANT_SERVICE_ACCOUNT_JSON={"type":"service_account",...}
```

5. Rebuild backend + celery-worker + celery-beat

Sans ces clés, le système reste en mode **feed URL** (déjà opérationnel).

## Contrôles admin API

- `GET /api/admin/merchant/status` — état du flux + nb produits éligibles
- `POST /api/admin/merchant/sync` — force un sync Content API de tout le catalogue (super admin)

## Règles d’éligibilité côté SombaTeka

Un produit entre dans le feed seulement s’il a :
- statut `active`
- **prix** (`price_cdf`)
- **au moins 1 image**

Sinon il est exclu (exigence Google).

## Ce que Merchant Center n’est PAS

- Ce n’est **pas** Google Ads / « Produits sponsorisés » payants
- Ce n’est **pas** une indexation organique web instantanée
- C’est le canal **Shopping / fiches produit Google** (comme les grandes marques)

## Après configuration

1. Merchant Center → Diagnostics produits : corriger les alertes (image, prix, landing)
2. Search Console : garder `sitemap-index.xml` vert
3. Publier une nouvelle annonce avec photo + prix → vérifier qu’elle apparaît dans le feed XML/TSV sous 1 minute
