import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_services.dart';
import '../services/cart_ui_helper.dart';
import '../services/data_service.dart';
import '../theme/premium_theme.dart';
import '../utils/constants.dart';
import '../utils/listing_attributes.dart';
import '../utils/listing_utils.dart';
import '../utils/rdc_locations.dart';
import '../services/listing_actions.dart';
import '../utils/app_feedback.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/fullscreen_image_viewer.dart';
import '../widgets/listing_reviews_section.dart';
import 'business_hub_screen.dart';
import '../widgets/marketplace_product_card.dart';
import 'chat_screen.dart';
import 'package:share_plus/share_plus.dart';

import '../services/recently_viewed_service.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key, required this.listing});

  final Map<String, dynamic> listing;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> with TickerProviderStateMixin {
  final _data = DataService();
  late Map<String, dynamic> _listing;
  late PageController _pageController;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  int _imageIndex = 0;
  bool _loading = true;
  bool _liked = false;
  List<Map<String, dynamic>> _apiSimilar = [];
  List<Map<String, dynamic>> _publicationSiblings = [];
  Map<String, dynamic>? _listingReviews;
  Map<String, dynamic>? _reviewEligibility;
  String? _selectedSize;
  String? _selectedColor;

  @override
  void initState() {
    super.initState();
    _listing = _withOwnership(widget.listing);
    _liked = _listing['isFavorite'] == true;
    _pageController = PageController();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final id = int.tryParse(_listing['id']?.toString() ?? '');
    if (id != null) {
      try {
        final full = await _data.fetchListingDetail(id);
        if (full != null && mounted) {
          setState(() {
            _listing = _withOwnership(full);
            _liked = _listing['isFavorite'] == true;
            _publicationSiblings = _data.getPublicationSiblings(_listing);
          });
          await RecentlyViewedService.instance.track(_listing);
        }
        final own = normalizeListing(
          _listing,
          favoriteIds: AppServices.instance.favoriteIds,
          currentUserId: _data.currentUser?['id']?.toString(),
        )['isOwnListing'] == true;
        if (!own) {
          final similar = await _data.fetchSimilarListings(id);
          if (mounted) {
            setState(() {
              _apiSimilar = similar.items.map(_withOwnership).toList();
            });
          }
        }
        final reviews = await _data.fetchListingReviews(id);
        final eligibility = await _data.fetchReviewEligibility(id);
        if (mounted) {
          setState(() {
            _listingReviews = reviews;
            _reviewEligibility = eligibility;
            _initCatalogSelection();
          });
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _loading = false;
        if (_publicationSiblings.isEmpty) {
          _publicationSiblings = _data.getPublicationSiblings(_listing);
        }
      });
      _fadeCtrl.forward();
    }
  }

  bool get _hasPublicationSiblings => _publicationSiblings.length > 1;

  String get _selectedSiblingLabel {
    final attrs = ListingAttributes.decodeMap(_listing['attributes']);
    final color = attrs?['color']?.toString() ?? attrs?['default_color']?.toString();
    if (color != null && color.isNotEmpty) return color;
    return _s('title', 'Variante');
  }

  Future<void> _switchPublicationSibling(Map<String, dynamic> sibling) async {
    final id = int.tryParse(sibling['id']?.toString() ?? '');
    if (id == null) return;
    if (id.toString() == _listing['id']?.toString()) return;
    setState(() {
      _loading = true;
      _imageIndex = 0;
    });
    _pageController.jumpToPage(0);
    try {
      final full = await _data.fetchListingDetail(id);
      if (full != null && mounted) {
        setState(() {
          _listing = _withOwnership(full);
          _liked = _listing['isFavorite'] == true;
          _publicationSiblings = _data.getPublicationSiblings(_listing);
          _selectedSize = null;
          _selectedColor = null;
          _initCatalogSelection();
        });
        final similar = await _data.fetchSimilarListings(id);
        if (mounted) _apiSimilar = similar.items.map(_withOwnership).toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<String> get _images {
    final imgs = (_listing['images'] as List?)?.map((e) => e.toString()).where((u) => u.isNotEmpty).toList() ?? [];
    if (imgs.isNotEmpty) return imgs;
    final one = _listing['imageUrl']?.toString() ?? '';
    return one.isNotEmpty ? [one] : [];
  }

  Map<String, dynamic> _withOwnership(Map<String, dynamic> raw) => normalizeListing(
        raw,
        favoriteIds: AppServices.instance.favoriteIds,
        currentUserId: _data.currentUser?['id']?.toString(),
      );

  bool get _isCatalog =>
      ListingAttributes.isCatalogListing(_listing['attributes']) ||
      _listing['isVerified'] == true ||
      _listing['isOfficial'] == true;

  List<Map<String, dynamic>> get _variants =>
      ListingAttributes.catalogVariants(_listing['attributes']);

  List<String> get _availableSizes {
    final fromVariants = _variants.map((v) => v['size']?.toString() ?? '').where((s) => s.isNotEmpty).toSet().toList();
    if (fromVariants.isNotEmpty) return fromVariants;
    final attrs = ListingAttributes.decodeMap(_listing['attributes']);
    final sizes = attrs?['available_sizes'];
    if (sizes is List) return sizes.map((e) => e.toString()).toList();
    return [];
  }

  List<String> get _availableColors {
    final fromVariants = _variants.map((v) => v['color']?.toString() ?? '').where((c) => c.isNotEmpty).toSet().toList();
    if (fromVariants.isNotEmpty) return fromVariants;
    final attrs = ListingAttributes.decodeMap(_listing['attributes']);
    final colors = attrs?['available_colors'];
    if (colors is List) return colors.map((e) => e.toString()).toList();
    final one = attrs?['color']?.toString();
    return one != null && one.isNotEmpty ? [one] : [];
  }

  Map<String, dynamic>? get _selectedVariant {
    if (_variants.isEmpty) return null;
    for (final v in _variants) {
      final sizeOk = _selectedSize == null || v['size']?.toString() == _selectedSize;
      final colorOk = _selectedColor == null || v['color']?.toString() == _selectedColor;
      if (sizeOk && colorOk) return v;
    }
    return _variants.first;
  }

  int get _selectedStock {
    if (!_isCatalog) return 1;
    return (_selectedVariant?['stock'] as num?)?.toInt() ?? ListingAttributes.catalogTotalStock(_listing['attributes']);
  }

  bool get _isOutOfStock => _isCatalog && _selectedStock <= 0;

  void _initCatalogSelection() {
    if (!_isCatalog) return;
    final sizes = _availableSizes;
    final colors = _availableColors;
    _selectedColor ??= colors.isNotEmpty ? colors.first : null;
    if (_selectedSize == null && sizes.isNotEmpty) {
      _selectedSize = sizes.firstWhere(
        (s) => ListingAttributes.stockForSize(_listing['attributes'], s, color: _selectedColor) > 0,
        orElse: () => sizes.first,
      );
    }
  }

  int _stockForSize(String size) =>
      ListingAttributes.stockForSize(_listing['attributes'], size, color: _selectedColor);

  String get _displayPrice {
    final v = _selectedVariant;
    if (v != null && v['price_cdf'] != null) {
      return _formatCdf(v['price_cdf']);
    }
    return _s('price', 'Prix sur demande');
  }

  String _formatCdf(dynamic cdf) {
    final n = cdf is num ? cdf.toInt() : int.tryParse(cdf?.toString() ?? '');
    if (n == null) return 'Prix sur demande';
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return '${buf.toString()} CDF';
  }

  Map<String, dynamic> _listingForAction() {
    final base = Map<String, dynamic>.from(_listing);
    final v = _selectedVariant;
    if (v != null) {
      base['price_cdf'] = v['price_cdf'];
      base['price'] = _formatCdf(v['price_cdf']);
      if (v['size'] != null) base['size'] = v['size'];
      if (v['color'] != null) base['color'] = v['color'];
    }
    return base;
  }

  Future<void> _reloadReviews() async {
    final id = int.tryParse(_listing['id']?.toString() ?? '');
    if (id == null) return;
    final reviews = await _data.fetchListingReviews(id);
    final eligibility = await _data.fetchReviewEligibility(id);
    if (mounted) {
      setState(() {
        _listingReviews = reviews;
        _reviewEligibility = eligibility;
      });
    }
  }

  Future<void> _submitProductReview(int rating, String? comment) async {
    final id = int.tryParse(_listing['id']?.toString() ?? '');
    if (id == null) return;
    try {
      await _data.submitReview(listingId: id, rating: rating, comment: comment);
      if (mounted) {
        showAppSuccess(context, 'Merci pour votre avis !');
        await _reloadReviews();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  bool get _isOwn => _listing['isOwnListing'] == true;

  void _openSimilarProducts() {
    Navigator.pushNamed(context, AppRoutes.similarProducts, arguments: _listing);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  String _s(dynamic k, [String fb = '']) {
    final v = _listing[k]?.toString().trim();
    if (v == null || v.isEmpty || v == 'null') return fb;
    return v;
  }

  @override
  Widget build(BuildContext context) {
    final isPayment = !_isOwn &&
        (_listing['listingType']?.toString() == ListingType.payment || _isCatalog);

    return Scaffold(
      backgroundColor: PremiumTheme.surface,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: PremiumTheme.blue))
          : FadeTransition(
              opacity: _fadeAnim,
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 360,
                    pinned: true,
                    backgroundColor: PremiumTheme.navy,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    actions: [
                      if (!_isOwn)
                        IconButton(
                          onPressed: _toggleFavorite,
                          icon: Icon(
                            _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: _liked ? AppColors.danger : Colors.white,
                          ),
                        ),
                      if (!_isOwn)
                        IconButton(
                          onPressed: _reportListing,
                          icon: const Icon(Icons.flag_outlined, color: Colors.white),
                        ),
                      IconButton(
                        onPressed: _shareListing,
                        icon: const Icon(Icons.ios_share_rounded, color: Colors.white),
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(background: _gallery()),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isOwn) _ownerBanner(),
                          Text(_s('title', 'Sans titre'), style: PremiumTheme.h1.copyWith(fontSize: 22)),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Text(
                                  _displayPrice,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: PremiumTheme.blue,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              if (_images.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${_imageIndex + 1}/${_images.length}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: PremiumTheme.blue),
                                  ),
                                ),
                            ],
                          ),
                          if (_hasPublicationSiblings) ...[
                            const SizedBox(height: 16),
                            _collectionVariantPicker(),
                          ],
                          if (_isCatalog && !_isOwn) ...[
                            const SizedBox(height: 12),
                            _stockUrgencyBadge(),
                            const SizedBox(height: 12),
                            _catalogVariantSection(),
                          ],
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _chip(Icons.category_rounded, _s('category', 'Général')),
                              _chip(Icons.location_on_rounded, _s('location', 'RDC')),
                              if (_listing['isVerified'] == true || _listing['isOfficial'] == true)
                                _chip(Icons.verified_rounded, 'Boutique officielle', gold: true),
                              if ((_listing['size']?.toString() ?? '').isNotEmpty && !_isCatalog)
                                _chip(Icons.straighten_rounded, 'Taille ${_listing['size']}'),
                            ],
                          ),
                          if (_listingReviews != null && ((_listingReviews!['review_count'] as num?)?.toInt() ?? 0) > 0) ...[
                            const SizedBox(height: 10),
                            _ratingSummaryChip(),
                          ],
                          const SizedBox(height: 24),
                          Text('Description', style: PremiumTheme.h1.copyWith(fontSize: 17)),
                          const SizedBox(height: 8),
                          Text(
                            _s('description', 'Aucune description pour cette annonce.'),
                            style: PremiumTheme.body.copyWith(fontSize: 15, height: 1.55, color: PremiumTheme.textDark),
                          ),
                          const SizedBox(height: 20),
                          if (_listingReviews != null) ...[
                            ListingReviewsSection(
                              reviews: _listingReviews!,
                              eligibility: _reviewEligibility,
                              listingTitle: _s('title', 'Produit'),
                              listingId: int.tryParse(_listing['id']?.toString() ?? '') ?? 0,
                              onSubmit: _submitProductReview,
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (!_isOwn && !_isCatalog) ...[
                            _listingParamsSection(),
                            const SizedBox(height: 16),
                            _quickContactMessages(),
                          ],
                          if (!_isOwn && _isCatalog) ...[
                            _listingParamsSection(),
                          ],
                          if (_isOwn) _ownerStatsCard(),
                          if (_hasPublicationSiblings) ...[
                            const SizedBox(height: 24),
                            _publicationProductsSection(),
                          ],
                          const SizedBox(height: 28),
                          if (!_isOwn) _similarSectionButton(),
                          if (!_isOwn) const SizedBox(height: 12),
                          if (!_isOwn && _apiSimilar.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: PremiumTheme.radiusMd,
                                border: Border.all(color: const Color(0xFFE8ECF4)),
                              ),
                              child: Text(
                                'Aucun produit similaire pour le moment.',
                                style: PremiumTheme.body,
                                textAlign: TextAlign.center,
                              ),
                            )
                          else if (!_isOwn && _apiSimilar.isNotEmpty)
                            SizedBox(
                              height: 220,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _apiSimilar.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 12),
                                itemBuilder: (_, i) {
                                  final item = _apiSimilar[i];
                                  return SizedBox(
                                    width: 150,
                                    child: MarketplaceProductCard(
                                      listing: item,
                                      compact: true,
                                      onTap: () => Navigator.pushReplacement(
                                        context,
                                        PageRouteBuilder(
                                          pageBuilder: (_, __, ___) => DetailScreen(listing: item),
                                          transitionsBuilder: (_, anim, __, child) {
                                            return FadeTransition(opacity: anim, child: child);
                                          },
                                          transitionDuration: const Duration(milliseconds: 280),
                                        ),
                                      ),
                                      onFavorite: () async {
                                        await _data.toggleFavorite(item['id']?.toString() ?? '');
                                        if (mounted) setState(() {});
                                      },
                                      onAddToCart: () => CartUiHelper.addListing(context, item),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _isOwn ? _ownerBottomBar() : _bottomBar(isPayment),
    );
  }

  Widget _ownerBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF059669), PremiumTheme.emerald]),
        borderRadius: PremiumTheme.radiusMd,
        boxShadow: [
          BoxShadow(color: PremiumTheme.emerald.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: const Row(
        children: [
          Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Votre annonce', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                Text(
                  'Les acheteurs voient une fiche différente',
                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stockUrgencyBadge() {
    if (!_isCatalog || _selectedStock <= 0) return const SizedBox.shrink();
    if (_selectedStock > 15) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, color: PremiumTheme.gold, size: 16),
          const SizedBox(width: 6),
          Text(
            'Il reste $_selectedStock en taille ${_selectedSize ?? ''}',
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _publicationProductsSection() {
    final others = _publicationSiblings
        .where((s) => s['id']?.toString() != _listing['id']?.toString())
        .toList();
    if (others.isEmpty) return const SizedBox.shrink();
    final pubTitle = ListingAttributes.publicationTitle(_listing['attributes']) ?? 'Cette publication';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Autres produits · $pubTitle',
                style: PremiumTheme.h1.copyWith(fontSize: 16),
              ),
            ),
            TextButton(
              onPressed: _showAllPublicationVariants,
              child: Text('Tous ${others.length + 1}', style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: others.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final item = others[i];
              return SizedBox(
                width: 130,
                child: MarketplaceProductCard(
                  listing: item,
                  compact: true,
                  onTap: () => _switchPublicationSibling(item),
                  onFavorite: () async {
                    await _data.toggleFavorite(item['id']?.toString() ?? '');
                    if (mounted) setState(() {});
                  },
                  onAddToCart: () => CartUiHelper.addListing(context, item),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _ownerStatsCard() {
    final status = _listing['status']?.toString() ?? 'active';
    final label = status == 'sold' ? 'Vendu' : (status == 'active' ? 'En ligne' : 'Masquée');
    final stats = _data.getBusinessDashboardStats();
    final isPro = _data.isOfficialSeller;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPro
              ? [PremiumTheme.navy, PremiumTheme.blue.withValues(alpha: 0.85)]
              : [const Color(0xFFF0FDF4), const Color(0xFFECFDF5)],
        ),
        borderRadius: PremiumTheme.radiusMd,
        border: Border.all(color: isPro ? Colors.transparent : PremiumTheme.emerald.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, color: isPro ? PremiumTheme.gold : PremiumTheme.emerald),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPro ? 'Tableau de bord boutique' : 'Mode vendeur',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: isPro ? Colors.white : PremiumTheme.textDark,
                      ),
                    ),
                    Text(
                      'Statut : $label',
                      style: PremiumTheme.body.copyWith(
                        fontSize: 12,
                        color: isPro ? Colors.white70 : null,
                      ),
                    ),
                  ],
                ),
              ),
              if (isPro)
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BusinessHubScreen()),
                  ),
                  child: const Text('Espace Pro', style: TextStyle(color: PremiumTheme.gold, fontWeight: FontWeight.w800)),
                ),
            ],
          ),
          if (isPro) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _miniStat('${stats['soldCount'] ?? 0}', 'Vendus', isPro: true),
                _miniStat('${stats['totalStock'] ?? 0}', 'Stock', isPro: true),
                _miniStat('${stats['productCount'] ?? 0}', 'Produits', isPro: true),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniStat(String value, String label, {bool isPro = false}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isPro ? Colors.white.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: isPro ? Colors.white : PremiumTheme.blue,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: isPro ? Colors.white70 : PremiumTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ownerBottomBar() {
    final id = int.tryParse(_listing['id']?.toString() ?? '');
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: id == null ? null : () => _republish(id),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Republier', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PremiumTheme.blue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: id == null ? null : () => _markSold(id),
                  icon: const Icon(Icons.sell_rounded, size: 18),
                  label: const Text('Vendu', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: id == null ? null : () => _deleteListing(id),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Supprimer l\'annonce', style: TextStyle(fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFEE2E2),
                foregroundColor: const Color(0xFFDC2626),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _republish(int id) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Republier ?',
      message: 'L\'annonce remontera en tête du catalogue.',
      confirmLabel: 'Republier',
      icon: Icons.publish_rounded,
    );
    if (ok != true || !mounted) return;
    await _data.republishListing(id);
    await _loadDetail();
    if (!mounted) return;
    showAppSuccess(context, 'Annonce republiée avec succès');
  }

  Future<void> _markSold(int id) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Marquer vendu ?',
      message: 'Choisissez l\'acheteur pour lui demander un avis.',
      confirmLabel: 'Continuer',
    );
    if (ok != true || !mounted) return;
    final title = _listing['title']?.toString() ?? 'Annonce';
    await markListingAsSoldFlow(context, _data, listingId: id, listingTitle: title);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _deleteListing(int id) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Supprimer ?',
      message: 'Action définitive.',
      confirmLabel: 'Supprimer',
      destructive: true,
      icon: Icons.delete_forever_rounded,
    );
    if (ok != true || !mounted) return;
    await _data.deleteMyListing(id);
    if (!mounted) return;
    showAppSuccess(context, 'Annonce supprimée');
    Navigator.pop(context);
  }

  Widget _gallery() {
    final imgs = _images;
    if (imgs.isEmpty) {
      return Container(
        color: const Color(0xFF1E293B),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image_not_supported_outlined, size: 64, color: Colors.white38),
              SizedBox(height: 8),
              Text('Pas de photo', style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: () => openFullscreenGallery(
        context,
        imageUrls: imgs,
        initialIndex: _imageIndex,
        onFindSimilar: _isOwn ? null : _openSimilarProducts,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _imageIndex = i),
            itemCount: imgs.length,
            itemBuilder: (_, i) => Hero(
              tag: 'listing-img-${_listing['id']}-$i',
              child: CachedNetworkImage(
                imageUrl: imgs[i],
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 300),
                placeholder: (_, __) => Container(color: const Color(0xFF334155)),
                errorWidget: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.zoom_out_map_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text('Agrandir', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        if (imgs.length > 1) ...[
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(imgs.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _imageIndex == i ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _imageIndex == i ? Colors.white : Colors.white38,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: _galleryArrow(Icons.chevron_left_rounded, () {
                if (_imageIndex > 0) _pageController.previousPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
              }),
            ),
          ),
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: _galleryArrow(Icons.chevron_right_rounded, () {
                if (_imageIndex < imgs.length - 1) {
                  _pageController.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
                }
              }),
            ),
          ),
        ],
      ],
      ),
    );
  }

  Widget _similarSectionButton() {
    final thumb = _images.isNotEmpty ? _images.first : '';
    return Material(
      color: Colors.white,
      borderRadius: PremiumTheme.radiusMd,
      child: InkWell(
        onTap: _openSimilarProducts,
        borderRadius: PremiumTheme.radiusMd,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: PremiumTheme.radiusMd,
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              if (thumb.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CachedNetworkImage(imageUrl: thumb, width: 56, height: 56, fit: BoxFit.cover),
                      Container(
                        width: 56,
                        height: 56,
                        color: Colors.black26,
                        child: const Icon(Icons.image_search_rounded, color: Colors.white, size: 26),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Produits similaires', style: PremiumTheme.h1.copyWith(fontSize: 16)),
                    Text(
                      'Par image, couleur, catégorie et paramètres',
                      style: PremiumTheme.body.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: PremiumTheme.blue),
            ],
          ),
        ),
      ),
    );
  }

  Widget _galleryArrow(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _ratingSummaryChip() {
    final avg = (_listingReviews!['average_rating'] as num?)?.toDouble() ?? 0;
    final count = (_listingReviews!['review_count'] as num?)?.toInt() ?? 0;
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFFE082)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 18),
            const SizedBox(width: 6),
            Text(
              '${avg.toStringAsFixed(1)} · $count avis',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _collectionVariantPicker() {
    final pubTitle = ListingAttributes.publicationTitle(_listing['attributes']) ?? 'Collection';
    final currentId = _listing['id']?.toString();
    const thumbSize = 64.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Modèle · $pubTitle',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
            ),
            if (_publicationSiblings.length > 6)
              TextButton(
                onPressed: _showAllPublicationVariants,
                child: Text('Tous ${_publicationSiblings.length}', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: thumbSize + 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _publicationSiblings.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final item = _publicationSiblings[i];
              final selected = item['id']?.toString() == currentId;
              final img = item['imageUrl']?.toString() ?? '';
              final label = ListingAttributes.decodeMap(item['attributes'])?['color']?.toString() ??
                  item['title']?.toString() ??
                  'Modèle ${i + 1}';
              return GestureDetector(
                onTap: () => _switchPublicationSibling(item),
                child: Column(
                  children: [
                    Container(
                      width: thumbSize,
                      height: thumbSize,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? PremiumTheme.blue : const Color(0xFFE2E8F0),
                          width: selected ? 2.5 : 1,
                        ),
                        boxShadow: selected
                            ? [BoxShadow(color: PremiumTheme.blue.withValues(alpha: 0.2), blurRadius: 8)]
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: img.isNotEmpty
                            ? CachedNetworkImage(imageUrl: img, fit: BoxFit.cover)
                            : ColoredBox(
                                color: const Color(0xFFF1F5F9),
                                child: Icon(Icons.image_outlined, color: Colors.grey.shade400, size: 22),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: thumbSize + 8,
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                          color: selected ? PremiumTheme.blue : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _selectedSiblingLabel,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
        ),
      ],
    );
  }

  void _showAllPublicationVariants() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final currentId = _listing['id']?.toString();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tous les modèles (${_publicationSiblings.length})',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: _publicationSiblings.length,
                  itemBuilder: (_, i) {
                    final item = _publicationSiblings[i];
                    final selected = item['id']?.toString() == currentId;
                    final img = item['imageUrl']?.toString() ?? '';
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _switchPublicationSibling(item);
                      },
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected ? PremiumTheme.blue : const Color(0xFFE2E8F0),
                                  width: selected ? 2 : 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: img.isNotEmpty
                                    ? CachedNetworkImage(imageUrl: img, fit: BoxFit.cover, width: double.infinity)
                                    : const ColoredBox(color: Color(0xFFF1F5F9)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['title']?.toString() ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 9),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _catalogVariantSection() {
    final sizes = _availableSizes;
    final colors = _availableColors;
    final brand = ListingAttributes.decodeMap(_listing['attributes'])?['brand']?.toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: PremiumTheme.radiusMd,
        border: Border.all(color: const Color(0xFFE8ECF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (brand != null && brand.isNotEmpty) ...[
            Text('Marque', style: PremiumTheme.body.copyWith(fontSize: 12, color: PremiumTheme.textMuted)),
            const SizedBox(height: 4),
            Text(brand, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 14),
          ],
          if (sizes.isNotEmpty) ...[
            Text('Taille', style: PremiumTheme.h1.copyWith(fontSize: 15)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sizes.map((s) {
                final selected = _selectedSize == s;
                final stock = _stockForSize(s);
                final out = stock <= 0;
                return FilterChip(
                  label: Text(out ? '$s · épuisé' : s),
                  selected: selected && !out,
                  onSelected: out ? null : (_) => setState(() => _selectedSize = s),
                  selectedColor: PremiumTheme.blue.withValues(alpha: 0.15),
                  showCheckmark: !out,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: out
                        ? PremiumTheme.textMuted
                        : (selected ? PremiumTheme.blue : PremiumTheme.textDark),
                    decoration: out ? TextDecoration.lineThrough : null,
                  ),
                  side: BorderSide(
                    color: out
                        ? const Color(0xFFE2E8F0)
                        : (selected ? PremiumTheme.blue : const Color(0xFFE2E8F0)),
                  ),
                  backgroundColor: out ? const Color(0xFFF8FAFC) : null,
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
          ],
          if (colors.isNotEmpty) ...[
            Text('Couleur', style: PremiumTheme.h1.copyWith(fontSize: 15)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: colors.map((c) {
                final selected = _selectedColor == c;
                return ChoiceChip(
                  label: Text(c),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedColor = c),
                  selectedColor: PremiumTheme.blue.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? PremiumTheme.blue : PremiumTheme.textDark,
                  ),
                  side: BorderSide(color: selected ? PremiumTheme.blue : const Color(0xFFE2E8F0)),
                );
              }).toList(),
            ),
          ],
          if (_selectedVariant != null) ...[
            const SizedBox(height: 12),
            Text(
              _selectedStock > 0 ? 'En stock : $_selectedStock' : 'Épuisé — plus disponible',
              style: PremiumTheme.body.copyWith(
                fontSize: 12,
                color: _selectedStock > 0 ? PremiumTheme.emerald : AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text, {bool gold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: gold ? PremiumTheme.gold.withValues(alpha: 0.2) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: gold ? PremiumTheme.gold : PremiumTheme.blue),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: gold ? Colors.black87 : PremiumTheme.blue)),
        ],
      ),
    );
  }

  static const _quickMessageTemplates = [
    'Comment puis-je récupérer l\'article ?',
    'L\'article est-il encore disponible ?',
    'Quel est votre dernier prix ?',
    'Livraison possible ?',
  ];

  Widget _listingParamsSection() {
    final params = ListingAttributes.displayParams(_listing);
    if (params.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Paramètres', style: PremiumTheme.h1.copyWith(fontSize: 17)),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: PremiumTheme.radiusMd,
            border: Border.all(color: const Color(0xFFE8ECF4)),
          ),
          child: Column(
            children: [
              for (var i = 0; i < params.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          params[i].key,
                          style: PremiumTheme.body.copyWith(fontSize: 13, color: PremiumTheme.textMuted),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          params[i].value,
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _quickContactMessages() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Contacter le vendeur', style: PremiumTheme.h1.copyWith(fontSize: 17)),
        const SizedBox(height: 6),
        Text(
          'Choisissez un message pour entamer la négociation sur cette annonce.',
          style: PremiumTheme.body.copyWith(fontSize: 13),
        ),
        const SizedBox(height: 12),
        ..._quickMessageTemplates.map((msg) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.white,
                borderRadius: PremiumTheme.radiusMd,
                child: InkWell(
                  onTap: () => _openChat(autoSend: msg),
                  borderRadius: PremiumTheme.radiusMd,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: PremiumTheme.radiusMd,
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded, size: 20, color: PremiumTheme.blue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(msg, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: PremiumTheme.textMuted),
                      ],
                    ),
                  ),
                ),
              ),
            )),
      ],
    );
  }

  Widget _bottomBar(bool isPayment) {
    final disabled = _isOutOfStock;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (disabled)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Produit épuisé pour cette variante',
                style: PremiumTheme.body.copyWith(color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: disabled ? null : _addToCart,
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: const Text('Panier'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PremiumTheme.blue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: PremiumTheme.radiusMd),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: disabled ? null : (isPayment ? _buyNow : _contactSeller),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPayment ? PremiumTheme.gold : PremiumTheme.blue,
                    foregroundColor: isPayment ? Colors.black87 : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: PremiumTheme.radiusMd),
                  ),
                  child: Text(
                    disabled ? 'Indisponible' : (isPayment ? 'Mobile Money' : 'Écrire au vendeur'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _shareListing() async {
    final title = _listing['title']?.toString() ?? 'Annonce SombaTeka';
    final price = _listing['price']?.toString() ?? '';
    final province = _listing['province']?.toString() ?? RdcLocations.guessProvince(_listing);
    final loc = _listing['location']?.toString() ?? _listing['city']?.toString() ?? '';
    final place = province.isNotEmpty ? '$province${loc.isNotEmpty ? ' · $loc' : ''}' : loc;
    final id = _listing['id']?.toString() ?? '';
    await Share.share(
      '$title${price.isNotEmpty ? ' — $price' : ''}\n$place\n\nVoir sur SombaTeka (annonce #$id)',
      subject: title,
    );
  }

  Future<void> _toggleFavorite() async {
    final id = _listing['id']?.toString() ?? '';
    try {
      await _data.toggleFavorite(id);
      setState(() => _liked = _data.isFavorite(id));
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _reportListing() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Signaler cette annonce'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(hintText: 'Motif (arnaque, contenu interdit…)'),
            maxLines: 3,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Envoyer'),
            ),
          ],
        );
      },
    );
    if (reason == null || reason.length < 3) return;
    try {
      final listingId = int.parse(_listing['id']?.toString() ?? '0');
      final sellerId = int.tryParse(
        _listing['sellerId']?.toString() ?? _listing['seller_id']?.toString() ?? '',
      );
      await _data.reportListing(
        listingId: listingId,
        targetUserId: sellerId,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signalement envoyé. Merci.'), backgroundColor: AppColors.secondary),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _addToCart() async {
    if (_isCatalog) {
      if (_availableSizes.isNotEmpty && (_selectedSize == null || _selectedSize!.isEmpty)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choisissez une taille'), backgroundColor: AppColors.danger),
        );
        return;
      }
      if (_isOutOfStock) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produit épuisé'), backgroundColor: AppColors.danger),
        );
        return;
      }
    }
    await CartUiHelper.addListing(
      context,
      _listingForAction(),
      variantSize: _selectedSize,
      variantColor: _selectedColor,
    );
  }

  Future<void> _contactSeller() => _openChat();

  Future<void> _openChat({String? autoSend}) async {
    final user = _data.currentUser;
    if (user == null) {
      Navigator.pushNamed(context, AppRoutes.auth);
      return;
    }
    final sellerId = _listing['sellerId']?.toString() ?? _listing['seller_id']?.toString();
    if (sellerId == null || sellerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de contacter pour cette annonce')),
      );
      return;
    }
    if (sellerId == user['id']?.toString()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('C\'est votre annonce — vous ne pouvez pas vous écrire à vous-même')),
      );
      return;
    }

    final isOfficial = _listing['isOfficial'] == true || _listing['listingType'] == ListingType.payment;
    if (isOfficial) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Boutique officielle : achetez d\'abord (Mobile Money ou sur place) pour ouvrir la messagerie'),
        ),
      );
      _buyNow();
      return;
    }

    final listingId = _listing['id']?.toString();
    if (listingId == null || listingId.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          peerId: sellerId,
          peerName: 'Annonce #$listingId',
          listingId: listingId,
          listingTitle: _s('title', ''),
          listingImageUrl: _listing['imageUrl']?.toString(),
          isOfficialPeer: false,
          autoSendMessage: autoSend,
        ),
      ),
    );
  }

  void _buyNow() {
    Navigator.pushNamed(context, AppRoutes.payment, arguments: _listingForAction());
  }
}
