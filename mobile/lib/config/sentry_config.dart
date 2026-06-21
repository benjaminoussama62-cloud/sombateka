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

    await SentryFlutter.init(
      (options) {
        options.dsn = dsn;
        options.environment = kReleaseMode ? 'production' : 'development';
        options.tracesSampleRate = kReleaseMode ? 0.2 : 1.0;
        options.sendDefaultPii = false;
      },
      appRunner: () async {
        await bootstrap();
        runApp(app);
      },
    );
  }
}
