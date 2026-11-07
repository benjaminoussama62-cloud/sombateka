import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const _key = 'st_access_token';
  static const _refreshKey = 'st_refresh_token';
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  Future<void> saveToken(String token, {String? refreshToken}) async {
    await _secure.write(key: _key, value: token);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _secure.write(key: _refreshKey, value: refreshToken);
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_refreshKey, refreshToken);
      }
    }
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

  Future<String?> getRefreshToken() async {
    var token = await _secure.read(key: _refreshKey);
    if ((token == null || token.isEmpty) && kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString(_refreshKey);
    }
    return token;
  }

  Future<void> clear() async {
    await _secure.delete(key: _key);
    await _secure.delete(key: _refreshKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('st_logged_in');
    await prefs.remove(_key);
    await prefs.remove(_refreshKey);
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('st_logged_in') == true &&
        ((await getToken()) != null || (await getRefreshToken()) != null);
  }
}
