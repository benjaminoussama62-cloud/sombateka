import 'package:shared_preferences/shared_preferences.dart';

/// Province préférée pour filtrer l'accueil (persistée localement).
class PreferredProvinceService {
  PreferredProvinceService._();
  static final PreferredProvinceService instance = PreferredProvinceService._();

  static const _key = 'preferred_province_v1';

  Future<String?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key);
    if (v == null || v.isEmpty) return null;
    return v;
  }

  Future<void> save(String? province) async {
    final prefs = await SharedPreferences.getInstance();
    if (province == null || province.isEmpty) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, province);
    }
  }
}
