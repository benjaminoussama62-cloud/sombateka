import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../core/api/api_client.dart';
import '../core/offline/offline_cache.dart';
import '../utils/multipart_image.dart';
import '../utils/rdc_locations.dart';

class ListingsRepository {
  ListingsRepository(this._api);

  final ApiClient _api;

  Future<List<Map<String, dynamic>>> fetchListings({
    String? q,
    String? city,
    int? categoryId,
    bool? isOfficial,
    String? size,
    double? minPrice,
    double? maxPrice,
    String? color,
    String? condition,
    String? brand,
    String? gender,
    String? audience,
    int? minRating,
    String? commune,
    String? quartier,
    String? province,
  }) async {
    try {
      final conn = await Connectivity().checkConnectivity();
      if (conn.contains(ConnectivityResult.none)) {
        return OfflineCache.getCachedListings() ?? [];
      }
      final r = await _api.get<Map<String, dynamic>>(
        '/listings',
        query: {
          if (q != null && q.isNotEmpty) 'q': q,
          if (city != null && city.isNotEmpty) 'city': city,
          if (province != null && province.isNotEmpty) 'province': province,
          if (categoryId != null) 'category_id': categoryId,
          if (isOfficial == true) 'is_official': true,
          if (size != null && size.isNotEmpty) 'size': size,
          if (minPrice != null && minPrice > 0) 'min_price': minPrice,
          if (maxPrice != null && maxPrice < 10000000) 'max_price': maxPrice,
          if (color != null && color.isNotEmpty) 'color': color,
          if (condition != null && condition.isNotEmpty) 'condition': condition,
          if (brand != null && brand.isNotEmpty) 'brand': brand,
          if (gender != null && gender.isNotEmpty) 'gender': gender,
          if (audience != null && audience.isNotEmpty) 'audience': audience,
          if (minRating != null && minRating > 0) 'min_rating': minRating,
          if (commune != null && commune.isNotEmpty) 'commune': commune,
          if (quartier != null && quartier.isNotEmpty) 'quartier': quartier,
          'limit': 50,
        },
      );
      final items = (r.data?['items'] as List?) ?? [];
      return items.map((e) => _mapListing(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return OfflineCache.getCachedListings() ?? [];
    }
  }

  Future<Map<String, dynamic>> fetchDetail(int id) async {
    final r = await _api.get<Map<String, dynamic>>('/listings/$id');
    return _mapListing(Map<String, dynamic>.from(r.data ?? {}), detailed: true);
  }

  Future<int> createListing({
    required String title,
    required String city,
    String? description,
    int? priceCdf,
    int? categoryId,
    String? attributes,
  }) async {
    final r = await _api.post<Map<String, dynamic>>(
      '/listings/',
      data: {
        'title': title,
        'city': city,
        if (description != null) 'description': description,
        if (priceCdf != null) 'price_cdf': priceCdf,
        if (categoryId != null) 'category_id': categoryId,
        if (attributes != null && attributes.isNotEmpty) 'attributes': attributes,
      },
      idempotent: true,
    );
    return (r.data?['id'] as int?) ?? 0;
  }

  Future<int> createOfficialCatalog({
    required String title,
    required String city,
    String? description,
    int? categoryId,
    required String brand,
    required String gender,
    required String audience,
    String? condition,
    String? defaultColor,
    String? commune,
    String? quartier,
    String? avenue,
    String? numero,
    String? province,
    required List<Map<String, dynamic>> variants,
    required String deliveryMethod,
  }) async {
    final r = await _api.post<Map<String, dynamic>>(
      '/listings/official-catalog',
      data: {
        'title': title,
        'city': city,
        if (description != null) 'description': description,
        if (categoryId != null) 'category_id': categoryId,
        'brand': brand,
        'gender': gender,
        'audience': audience,
        'delivery_method': deliveryMethod,
        if (condition != null) 'condition': condition,
        if (defaultColor != null) 'default_color': defaultColor,
        if (province != null && province.isNotEmpty) 'province': province,
        if (commune != null && commune.isNotEmpty) 'commune': commune,
        if (quartier != null && quartier.isNotEmpty) 'quartier': quartier,
        if (avenue != null && avenue.isNotEmpty) 'avenue': avenue,
        if (numero != null && numero.isNotEmpty) 'numero': numero,
        'variants': variants,
      },
      idempotent: true,
    );
    return (r.data?['id'] as int?) ?? 0;
  }

  Future<List<Map<String, dynamic>>> fetchMyListings() async {
    final r = await _api.get<Map<String, dynamic>>('/listings/mine');
    final items = (r.data?['items'] as List?) ?? [];
    return items.map((e) => _mapListing(Map<String, dynamic>.from(e as Map), includeStatus: true)).toList();
  }

  Future<void> republish(int listingId) async {
    await _api.post('/listings/$listingId/republish', idempotent: true);
  }

  Future<List<Map<String, dynamic>>> fetchInquirers(int listingId) async {
    final r = await _api.get<Map<String, dynamic>>('/listings/$listingId/inquirers');
    final items = (r.data?['items'] as List?) ?? [];
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> markSold(int listingId, {int? buyerId}) async {
    final r = await _api.post<Map<String, dynamic>>(
      '/listings/$listingId/sold',
      data: {if (buyerId != null) 'buyer_id': buyerId},
      idempotent: true,
    );
    return Map<String, dynamic>.from(r.data ?? {});
  }

  Future<void> deleteListing(int listingId) async {
    await _api.delete('/listings/$listingId');
  }

  Future<({List<Map<String, dynamic>> items, String? message, String? sourceTitle, String? sourceImageUrl})>
      fetchSimilar(int listingId) async {
    final r = await _api.get<Map<String, dynamic>>('/listings/$listingId/similar');
    final data = r.data ?? {};
    final source = data['source'] as Map?;
    final items = (data['items'] as List?) ?? [];
    final mapped = items.map((e) {
      final m = _mapListing(Map<String, dynamic>.from(e as Map));
      final sim = (e as Map)['similarity'];
      if (sim != null) m['similarity'] = sim;
      return m;
    }).toList();
    mapped.sort((a, b) {
      final sa = (a['similarity'] as num?)?.toDouble() ?? 0;
      final sb = (b['similarity'] as num?)?.toDouble() ?? 0;
      return sb.compareTo(sa);
    });
    return (
      items: mapped,
      message: data['message']?.toString(),
      sourceTitle: source?['title']?.toString(),
      sourceImageUrl: source?['primary_image_url']?.toString(),
    );
  }

  Future<void> uploadImage(int listingId, String filePath) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    await _uploadForm(listingId, form);
  }

  Future<void> uploadImageBytes(
    int listingId, {
    required Uint8List bytes,
    required String filename,
    String contentType = 'image/jpeg',
  }) async {
    final safeName = _safeImageFilename(filename);
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: safeName,
        contentType: _mediaTypeFor(contentType, safeName),
      ),
    });
    await _uploadForm(listingId, form);
  }

  String _safeImageFilename(String raw) {
    final base = raw.trim().isEmpty ? 'photo.jpg' : raw.trim();
    if (base.contains('.')) return base;
    return '$base.jpg';
  }

  MediaType _mediaTypeFor(String contentType, String filename) {
    final ct = contentType.toLowerCase();
    if (ct.contains('png') || filename.toLowerCase().endsWith('.png')) {
      return MediaType('image', 'png');
    }
    if (ct.contains('webp') || filename.toLowerCase().endsWith('.webp')) {
      return MediaType('image', 'webp');
    }
    return MediaType('image', 'jpeg');
  }

  Future<List<int>> searchByImageIds({
    Uint8List? bytes,
    String? filePath,
    String filename = 'search.jpg',
  }) async {
    final result = await searchByImageListings(
      bytes: bytes,
      filePath: filePath,
      filename: filename,
    );
    return result.items
        .map((e) => int.tryParse(e['id']?.toString() ?? ''))
        .whereType<int>()
        .toList();
  }

  Future<({List<Map<String, dynamic>> items, String? message})> searchByImageListings({
    Uint8List? bytes,
    String? filePath,
    String filename = 'search.jpg',
  }) async {
    assertWebImageBytes(bytes);
    final MultipartFile part;
    if (bytes != null && bytes.isNotEmpty) {
      part = buildImageMultipart(bytes: bytes, filename: filename);
    } else if (!kIsWeb && filePath != null && filePath.isNotEmpty) {
      part = await MultipartFile.fromFile(filePath, filename: _safeImageFilename(filename));
    } else {
      throw StateError('Impossible de lire l\'image — réessayez');
    }
    final form = FormData.fromMap({'file': part});
    final r = await _api.dio.post<Map<String, dynamic>>('/listings/search-by-image', data: form);
    final items = (r.data?['items'] as List?) ?? [];
    final mapped = items.map((e) {
      final m = _mapListing(Map<String, dynamic>.from(e as Map));
      final sim = (e as Map)['similarity'];
      if (sim != null) m['similarity'] = sim;
      return m;
    }).toList();
    mapped.sort((a, b) {
      final sa = (a['similarity'] as num?)?.toDouble() ?? 0;
      final sb = (b['similarity'] as num?)?.toDouble() ?? 0;
      return sb.compareTo(sa);
    });
    return (items: mapped, message: r.data?['message']?.toString());
  }

  Future<void> _uploadForm(int listingId, FormData form) async {
    await _api.dio.post(
      '/listings/$listingId/images',
      data: form,
      options: Options(headers: {'X-Idempotency-Key': _api.newIdempotencyKey()}),
    );
  }

  Map<String, dynamic> _mapListing(Map<String, dynamic> raw, {bool detailed = false, bool includeStatus = false}) {
    final primary = raw['primary_image_url']?.toString();
    final img = (primary != null && primary.isNotEmpty) ? _api.absoluteUrl(primary) : '';
    final images = detailed
        ? ((raw['images'] as List?) ?? [])
            .map((i) {
              if (i is Map) return _api.absoluteUrl(i['url']?.toString());
              return _api.absoluteUrl(i?.toString());
            })
            .where((u) => u.isNotEmpty)
            .toList()
        : (img.isNotEmpty ? [img] : <String>[]);

    final province = RdcLocations.parseProvince(raw['attributes']);
    final commune = RdcLocations.parseCommune(raw['attributes']);
    final quartier = RdcLocations.parseQuartier(raw['attributes']);
    final avenue = RdcLocations.parseAvenue(raw['attributes']);
    final numero = RdcLocations.parseNumero(raw['attributes']);
    final locLabel = RdcLocations.displayLabel(
      province: province ?? RdcLocations.guessProvince(raw),
      commune: commune,
      quartier: quartier,
      avenue: avenue,
      numero: numero,
    );

    return {
      'id': raw['id'].toString(),
      'title': raw['title'] ?? '',
      'description': raw['description'] ?? '',
      'price': _formatPrice(raw['price_cdf']),
      'price_cdf': raw['price_cdf'],
      'city': raw['city'] ?? RdcLocations.kinshasa,
      'province': province ?? RdcLocations.guessProvince(raw),
      'location': locLabel,
      'commune': commune,
      'quartier': quartier,
      'category': raw['category_name']?.toString() ?? raw['category_id']?.toString() ?? 'Général',
      'listingType': (raw['is_official'] == true) ? 'payment' : 'contact',
      'isOfficial': raw['is_official'] == true,
      'isVerified': raw['is_official'] == true,
      'sellerRating': (raw['seller_rating'] as num?)?.toDouble() ?? 0.0,
      'seller_id': raw['seller_id']?.toString(),
      'sellerId': raw['seller_id']?.toString(),
      'sellerName': raw['seller_name']?.toString() ?? 'Vendeur',
      'images': images,
      'imageUrl': images.isNotEmpty ? images.first : '',
      'createdAt': raw['created_at'],
      'attributes': raw['attributes'],
      'size': _parseSize(raw['attributes']),
      'delivery_method': raw['delivery_method']?.toString(),
      'delivery_method_label': raw['delivery_method_label']?.toString(),
      'status': includeStatus ? (raw['status']?.toString() ?? 'active') : 'active',
    };
  }

  String? _parseSize(dynamic attributes) {
    if (attributes == null) return null;
    final s = attributes.toString();
    if (s.contains('"size"')) {
      final m = RegExp(r'"size"\s*:\s*"([^"]+)"').firstMatch(s);
      return m?.group(1);
    }
    return null;
  }

  String _formatPrice(dynamic cdf) {
    if (cdf == null) return 'Prix sur demande';
    final n = cdf is int ? cdf : int.tryParse(cdf.toString()) ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M CDF';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K CDF';
    return '$n CDF';
  }
}
