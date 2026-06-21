/// Textes légaux complets pour les stores et l'application.
class LegalContent {
  LegalContent._();

  static const String termsTitle = "Conditions générales d'utilisation";
  static const String privacyTitle = 'Politique de confidentialité';

  static const String termsBody = '''
1. Objet
SombaTeka est une marketplace congolaise permettant l'achat et la vente entre particuliers (C2C) et via des vendeurs officiels certifiés. En utilisant l'application, vous acceptez les présentes conditions.

2. Comptes utilisateurs
• L'inscription requiert un numéro de téléphone valide (format E.164, ex. +243…).
• Vous êtes responsable de la confidentialité de votre compte.
• SombaTeka peut suspendre ou bannir un compte en cas de fraude, contenu illicite ou signalements répétés.

3. Annonces C2C (comptes ordinaires)
• Les vendeurs particuliers publient des annonces et négocient directement avec les acheteurs.
• Le paiement s'effectue hors application (Mobile Money, espèces, etc.) entre les parties.
• SombaTeka n'est pas partie au contrat de vente C2C et ne garantit pas la transaction.

4. Vendeurs officiels et paiement in-app
• Les vendeurs certifiés (KYC/KYB validé) peuvent recevoir des paiements Mobile Money via l'application.
• Les fonds sont placés en séquestre jusqu'à confirmation de réception par l'acheteur.
• Une commission plateforme (5 % par défaut) est prélevée sur les ventes officielles.
• Le reversement vendeur intervient sous 24 h (T+1) après validation, sauf litige ouvert.

5. Livraison et code de remise
• Pour les commandes officielles, un code de remise (QR/code) est généré après paiement.
• L'acheteur confirme la réception de l'article pour libérer le paiement au vendeur.

6. Litiges
• En cas de problème (article non conforme, non reçu), l'acheteur peut ouvrir un litige depuis l'application.
• SombaTeka examine le dossier et peut ordonner un remboursement ou valider le paiement vendeur.

7. Contenu interdit
Sont interdits : contrefaçons, armes, drogues, contenu illégal, escroquerie, fausses annonces, harcèlement.

8. Modération
• Les utilisateurs peuvent signaler annonces ou comportements.
• L'équipe SombaTeka peut masquer des annonces ou bannir des comptes.

9. Limitation de responsabilité
SombaTeka met en relation acheteurs et vendeurs. Nous ne sommes pas responsables des transactions C2C directes ni des pertes résultant d'un usage non conforme de l'application.

10. Modifications
SombaTeka peut modifier ces conditions. La poursuite de l'utilisation vaut acceptation des nouvelles conditions.

11. Contact
support@sombateka.cd — République Démocratique du Congo.
''';

  static const String privacyBody = '''
1. Responsable du traitement
SombaTeka — marketplace RDC. Contact : support@sombateka.cd

2. Données collectées
• Identité : numéro de téléphone, nom affiché, e-mail (optionnel).
• Profil : photo, préférences de confidentialité.
• Annonces : photos, descriptions, prix, localisation (ville/quartier).
• Messages : conversations entre utilisateurs.
• Commandes officielles : historique, statut paiement, code de remise.
• KYC vendeurs officiels : documents d'entreprise (RCCM, pièce d'identité, etc.).
• Technique : jeton de session (JWT), jeton push (FCM), logs d'erreurs anonymisés (Sentry).

3. Finalités
• Création et gestion du compte.
• Publication et consultation d'annonces.
• Messagerie et notifications (messages, likes, paiements).
• Paiements Mobile Money sécurisés (vendeurs officiels).
• Modération, prévention de la fraude et support client.
• Amélioration du service et correction de bugs.

4. Base légale
Exécution du contrat (utilisation de la marketplace), intérêt légitime (sécurité, modération), consentement (notifications push, CGU).

5. Partage des données
• Prestataires SMS (OTP) : Africa's Talking ou Twilio.
• Prestataires paiement : MTN Mobile Money, Orange Money.
• Hébergement et stockage images (serveur ou S3).
• Aucune vente de données personnelles à des tiers.

6. Conservation
• Compte actif : données conservées tant que le compte existe.
• Commandes et transactions : conservées pour obligations comptables et litiges.
• OTP : supprimés après utilisation ou expiration (10 min).

7. Vos droits
Vous pouvez consulter, modifier ou supprimer certaines données depuis l'application (profil, confidentialité, Paramètres → Supprimer mon compte). Page web : https://sombateka.cd/account-deletion — Pour toute demande : support@sombateka.cd.

8. Sécurité
Chiffrement HTTPS, stockage sécurisé des jetons sur l'appareil, authentification OTP, rate limiting API.

9. Mineurs
SombaTeka n'est pas destinée aux moins de 18 ans sans autorisation parentale.

10. Modifications
Cette politique peut être mise à jour. La date de dernière mise à jour est indiquée dans l'application.

Dernière mise à jour : juin 2026.
''';
}
