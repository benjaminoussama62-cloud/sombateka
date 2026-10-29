import 'dart:convert';

import 'package:flutter/material.dart';

import 'kinshasa_locations.dart';

/// Tailles et paramètres pour mode, chaussures, pantalons, etc.
class ListingAttributes {
  ListingAttributes._();

  static const clothingSizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL'];
  static const shoeSizes = [
    '35', '36', '37', '38', '39', '40', '41', '42', '43', '44', '45', '46',
  ];
  static const pantsSizes = [
    '26', '28', '30', '32', '34', '36', '38', '40', '42', '44',
  ];
  static const kidsSizes = ['2 ans', '4 ans', '6 ans', '8 ans', '10 ans', '12 ans', '14 ans'];

  static const conditions = ['Neuf', 'Très bon état', 'Bon état', 'État satisfaisant'];
  static const colors = [
    'Noir', 'Blanc', 'Bleu', 'Rouge', 'Vert', 'Jaune', 'Gris', 'Beige', 'Marron', 'Multicolore',
  ];

  /// Pastilles couleur (nom + valeur affichage).
  static const colorOptions = <(String, Color)>[
    ('Noir', Color(0xFF1A1A1A)),
    ('Blanc', Color(0xFFF8FAFC)),
    ('Bleu', Color(0xFF2563EB)),
    ('Rouge', Color(0xFFDC2626)),
    ('Vert', Color(0xFF16A34A)),
    ('Jaune', Color(0xFFFACC15)),
    ('Gris', Color(0xFF94A3B8)),
    ('Beige', Color(0xFFD4B896)),
    ('Marron', Color(0xFF78350F)),
    ('Multicolore', Color(0xFF6366F1)),
  ];

  static const genders = ['Masculin', 'Féminin', 'Mixte', 'Unisexe'];
  static const audiences = ['Adulte', 'Enfant', 'Bébé'];

  static const popularBrands = [
    'Nike', 'Adidas', 'Zara', 'H&M', 'Puma', 'Gucci', 'Louis Vuitton', 'Dior',
    'Samsung', 'Apple', 'Sony', 'LG', 'Xiaomi', 'Huawei',
  ];

  static const starRatings = [5, 4, 3, 2, 1];

  /// Catégories mode affichées si l’API n’en fournit pas assez.
  static const fashionCategoryNames = [
    'Mode & Vêtements',
    'Chaussures',
    'Baskets & Sneakers',
    'Souliers',
    'Sandales',
    'Pantalons',
    'Jeans',
    'Chemises & Hauts',
    'Robes & Jupes',
    'Vestes & Manteaux',
    'Sportswear',
    'Accessoires mode',
    'Bébé & Enfants',
  ];

  /// Annonces type Kufar (immobilier, véhicules, hôtels…).
  static const marketplaceCategoryNames = [
    'Immobilier — Vente',
    'Immobilier — Location',
    'Parcelles & Terrains',
    'Hôtels & Hébergement',
    'Véhicules — Voitures',
    'Véhicules — Motos',
    'Véhicules — Camions & Bus',
    'Emploi & Services',
    'Location courte durée',
  ];

  static List<String> allPublishCategories(List<String> apiCategories) {
    final seen = <String>{};
    final out = <String>[];
    for (final c in [...apiCategories, ...marketplaceCategoryNames, ...fashionCategoryNames]) {
      if (seen.add(c)) out.add(c);
    }
    return out;
  }

  static bool isVehicleCategory(String? category) {
    if (category == null) return false;
    final c = category.toLowerCase();
    return c.contains('véhicule') || c.contains('vehicule') || c.contains('voiture') ||
        c.contains('moto') || c.contains('scooter') || c.contains('camion') ||
        c.contains('bus') || c.contains('pièces auto') || c.contains('pieces auto') ||
        c.contains('pneu') || c.contains('jante') || c == 'véhicules';
  }

  static bool isRealEstateCategory(String? category) {
    if (category == null) return false;
    final c = category.toLowerCase();
    return c.contains('immobilier') || c.contains('appartement') || c.contains('maison') ||
        c.contains('parcelle') || c.contains('terrain') || c.contains('bureau') ||
        c.contains('commerce') || c.contains('colocation') || c.contains('location courte');
  }

