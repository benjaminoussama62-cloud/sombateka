import '../config/api_config.dart';
import 'constants.dart';
import 'listing_attributes.dart';
import 'rdc_locations.dart';

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
    'category': _str(raw['category_name'] ?? raw['category'], 'Général'),
    'listingType': (raw['is_official'] == true || raw['listingType'] == ListingType.payment)
        ? ListingType.payment
        : ListingType.contact,
    'isOfficial': raw['is_official'] == true,
    'isVerified': raw['is_official'] == true || raw['isVerified'] == true,
    'seller_id': raw['seller_id']?.toString() ?? '',
    'sellerId': raw['seller_id']?.toString() ?? raw['sellerId']?.toString() ?? '',
    'sellerName': _str(raw['seller_name'] ?? raw['sellerName'], 'Vendeur'),
    'images': imgs,
    'imageUrl': imageUrl,
    'isFavorite': raw['isFavorite'] == true || isFav,
    'status': raw['status']?.toString() ?? 'active',
    'createdAt': raw['created_at'] ?? raw['createdAt'],
    'attributes': raw['attributes'],
    'size': raw['size']?.toString() ?? ListingAttributes.parseSize(raw['attributes']),
    'isOwnListing': own,
  };
}

String _str(dynamic v, String fallback) {
  final s = v?.toString().trim();
  if (s == null || s.isEmpty || s == 'null') return fallback;
  return s;
}

String _absoluteUrl(String? path) {
  if (path == null || path.isEmpty) return '';
  var url = path;
  if (!url.startsWith('http')) {
    url = ApiConfig.baseUrl + (url.startsWith('/') ? url : '/$url');
  }
  url = url.replaceAll('http://localhost:8000', ApiConfig.baseUrl);
  return url;
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
