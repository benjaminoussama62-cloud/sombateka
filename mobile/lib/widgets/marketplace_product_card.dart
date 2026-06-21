import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/data_service.dart';
import '../theme/premium_theme.dart';
import '../utils/constants.dart';
import '../utils/listing_utils.dart';
import '../utils/rdc_locations.dart';

/// Carte produit premium (grille accueil, recherche, similaires).
class MarketplaceProductCard extends StatefulWidget {
  const MarketplaceProductCard({
    super.key,
    required this.listing,
    required this.onTap,
    this.onFavorite,
    this.onAddToCart,
    this.compact = false,
    this.autoRotateImages = false,
  });

  final Map<String, dynamic> listing;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onAddToCart;
  final bool compact;
  /// Défilement auto des photos (accueil uniquement, ≥2 images, 5 s).
  final bool autoRotateImages;

  @override
  State<MarketplaceProductCard> createState() => _MarketplaceProductCardState();
}

class _MarketplaceProductCardState extends State<MarketplaceProductCard>
    with SingleTickerProviderStateMixin {
  late bool _liked;
  late AnimationController _pressCtrl;
  late Animation<double> _scale;
  Timer? _carouselTimer;
  PageController? _pageController;
  int _carouselIndex = 0;

  static const _carouselInterval = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _liked = _normalized['isFavorite'] == true;
    _pressCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120), upperBound: 0.04);
    _scale = Tween<double>(begin: 1, end: 0.96).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
    _setupCarousel();
  }

  Map<String, dynamic> get _normalized {
    final uid = DataService().currentUser?['id']?.toString();
    return normalizeListing(widget.listing, currentUserId: uid);
  }

  List<String> get _imageUrls {
    final raw = _normalized['images'];
    if (raw is List) {
      final urls = raw.map((e) => e?.toString() ?? '').where((u) => u.isNotEmpty).toList();
      if (urls.length >= 2) return urls;
    }
    final single = _normalized['imageUrl']?.toString() ?? '';
    return single.isNotEmpty ? [single] : <String>[];
  }

  bool get _shouldCarousel => widget.autoRotateImages && _imageUrls.length >= 2;

  void _setupCarousel() {
    _carouselTimer?.cancel();
    _pageController?.dispose();
    _pageController = null;
    _carouselIndex = 0;
    if (!_shouldCarousel) return;
    _pageController = PageController();
    _carouselTimer = Timer.periodic(_carouselInterval, (_) => _advanceCarousel());
  }

  void _advanceCarousel() {
    if (!mounted || _pageController == null) return;
    final count = _imageUrls.length;
    if (count < 2) return;
    final next = (_carouselIndex + 1) % count;
    _pageController!.animateToPage(
      next,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    );
  }

  @override
  void didUpdateWidget(covariant MarketplaceProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _liked = _normalized['isFavorite'] == true;
    if (oldWidget.autoRotateImages != widget.autoRotateImages ||
        oldWidget.listing != widget.listing) {
      _setupCarousel();
    }
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController?.dispose();
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = _normalized;
    final title = l['title']?.toString() ?? 'Sans titre';
    final price = l['price']?.toString() ?? 'Prix sur demande';
    final location = l['location']?.toString() ?? '';
    final province = l['province']?.toString() ?? RdcLocations.guessProvince(l);
    final locationLabel = _locationLabel(province, location);
    final isNew = _isNewListing(l);
    final verified = l['isVerified'] == true;
    final size = l['size']?.toString() ?? '';
    final isOwn = l['isOwnListing'] == true;
    final urls = _imageUrls;

    return ScaleTransition(
      scale: _scale,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onTap();
          },
          onTapDown: (_) => _pressCtrl.forward(),
          onTapUp: (_) => _pressCtrl.reverse(),
          onTapCancel: () => _pressCtrl.reverse(),
          borderRadius: PremiumTheme.radiusMd,
          child: Ink(
            decoration: BoxDecoration(
              color: isOwn ? const Color(0xFFF0FDF4) : Colors.white,
              borderRadius: PremiumTheme.radiusMd,
              border: Border.all(color: isOwn ? PremiumTheme.emerald : const Color(0xFFE8ECF4), width: isOwn ? 2 : 1),
              boxShadow: isOwn
                  ? [BoxShadow(color: PremiumTheme.emerald.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))]
                  : PremiumTheme.softShadow,
            ),
            child: widget.compact
                ? _compactBody(title, price, urls, verified, size, isOwn)
                : _gridBody(title, price, urls, locationLabel, verified, size, isOwn, isNew),
          ),
        ),
      ),
    );
  }

  String _locationLabel(String province, String location) {
    if (province.isEmpty) return location;
    if (location.isEmpty) return province;
    if (location.contains(province)) return location;
    return '$province · $location';
  }

  bool _isNewListing(Map<String, dynamic> l) {
    final raw = l['createdAt'] ?? l['created_at'];
    if (raw == null) return false;
    DateTime? dt;
    if (raw is DateTime) {
      dt = raw;
    } else {
      dt = DateTime.tryParse(raw.toString());
    }
    if (dt == null) return false;
    return DateTime.now().difference(dt).inDays < 7;
  }

  Widget _gridBody(
    String title,
    String price,
    List<String> imageUrls,
    String location,
    bool verified,
    String size,
    bool isOwn,
    bool isNew,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _imageStack(
            imageUrls,
            verified,
            size: size,
            isOwn:             isOwn,
            showCart: !isOwn && widget.onAddToCart != null,
            showFavorite: !isOwn,
            fillHeight: true,
            isNew: isNew,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 5, 6, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, height: 1.15, color: PremiumTheme.textDark),
              ),
              const SizedBox(height: 2),
              Text(
                price,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: isOwn ? PremiumTheme.emerald : PremiumTheme.blue),
              ),
              if (location.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PremiumTheme.label.copyWith(fontSize: 8),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _compactBody(String title, String price, List<String> imageUrls, bool verified, String size, bool isOwn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _imageStack(imageUrls, verified, aspectRatio: 0.92, size: size, isOwn: isOwn, showCart: false, showFavorite: !isOwn),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, height: 1.1)),
              const SizedBox(height: 2),
              Text(price, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: isOwn ? PremiumTheme.emerald : PremiumTheme.blue)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _imageStack(
    List<String> imageUrls,
    bool verified, {
    double aspectRatio = 0.88,
    String size = '',
    bool isOwn = false,
    bool showCart = false,
    bool showFavorite = true,
    bool fillHeight = false,
    bool isNew = false,
  }) {
    final primary = imageUrls.isNotEmpty ? imageUrls.first : '';
    final carousel = _shouldCarousel && imageUrls.length >= 2;

    Widget image;
    if (carousel && _pageController != null) {
      image = PageView.builder(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (i) => setState(() => _carouselIndex = i),
        itemCount: imageUrls.length,
        itemBuilder: (_, i) => _networkImage(imageUrls[i], fillHeight: fillHeight),
      );
    } else {
      image = primary.isNotEmpty ? _networkImage(primary, fillHeight: fillHeight) : _noImage();
    }

    final stack = Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          child: image,
        ),
        if (carousel)
          Positioned(
            bottom: 6,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(imageUrls.length, (i) {
                final active = i == _carouselIndex;
                return Container(
                  width: active ? 6 : 4,
                  height: active ? 6 : 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? Colors.white : Colors.white.withValues(alpha: 0.45),
                    boxShadow: active ? [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 2)] : null,
                  ),
                );
              }),
            ),
          ),
        if (isNew && !isOwn)
          Positioned(
            top: 5,
            right: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFEA580C)]),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('NOUVEAU', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
          ),
        if (isOwn)
          Positioned(
            top: 5,
            left: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [PremiumTheme.emerald, Color(0xFF059669)]),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('MOI', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
          ),
        if (size.isNotEmpty)
          Positioned(
            bottom: carousel ? 16 : 5,
            left: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(5)),
              child: Text(size, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
            ),
          ),
        if (verified && !isOwn)
          Positioned(
            top: 5,
            left: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(color: PremiumTheme.gold, borderRadius: BorderRadius.circular(5)),
              child: const Text('Officiel', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w800)),
            ),
          ),
        if (showFavorite)
          Positioned(
            top: 4,
            right: 4,
            child: _roundAction(
              icon: _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: _liked ? AppColors.danger : Colors.white,
              bg: _liked ? Colors.white : Colors.black.withValues(alpha: 0.45),
              onTap: () {
                HapticFeedback.mediumImpact();
                setState(() => _liked = !_liked);
                widget.onFavorite?.call();
              },
            ),
          ),
        if (showCart)
          Positioned(
            bottom: 5,
            right: 5,
            child: _roundAction(
              icon: Icons.add_shopping_cart_rounded,
              color: Colors.white,
              bg: PremiumTheme.blue,
              onTap: widget.onAddToCart,
            ),
          ),
      ],
    );

    if (fillHeight) return stack;
    return AspectRatio(aspectRatio: aspectRatio, child: stack);
  }

  Widget _networkImage(String url, {bool fillHeight = false}) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: fillHeight ? double.infinity : null,
      height: fillHeight ? double.infinity : null,
      fadeInDuration: const Duration(milliseconds: 280),
      placeholder: (_, __) => _shimmerPlaceholder(),
      errorWidget: (_, __, ___) => _noImage(),
    );
  }

  Widget _shimmerPlaceholder() => Container(color: const Color(0xFFF1F5F9));

  Widget _noImage() => Container(
        color: const Color(0xFFF1F5F9),
        child: const Center(child: Icon(Icons.image_outlined, size: 32, color: PremiumTheme.textMuted)),
      );

  Widget _roundAction({
    required IconData icon,
    required Color color,
    required Color bg,
    VoidCallback? onTap,
  }) {
    return Material(
      color: bg,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(padding: const EdgeInsets.all(6), child: Icon(icon, size: 15, color: color)),
      ),
    );
  }
}