  static bool isHotelCategory(String? category) {
    if (category == null) return false;
    final c = category.toLowerCase();
    return c.contains('hôtel') || c.contains('hotel') || c.contains('hébergement') ||
        c.contains('hebergement') || c.contains('auberge') || c.contains('guesthouse') ||
        c.contains('événement') || c.contains('evenement') || c.contains('salle');
  }

  static bool isClothingCategory(String? category) {
    if (category == null || isShoeCategory(category) || isPantsCategory(category)) return false;
    final c = category.toLowerCase();
    return c.contains('mode') ||
        c.contains('vêtement') ||
        c.contains('vetement') ||
        c.contains('chemise') ||
        c.contains('robe') ||
        c.contains('jupe') ||
        c.contains('veste') ||
        c.contains('manteau') ||
        c.contains('sportswear') ||
        c.contains('accessoire');
  }

  static bool categoryNeedsSize(String? category) {
    if (category == null || category.isEmpty) return false;
    return isShoeCategory(category) ||
        isPantsCategory(category) ||
        isKidsCategory(category) ||
        isClothingCategory(category);
  }

  static bool isShoeCategory(String? category) {
    if (category == null) return false;
    final c = category.toLowerCase();
    return c.contains('chaussure') ||
        c.contains('soulier') ||
        c.contains('sneaker') ||
        (c.contains('basket') && !c.contains('ball')) ||
        c.contains('sandale') ||
        c.contains('botte');
  }

  static bool isPantsCategory(String? category) {
    if (category == null) return false;
    final c = category.toLowerCase();
    return c.contains('pantalon') || c.contains('jean');
  }

  static bool isKidsCategory(String? category) {
    if (category == null) return false;
    final c = category.toLowerCase();
    return c.contains('bébé') || c.contains('bebe') || c.contains('enfant');
  }

  static String sizeLabelForCategory(String? category) {
    if (isShoeCategory(category)) return 'Pointure';
    if (isPantsCategory(category)) return 'Taille (pantalon)';
    if (isKidsCategory(category)) return 'Taille enfant';
    return 'Taille';
  }

  static List<String> sizesForCategory(String? category) {
    if (isShoeCategory(category)) return shoeSizes;
    if (isPantsCategory(category)) return pantsSizes;
    if (isKidsCategory(category)) return kidsSizes;
    return clothingSizes;
  }

  static bool categorySupportsExtraParams(String? category) {
    if (category == null || category.isEmpty) return false;
    return categoryNeedsSize(category) ||
        isVehicleCategory(category) ||
        isRealEstateCategory(category) ||
        isHotelCategory(category);
  }

  static const vehicleYears = ['2024', '2023', '2022', '2021', '2020', '2019', '2018', '2017', '2016', '2015', '≤ 2014'];
  static const fuelTypes = ['Essence', 'Diesel', 'Hybride', 'Électrique'];
  static const realEstateTypes = ['Vente', 'Location', 'Colocation'];
  static const roomCounts = ['Studio', '1', '2', '3', '4', '5+'];

