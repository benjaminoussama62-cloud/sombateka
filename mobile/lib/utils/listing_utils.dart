import '../config/api_config.dart';
import 'constants.dart';
import 'listing_attributes.dart';
import 'rdc_locations.dart';

/// Prix CDF numérique d'une annonce (pour filtres).
double? listingPriceCdf(Map<String, dynamic> listing) {
  final raw = listing['price_cdf'];
  if (raw is int) return raw.toDouble();
  if (raw is num) return raw.toDouble();
  final parsed = int.tryParse(raw?.toString() ?? '');
  if (parsed != null) return parsed.toDouble();
  final digits = listing['price']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '';
  return double.tryParse(digits);
}

/// Filtre prix (min/max du sheet SombaTeka).
bool listingMatchesPriceRange(
  Map<String, dynamic> listing, {
  required double minPrice,
  required double maxPrice,
  double openMax = 10000000,
}) {
  if (minPrice <= 0 && maxPrice >= openMax) return true;
  final p = listingPriceCdf(listing);
  if (p == null) return minPrice <= 0;
  return p >= minPrice && p <= maxPrice;
}

String formatFilterPriceCdf(double value) {
  final n = value.round();
  if (n >= 1000000) {
    final m = n / 1000000;
    return m == m.roundToDouble() ? '${m.round()}M CDF' : '${m.toStringAsFixed(1)}M CDF';
  }
  if (n >= 1000) return '${(n / 1000).round()}K CDF';
  return '$n CDF';
}
bool isProListing(Map<String, dynamic> listing) {
  if (listing['is_official'] == true || listing['isOfficial'] == true || listing['isVerified'] == true) {
    return true;
  }
  if (listing['listingType'] == ListingType.payment) return true;
  if (ListingAttributes.isCatalogListing(listing['attributes'])) return true;
  final pid = listing['publicationId']?.toString() ??
      ListingAttributes.publicationId(listing['attributes']);
  return pid != null && pid.isNotEmpty && !pid.startsWith('solo_');
}

