import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/constants.dart';

enum ProductCardVariant {
  vertical,
  horizontal,
  compact,
  featured,
}

class ProductCard extends StatefulWidget {
  final String id;
  final String title;
  final String price;
  final String? oldPrice;
  final String location;
  final String category;
  final String imageUrl;
  final String listingType;
  final String sellerName;
  final String? sellerAvatar;
  final double? rating;
  final int? reviewCount;
  final bool isVerified;
  final bool isPremium;
  final bool isUrgent;
  final bool isPromoted;
  final int? discount;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onShare;
  final VoidCallback? onSellerTap;
  final bool isFavorite;
  final ProductCardVariant variant;
  final bool showSellerInfo;
  final bool showLocation;
  final bool showRating;

  const ProductCard({
    super.key,
    required this.id,
    required this.title,
    required this.price,
    this.oldPrice,
    required this.location,
    required this.category,
    required this.imageUrl,
    required this.listingType,
    required this.sellerName,
    this.sellerAvatar,
    this.rating,
    this.reviewCount,
    this.isVerified = false,
    this.isPremium = false,
    this.isUrgent = false,
    this.isPromoted = false,
    this.discount,
    required this.onTap,
    this.onFavorite,
    this.onShare,
    this.onSellerTap,
    this.isFavorite = false,
    this.variant = ProductCardVariant.vertical,
    this.showSellerInfo = true,
    this.showLocation = true,
    this.showRating = true,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  late AnimationController _likeController;
  late Animation<double> _likeScaleAnimation;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.isFavorite;
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
    
    _likeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _likeScaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _likeController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _likeController.dispose();
    super.dispose();
  }

  void _handleTap() async {
    HapticFeedback.lightImpact();
    _scaleController.forward();
    await Future.delayed(const Duration(milliseconds: 150));
    _scaleController.reverse();
    widget.onTap();
  }

  void _handleFavorite() async {
    HapticFeedback.mediumImpact();
    setState(() => _isLiked = !_isLiked);
    _likeController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _likeController.reverse();
    if (widget.onFavorite != null) widget.onFavorite!();
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.variant) {
      case ProductCardVariant.horizontal:
        return _buildHorizontalCard();
      case ProductCardVariant.compact:
        return _buildCompactCard();
      case ProductCardVariant.featured:
        return _buildFeaturedCard();
      default:
        return _buildVerticalCard();
    }
  }

  Widget _buildVerticalCard() {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildImageSection(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTitleSection(),
                        const SizedBox(height: 6),
                        _buildPriceSection(),
                        const Spacer(),
                        if (widget.showSellerInfo) _buildSellerInfo(),
                        if (widget.showLocation) _buildLocationInfo(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalCard() {
    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              height: 130,
              child: _buildImageSection(compact: true),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTitleSection(maxLines: 2),
                    const SizedBox(height: 4),
                    _buildPriceSection(),
                    const SizedBox(height: 8),
                    if (widget.showSellerInfo) _buildSellerInfo(compact: true),
                    if (widget.showLocation) _buildLocationInfo(compact: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactCard() {
    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 120,
              child: _buildImageSection(compact: true),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.price,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedCard() {
    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              SizedBox(
                height: 280,
                width: double.infinity,
                child: _buildImageSection(compact: true),
              ),
              Container(
                height: 280,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.3),
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.isPremium)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, size: 12, color: Colors.white),
                              SizedBox(width: 4),
                              Text('Premium', style: TextStyle(color: Colors.white, fontSize: 10)),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.price,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection({bool compact = false}) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppConstants.borderRadius),
          ),
          child: widget.imageUrl.trim().isEmpty
              ? Container(
                  height: compact ? double.infinity : 140,
                  width: double.infinity,
                  color: AppColors.background,
                  child: const Icon(Icons.image_outlined, size: 40, color: AppColors.textSecondary),
                )
              : CachedNetworkImage(
            imageUrl: widget.imageUrl.trim(),
            height: compact ? double.infinity : 140,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: AppColors.background,
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2,
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: AppColors.background,
              child: Icon(
                Icons.image_outlined,
                size: 40,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
        if (widget.isUrgent)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flash_on, size: 12, color: Colors.white),
                  SizedBox(width: 4),
                  Text('URGENT', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        if (widget.isPromoted)
          Positioned(
            top: 8,
            left: widget.isUrgent ? 70 : 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('⭐ PROMU', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: widget.listingType == ListingType.payment ? Colors.orange : AppColors.secondary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.listingType == ListingType.payment ? 'PAYANT' : 'CONTACT',
              style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          right: 8,
          child: GestureDetector(
            onTap: _handleFavorite,
            child: AnimatedBuilder(
              animation: _likeScaleAnimation,
              builder: (context, child) => Transform.scale(
                scale: _likeScaleAnimation.value,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 16,
                    color: _isLiked ? AppColors.danger : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.discount != null && widget.discount! > 0)
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '-${widget.discount}%',
                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTitleSection({int maxLines = 2}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            widget.title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceSection() {
    return Row(
      children: [
        Text(
          widget.price,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        if (widget.oldPrice != null) ...[
          const SizedBox(width: 6),
          Text(
            widget.oldPrice!,
            style: TextStyle(
              fontSize: 11,
              decoration: TextDecoration.lineThrough,
              color: AppColors.textSecondary.withValues(alpha: 0.6),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSellerInfo({bool compact = false}) {
    return GestureDetector(
      onTap: widget.onSellerTap,
      child: Row(
        children: [
          CircleAvatar(
            radius: compact ? 10 : 12,
            backgroundColor: AppColors.background,
            child: Icon(
              Icons.person_outline_rounded,
              size: compact ? 12 : 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              widget.sellerName,
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (widget.isVerified)
            const Icon(
              Icons.verified_rounded,
              size: 12,
              color: AppColors.gold,
            ),
        ],
      ),
    );
  }

  Widget _buildLocationInfo({bool compact = false}) {
    return Row(
      children: [
        Icon(
          Icons.location_on_outlined,
          size: compact ? 10 : 12,
          color: AppColors.textSecondary.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 2),
        Expanded(
          child: Text(
            widget.location,
            style: TextStyle(
              fontSize: compact ? 9 : 10,
              color: AppColors.textSecondary.withValues(alpha: 0.7),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}