  /// Attributs JSON unifiés (localisation + mode + catalogue).
  static String buildAttributes({
    required String category,
    String? size,
    String? province,
    String? commune,
    String? quartier,
    String? avenue,
    String? numero,
    String? condition,
    String? brand,
    String? color,
    String? material,
    String? gender,
    String? audience,
    String? vehicleYear,
    String? mileageKm,
    String? fuel,
    String? surfaceSqm,
    String? rooms,
    String? listingType,
    String? vehicleModel,
  }) {
    final map = <String, dynamic>{};
    if (province != null && province.trim().isNotEmpty) map['province'] = province.trim();
    if (commune != null && commune.trim().isNotEmpty) map['commune'] = commune.trim();
    if (quartier != null && quartier.trim().isNotEmpty) map['quartier'] = quartier.trim();
    if (avenue != null && avenue.trim().isNotEmpty) map['avenue'] = avenue.trim();
    if (numero != null && numero.trim().isNotEmpty) map['numero'] = numero.trim();

    if (size != null && size.isNotEmpty && categoryNeedsSize(category)) {
      String type = 'clothing';
      if (isShoeCategory(category)) {
        type = 'shoe';
      } else if (isPantsCategory(category)) {
        type = 'pants';
      } else if (isKidsCategory(category)) {
        type = 'kids';
      }
      map['size'] = size.trim();
      map['size_type'] = type;
    }
    if (condition != null && condition.trim().isNotEmpty) map['condition'] = condition.trim();
    if (brand != null && brand.trim().isNotEmpty) map['brand'] = brand.trim();
    if (color != null && color.trim().isNotEmpty) map['color'] = color.trim();
    if (material != null && material.trim().isNotEmpty) map['material'] = material.trim();
    if (gender != null && gender.trim().isNotEmpty) map['gender'] = _genderKey(gender);
    if (audience != null && audience.trim().isNotEmpty) map['audience'] = _audienceKey(audience);

    if (isVehicleCategory(category)) {
      if (vehicleYear != null && vehicleYear.trim().isNotEmpty) map['vehicle_year'] = vehicleYear.trim();
      if (mileageKm != null && mileageKm.trim().isNotEmpty) map['mileage_km'] = mileageKm.trim();
      if (fuel != null && fuel.trim().isNotEmpty) map['fuel'] = fuel.trim();
      if (vehicleModel != null && vehicleModel.trim().isNotEmpty) map['vehicle_model'] = vehicleModel.trim();
      if (brand != null && brand.trim().isNotEmpty) map['brand'] = brand.trim();
    }
    if (isRealEstateCategory(category) || isHotelCategory(category)) {
      if (listingType != null && listingType.trim().isNotEmpty) map['listing_type'] = listingType.trim();
      if (surfaceSqm != null && surfaceSqm.trim().isNotEmpty) map['surface_sqm'] = surfaceSqm.trim();
      if (rooms != null && rooms.trim().isNotEmpty) map['rooms'] = rooms.trim();
    }

    if (map.isEmpty) return '';
    return jsonEncode(map);
  }

  static String encodeCatalog({
    required String brand,
    required String gender,
    required String audience,
    required List<Map<String, dynamic>> variants,
    String? defaultColor,
    String? condition,
    String? province,
    String? commune,
    String? quartier,
    String? avenue,
    String? numero,
  }) {
    final sizes = <String>[];
    final colors = <String>{};
    for (final v in variants) {
      final s = v['size']?.toString().trim();
      if (s != null && s.isNotEmpty) sizes.add(s);
      final c = v['color']?.toString().trim();
      if (c != null && c.isNotEmpty) colors.add(c);
    }
    return jsonEncode({
      'catalog': true,
      'brand': brand.trim(),
      'gender': _genderKey(gender),
      'audience': _audienceKey(audience),
      if (province != null && province.isNotEmpty) 'province': province.trim(),
      if (commune != null && commune.isNotEmpty) 'commune': commune.trim(),
      if (quartier != null && quartier.isNotEmpty) 'quartier': quartier.trim(),
      if (avenue != null && avenue.isNotEmpty) 'avenue': avenue.trim(),
      if (numero != null && numero.isNotEmpty) 'numero': numero.trim(),
      if (condition != null && condition.isNotEmpty) 'condition': condition.trim(),
      if (defaultColor != null && defaultColor.isNotEmpty) 'color': defaultColor.trim(),
      'variants': variants,
      'available_sizes': sizes,
      'available_colors': colors.toList(),
    });
  }

  static String _genderKey(String label) {
    switch (label.toLowerCase()) {
      case 'masculin':
        return 'masculin';
      case 'féminin':
      case 'feminin':
        return 'feminin';
      case 'mixte':
        return 'mixte';
      default:
        return 'unisexe';
    }
  }

  static String _audienceKey(String label) {
    final l = label.toLowerCase();
    if (l.contains('bébé') || l.contains('bebe')) return 'bebe';
    if (l.contains('enfant')) return 'enfant';
    return 'adulte';
  }

  static String encode({
    required String size,
    required String category,
    String? condition,
    String? brand,
    String? color,
    String? material,
    String? gender,
    String? audience,
    String? commune,
    String? quartier,
  }) {
    return buildAttributes(
      category: category,
      size: size,
      commune: commune,
      quartier: quartier,
      condition: condition,
      brand: brand,
      color: color,
      material: material,
      gender: gender,
      audience: audience,
    );
  }

