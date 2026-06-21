# SombaTeka — Panneau Admin

Interface web **séparée de l'app mobile** pour modérer la plateforme (style Wildberries / Kufar).

## Accès

1. Démarrez le backend :

```powershell
cd backend
.\.venv\Scripts\uvicorn.exe app.main:app --host 0.0.0.0 --port 8000 --reload
```

Redémarrez le backend après une mise à jour du dépôt (sinon `/admin` peut renvoyer 404).

2. Ouvrez dans le navigateur :

- **Connexion :** http://localhost:8000/admin/login  
- **Tableau de bord :** http://localhost:8000/admin/dashboard (après connexion)

## Connexion

Endpoint dédié : `POST /api/auth/admin/login` (admin / modérateur uniquement).

| Champ | Valeur (dev) |
|--------|--------|
| Téléphone | `+243900000001` |
| Mot de passe | `developer` ou `ADMIN_PANEL_PASSWORD` dans `.env` |

**Sécurité :** session courte, rate-limit sur la connexion, en-têtes CSP sur `/admin`, token en `sessionStorage` (fermé avec l'onglet).

Les **commandes** des boutiques ne sont **pas** gérées ici — chaque vendeur les traite dans l'app mobile.

Le compte admin est créé automatiquement au démarrage en environnement `dev`.

## Fonctions

- **Tableau de bord** — statistiques (utilisateurs, KYC, signalements, annonces, commandes)
- **Comptes pro (KYC)** — dossier complet (infos, checklist, documents RCCM/ID/NIF), avis équipe, approuver / refuser avec motif
- **Signalements** — traiter, clôturer, bannir la cible
- **Utilisateurs** — recherche, bannir / débannir, révoquer le statut pro
- **Annonces** — masquer / rétablir
- **Commandes** — vue des commandes Mobile Money

## API

Toutes les actions passent par `/api/admin/*` (JWT admin ou modérateur requis).

## Production

- Désactiver `allow_dev_password_login` et utiliser OTP + comptes `role=admin` en base.
- Protéger `/admin` derrière VPN ou authentification reverse-proxy (Nginx).
