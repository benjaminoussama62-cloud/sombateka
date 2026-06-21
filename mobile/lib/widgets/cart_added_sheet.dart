import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/premium_theme.dart';
import '../utils/listing_utils.dart';

/// Alerte premium après ajout au panier.
Future<void> showCartAddedSheet(
  BuildContext context, {
  required Map<String, dynamic> listing,
  required int cartCount,
  VoidCallback? onViewCart,
}) {
  final l = normalizeListing(listing);
  final title = l['title']?.toString() ?? 'Article';
  final price = l['price']?.toString() ?? '';
  final imageUrl = l['imageUrl']?.toString() ?? '';

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        builder: (_, t, child) => Transform.translate(
          offset: Offset(0, 40 * (1 - t)),
          child: Opacity(opacity: t, child: child),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(ctx).padding.bottom),
          child: Material(
            borderRadius: PremiumTheme.radiusLg,
            clipBehavior: Clip.antiAlias,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: PremiumTheme.radiusLg,
                boxShadow: PremiumTheme.softShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: PremiumTheme.heroGradient,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: PremiumTheme.emerald.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded, color: PremiumTheme.emerald, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Ajouté au panier',
                          style: PremiumTheme.display.copyWith(fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: PremiumTheme.radiusMd,
                          child: imageUrl.isNotEmpty
                              ? CachedNetworkImage(imageUrl: imageUrl, width: 72, height: 72, fit: BoxFit.cover)
                              : Container(
                                  width: 72,
                                  height: 72,
                                  color: const Color(0xFFF1F5F9),
                                  child: const Icon(Icons.image_outlined, color: PremiumTheme.textMuted),
                                ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                              ),
                              const SizedBox(height: 4),
                              Text(price, style: const TextStyle(color: PremiumTheme.blue, fontWeight: FontWeight.w900, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(
                                '$cartCount article${cartCount > 1 ? 's' : ''} dans le panier',
                                style: PremiumTheme.label.copyWith(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.pop(ctx);
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: PremiumTheme.radiusMd),
                            ),
                            child: const Text('Continuer', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              Navigator.pop(ctx);
                              onViewCart?.call();
                            },
                            icon: const Icon(Icons.shopping_bag_rounded, size: 20),
                            label: const Text('Voir le panier', style: TextStyle(fontWeight: FontWeight.w800)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: PremiumTheme.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: PremiumTheme.radiusMd),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