  static int catalogTotalStock(dynamic attributes) {
    final variants = catalogVariants(attributes);
    if (variants.isEmpty) return 1;
    return variants.fold<int>(0, (s, v) => s + ((v['stock'] as num?)?.toInt() ?? 0));
  }

  static int stockForSize(dynamic attributes, String size, {String? color}) {
    for (final v in catalogVariants(attributes)) {
      if (v['size']?.toString() != size) continue;
      if (color != null && color.isNotEmpty && v['color']?.toString() != color) continue;
      return (v['stock'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  static int priceForSize(dynamic attributes, String size, {String? color}) {
    for (final v in catalogVariants(attributes)) {
      if (v['size']?.toString() != size) continue;
      if (color != null && color.isNotEmpty && v['color']?.toString() != color) continue;
      return (v['price_cdf'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  static bool isCatalogListing(dynamic attributes) {
    return decodeMap(attributes)?['catalog'] == true;
  }

  static String? publicationId(dynamic attributes) {
    return decodeMap(attributes)?['publication_id']?.toString();
  }

  static String? publicationTitle(dynamic attributes) {
    return decodeMap(attributes)?['publication_title']?.toString();
  }

  static List<Map<String, dynamic>> catalogVariants(dynamic attributes) {
    final m = decodeMap(attributes);
    if (m == null) return [];
    final v = m['variants'];
    if (v is List) {
      return v.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  static Map<String, dynamic>? decodeMap(dynamic attributes) {
    if (attributes == null) return null;
    if (attributes is Map) return Map<String, dynamic>.from(attributes);
    final raw = attributes.toString().trim();
    if (raw.isEmpty) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  static String encodeMap(Map<String, dynamic> map) => jsonEncode(map);

  static String? parseSize(dynamic attributes) {
    final m = decodeMap(attributes);
    return m?['size']?.toString();
  }

  static List<MapEntry<String, String>> displayParams(Map<String, dynamic> listing) {
    final out = <MapEntry<String, String>>[];
    final attrs = decodeMap(listing['attributes']);
    final province = attrs?['province']?.toString() ?? RdcLocations.parseProvince(listing['attributes']);
    final commune = attrs?['commune']?.toString() ?? RdcLocations.parseCommune(listing['attributes']);
    final quartier = attrs?['quartier']?.toString() ?? RdcLocations.parseQuartier(listing['attributes']);
    if (province != null && province.isNotEmpty) {
      out.add(MapEntry('Province', province));
    }
    if (commune != null && commune.isNotEmpty) {
      out.add(MapEntry('Commune', commune));
    }
    if (quartier != null && quartier.isNotEmpty) {
      out.add(MapEntry('Quartier', quartier));
    }
    final avenue = attrs?['avenue']?.toString();
    if (avenue != null && avenue.isNotEmpty) {
      out.add(MapEntry('Avenue', avenue));
    }
    final numero = attrs?['numero']?.toString();
    if (numero != null && numero.isNotEmpty) {
      out.add(MapEntry('N°', numero));
    }
    final city = listing['city']?.toString() ?? listing['location']?.toString();
    if (city != null && city.trim().isNotEmpty) {
      out.add(MapEntry('Ville', city.trim()));
    }
    final cat = listing['category']?.toString();
    if (cat != null && cat.trim().isNotEmpty) {
      out.add(MapEntry('Catégorie', cat.trim()));
    }
    final attrsMap = attrs;
    final size = listing['size']?.toString() ?? attrsMap?['size']?.toString();
    if (size != null && size.isNotEmpty) {
      final type = attrsMap?['size_type']?.toString() ?? parseSizeType(listing['attributes']);
      String label = 'Taille';
      if (type == 'shoe') {
        label = 'Pointure';
      } else if (type == 'pants') {
        label = 'Taille pantalon';
      } else if (type == 'kids') {
        label = 'Taille enfant';
      }
      out.add(MapEntry(label, size));
    }
    if (attrsMap != null) {
      for (final key in ['condition', 'brand', 'color', 'material', 'gender', 'audience']) {
        final val = attrsMap[key]?.toString().trim() ?? '';
        if (val.isNotEmpty) out.add(MapEntry(_attrLabel(key), _displayValue(key, val)));
      }
      if (attrsMap['catalog'] == true) {
        final sizes = attrsMap['available_sizes'];
        if (sizes is List && sizes.isNotEmpty) {
          out.add(MapEntry('Tailles dispo.', sizes.map((e) => e.toString()).join(', ')));
        }
      }
    }
    final status = listing['status']?.toString();
    if (status != null && status.isNotEmpty && status != 'active') {
      out.add(MapEntry('Statut', _statusLabel(status)));
    }
    return out;
  }

  static String? parseSizeType(dynamic attributes) {
    return decodeMap(attributes)?['size_type']?.toString();
  }

  static String _statusLabel(String s) {
    switch (s.toLowerCase()) {
      case 'sold':
        return 'Vendu';
      case 'hidden':
        return 'Masqué';
      default:
        return s;
    }
  }

  static String _attrLabel(String key) {
    switch (key.toLowerCase()) {
      case 'condition':
        return 'État';
      case 'brand':
        return 'Marque';
      case 'color':
        return 'Couleur';
      case 'material':
        return 'Matière';
      case 'gender':
        return 'Genre';
      case 'audience':
        return 'Public';
      default:
        if (key.isEmpty) return 'Info';
        return key[0].toUpperCase() + key.substring(1);
    }
  }

  static String _displayValue(String key, String val) {
    if (key == 'gender') {
      switch (val.toLowerCase()) {
        case 'masculin':
          return 'Masculin';
        case 'feminin':
          return 'Féminin';
        case 'mixte':
          return 'Mixte';
        default:
          return 'Unisexe';
      }
    }
    if (key == 'audience') {
      switch (val.toLowerCase()) {
        case 'bebe':
          return 'Bébé';
        case 'enfant':
          return 'Enfant';
        default:
          return 'Adulte';
      }
    }
    return val;
  }

  static bool matchesSize(Map<String, dynamic> listing, String? filterSize) {
    if (filterSize == null || filterSize.isEmpty) return true;
    final attrs = decodeMap(listing['attributes']);
    final sizes = attrs?['available_sizes'];
    if (sizes is List && sizes.isNotEmpty) {
      return sizes.map((e) => e.toString().toUpperCase()).contains(filterSize.toUpperCase());
    }
    final s = parseSize(listing['attributes']) ?? listing['size']?.toString();
    if (s == null) return false;
    return s.toUpperCase() == filterSize.toUpperCase();
  }

  static bool matchesExtraFilters(
    Map<String, dynamic> listing, {
    String? condition,
    String? color,
    String? brand,
    String? gender,
    String? audience,
    String? commune,
    String? quartier,
    bool? officialOnly,
    double? minSellerRating,
  }) {
    final m = decodeMap(listing['attributes']);
    if (commune != null && commune.isNotEmpty) {
      if ((m?['commune']?.toString() ?? '') != commune) return false;
    }
    if (quartier != null && quartier.isNotEmpty) {
      if ((m?['quartier']?.toString() ?? '') != quartier) return false;
    }
    if (condition != null && condition.isNotEmpty) {
      if ((m?['condition']?.toString() ?? '') != condition) return false;
    }
    if (color != null && color.isNotEmpty) {
      final c = m?['color']?.toString() ?? '';
      final variantColors = m?['available_colors'];
      final hasColor = c == color ||
          (variantColors is List && variantColors.map((e) => e.toString()).contains(color));
      if (!hasColor) return false;
    }
    if (brand != null && brand.isNotEmpty) {
      if ((m?['brand']?.toString().toLowerCase() ?? '') != brand.toLowerCase()) return false;
    }
    if (gender != null && gender.isNotEmpty) {
      final g = m?['gender']?.toString() ?? '';
      if (g != _genderKey(gender) && g != gender.toLowerCase()) return false;
    }
    if (audience != null && audience.isNotEmpty) {
      final a = m?['audience']?.toString() ?? '';
      if (a != _audienceKey(audience) && a != audience.toLowerCase()) return false;
    }
    if (officialOnly == true && listing['isOfficial'] != true) return false;
    if (minSellerRating != null && minSellerRating > 0) {
      final r = (listing['sellerRating'] as num?)?.toDouble() ?? 0;
      if (r < minSellerRating) return false;
    }
    return true;
  }
}
