import 'package:flutter/foundation.dart';

import 'app_config.dart';
import 'api_config_stub.dart' if (dart.library.js_interop) 'api_config_web.dart';

/// Base URL de l'API SombaTeka (sans suffixe /api).
class ApiConfig {
  ApiConfig._();

  static String get baseUrl {
    if (kIsWeb) {
      final fromWindow = getWebApiBaseUrl();
      if (fromWindow != null && fromWindow.isNotEmpty) {
        return fromWindow.replaceAll(RegExp(r'/api/?$'), '');
      }
    }

    const fromEnv = String.fromEnvironment('ST_API_BASE_URL');
    if (fromEnv.isNotEmpty) {
      return fromEnv.replaceAll(RegExp(r'/api/?$'), '');
    }

    if (kReleaseMode) return AppConfig.defaultProdApiUrl;

    if (kIsWeb) return 'http://localhost:8000';

    // Émulateur Android → PC local ; appareil physique : passer ST_API_BASE_URL.
    return 'http://10.0.2.2:8000';
  }

  static String get apiPrefix => '/api';

  static String get wsUrl {
    final b = baseUrl.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
    return '$b/ws/chat';
  }
}
