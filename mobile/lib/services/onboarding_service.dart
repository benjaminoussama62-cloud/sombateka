import 'package:shared_preferences/shared_preferences.dart';

/// Visites guidées par écran (première connexion).
enum AppTourPage {
  home('tour_home'),
  cart('tour_cart'),
  publish('tour_publish'),
  messages('tour_messages'),
  profile('tour_profile'),
  search('tour_search');

  const AppTourPage(this.key);
  final String key;
}

class AppTourStep {
  const AppTourStep({
    required this.emoji,
    required this.title,
    required this.body,
  });

  final String emoji;
  final String title;
  final String body;
}

class OnboardingService {
  OnboardingService._();
  static final instance = OnboardingService._();

  static const _allDoneKey = 'tour_all_skipped';

  static const steps = <AppTourPage, List<AppTourStep>>{
    AppTourPage.home: [
      AppTourStep(
        emoji: '🏠',
        title: 'Bienvenue sur SombaTeka',
        body: 'Parcourez les annonces Particulier et Professionnel. Utilisez la recherche ou la photo pour trouver un article.',
      ),
      AppTourStep(
        emoji: '🔔',
        title: 'Restez informé',
        body: 'Les notifications et le panier sont accessibles en haut à droite — un badge indique les nouveautés.',
      ),
    ],
    AppTourPage.cart: [
      AppTourStep(
        emoji: '🛒',
        title: 'Votre panier',
        body: 'Ajoutez plusieurs articles, vérifiez les prix puis payez en Mobile Money en toute sécurité.',
      ),
    ],
    AppTourPage.publish: [
      AppTourStep(
        emoji: '📸',
        title: 'Publier une annonce',
        body: 'Photos claires, titre précis, prix en CDF et localisation : plus c\'est complet, plus vous vendez vite.',
      ),
    ],
    AppTourPage.messages: [
      AppTourStep(
        emoji: '💬',
        title: 'Messagerie acheteur / vendeur',
        body: 'Chaque produit a son fil de discussion. Le centre d\'aide est en lecture seule ici — pour écrire au support, allez dans Paramètres.',
      ),
    ],
    AppTourPage.profile: [
      AppTourStep(
        emoji: '👤',
        title: 'Votre profil',
        body: 'Gérez vos annonces, vos favoris, la confidentialité et le centre d\'aide depuis Paramètres.',
      ),
    ],
    AppTourPage.search: [
      AppTourStep(
        emoji: '📷',
        title: 'Recherche par photo',
        body: 'Prenez une photo ou importez depuis la galerie pour retrouver un article visuellement similaire sur SombaTeka.',
      ),
    ],
  };

  Future<bool> shouldShow(AppTourPage page) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_allDoneKey) == true) return false;
    return prefs.getBool(page.key) != true;
  }

  Future<void> markDone(AppTourPage page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(page.key, true);
  }

  Future<void> skipAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_allDoneKey, true);
    for (final p in AppTourPage.values) {
      await prefs.setBool(p.key, true);
    }
  }
}
