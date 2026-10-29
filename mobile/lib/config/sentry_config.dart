import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Configuration Sentry (DSN via `--dart-define=SENTRY_DSN=...`).
class SentryConfig {
  SentryConfig._();

  static String? get dsn {
    const fromEnv = String.fromEnvironment('SENTRY_DSN');
    if (fromEnv.isNotEmpty) return fromEnv;
    return null;
  }

  static Future<void> launch({
    required Future<void> Function() bootstrap,
    required Widget app,
  }) async {
    final dsn = SentryConfig.dsn;
    if (dsn == null || dsn.isEmpty) {
      await bootstrap();
      runApp(app);
      return;
    }

    // runApp ne doit JAMAIS dépendre de la complétion de l'init Sentry :
    // si l'init pende (réseau, DNS), le premier frame serait bloqué à vie.
    var started = false;
    Future<void> start() async {
      if (started) return;
      started = true;
      await bootstrap();
      runApp(app);
    }

    await SentryFlutter.init(
      (options) {
        options.dsn = dsn;
        options.environment = kReleaseMode ? 'production' : 'development';
        options.tracesSampleRate = kReleaseMode ? 0.2 : 1.0;
        options.sendDefaultPii = false;
      },
      appRunner: start,
    ).timeout(
      const Duration(seconds: 5),
      onTimeout: () async {
        debugPrint('SentryConfig: init timed out — starting app without it');
        await start();
      },
    );
  }
}
