import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color primaryDeep = Color(0xFF1E3A8A);
  static const Color secondary = Color(0xFF16A34A);
  static const Color danger = Color(0xFFE74C3C);
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF2C3E50);
  static const Color textSecondary = Color(0xFF7F8C8D);
  
  // Couleurs supplémentaires
  static const Color primaryLight = Color(0xFFE3F2FD);
  static const Color success = Color(0xFF27AE60);
  static const Color error = Color(0xFFE74C3C);
  static const Color warning = Color(0xFFF39C12);
  static const Color border = Color(0xFFE5E7EB);
  static const Color shadow = Color(0x0F000000);
  static const Color gold = Color(0xFFFFD700);
  static const Color splashBg = Color(0xFF0D1B4B);
}

class AppStrings {
  static const String appName = 'SombaTeka';
  static const String appFullName = 'SombaTeka';
  static const String tagline = 'La marketplace premium de la RDC';
  static const String country = 'RÉPUBLIQUE DÉMOCRATIQUE DU CONGO';

  static const List<String> navItems = [
    'Accueil',
    'Rechercher',
    'Publier',
    'Messages',
    'Profil',
  ];

  // Liste texte des catégories (utilisée dans search_screen, publish_screen, etc.)
  static const List<String> categories = [
    'Téléphones',
    'Ordinateurs',
    'Électronique',
    'Véhicules',
    'Maison & Meubles',
    'Mode & Vêtements',
    'Sports & Loisirs',
    'Beauté & Santé',
    'Livres & Médias',
    'Jeux & Jouets',
    'Animaux & Accessoires',
    'Immobilier',
    'Emploi & Services',
    'Alimentation & Boissons',
    'Bébé & Enfants',
    'Jardinage',
    'Bureautique',
    'Instruments de musique',
    'Art & Collection',
    'Bijoux & Montres',
  ];

  static const List<Map<String, dynamic>> categoriesIcons = [
    {'name': 'Mode', 'icon': Icons.checkroom_rounded, 'color': Color(0xFFEC4899)},
    {'name': 'Électronique', 'icon': Icons.devices_rounded, 'color': Color(0xFF8B5CF6)},
    {'name': 'Maison', 'icon': Icons.chair_rounded, 'color': Color(0xFFF59E0B)},
    {'name': 'Chaussures', 'icon': Icons.directions_walk_rounded, 'color': Color(0xFF10B981)},
    {'name': 'Téléphones', 'icon': Icons.smartphone_rounded, 'color': Color(0xFF2563EB)},
    {'name': 'Ordinateurs', 'icon': Icons.laptop_rounded, 'color': Color(0xFF06B6D4)},
    {'name': 'Véhicules', 'icon': Icons.directions_car_rounded, 'color': Color(0xFFEF4444)},
    {'name': 'Immobilier', 'icon': Icons.apartment_rounded, 'color': Color(0xFF84CC16)},
  ];

  static const Map<String, double> commissionRates = {
    'electronique': 0.05,
    'mode': 0.15,
    'meubles': 0.10,
    'chaussures': 0.12,
    'maison': 0.08,
    'telephone': 0.06,
    'ordinateur': 0.05,
    'voiture': 0.03,
    'default': 0.07,
  };

  static const List<Map<String, String>> flagPrefixes = [
    {'flag': '🇨🇩', 'code': '+243', 'country': 'RDC'},
    {'flag': '🇨🇬', 'code': '+242', 'country': 'Congo'},
    {'flag': '🇰🇪', 'code': '+254', 'country': 'Kenya'},
    {'flag': '🇷🇼', 'code': '+250', 'country': 'Rwanda'},
    {'flag': '🇳🇬', 'code': '+234', 'country': 'Nigeria'},
    {'flag': '🇿🇦', 'code': '+27', 'country': 'Afrique du Sud'},
    {'flag': '🇫🇷', 'code': '+33', 'country': 'France'},
    {'flag': '🇧🇪', 'code': '+32', 'country': 'Belgique'},
  ];
}

class AppConstants {
  static const double borderRadius = 12.0;
  static const double buttonRadius = 16.0;
  static const double margin = 16.0;
  static const double largeBorderRadius = 16.0;
  static const double topBarHeight = 60.0;
  static const double bottomBarHeight = 70.0;
  static const int maxImages = 5;
  static const int maxListingsOrdinary = 5;
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration splashDuration = Duration(milliseconds: 2400);
}

class AppRoutes {
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String auth = '/auth';
  static const String otp = '/otp';
  static const String main = '/main';
  static const String home = '/home';
  static const String search = '/search';
  static const String favorites = '/favorites';
  static const String publish = '/publish';
  static const String editProfile = '/edit-profile';
  static const String officialSeller = '/official-seller';
  static const String paymentSettings = '/payment-settings';
  static const String privacy = '/privacy';
  static const String messages = '/messages';
  static const String notifications = '/notifications';
  static const String profile = '/profile';
  static const String detail = '/detail';
  static const String similarProducts = '/similar-products';
  static const String officialCatalogPublish = '/official-catalog-publish';
  static const String businessHub = '/business-hub';
  static const String settings = '/settings';
  static const String payment = '/payment';
  static const String chat = '/chat';
}

class AppStatus {
  static const String ordinary = 'ORDINARY';
  static const String official = 'OFFICIAL';
  static const String pending = 'PENDING';
}

class ListingType {
  static const String contact = 'CONTACT';
  static const String payment = 'PAYMENT';
}

class PaymentMethod {
  static const String mtn = 'MTN';
  static const String orange = 'ORANGE';
  /// Moov — bientôt disponible (backend : mtn | orange uniquement).
  static const String moov = 'MOOV';
}