/// Normalise une annonce API → map sûr pour l’UI (plus de null sur String).
Map<String, dynamic> normalizeListing(
  Map<String, dynamic> raw, {
  Set<int>? favoriteIds,
  String? currentUserId,
}) {
  var imageUrl = '';
  final primary = raw['primary_image_url']?.toString();
  if (primary != null && primary.isNotEmpty) {
    imageUrl = _absoluteUrl(primary);
  }
  final imgs = <String>[];
  if (raw['image_urls'] is List) {
    for (final u in raw['image_urls'] as List) {
      final abs = _absoluteUrl(u?.toString());
      if (abs.isNotEmpty && !imgs.contains(abs)) imgs.add(abs);
    }
  }
  if (raw['images'] is List) {
    for (final i in raw['images'] as List) {
      if (i is Map) {
        final u = _absoluteUrl(i['url']?.toString());
        if (u.isNotEmpty) imgs.add(u);
      } else {
        final u = i?.toString() ?? '';
        if (u.isNotEmpty) imgs.add(_absoluteUrl(u));
      }
    }
  }
  if (imageUrl.isEmpty && imgs.isNotEmpty) imageUrl = imgs.first;
  if (imageUrl.isEmpty) {
    final legacy = raw['imageUrl']?.toString() ?? '';
    if (legacy.isNotEmpty) imageUrl = _absoluteUrl(legacy);
  }

  final idStr = raw['id']?.toString() ?? '';
  final idInt = int.tryParse(idStr);
  final isFav = idInt != null && (favoriteIds?.contains(idInt) ?? false);
  final sellerIdStr = raw['seller_id']?.toString() ?? raw['sellerId']?.toString() ?? '';
  final own = currentUserId != null && sellerIdStr.isNotEmpty && sellerIdStr == currentUserId;
  final province = RdcLocations.parseProvince(raw['attributes']) ?? RdcLocations.guessProvince(raw);

  final attrs = raw['attributes'];
  final catalog = ListingAttributes.isCatalogListing(attrs);
  final pubId = ListingAttributes.publicationId(attrs);
  final apiOfficial = raw['is_official'] == true;
  final commune = raw['commune']?.toString().trim() ?? RdcLocations.parseCommune(attrs) ?? '';
  final quartier = raw['quartier']?.toString().trim() ?? RdcLocations.parseQuartier(attrs) ?? '';

  return {
    ...raw,
    'id': idStr,
    'title': _str(raw['title'], 'Sans titre'),
    'description': _str(raw['description'], ''),
    'price': raw['price']?.toString() ?? _formatPrice(raw['price_cdf']),
    'price_cdf': raw['price_cdf'],
    'city': _str(raw['city'], 'Kinshasa'),
    'province': province,
    'location': _str(raw['location'], raw['city']?.toString() ?? 'Kinshasa'),
    'commune': commune,
    'quartier': quartier,
    'category': _str(raw['category_name'] ?? raw['category'], 'Général'),
    'listingType': (raw['is_official'] == true || raw['listingType'] == ListingType.payment)
        ? ListingType.payment
        : ListingType.contact,
    'isOfficial': apiOfficial ||
        catalog ||
        (pubId != null && pubId.isNotEmpty && !pubId.startsWith('solo_')),
    'isVerified': apiOfficial || raw['isVerified'] == true || catalog,
    'seller_id': raw['seller_id']?.toString() ?? '',
    'sellerId': raw['seller_id']?.toString() ?? raw['sellerId']?.toString() ?? '',
    'sellerName': _str(
      raw['seller_display_name'] ?? raw['seller_name'] ?? raw['sellerName'],
      'Vendeur',
    ),
    'sellerAvatarUrl': _absSellerImage(raw['sellerAvatarUrl'] ?? raw['seller_avatar_url']),
    'sellerLogoUrl': _absSellerImage(raw['sellerLogoUrl'] ?? raw['seller_logo_url']),
    'sellerReviewCount': (raw['sellerReviewCount'] as num?)?.toInt() ?? (raw['seller_review_count'] as num?)?.toInt() ?? 0,
    'sellerProfilePublic': raw['sellerProfilePublic'] != false && raw['seller_profile_public'] != false,
    'sellerEmailVerified': raw['sellerAccountVerified'] == true ||
        raw['seller_account_verified'] == true ||
        raw['sellerEmailVerified'] == true ||
        raw['seller_email_verified'] == true,
    'sellerAccountVerified': raw['sellerAccountVerified'] == true ||
        raw['seller_account_verified'] == true ||
        raw['sellerEmailVerified'] == true ||
        raw['seller_email_verified'] == true,
    'images': imgs,
    'imageUrl': imageUrl,
    'isFavorite': raw['isFavorite'] == true || isFav,
    'status': raw['status']?.toString() ?? 'active',
    'createdAt': raw['created_at'] ?? raw['createdAt'],
    'attributes': raw['attributes'],
    'size': raw['size']?.toString() ?? ListingAttributes.parseSize(raw['attributes']),
    'isOwnListing': own,
    'promoted': raw['promoted'] == true,
    'publicationId': ListingAttributes.publicationId(raw['attributes']),
    'publicationTitle': ListingAttributes.publicationTitle(raw['attributes']),
  };
}

String _str(dynamic v, String fallback) {
  final s = v?.toString().trim();
  if (s == null || s.isEmpty || s == 'null') return fallback;
  return s;
}

String _absoluteUrl(String? path) {
  if (path == null || path.isEmpty) return '';
  var url = path.trim();
  if (!url.startsWith('http')) {
    url = ApiConfig.baseUrl + (url.startsWith('/') ? url : '/$url');
  }
  final base = ApiConfig.baseUrl;
  for (final bad in [
    'http://localhost:8000',
    'https://localhost:8000',
    'http://127.0.0.1:8000',
    'https://127.0.0.1:8000',
    'http://backend:8000',
  ]) {
    url = url.replaceAll(bad, base);
  }
  return url;
}

String _absSellerImage(dynamic v) {
  final s = v?.toString().trim();
  if (s == null || s.isEmpty || s == 'null') return '';
  return _absoluteUrl(s);
}

String _formatPrice(dynamic cdf) {
  if (cdf == null) return 'Prix sur demande';
  final n = cdf is int ? cdf : int.tryParse(cdf.toString()) ?? 0;
  if (n <= 0) return 'Prix sur demande';
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M CDF';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K CDF';
  return '$n CDF';
}

List<Map<String, dynamic>> normalizeListings(
  List<Map<String, dynamic>> items, {
  Set<int>? favoriteIds,
  String? currentUserId,
}) =>
    items
        .map((e) => normalizeListing(e, favoriteIds: favoriteIds, currentUserId: currentUserId))
        .toList();

/// True si l'annonce appartient à l'utilisateur connecté.
bool isOwnListing(Map<String, dynamic> listing, String? currentUserId) {
  if (currentUserId == null || currentUserId.isEmpty) return false;
  final sid = listing['seller_id']?.toString() ?? listing['sellerId']?.toString() ?? '';
  return sid.isNotEmpty && sid == currentUserId;
}
