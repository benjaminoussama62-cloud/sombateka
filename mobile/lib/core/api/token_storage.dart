import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const _key = 'st_access_token';
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  Future<void> saveToken(String token) async {
    await _secure.write(key: _key, value: token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('st_logged_in', true);
    // Web: copie de secours (secure storage parfois instable)
    if (kIsWeb) {
      await prefs.setString(_key, token);
    }
  }

  Future<String?> getToken() async {
    var token = await _secure.read(key: _key);
    if ((token == null || token.isEmpty) && kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString(_key);
    }
    return token;
  }

  Future<void> clear() async {
    await _secure.delete(key: _key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('st_logged_in');
    await prefs.remove(_key);
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('st_logged_in') == true && (await getToken()) != null;
  }
}
