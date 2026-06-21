import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

class OfflineCache {
  static const _listingsBox = 'st_listings_cache';
  static const _userBox = 'st_user_cache';
  static const _syncBox = 'st_sync_queue';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<String>(_listingsBox);
    await Hive.openBox<String>(_userBox);
    await Hive.openBox<String>(_syncBox);
  }

  static Future<void> cacheListings(List<Map<String, dynamic>> items) async {
    final box = Hive.box<String>(_listingsBox);
    await box.put('items', jsonEncode(items));
    await box.put('cached_at', DateTime.now().toIso8601String());
  }

  static List<Map<String, dynamic>>? getCachedListings() {
    final box = Hive.box<String>(_listingsBox);
    final raw = box.get('items');
    if (raw == null) return null;
    final list = jsonDecode(raw) as List;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> cacheUser(Map<String, dynamic> user) async {
    await Hive.box<String>(_userBox).put('me', jsonEncode(user));
  }

  static Map<String, dynamic>? getCachedUser() {
    final raw = Hive.box<String>(_userBox).get('me');
    if (raw == null) return null;
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  static Future<void> enqueueSync(String action, Map<String, dynamic> payload) async {
    final box = Hive.box<String>(_syncBox);
    final key = '${DateTime.now().millisecondsSinceEpoch}_$action';
    await box.put(key, jsonEncode({'action': action, 'payload': payload}));
  }
}
