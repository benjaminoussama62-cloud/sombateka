import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/premium_theme.dart';
import '../utils/listing_utils.dart';

/// Confirmation discrète après ajout au panier (bleu / blanc, sans jaune).
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
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(ctx).padding.bottom),
        child: Material(
          borderRadius: PremiumTheme.radiusLg,
          clipBehavior: Clip.antiAlias,
          elevation: 12,
          shadowColor: PremiumTheme.blue.withValues(alpha: 0.2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                color: const Color(0xFFF0FDF4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: PremiumTheme.emerald.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_rounded, color: PremiumTheme.emerald, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ajouté au panier 🛒', style: PremiumTheme.h1.copyWith(fontSize: 16, color: PremiumTheme.textDark)),
                          Text(
                            '$cartCount article${cartCount > 1 ? 's' : ''} · prêt pour le paiement',
                            style: PremiumTheme.label.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded, color: PremiumTheme.textMuted),
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
                          ? CachedNetworkImage(imageUrl: imageUrl, width: 68, height: 68, fit: BoxFit.cover)
                          : Container(
                              width: 68,
                              height: 68,
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
                          Text(
                            price,
                            style: const TextStyle(color: PremiumTheme.blue, fontWeight: FontWeight.w900, fontSize: 16),
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
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
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
      );
    },
  );
}
