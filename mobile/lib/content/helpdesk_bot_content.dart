/// Options du bot centre d'aide SombaTeka (réponses locales instantanées).
class HelpdeskBotOption {
  const HelpdeskBotOption({
    required this.id,
    required this.title,
    required this.answer,
    this.category = 'Général',
  });

  final String id;
  final String title;
  final String answer;
  final String category;
}

class HelpdeskBotContent {
  HelpdeskBotContent._();

  static const String welcome =
      'Bonjour ! Je suis Maya, votre assistante SombaTeka ✨\n\nChoisissez un sujet ci-dessous — la plupart des réponses sont immédiates. Si votre question n\'apparaît pas, touchez « Autre sujet » en bas pour écrire à notre équipe.';

  static const String escalationPrompt =
      'Mon problème n\'est pas dans la liste';

  static const String afterTicketMessage =
      'Merci pour votre message. Notre équipe SombaTeka l\'a bien reçu et vous contactera dans les plus brefs délais (généralement sous 24–48 h ouvrées). Vous recevrez une notification dès qu\'un conseiller répondra ici.';

  static const List<HelpdeskBotOption> options = [
    HelpdeskBotOption(
      id: 'publish',
      category: 'Annonces',
      title: 'Comment publier une annonce ?',
      answer:
          '1. Touchez « + » (Publier) en bas.\n2. Ajoutez des photos claires (1 produit par annonce).\n3. Renseignez titre, prix en FC, catégorie, état et localisation.\n4. Validez — votre annonce apparaît après modération automatique (quelques minutes).',
    ),
    HelpdeskBotOption(
      id: 'edit_listing',
      category: 'Annonces',
      title: 'Modifier ou supprimer mon annonce',
      answer:
          'Profil → onglet « Mes annonces » → touchez l\'annonce → modifier le prix/description ou « Supprimer ». Une annonce vendue peut être marquée comme vendue depuis le même menu.',
    ),
    HelpdeskBotOption(
      id: 'search',
      category: 'Annonces',
      title: 'Rechercher un produit (texte ou photo)',
      answer:
          'Accueil → barre de recherche : tapez un mot-clé, une marque ou une ville.\nIcône 📷 : recherche par photo (cadrez un seul article, fond neutre). Les résultats les plus proches s\'affichent avec un pourcentage de similarité.',
    ),
    HelpdeskBotOption(
      id: 'become_pro',
      category: 'Compte pro',
      title: 'Devenir vendeur officiel (pro)',
      answer:
          'Paramètres → « Devenir vendeur officiel ».\nPréparez : RCCM ou document entreprise, pièce d\'identité, contacts professionnels.\nSoumettez le dossier KYC — validation sous 2 à 5 jours ouvrés.\nUne fois approuvé : badge boutique, catalogues illimités, mise en avant sur l\'accueil et messagerie clients prioritaire.',
    ),
    HelpdeskBotOption(
      id: 'kyc_status',
      category: 'Compte pro',
      title: 'Suivre ma demande KYC / pro',
      answer:
          'Paramètres → carte compte : le statut s\'affiche (en attente, approuvé, refusé). En cas de refus, corrigez les documents indiqués et resoumettez. Vous serez notifié par l\'app et dans Messages (centre d\'aide).',
    ),
    HelpdeskBotOption(
      id: 'catalog_pro',
      category: 'Compte pro',
      title: 'Publier un catalogue pro (plusieurs variantes)',
      answer:
          'Compte pro validé → Publier → « Catalogue officiel » : une publication, plusieurs tailles/couleurs/stocks. Les acheteurs choisissent les variantes sur la fiche produit.',
    ),
    HelpdeskBotOption(
      id: 'cart',
      category: 'Achats',
      title: 'Utiliser le panier',
      answer:
          'Onglet « Panier » : gardez des articles pour les retrouver facilement. Le paiement in-app n\'est pas encore actif — contactez le vendeur via Messages pour convenir du paiement (Mobile Money hors app, espèces…).',
    ),
    HelpdeskBotOption(
      id: 'pay_official',
      category: 'Achats',
      title: 'Payer un vendeur (en confiance)',
      answer:
          'Sur une boutique officielle, touchez « Contacter la boutique » : la messagerie est liée à l\'annonce. Convenez du lieu de remise et du paiement (Mobile Money ou espèces) hors app. Vérifiez toujours l\'article avant de payer. Le badge KYC signifie que l\'identité de la boutique a été contrôlée par SombaTeka.',
    ),
    HelpdeskBotOption(
      id: 'confirm_delivery',
      category: 'Achats',
      title: 'Confirmer réception / remise',
      answer:
          'Vérifiez l\'article en personne avant de payer hors app. En cas de problème après un échange, signalez l\'annonce ou contactez le centre d\'aide avec photos et détails.',
    ),
    HelpdeskBotOption(
      id: 'dispute',
      category: 'Achats',
      title: 'Litige ou problème d\'achat',
      answer:
          'Contactez d\'abord le vendeur via Messages. Si pas de solution, écrivez au support (Autre sujet) avec photos et captures. SombaTeka peut modérer les comptes ; les remboursements hors app se règlent entre les parties.',
    ),
    HelpdeskBotOption(
      id: 'c2c_pay',
      category: 'Achats',
      title: 'Paiement entre particuliers (C2C)',
      answer:
          'SombaTeka ne gère pas le paiement C2C in-app. Convenez du prix et du mode (Mobile Money direct, espèces) avec le vendeur via Messages. Méfiez-vous des arnaques : privilégiez remise en main propre ou paiement après inspection.',
    ),
    HelpdeskBotOption(
      id: 'messages',
      category: 'Messages',
      title: 'Contacter un vendeur / acheteur',
      answer:
          'Fiche produit → « Contacter » ou « Message ». Chaque annonce a son fil de discussion. Ne partagez jamais votre code PIN Mobile Money dans le chat.',
    ),
    HelpdeskBotOption(
      id: 'notifications',
      category: 'Compte',
      title: 'Notifications et alertes',
      answer:
          'Cloche en haut de l\'accueil : likes, messages, commandes, réponses support. Paramètres → Notifications pour ajuster les préférences. Autorisez les notifications système pour ne rien manquer.',
    ),
    HelpdeskBotOption(
      id: 'profile',
      category: 'Compte',
      title: 'Modifier profil, photo, nom',
      answer:
          'Profil → icône engrenage (Paramètres) → « Modifier profil ». Photo, nom affiché et téléphone : modifiables. Comptes Google/Apple : finalisez téléphone + mot de passe dans Paramètres si demandé.',
    ),
    HelpdeskBotOption(
      id: 'privacy',
      category: 'Compte',
      title: 'Confidentialité et blocage',
      answer:
          'Paramètres → Confidentialité : profil public, afficher le téléphone, autoriser les messages. « Bloquer des utilisateurs » : la personne ne pourra plus vous écrire.',
    ),
    HelpdeskBotOption(
      id: 'delete_account',
      category: 'Compte',
      title: 'Supprimer mon compte',
      answer:
          'Paramètres → « Supprimer mon compte » (action irréversible). Vos annonces actives seront retirées. Les données légales (commandes, litiges) peuvent être conservées selon la loi. Page web : sombatekaonline.com/account-deletion',
    ),
    HelpdeskBotOption(
      id: 'login',
      category: 'Sécurité',
      title: 'Connexion impossible',
      answer:
          'Utilisez l\'e-mail et le mot de passe définis à l\'inscription, ou Google/Apple si le compte est lié. Mot de passe oublié : Connexion → « Mot de passe oublié ? » → code reçu par e-mail.',
    ),
    HelpdeskBotOption(
      id: 'report',
      category: 'Sécurité',
      title: 'Signaler une annonce ou un utilisateur',
      answer:
          'Fiche produit → menu ⋮ → « Signaler ». Indiquez la raison (arnaque, contrefaçon, contenu interdit). Notre modération traite sous 24–72 h. Urgence : « Autre sujet » avec captures d\'écran.',
    ),
    HelpdeskBotOption(
      id: 'mm_seller',
      category: 'Compte pro',
      title: 'Paiements vendeur pro',
      answer:
          'Le paiement Mobile Money in-app n\'est pas encore actif. En attendant, vos acheteurs vous contactent via Messages pour convenir d\'un paiement hors app. Nous activerons le séquestre in-app après ouverture OOO et intégration opérateurs.',
    ),
    HelpdeskBotOption(
      id: 'legal',
      category: 'Légal',
      title: 'CGU, confidentialité, cookies',
      answer:
          'Paramètres → Informations légales : Conditions générales, Politique de confidentialité, Cookies. Support e-mail : support@sombatekaonline.com',
    ),
  ];
}
