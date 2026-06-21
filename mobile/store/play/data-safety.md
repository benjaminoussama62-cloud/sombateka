# Google Play — Data Safety (SombaTeka)

Réponses recommandées pour le formulaire **Sécurité des données** dans Play Console.

## Collecte de données

| Type | Collecté | Partagé | Obligatoire | Finalité |
|------|----------|---------|-------------|----------|
| Numéro de téléphone | Oui | Non (SMS OTP) | Oui | Compte, authentification |
| Nom | Oui | Non | Non | Profil |
| E-mail | Oui | Non | Non | Profil (optionnel) |
| Photos | Oui | Non | Non | Annonces, avatar |
| Messages | Oui | Non | Non | Messagerie vendeur/acheteur |
| Localisation approximative | Oui | Non | Non | Ville/quartier annonces |
| Identifiants appareil (FCM) | Oui | Non | Non | Notifications push |
| Historique achats | Oui | Non | Non | Commandes officielles |
| Documents KYC | Oui | Non | Non | Vendeurs officiels uniquement |
| Logs crash (Sentry) | Oui | Oui (Sentry) | Non | Stabilité app |

## Chiffrement

- Données en transit : **Oui** (HTTPS/TLS)
- Données au repos côté serveur : **Oui** (infrastructure sécurisée)

## Suppression des données

- **Oui** — l'utilisateur peut demander la suppression :
  - In-app : Paramètres → Supprimer mon compte
  - Web : https://sombateka.cd/account-deletion
  - E-mail : support@sombateka.cd

## Permissions Android justifiées

| Permission | Justification |
|------------|---------------|
| INTERNET | API, images, messagerie |
| CAMERA | Photo annonces / avatar |
| READ_MEDIA_IMAGES | Galerie pour photos annonces |
| POST_NOTIFICATIONS | Alertes messages et commandes |
| VIBRATE | Notifications |

## Public cible

- App **non destinée aux enfants** (18+)
- Contenu généré par les utilisateurs (UGC) — modération active
