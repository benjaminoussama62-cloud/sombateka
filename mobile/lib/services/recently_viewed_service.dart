import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Annonces consultées récemment (local, max 12).
class RecentlyViewedService {
  RecentlyViewedService._();
  static final RecentlyViewedService instance = RecentlyViewedService._();

  static const _key = 'recently_viewed_listings_v1';
  static const _max = 12;

  Future<List<Map<String, dynamic>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> track(Map<String, dynamic> listing) async {
    final id = listing['id']?.toString();
    if (id == null || id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final current = await load();
    final snapshot = {
      'id': id,
      'title': listing['title']?.toString() ?? '',
      'price': listing['price']?.toString() ?? '',
      'imageUrl': listing['imageUrl']?.toString() ?? listing['primary_image_url']?.toString() ?? '',
      'city': listing['city']?.toString() ?? '',
      'viewed_at': DateTime.now().toIso8601String(),
    };
    final next = [snapshot, ...current.where((e) => e['id']?.toString() != id)].take(_max).toList();
    await prefs.setString(_key, jsonEncode(next));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
