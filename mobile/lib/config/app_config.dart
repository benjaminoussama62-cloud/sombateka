import 'package:flutter/foundation.dart';

/// Configuration release (URLs, feature flags) via `--dart-define`.
class AppConfig {
  AppConfig._();

  /// URL API production par défaut — surcharge avec `--dart-define=ST_API_BASE_URL=...`
  static const String defaultProdApiUrl = 'https://api.sombateka.cd';

  static const String termsUrl = String.fromEnvironment(
    'ST_TERMS_URL',
    defaultValue: 'https://sombateka.cd/terms',
  );

  static const String privacyUrl = String.fromEnvironment(
    'ST_PRIVACY_URL',
    defaultValue: 'https://sombateka.cd/privacy',
  );

  static const String accountDeletionUrl = String.fromEnvironment(
    'ST_DELETE_ACCOUNT_URL',
    defaultValue: 'https://sombateka.cd/account-deletion',
  );

  static const String supportEmail = String.fromEnvironment(
    'ST_SUPPORT_EMAIL',
    defaultValue: 'support@sombateka.cd',
  );

  /// Connexion Google/Apple réelle — masquée en release tant que OAuth n'est pas branché.
  static bool get showSocialLogin => kDebugMode;

  /// Paiement : en release on attend la confirmation Mobile Money (pas d'auto-success).
  static bool get paymentPollingEnabled => kReleaseMode;

  static String get buildModeLabel => kReleaseMode ? 'production' : 'development';
}
