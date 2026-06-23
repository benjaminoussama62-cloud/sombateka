import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../services/app_services.dart';
import '../core/offline/offline_cache.dart';
import '../utils/constants.dart';
import '../utils/listing_attributes.dart';
import '../utils/listing_utils.dart';
import '../utils/rdc_locations.dart';

/// Façade unifiée : API + cache offline pour tous les écrans.
class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  final _app = AppServices.instance;
  List<Map<String, dynamic>> _listings = [];
  List<Map<String, dynamic>> _officialListingsCache = [];
  List<Map<String, dynamic>> _favoriteListings = [];
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _notifications = [];
  int _unreadNotifications = 0;
  final Map<String, List<Map<String, dynamic>>> _messageThreads = {};

  List<Map<String, dynamic>> get listings => List.unmodifiable(_listings);
  Map<String, dynamic>? get currentUser => _app.currentUser;

  void setCurrentUser(Map<String, dynamic> user) {
    _app.currentUser = user;
    OfflineCache.cacheUser(user);
  }

  static String normalizePhoneE164(String raw, {String defaultCode = '+243'}) {
    var p = raw.replaceAll(' ', '').replaceAll('-', '');
    if (p.startsWith('00')) p = '+${p.substring(2)}';
    if (p.startsWith('+')) return p;
    // 243812345678 → +243812345678 (évite +243243…)
    final dc = defaultCode.replaceFirst('+', '');
    if (p.startsWith(dc)) return '+$p';
    if (p.startsWith('0')) p = p.substring(1);
    return '$defaultCode$p';
  }

  /// Code OTP toujours sur 6 chiffres (ex. 082036).
  static String normalizeOtpCode(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    return digits.length >= 6 ? digits.substring(0, 6) : digits.padLeft(6, '0');
  }

  Future<void> refreshListings({
    String? q,
    String? city,
    String? size,
    int? categoryId,
    bool? isOfficial,
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
    bool mixPromoted = false,
  }) async {
    final raw = await _app.listings.fetchListings(
      q: q,
      city: city,
      province: province,
      size: size,
      categoryId: categoryId,
      isOfficial: isOfficial,
      minPrice: minPrice,
      maxPrice: maxPrice,
      color: color,
      condition: condition,
      brand: brand,
      gender: gender,
      audience: audience,
      minRating: minRating,
      commune: commune,
      quartier: quartier,
      mixPromoted: mixPromoted,
    );
    _listings = normalizeListings(
      raw,
      favoriteIds: _app.favoriteIds,
      currentUserId: _app.currentUser?['id']?.toString(),
    );
    await OfflineCache.cacheListings(_listings);
  }

  List<Map<String, dynamic>> _myListingsCache = [];

  List<Map<String, dynamic>> get myListings => List.unmodifiable(_myListingsCache);

  Future<void> refreshMyListings() async {
    if (!await hasApiSession()) {
      _myListingsCache = [];
      return;
    }
    final raw = await _app.listings.fetchMyListings();
    _myListingsCache = normalizeListings(
      raw,
      favoriteIds: _app.favoriteIds,
      currentUserId: _app.currentUser?['id']?.toString(),
    ).map((l) => {...l, 'isOwnListing': true, 'seller_id': _app.currentUser?['id']?.toString()}).toList();
  }

  /// Clé de fil : 1 produit = 1 conversation (support SombaTeka = fil unique).
  static String messageThreadKey({
    required String peerId,
    String? listingId,
    bool isOfficialPeer = false,
    bool isTeamPeer = false,
  }) {
    if (isTeamPeer) return '${peerId}_helpdesk';
    final lid = listingId ?? '0';
    return '${peerId}_$lid';
  }

  static bool isHelpdeskThread({bool isOfficialPeer = false, bool isTeamPeer = false}) {
    return isTeamPeer;
  }

  Future<void> republishListing(int listingId) async {
    await _app.listings.republish(listingId);
    await refreshMyListings();
    await refreshListings();
  }

  Future<List<Map<String, dynamic>>> fetchListingInquirers(int listingId) async {
    return _app.listings.fetchInquirers(listingId);
  }

  Future<Map<String, dynamic>> markListingSold(int listingId, {int? buyerId}) async {
    final r = await _app.listings.markSold(listingId, buyerId: buyerId);
    await refreshMyListings();
    await refreshListings();
    await refreshConversations();
    return r;
  }

  Future<void> deleteMyListing(int listingId) async {
    await _app.listings.deleteListing(listingId);
    await refreshMyListings();
    await refreshListings();
  }

  Future<Map<String, dynamic>?> fetchListingDetail(int id) async {
    final raw = await _app.listings.fetchDetail(id);
    return normalizeListing(
      raw,
      favoriteIds: _app.favoriteIds,
      currentUserId: _app.currentUser?['id']?.toString(),
    );
  }

  Future<void> addListingToCart(
    Map<String, dynamic> listing, {
    int quantity = 1,
    String? variantSize,
    String? variantColor,
  }) async {
    final uid = _app.currentUser?['id']?.toString();
    if (isOwnListing(listing, uid)) {
      throw Exception('Vous ne pouvez pas ajouter votre propre annonce au panier');
    }
    final id = int.tryParse(listing['id']?.toString() ?? '');
    if (id == null) return;
    final official = listing['isOfficial'] == true || listing['is_official'] == true;
    await _app.cart.add(
      id,
      quantity: official ? quantity : 1,
      variantSize: variantSize,
      variantColor: variantColor,
    );
    await loadCart();
  }

  Future<void> refreshUser() async {
    await _app.refreshUser();
    _syncUserDisplayFields();
  }

  /// Nom affiché pour le profil (jamais « Non connecté » si session valide).
  String profileDisplayName([Map<String, dynamic>? user]) {
    final u = user ?? _app.currentUser;
    if (u == null) return 'Mon profil';
    final dn = u['display_name']?.toString().trim();
    if (dn != null && dn.isNotEmpty) return dn;
    final name = u['name']?.toString().trim();
    if (name != null && name.isNotEmpty && name != 'Utilisateur') return name;
    final official = u['official_name']?.toString().trim();
    if (official != null && official.isNotEmpty) return official;
    return 'Mon profil';
  }

  Future<Map<String, dynamic>> sendOtp(String phoneE164) async {
    final r = await _app.auth.sendOtp(phoneE164);
    return Map<String, dynamic>.from(r);
  }

  Future<Map<String, dynamic>> sendEmailOtp(String email, {String? displayName}) async {
    final r = await _app.auth.sendEmailOtp(email, displayName: displayName);
    return Map<String, dynamic>.from(r);
  }

  Future<void> verifyOtp(String phoneE164, String code) async {
    await _app.auth.verifyOtp(phoneE164, code);
    await refreshUser();
    _syncUserDisplayFields();
    _myListingsCache = [];
    await refreshMyListings();
  }

  Future<void> verifyEmailOtp(String email, String code) async {
    await _app.auth.verifyEmailOtp(email, code);
    await refreshUser();
    _syncUserDisplayFields();
    _myListingsCache = [];
    await refreshMyListings();
  }

  /// Connexion API réelle (dev ou après OTP).
  Future<void> loginWithPhone(String phoneE164, {bool useDevLogin = false}) async {
    _myListingsCache = [];
    _messageThreads.clear();
    _conversations = [];
    if (useDevLogin) {
      await _app.auth.devLogin(phoneE164);
    }
    await refreshUser();
    _syncUserDisplayFields();
    await refreshMyListings();
  }

  Future<bool> hasApiSession() => _app.auth.hasSession();

  /// Compte réel (OTP téléphone) — pas visiteur Google/dev.
  Future<bool> hasVerifiedProfile() async {
    if (!await hasApiSession()) return false;
    final u = _app.currentUser;
    if (u == null) return false;
    final phone = u['phone_e164']?.toString() ?? '';
    if (phone == '+243000000000') return false;
    return u['is_phone_verified'] == true;
  }

  List<Map<String, dynamic>> get notifications => List.unmodifiable(_notifications);
  int get unreadNotificationCount => _unreadNotifications;

  Future<void> loadNotifications() async {
    if (!await hasApiSession()) {
      _notifications = [];
      _unreadNotifications = 0;
      return;
    }
    final data = await _app.notifications.fetchAll();
    _notifications = ((data['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    _unreadNotifications = (data['unread_count'] as int?) ?? 0;
  }

  Future<void> markNotificationRead(int id) async {
    await _app.notifications.markRead(id);
    final i = _notifications.indexWhere((n) => n['id'] == id);
    if (i >= 0) {
      _notifications[i]['is_read'] = true;
      _unreadNotifications = _notifications.where((n) => n['is_read'] != true).length;
    }
  }

  Future<void> markAllNotificationsRead() async {
    await _app.notifications.markAllRead();
    for (final n in _notifications) {
      n['is_read'] = true;
    }
    _unreadNotifications = 0;
  }

  void _applyUserFromApi(Map<String, dynamic> user) {
    _app.currentUser = Map<String, dynamic>.from(user);
    _syncUserDisplayFields();
  }

  void _syncUserDisplayFields() {
    if (_app.currentUser == null) return;
    _app.currentUser!['name'] = profileDisplayName(_app.currentUser);
    _app.currentUser!['phone'] = _app.currentUser!['phone_e164'];
    final avatar = _app.currentUser!['avatar_url']?.toString();
    if (avatar != null && avatar.isNotEmpty) {
      _app.currentUser!['avatarUrl'] = _app.api.absoluteUrl(avatar);
    } else {
      _app.currentUser!['avatarUrl'] = null;
    }
    final role = _app.currentUser!['role']?.toString() ?? '';
    final verified = _app.currentUser!['is_verified_seller'] == true;
    _app.currentUser!['status'] = verified || role.contains('official')
        ? AppStatus.official
        : AppStatus.ordinary;
    setCurrentUser(_app.currentUser!);
  }

  Map<String, dynamic> createUser({
    required String phone,
    required String name,
    required String city,
    String status = 'ordinary',
  }) {
    final user = {
      'id': _app.currentUser?['id']?.toString() ?? '',
      'phone': phone,
      'name': name,
      'city': city,
      'status': status,
      'isVerified': _app.currentUser?['is_verified_seller'] == true,
    };
    setCurrentUser(user);
    return user;
  }

  Future<void> updateChatMessage({
    required int messageId,
    required String peerId,
    String? listingId,
    bool isOfficialPeer = false,
    required String content,
  }) async {
    await _app.messages.updateMessage(messageId, content);
    await loadThread(peerId, listingId: listingId, isOfficialPeer: isOfficialPeer);
    await refreshConversations();
  }

  Future<void> deleteChatMessage({
    required int messageId,
    required String peerId,
    String? listingId,
    bool isOfficialPeer = false,
  }) async {
    await _app.messages.deleteMessage(messageId);
    await loadThread(peerId, listingId: listingId, isOfficialPeer: isOfficialPeer);
    await refreshConversations();
  }

  Future<Map<String, dynamic>> createListing({
    required String userId,
    required String title,
    required String description,
    required String price,
    required String category,
    required String location,
    required String listingType,
    required List<String> images,
    List<XFile>? imageFiles,
    List<Uint8List>? imageBytesList,
    int? categoryId,
    int stock = 1,
    String? size,
    String? condition,
    String? brand,
    String? color,
    String? province,
    String? commune,
    String? quartier,
    String? avenue,
    String? numero,
  }) async {
    if (!await hasApiSession()) {
      throw Exception('SESSION_REQUIRED');
    }
    final priceCdf = int.tryParse(price.replaceAll(RegExp(r'[^0-9]'), ''));
    final attributes = ListingAttributes.buildAttributes(
      category: category,
      size: size,
      province: province,
      commune: commune,
      quartier: quartier,
      avenue: avenue,
      numero: numero,
      condition: condition,
      brand: brand,
      color: color,
    );
    final attrs = attributes.isEmpty ? null : attributes;
    final id = await _app.listings.createListing(
      title: title,
      city: location,
      description: description,
      priceCdf: priceCdf,
      categoryId: categoryId,
      attributes: attrs,
    );
    final files = imageFiles ?? [];
    var uploaded = 0;
    String? lastUploadError;

    if (files.isNotEmpty) {
      for (var i = 0; i < files.length; i++) {
        final x = files[i];
        try {
          final bytes = (imageBytesList != null && i < imageBytesList.length)
              ? imageBytesList[i]
              : await x.readAsBytes();
          if (bytes.isEmpty) {
            lastUploadError = 'Photo ${i + 1} vide';
            continue;
          }
          final name = _photoFilename(x.name, i);
          final mime = name.toLowerCase().endsWith('.png')
              ? 'image/png'
              : (name.toLowerCase().endsWith('.webp') ? 'image/webp' : 'image/jpeg');
          if (kIsWeb || x.path.isEmpty) {
            await _app.listings.uploadImageBytes(id, bytes: bytes, filename: name, contentType: mime);
          } else {
            await _app.listings.uploadImage(id, x.path);
          }
          uploaded++;
        } catch (e) {
          lastUploadError = e.toString();
        }
      }
    } else {
      for (var i = 0; i < images.length; i++) {
        final path = images[i];
        if (path.isNotEmpty && !path.startsWith('http')) {
          try {
            await _app.listings.uploadImage(id, path);
            uploaded++;
          } catch (e) {
            lastUploadError = e.toString();
          }
        }
      }
    }

    if (files.isNotEmpty && uploaded == 0) {
      throw Exception(lastUploadError ?? 'Impossible d\'envoyer les photos');
    }

    await refreshListings();
    await refreshMyListings();
    final found = _listings.where((l) => l['id']?.toString() == id.toString());
    if (found.isNotEmpty) return found.first;
    return {
      'id': id.toString(),
      'title': title,
      'price': price,
      'location': location,
      'category': category,
      'listingType': listingType,
      'imageUrl': '',
      'sellerName': profileDisplayName(),
    };
  }

  Future<Map<String, dynamic>> createOfficialCollection({
    required String publicationTitle,
    required String location,
    String? province,
    String? commune,
    String? quartier,
    String? avenue,
    String? numero,
    required String category,
    int? categoryId,
    required String brand,
    required String gender,
    required String audience,
    required String deliveryMethod,
    required List<({
      String title,
      String? description,
      String? condition,
      String? defaultColor,
      List<Map<String, dynamic>> variants,
      List<XFile> imageFiles,
      List<Uint8List> imageBytesList,
    })> products,
  }) async {
    if (!await hasApiSession()) throw Exception('SESSION_REQUIRED');
    final productPayloads = products
        .map((p) => {
              'title': p.title,
              if (p.description != null && p.description!.isNotEmpty) 'description': p.description,
              if (p.condition != null) 'condition': p.condition,
              if (p.defaultColor != null) 'default_color': p.defaultColor,
              'variants': p.variants,
            })
        .toList();

    final created = await _app.listings.createOfficialCollection(
      publicationTitle: publicationTitle,
      city: location,
      categoryId: categoryId,
      brand: brand,
      gender: gender,
      audience: audience,
      province: province,
      commune: commune,
      quartier: quartier,
      avenue: avenue,
      numero: numero,
      deliveryMethod: deliveryMethod,
      products: productPayloads,
    );

    for (var i = 0; i < created.listingIds.length && i < products.length; i++) {
      final id = created.listingIds[i];
      final p = products[i];
      for (var j = 0; j < p.imageFiles.length; j++) {
        final x = p.imageFiles[j];
        try {
          final bytes = j < p.imageBytesList.length ? p.imageBytesList[j] : await x.readAsBytes();
          if (bytes.isEmpty) continue;
          final name = _photoFilename(x.name, j);
          final mime = name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
          if (kIsWeb || x.path.isEmpty) {
            await _app.listings.uploadImageBytes(id, bytes: bytes, filename: name, contentType: mime);
          } else {
            await _app.listings.uploadImage(id, x.path);
          }
        } catch (_) {}
      }
    }

    await refreshListings(mixPromoted: true);
    await refreshMyListings();
    return {
      'publicationId': created.publicationId,
      'listingIds': created.listingIds,
      'productCount': created.listingIds.length,
    };
  }

  Future<Map<String, dynamic>> createOfficialCatalog({
    required String title,
    required String description,
    required String location,
    String? province,
    String? commune,
    String? quartier,
    String? avenue,
    String? numero,
    required String category,
    int? categoryId,
    required String brand,
    required String gender,
    required String audience,
    String? condition,
    String? defaultColor,
    required List<Map<String, dynamic>> variants,
    required String deliveryMethod,
    List<XFile>? imageFiles,
    List<Uint8List>? imageBytesList,
  }) async {
    if (!await hasApiSession()) throw Exception('SESSION_REQUIRED');
    final id = await _app.listings.createOfficialCatalog(
      title: title,
      city: location,
      description: description,
      categoryId: categoryId,
      brand: brand,
      gender: gender,
      audience: audience,
      condition: condition,
      defaultColor: defaultColor,
      variants: variants,
      province: province,
      commune: commune,
      quartier: quartier,
      avenue: avenue,
      numero: numero,
      deliveryMethod: deliveryMethod,
    );
    final files = imageFiles ?? [];
    for (var i = 0; i < files.length; i++) {
      final x = files[i];
      try {
        final bytes = (imageBytesList != null && i < imageBytesList.length)
            ? imageBytesList[i]
            : await x.readAsBytes();
        if (bytes.isEmpty) continue;
        final name = _photoFilename(x.name, i);
        final mime = name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
        if (kIsWeb || x.path.isEmpty) {
          await _app.listings.uploadImageBytes(id, bytes: bytes, filename: name, contentType: mime);
        } else {
          await _app.listings.uploadImage(id, x.path);
        }
      } catch (_) {}
    }
    await refreshListings();
    await refreshMyListings();
    final found = _listings.where((l) => l['id']?.toString() == id.toString());
    if (found.isNotEmpty) return found.first;
    return {'id': id.toString(), 'title': title};
  }

  String _photoFilename(String raw, int index) {
    final n = raw.trim();
    if (n.isNotEmpty && n.contains('.')) return n;
    return 'photo_${index + 1}.jpg';
  }

  List<Map<String, dynamic>> getParticularListings() =>
      _listings.where((l) => l['isOfficial'] != true).toList();

  /// Fil accueil particuliers uniquement.
  List<Map<String, dynamic>> getHomeFeedListings() => List.unmodifiable(_listings);

  /// Toutes les annonces (particuliers + officiels) pour recherche / variantes.
  List<Map<String, dynamic>> getAllListings() =>
      List.unmodifiable([..._listings, ..._officialListingsCache]);

  /// Recharge les fils accueil Particulier et Professionnel séparément.
  Future<void> refreshHomeFeeds({String? province}) async {
    final uid = _app.currentUser?['id']?.toString();
    final fav = _app.favoriteIds;
    final rawAll = await _app.listings.fetchListings(province: province, mixPromoted: false);
    var normalized = normalizeListings(rawAll, favoriteIds: fav, currentUserId: uid);

    final rawOfficial = await _app.listings.fetchListings(province: province, isOfficial: true);
    final officialFromApi = normalizeListings(rawOfficial, favoriteIds: fav, currentUserId: uid);
    final proFromAll = normalized.where(isProListing).toList();
    final byId = <String, Map<String, dynamic>>{};
    for (final l in [...officialFromApi, ...proFromAll]) {
      final id = l['id']?.toString();
      if (id != null && id.isNotEmpty) byId[id] = l;
    }
    _officialListingsCache = byId.values.toList();
    _listings = normalized.where((l) {
      final id = l['id']?.toString() ?? '';
      return id.isEmpty || !byId.containsKey(id);
    }).toList();
    await OfflineCache.cacheListings(getAllListings());
  }

  /// Fil accueil : particuliers + comptes officiels promus (mix API).

  /// Bandeau horizontal des produits officiels promus.
  List<Map<String, dynamic>> getPromotedOfficialListings() {
    final official = _listings.where((l) => l['isOfficial'] == true).toList();
    if (official.isEmpty) return [];
    final bySeller = <String, List<Map<String, dynamic>>>{};
    for (final l in official) {
      final sid = l['seller_id']?.toString() ?? '0';
      bySeller.putIfAbsent(sid, () => []).add(l);
    }
    final queues = bySeller.values.map((list) {
      list.sort((a, b) {
        final ta = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime(2000);
        final tb = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime(2000);
        return tb.compareTo(ta);
      });
      return List<Map<String, dynamic>>.from(list);
    }).toList();
    final out = <Map<String, dynamic>>[];
    while (queues.any((q) => q.isNotEmpty)) {
      for (final q in queues) {
        if (q.isNotEmpty) out.add({...q.removeAt(0), 'promoted': true});
      }
    }
    return out;
  }

  /// Produits de la même publication officielle (même écran, plusieurs variantes).
  List<Map<String, dynamic>> getPublicationSiblings(Map<String, dynamic> listing) {
    final pid = listing['publicationId']?.toString() ??
        ListingAttributes.publicationId(listing['attributes']);
    if (pid == null || pid.isEmpty || pid.startsWith('solo_')) {
      return [normalizeListing(listing, favoriteIds: _app.favoriteIds, currentUserId: _app.currentUser?['id']?.toString())];
    }
    final siblings = getAllListings()
        .where((l) {
          final other = l['publicationId']?.toString() ?? ListingAttributes.publicationId(l['attributes']);
          return other == pid;
        })
        .map((l) => normalizeListing(l, favoriteIds: _app.favoriteIds, currentUserId: _app.currentUser?['id']?.toString()))
        .toList();
    if (siblings.isEmpty) {
      return [normalizeListing(listing, favoriteIds: _app.favoriteIds, currentUserId: _app.currentUser?['id']?.toString())];
    }
    siblings.sort((a, b) {
      final ia = ListingAttributes.decodeMap(a['attributes'])?['product_index'] as num? ?? 0;
      final ib = ListingAttributes.decodeMap(b['attributes'])?['product_index'] as num? ?? 0;
      return ia.compareTo(ib);
    });
    return siblings;
  }

  List<Map<String, dynamic>> getOfficialProductListings() =>
      _officialListingsCache.isNotEmpty
          ? List.unmodifiable(_officialListingsCache)
          : _listings.where((l) => isProListing(l)).toList();

  /// Publications officielles groupées (1 publication → plusieurs produits).
  List<Map<String, dynamic>> getOfficialPublications() {
    final official = getOfficialProductListings();
    if (official.isEmpty) return [];
    final pubs = <String, Map<String, dynamic>>{};
    for (final l in official) {
      final pid = l['publicationId']?.toString() ??
          ListingAttributes.publicationId(l['attributes']) ??
          'solo_${l['id']}';
      final pubTitle = ListingAttributes.publicationTitle(l['attributes']) ??
          l['title']?.toString() ??
          'Publication';
      pubs.putIfAbsent(pid, () => {
        'id': pid,
        'title': pubTitle,
        'sellerId': l['seller_id']?.toString() ?? '',
        'sellerName': l['sellerName']?.toString() ?? 'Boutique officielle',
        'location': l['location'] ?? l['city'] ?? '',
        'products': <Map<String, dynamic>>[],
      });
      (pubs[pid]!['products'] as List<Map<String, dynamic>>).add(l);
    }
    final list = pubs.values.toList();
    list.sort((a, b) {
      final pa = (a['products'] as List).length;
      final pb = (b['products'] as List).length;
      return pb.compareTo(pa);
    });
    return list;
  }

  bool get isOfficialSeller {
    final u = _app.currentUser;
    if (u == null) return false;
    if (u['is_verified_seller'] == true || u['isVerified'] == true) return true;
    final role = u['role']?.toString().toLowerCase() ?? '';
    return role.contains('official');
  }

  /// Stats tableau de bord vendeur officiel.
  Map<String, dynamic> getBusinessDashboardStats() {
    final uid = _app.currentUser?['id']?.toString();
    if (uid == null) {
      return {'productCount': 0, 'publicationCount': 0, 'totalStock': 0, 'promotedOnHome': 0, 'publications': <Map<String, dynamic>>[]};
    }
    final mine = _myListingsCache.isNotEmpty
        ? _myListingsCache
        : getUserListings(uid);
    final catalog = mine.where((l) => ListingAttributes.isCatalogListing(l['attributes'])).toList();
    var totalStock = 0;
    for (final l in catalog) {
      totalStock += ListingAttributes.catalogTotalStock(l['attributes']);
    }
    final pubMap = <String, Map<String, dynamic>>{};
    for (final l in catalog) {
      final pid = ListingAttributes.publicationId(l['attributes']) ?? 'solo_${l['id']}';
      final title = ListingAttributes.publicationTitle(l['attributes']) ?? l['title']?.toString() ?? 'Publication';
      pubMap.putIfAbsent(pid, () => {'title': title, 'productCount': 0});
      pubMap[pid]!['productCount'] = (pubMap[pid]!['productCount'] as int) + 1;
    }
    final promotedOnHome = catalog.where((l) {
      final id = l['id']?.toString();
      return _listings.any((f) => f['id']?.toString() == id && (f['promoted'] == true || f['isOfficial'] == true));
    }).length;
    final sold = mine.where((l) => l['status']?.toString() == 'sold').length;
    final active = mine.where((l) => l['status']?.toString() == 'active').length;
    var revenue = 0;
    for (final l in mine.where((x) => x['status']?.toString() == 'sold')) {
      revenue += int.tryParse(l['price_cdf']?.toString() ?? l['price']?.toString().replaceAll(RegExp(r'[^\d]'), '') ?? '0') ?? 0;
    }
    return {
      'productCount': catalog.length,
      'publicationCount': pubMap.length,
      'totalStock': totalStock,
      'promotedOnHome': promotedOnHome,
      'publications': pubMap.values.toList(),
      'soldCount': sold,
      'activeCount': active,
      'revenueCdf': revenue,
    };
  }

  List<Map<String, dynamic>> getProfessionalStores() {
    final official = getOfficialProductListings();
    if (official.isEmpty) return [];
    final bySeller = <String, List<Map<String, dynamic>>>{};
    for (final l in official) {
      final sid = l['seller_id']?.toString() ?? '0';
      bySeller.putIfAbsent(sid, () => []).add(l);
    }
    return bySeller.entries.map((e) {
      final first = e.value.first;
      return {
        'id': e.key,
        'name': first['sellerName']?.toString() ?? 'Boutique certifiée',
        'verified': true,
        'listings': e.value,
        'totalListings': e.value.length,
        'location': first['location'] ?? first['city'],
      };
    }).toList();
  }

  Future<void> refreshConversations() async {
    if (!await _app.auth.hasSession()) return;
    final items = await _app.messages.fetchConversations();
    _conversations = items.map((c) {
      final peerId = c['peer_id'].toString();
      final listingId = c['listing_id']?.toString();
      final official = c['is_official_peer'] == true;
      final team = c['is_team_peer'] == true;
      final threadKey = messageThreadKey(
        peerId: peerId,
        listingId: listingId,
        isOfficialPeer: official,
        isTeamPeer: team,
      );
      return {
        'id': threadKey,
        'peer_id': peerId,
        'listingId': listingId,
        'listingTitle': c['listing_title']?.toString(),
        'listingImageUrl': c['listing_image_url']?.toString(),
        'isOfficialPeer': official,
        'isTeamPeer': team,
        'userName': c['peer_name'] ?? 'Utilisateur',
        'lastMessage': c['last_message'] ?? '',
        'lastMessageTime': c['last_at'],
        'unreadCount': c['unread_count'] ?? 0,
      };
    }).toList();
  }

  List<Map<String, dynamic>> getUserConversations(String userId) => _conversations;

  Future<void> loadThread(
    String peerId, {
    String? listingId,
    bool isOfficialPeer = false,
    bool isTeamPeer = false,
  }) async {
    final key = messageThreadKey(
      peerId: peerId,
      listingId: listingId,
      isOfficialPeer: isOfficialPeer,
      isTeamPeer: isTeamPeer,
    );
    final helpdesk = isHelpdeskThread(isOfficialPeer: isOfficialPeer, isTeamPeer: isTeamPeer);
    final lid = helpdesk ? null : int.tryParse(listingId ?? '');
    final messages = await _app.messages.fetchThread(int.parse(peerId), listingId: lid);
    final me = currentUser?['id']?.toString();
    _messageThreads[key] = messages.map((m) {
      final created = _parseDate(m['createdAt']);
      final updated = _parseDate(m['updatedAt'] ?? m['createdAt']);
      return {
        'id': m['id'],
        'message': m['content']?.toString() ?? '',
        'isMe': m['senderId']?.toString() == me,
        'timestamp': created,
        'updatedAt': updated,
        'edited': updated.difference(created).inSeconds > 2,
        'isRead': m['isRead'] == true,
        'kind': m['kind']?.toString() ?? 'text',
        'listingId': m['listingId']?.toString() ?? listingId,
      };
    }).toList();
  }

  DateTime _parseDate(dynamic v) {
    if (v is DateTime) return v;
    if (v == null) return DateTime.now();
    return DateTime.tryParse(v.toString()) ?? DateTime.now();
  }

  /// Ouvre une discussion : charge l'historique et marque comme lu.
  Future<void> prepareChatWithPeer({
    required String peerId,
    String? listingId,
    bool isOfficialPeer = false,
    bool isTeamPeer = false,
  }) async {
    if (!await _app.auth.hasSession()) return;
    final pid = int.tryParse(peerId);
    if (pid == null) return;
    await loadThread(
      peerId,
      listingId: listingId,
      isOfficialPeer: isOfficialPeer,
      isTeamPeer: isTeamPeer,
    );
    try {
      final helpdesk = isHelpdeskThread(isOfficialPeer: isOfficialPeer, isTeamPeer: isTeamPeer);
      final lid = helpdesk ? null : int.tryParse(listingId ?? '');
      await _app.messages.markRead(pid, listingId: lid);
    } catch (_) {}
    await refreshConversations();
  }

  Future<Map<String, dynamic>> fetchSupportContact() async {
    return _app.support.fetchContact();
  }

  Future<void> openSupportChat() async {
    final contact = await fetchSupportContact();
    final peerId = contact['peer_id']?.toString();
    if (peerId == null) return;
    await prepareChatWithPeer(
      peerId: peerId,
      isTeamPeer: true,
    );
  }

  int? _inferListingIdFromThread(
    String peerId, {
    String? listingId,
    bool isOfficialPeer = false,
  }) {
    final parsed = int.tryParse(listingId ?? '');
    if (parsed != null) return parsed;
    final msgs = getConversationMessages(peerId, listingId: listingId, isOfficialPeer: isOfficialPeer);
    for (final m in msgs) {
      final lid = int.tryParse(m['listingId']?.toString() ?? '');
      if (lid != null) return lid;
    }
    for (final c in _conversations) {
      if (c['peer_id']?.toString() == peerId) {
        final lid = int.tryParse(c['listingId']?.toString() ?? '');
        if (lid != null) return lid;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> getConversationMessages(
    String peerId, {
    String? listingId,
    bool isOfficialPeer = false,
    bool isTeamPeer = false,
  }) {
    final key = messageThreadKey(
      peerId: peerId,
      listingId: listingId,
      isOfficialPeer: isOfficialPeer,
      isTeamPeer: isTeamPeer,
    );
    return _messageThreads[key] ?? [];
  }

  Future<void> sendMessage({
    required String peerId,
    required String senderId,
    required String content,
    String? listingId,
    bool isOfficialPeer = false,
    bool isTeamPeer = false,
  }) async {
    final rid = int.parse(peerId);
    final helpdesk = isHelpdeskThread(isOfficialPeer: isOfficialPeer, isTeamPeer: isTeamPeer);
    var lid = helpdesk ? null : int.tryParse(listingId ?? '');
    if (!helpdesk && lid == null) {
      lid = _inferListingIdFromThread(peerId, listingId: listingId, isOfficialPeer: isOfficialPeer);
    }
    await _app.messages.sendMessage(
      recipientId: rid,
      content: content,
      listingId: lid,
    );
    await loadThread(
      peerId,
      listingId: listingId,
      isOfficialPeer: isOfficialPeer,
      isTeamPeer: isTeamPeer,
    );
    await refreshConversations();
  }

  /// Lance l'écran chat avec le vendeur d'une annonce.
  Future<void> openSellerChat({
    required String sellerId,
    String? sellerName,
    String? listingId,
    String? listingTitle,
    String? listingImageUrl,
  }) async {
    await prepareChatWithPeer(peerId: sellerId, listingId: listingId);
  }

  Future<Map<String, dynamic>> payListing({
    required int listingId,
    required String provider,
    String? variantSize,
    String? variantColor,
    int quantity = 1,
  }) async {
    final order = await _app.orders.createOrder(
      listingId,
      variantSize: variantSize,
      variantColor: variantColor,
      quantity: quantity,
    );
    final orderId = order['id'] as int;
    final pay = await _app.orders.payOrder(orderId, provider);
    return {...pay, 'order_id': orderId};
  }

  Future<Map<String, dynamic>> confirmOrderReceipt(int orderId) async {
    return _app.orders.confirmReceipt(orderId);
  }

  Future<void> reportListing({
    required int listingId,
    int? targetUserId,
    required String reason,
    String? details,
  }) async {
    await _app.api.post('/reports/', data: {
      'listing_id': listingId,
      if (targetUserId != null) 'target_user_id': targetUserId,
      'reason': reason,
      if (details != null) 'details': details,
    });
  }

  Future<Map<String, dynamic>> submitKyc({
    required String businessName,
    required String businessType,
    String? rccm,
    String? taxId,
    String? legalRepresentative,
    String? businessAddress,
    String? contactPhone,
    String? applicantNote,
    Uint8List? docRccmBytes,
    String? docRccmFilename,
    Uint8List? docTaxBytes,
    String? docTaxFilename,
    Uint8List? docIdBytes,
    String? docIdFilename,
    Uint8List? docShopBytes,
    String? docShopFilename,
  }) async {
    return _app.kyc.apply(
      businessName: businessName,
      businessType: businessType,
      rccm: rccm,
      taxId: taxId,
      legalRepresentative: legalRepresentative,
      businessAddress: businessAddress,
      contactPhone: contactPhone,
      applicantNote: applicantNote,
      docRccmBytes: docRccmBytes,
      docRccmFilename: docRccmFilename,
      docTaxBytes: docTaxBytes,
      docTaxFilename: docTaxFilename,
      docIdBytes: docIdBytes,
      docIdFilename: docIdFilename,
      docShopBytes: docShopBytes,
      docShopFilename: docShopFilename,
    );
  }

  Future<List<Map<String, dynamic>>> fetchMyOrders() async {
    if (!await hasApiSession()) return [];
    return _app.orders.listMyOrders();
  }

  Future<Map<String, dynamic>?> fetchKycStatus() async {
    if (!await _app.auth.hasSession()) return null;
    return _app.kyc.fetchMyApplication();
  }

  Future<List<Map<String, dynamic>>> fetchCategories() async {
    return _app.categories.fetchCategories();
  }

  Future<void> sendMessageToSeller({
    required String sellerId,
    required String content,
    String? listingId,
  }) async {
    await _app.messages.sendMessage(
      recipientId: int.parse(sellerId),
      content: content,
      listingId: listingId != null ? int.tryParse(listingId) : null,
    );
  }

  Future<void> clearAllData() async {
    await _app.auth.logout();
    _app.currentUser = null;
    _listings = [];
    _myListingsCache = [];
    _conversations = [];
    _messageThreads.clear();
  }

  Future<void> deleteAccount() async {
    await _app.users.deleteAccount();
    await clearAllData();
  }

  List<Map<String, dynamic>> searchListings({
    String? query,
    String? category,
    double? minPrice,
    double? maxPrice,
    String? location,
    String? size,
    String? color,
    String? condition,
    String? brand,
    String? gender,
    String? audience,
    String? commune,
    String? quartier,
    bool? officialOnly,
    double? minSellerRating,
  }) {
    var results = _listings;
    if (query != null && query.isNotEmpty) {
      final q = query.toLowerCase();
      results = results
          .where((l) =>
              l['title'].toString().toLowerCase().contains(q) ||
              l['description'].toString().toLowerCase().contains(q) ||
              (l['size']?.toString().toLowerCase().contains(q) ?? false))
          .toList();
    }
    if (category != null && category.isNotEmpty && category != 'Toutes') {
      final c = category.toLowerCase();
      results = results
          .where((l) {
            final lc = l['category'].toString().toLowerCase();
            return lc.contains(c) || c.contains(lc);
          })
          .toList();
    }
    if (minPrice != null || maxPrice != null) {
      final min = minPrice ?? 0;
      final max = maxPrice ?? double.infinity;
      results = results.where((l) {
        final p = l['price_cdf'] is int
            ? (l['price_cdf'] as int).toDouble()
            : double.tryParse(l['price_cdf']?.toString() ?? '') ??
                double.tryParse(l['price'].toString().replaceAll(RegExp(r'[^0-9]'), '')) ??
                0;
        return p >= min && p <= max;
      }).toList();
    }
    if (location != null && location.isNotEmpty) {
      results = results
          .where((l) => l['location'].toString().toLowerCase().contains(location.toLowerCase()))
          .toList();
    }
    if (size != null && size.isNotEmpty) {
      results = results.where((l) => ListingAttributes.matchesSize(l, size)).toList();
    }
    results = results
        .where((l) => ListingAttributes.matchesExtraFilters(
              l,
              condition: condition,
              color: color,
              brand: brand,
              gender: gender,
              audience: audience,
              commune: commune,
              quartier: quartier,
              officialOnly: officialOnly,
              minSellerRating: minSellerRating,
            ))
        .toList();
    return results;
  }

  Future<({List<Map<String, dynamic>> items, String? message})> searchByImage({
    required Uint8List bytes,
    String filename = 'search.jpg',
  }) async {
    return _app.listings.searchByImageListings(bytes: bytes, filename: filename);
  }

  Future<({
    List<Map<String, dynamic>> items,
    String? message,
    String? sourceTitle,
    String? sourceImageUrl,
  })> fetchSimilarListings(int listingId) async {
    return _app.listings.fetchSimilar(listingId);
  }

  List<Map<String, dynamic>> getUserListings(String userId) {
    final me = _app.currentUser?['id']?.toString();
    if (me != null && me == userId.toString() && _myListingsCache.isNotEmpty) {
      return List<Map<String, dynamic>>.from(_myListingsCache);
    }
    if (me != null && me == userId.toString()) {
      return [];
    }
    return _listings
        .where((l) =>
            l['seller_id']?.toString() == userId.toString() ||
            l['sellerId']?.toString() == userId.toString())
        .toList();
  }

  List<Map<String, dynamic>> getFavoriteListings() {
    if (_favoriteListings.isNotEmpty) return List.unmodifiable(_favoriteListings);
    return _listings
        .where((l) {
          final id = int.tryParse(l['id']?.toString() ?? '');
          return id != null && _app.favoriteIds.contains(id);
        })
        .toList();
  }

  List<Map<String, dynamic>> get cartItems => List.unmodifiable(_app.cartItems);

  List<Map<String, dynamic>> getUserFavorites(String userId) => getFavoriteListings();

  Map<String, dynamic> getUserStats(String userId) {
    final ul = getUserListings(userId);
    final u = _app.currentUser;
    return {
      'totalListings': ul.length,
      'activeListings': ul.where((l) => l['status'] == 'active').length,
      'soldListings': ul.where((l) => l['status'] == 'sold').length,
      'totalViews': 0,
      'totalLikes': 0,
      'averageRating': (u?['average_rating'] as num?)?.toDouble() ?? 0.0,
      'reviewCount': (u?['review_count'] as num?)?.toInt() ?? 0,
    };
  }

  Future<List<Map<String, dynamic>>> fetchMyReviews() async {
    final uid = int.tryParse(_app.currentUser?['id']?.toString() ?? '');
    if (uid == null) return [];
    return _app.reviews.fetchForUser(uid);
  }

  Future<Map<String, dynamic>> fetchListingReviews(int listingId) async {
    return _app.reviews.fetchForListing(listingId);
  }

  Future<Map<String, dynamic>?> fetchReviewEligibility(int listingId) async {
    if (!await _app.auth.hasSession()) return null;
    return _app.reviews.fetchEligibility(listingId);
  }

  Future<bool> hasReviewedListing(int listingId) async {
    if (!await _app.auth.hasSession()) return false;
    return _app.reviews.hasReviewForListing(listingId);
  }

  Future<void> submitReview({
    required int listingId,
    required int rating,
    String? comment,
  }) async {
    await _app.reviews.submit(listingId: listingId, rating: rating, comment: comment);
    await refreshUser();
  }

  Future<void> hideConversation({
    required String peerId,
    String? listingId,
    bool isOfficialPeer = false,
    bool isTeamPeer = false,
  }) async {
    final pid = int.parse(peerId);
    final lid = isHelpdeskThread(isTeamPeer: isTeamPeer) ? null : int.tryParse(listingId ?? '');
    await _app.messages.hideConversation(peerId: pid, listingId: lid);
    await refreshConversations();
  }

  Future<void> blockPeer(String peerId) async {
    await _app.messages.blockPeer(int.parse(peerId));
    await refreshConversations();
  }

  Future<void> unblockPeer(String peerId) async {
    await _app.messages.unblockPeer(int.parse(peerId));
  }

  Future<List<Map<String, dynamic>>> fetchBlockedUsers() async {
    return _app.users.fetchBlocked();
  }

  Future<void> reportPeer({
    required String peerId,
    required String reason,
    String? details,
    String? listingId,
  }) async {
    await _app.messages.reportUser(
      targetUserId: int.parse(peerId),
      reason: reason,
      details: details,
      listingId: int.tryParse(listingId ?? ''),
    );
  }

  Future<void> updatePrivacySettings({
    bool? profilePublic,
    bool? showPhone,
    bool? allowMessages,
  }) async {
    await _app.users.updatePrivacy(
      profilePublic: profilePublic,
      showPhone: showPhone,
      allowMessages: allowMessages,
    );
    await refreshUser();
  }

  Future<void> toggleFavorite(String listingId) async {
    final id = int.tryParse(listingId);
    if (id == null) return;
    if (_app.favoriteIds.contains(id)) {
      await _app.favorites.remove(id);
      _app.favoriteIds.remove(id);
    } else {
      await _app.favorites.add(id);
      _app.favoriteIds.add(id);
    }
  }

  Future<void> loadFavorites() async {
    if (!await _app.auth.hasSession()) return;
    try {
      _app.favoriteIds = (await _app.favorites.listIds()).toSet();
      final raw = await _app.favorites.listItems();
      _favoriteListings = raw
          .map((item) => normalizeListing({
                'id': item['id'],
                'title': item['title'],
                'price_cdf': item['price_cdf'],
                'primary_image_url': item['primary_image_url'],
                'city': item['city'],
                'isFavorite': true,
              }, favoriteIds: _app.favoriteIds))
          .toList();
    } catch (_) {}
  }

  Future<void> loadCart() async {
    if (!await _app.auth.hasSession()) {
      _app.cartItems = [];
      return;
    }
    _app.cartItems = await _app.cart.listItems();
  }

  Future<void> addToCart(int listingId, {int quantity = 1}) async {
    await _app.cart.add(listingId, quantity: quantity);
    await loadCart();
  }

  Future<void> removeFromCart(int listingId) async {
    await _app.cart.remove(listingId);
    await loadCart();
  }

  Future<void> updateCartQty(int listingId, int quantity, {int? maxQuantity}) async {
    if (quantity <= 0) {
      await removeFromCart(listingId);
      return;
    }
    if (maxQuantity != null && quantity > maxQuantity) {
      quantity = maxQuantity;
    }
    _patchLocalCartQty(listingId, quantity);
    await _app.cart.updateQty(listingId, quantity);
    await loadCart();
  }

  void _patchLocalCartQty(int listingId, int quantity) {
    final idx = _app.cartItems.indexWhere((e) {
      final id = e['listing_id'] as int? ?? int.tryParse(e['listing_id']?.toString() ?? '');
      return id == listingId;
    });
    if (idx < 0) return;
    _app.cartItems[idx] = Map<String, dynamic>.from(_app.cartItems[idx])..['quantity'] = quantity;
  }

  Future<void> updateProfile({String? displayName}) async {
    final user = await _app.users.updateProfile(displayName: displayName);
    if (user.isNotEmpty) {
      _applyUserFromApi(user);
    } else {
      await refreshUser();
    }
  }

  String? get profileAvatarUrl => _app.currentUser?['avatarUrl']?.toString();

  Future<void> uploadProfileAvatar({required String filePath}) async {
    final user = await _app.users.uploadAvatarFile(filePath);
    _applyUserFromApi(user);
  }

  Future<void> uploadProfileAvatarBytes({
    required Uint8List bytes,
    required String filename,
    String contentType = 'image/jpeg',
  }) async {
    final user = await _app.users.uploadAvatarBytes(bytes: bytes, filename: filename, contentType: contentType);
    _applyUserFromApi(user);
  }

  Future<void> deleteProfileAvatar() async {
    final user = await _app.users.deleteAvatar();
    _applyUserFromApi(user);
  }

  bool isFavorite(String listingId) {
    final id = int.tryParse(listingId);
    return id != null && _app.favoriteIds.contains(id);
  }

  Future<Map<String, dynamic>> createTransaction({
    required String userId,
    required String listingId,
    required int amount,
    required String method,
    required int quantity,
  }) async {
    final provider = method.toLowerCase().contains('orange') ? 'orange' : 'mtn';
    return payListing(listingId: int.parse(listingId), provider: provider);
  }
}
