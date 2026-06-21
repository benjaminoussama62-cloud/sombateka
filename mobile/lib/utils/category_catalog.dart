import 'package:flutter/material.dart';

import '../services/data_service.dart';
import '../theme/premium_theme.dart';
import '../utils/listing_attributes.dart';

/// Catégories partagées (Recherche + Publier) — même source que l’API.
class CategoryCatalog {
  CategoryCatalog._();

  static IconData iconFor(String name) {
    final n = name.toLowerCase();
    if (n.contains('téléphone') || n.contains('telephone')) return Icons.smartphone_rounded;
    if (n.contains('électronique') || n.contains('electronique')) return Icons.devices_rounded;
    if (n.contains('mode') || n.contains('vêtement') || n.contains('vetement')) return Icons.checkroom_rounded;
    if (n.contains('chaussure') || n.contains('soulier') || n.contains('basket') || n.contains('sneaker')) {
      return Icons.directions_walk_rounded;
    }
    if (n.contains('pantalon') || n.contains('jean')) return Icons.straighten_rounded;
    if (n.contains('robe') || n.contains('jupe')) return Icons.woman_rounded;
    if (n.contains('sport')) return Icons.fitness_center_rounded;
    if (n.contains('enfant') || n.contains('bébé') || n.contains('bebe')) return Icons.child_care_rounded;
    if (n.contains('maison') || n.contains('meuble')) return Icons.chair_rounded;
    if (n.contains('véhicule') || n.contains('vehicule') || n.contains('auto')) return Icons.directions_car_rounded;
    if (n.contains('accessoire')) return Icons.watch_rounded;
    return Icons.category_rounded;
  }

  static Color colorFor(String name) {
    final n = name.toLowerCase();
    if (n.contains('mode') || n.contains('vêtement')) return const Color(0xFFEC4899);
    if (n.contains('électronique') || n.contains('téléphone')) return const Color(0xFF3B82F6);
    if (n.contains('chaussure') || n.contains('basket')) return const Color(0xFF8B5CF6);
    if (n.contains('maison')) return const Color(0xFF10B981);
    if (n.contains('véhicule')) return const Color(0xFFF59E0B);
    if (n.contains('enfant')) return const Color(0xFFF97316);
    return PremiumTheme.blue;
  }

  /// Charge catégories API + labels mode (alignés Publier).
  static Future<({List<String> names, Map<String, int> ids})> load(DataService data) async {
    final names = <String>{'Toutes'};
    final ids = <String, int>{};
    try {
      final cats = await data.fetchCategories();
      for (final c in cats) {
        final name = c['name']?.toString() ?? '';
        final id = c['id'];
        if (name.isEmpty || id == null) continue;
        names.add(name);
        ids[name] = id is int ? id : int.tryParse(id.toString()) ?? 0;
      }
    } catch (_) {}
    names.addAll(ListingAttributes.fashionCategoryNames);
    final sorted = names.toList()..sort((a, b) {
      if (a == 'Toutes') return -1;
      if (b == 'Toutes') return 1;
      return a.compareTo(b);
    });
    return (names: sorted, ids: ids);
  }
}
