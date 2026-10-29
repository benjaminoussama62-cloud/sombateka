/// DevAlpha Cyber — SDK Flutter (SombaTeka)
///
/// Couvre: secure storage, HTTPS-only, signals tamper/pinning → HQ.
///
/// Pubspec (dans l'app) :
///   flutter_secure_storage: ^9.0.0
///   http: ^1.2.0
///
/// Usage:
///   final army = CyberArmyMobile(hqUrl: '...', agentKey: '...');
///   await army.init();
///   await army.secureWrite('auth_token', token);
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class CyberArmyMobile {
  CyberArmyMobile({
    required this.hqUrl,
    required this.agentKey,
    this.appId = 'sombateka',
    this.pinnedHosts = const [],
  });

  final String hqUrl;
  final String agentKey;
  final String appId;
  final List<String> pinnedHosts;

  final FlutterSecureStorage _store = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> init() async {
    await report('mobile_boot', severity: 1, payload: {'appId': appId});
  }

  Future<void> report(String type, {int severity = 3, Map<String, dynamic>? payload}) async {
    try {
      final uri = Uri.parse('${hqUrl.replaceAll(RegExp(r'/$'), '')}/v1/ingest');
      await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'x-cyber-agent-key': agentKey,
            },
            body: jsonEncode({
              'type': type,
              'severity': severity,
              'path': 'mobile://$appId',
              'method': 'MOBILE',
              'ua': 'cyber-mobile-flutter/$appId',
              'payload': payload ?? {},
            }),
          )
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      /* offline ok */
    }
  }

  Future<void> secureWrite(String key, String value) => _store.write(key: key, value: value);
  Future<String?> secureRead(String key) => _store.read(key: key);
  Future<void> secureDelete(String key) => _store.delete(key: key);

  /// Interdit HTTP clair (anti-MitM basique).
  Future<http.Response> secureGet(Uri uri, {Map<String, String>? headers}) async {
    if (uri.scheme != 'https') {
      await report('mitm_suspect', severity: 4, payload: {'url': uri.toString(), 'reason': 'cleartext'});
      throw Exception('cyber-army: HTTPS obligatoire');
    }
    return http.get(uri, headers: headers);
  }

  Future<http.Response> securePost(Uri uri, {Object? body, Map<String, String>? headers}) async {
    if (uri.scheme != 'https') {
      await report('mitm_suspect', severity: 4, payload: {'url': uri.toString(), 'reason': 'cleartext'});
      throw Exception('cyber-army: HTTPS obligatoire');
    }
    return http.post(uri, headers: headers, body: body);
  }

  Future<Map<String, dynamic>> checkIntegrity({
    bool isRooted = false,
    bool isDebuggerAttached = false,
    bool apkTampered = false,
  }) async {
    if (isRooted || apkTampered) {
      await report('mobile_tamper', severity: 5, payload: {
        'isRooted': isRooted,
        'apkTampered': apkTampered,
      });
      return {'ok': false, 'reason': 'tamper'};
    }
    if (!kDebugMode && isDebuggerAttached) {
      await report('mobile_re_suspect', severity: 4, payload: {'debugger': true});
      return {'ok': false, 'reason': 'debug'};
    }
    return {'ok': true};
  }

  Future<void> reportPinningFailure(String host, String error) async {
    await report('mobile_pinning_fail', severity: 5, payload: {'host': host, 'error': error});
  }
}
