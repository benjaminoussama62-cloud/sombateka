import 'package:flutter/foundation.dart';

/// Configuration release (URLs, feature flags) via `--dart-define`.
class AppConfig {
  AppConfig._();

  /// URL API production par défaut — surcharge avec `--dart-define=ST_API_BASE_URL=...`
  static const String defaultProdApiUrl = 'https://sombatekaonline.com';

  static const String termsUrl = String.fromEnvironment(
    'ST_TERMS_URL',
    defaultValue: 'https://sombatekaonline.com/terms',
  );

  static const String privacyUrl = String.fromEnvironment(
    'ST_PRIVACY_URL',
    defaultValue: 'https://sombatekaonline.com/privacy',
  );

  static const String accountDeletionUrl = String.fromEnvironment(
    'ST_DELETE_ACCOUNT_URL',
    defaultValue: 'https://sombatekaonline.com/account-deletion',
  );

  static const String supportEmail = String.fromEnvironment(
    'ST_SUPPORT_EMAIL',
    defaultValue: 'support@sombatekaonline.com',
  );

  /// Connexion Google/Apple — activée par défaut en release (désactiver avec ST_SOCIAL_AUTH_ENABLED=false).
  static const bool socialAuthEnabled = bool.fromEnvironment(
    'ST_SOCIAL_AUTH_ENABLED',
    defaultValue: true,
  );

  /// Client OAuth Web Google (serverClientId Android) — ST_GOOGLE_WEB_CLIENT_ID
  static const String googleWebClientId = String.fromEnvironment(
    'ST_GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  static const bool appleSignInEnabled = bool.fromEnvironment(
    'ST_APPLE_SIGNIN_ENABLED',
    defaultValue: true,
  );

  /// Google : app native + PWA web (client OAuth Web requis).
  static bool get showGoogleLogin =>
      socialAuthEnabled &&
      ((!kIsWeb &&
              (defaultTargetPlatform == TargetPlatform.android ||
                  defaultTargetPlatform == TargetPlatform.iOS)) ||
          (kIsWeb && googleWebClientId.isNotEmpty));

  /// Apple : apps natives iOS/Android uniquement (pas Safari / PWA).
  static bool get showAppleLogin =>
      socialAuthEnabled &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  /// Rétrocompat — au moins un provider social visible.
  static bool get showSocialLogin => showGoogleLogin || showAppleLogin;

  /// Paiement in-app (Mobile Money / séquestre). Off jusqu'à OOO + clés opérateurs.
  /// Réactiver : `--dart-define=ST_PAYMENTS_ENABLED=true`
  static const bool paymentsEnabled = bool.fromEnvironment(
    'ST_PAYMENTS_ENABLED',
    defaultValue: false,
  );

  /// Paiement : en release on attend la confirmation Mobile Money (pas d'auto-success).
  static bool get paymentPollingEnabled => paymentsEnabled && kReleaseMode;

  static String get buildModeLabel => kReleaseMode ? 'production' : 'development';

  /// DevAlpha Cyber HQ — `--dart-define=ST_CYBER_HQ_URL=...`
  static const String cyberHqUrl = String.fromEnvironment(
    'ST_CYBER_HQ_URL',
    defaultValue: '',
  );

  /// DevAlpha Cyber agent key — `--dart-define=ST_CYBER_AGENT_KEY=...`
  static const String cyberAgentKey = String.fromEnvironment(
    'ST_CYBER_AGENT_KEY',
    defaultValue: '',
  );
}
