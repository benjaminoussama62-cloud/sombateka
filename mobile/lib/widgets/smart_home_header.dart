import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/premium_theme.dart';
import '../utils/constants.dart';

/// En-tête accueil : logo, panier, notifications, recherche.
class SmartHomeHeader extends StatelessWidget {
  const SmartHomeHeader({
    super.key,
    this.onSearchTap,
    this.onNotificationTap,
    this.onCartTap,
    this.notificationCount = 0,
    this.cartCount = 0,
    this.expanded = true,
  });

  final VoidCallback? onSearchTap;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onCartTap;
  final int notificationCount;
  final int cartCount;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Bonjour' : hour < 18 ? 'Bon après-midi' : 'Bonsoir';

    return Container(
      decoration: PremiumTheme.heroGradient,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _LogoBadge(),
                  const Spacer(),
                  _IconChip(
                    icon: Icons.shopping_cart_rounded,
                    badge: cartCount,
                    onTap: onCartTap,
                  ),
                  const SizedBox(width: 10),
                  _IconChip(
                    icon: Icons.notifications_rounded,
                    badge: notificationCount,
                    onTap: onNotificationTap ?? () {},
                  ),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$greeting 👋',
                            style: PremiumTheme.display.copyWith(fontSize: 26),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Votre marketplace RDC',
                            style: PremiumTheme.body.copyWith(
                              color: Colors.white70,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (cartCount > 0)
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onCartTap?.call();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: PremiumTheme.gold.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: PremiumTheme.gold.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.shopping_bag_rounded, color: PremiumTheme.gold, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'Panier ($cartCount)',
                                style: PremiumTheme.label.copyWith(color: PremiumTheme.gold, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Achetez, vendez, payez en Mobile Money',
                  style: PremiumTheme.body.copyWith(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 16),
                _SmartSearchBar(onTap: onSearchTap),
                const SizedBox(height: 12),
                const _QuickPills(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoBadge extends StatelessWidget {
  const _LogoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: PremiumTheme.gold, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            AppStrings.appName,
            style: PremiumTheme.h1.copyWith(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _SmartSearchBar extends StatelessWidget {
  const _SmartSearchBar({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          if (onTap != null) {
            onTap!();
          } else {
            Navigator.pushNamed(context, AppRoutes.search);
          }
        },
        borderRadius: PremiumTheme.radiusLg,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: PremiumTheme.radiusLg,
            boxShadow: PremiumTheme.softShadow,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: PremiumTheme.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.search_rounded, color: PremiumTheme.blue, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rechercher', style: PremiumTheme.label.copyWith(color: PremiumTheme.textDark)),
                    Text(
                      'Produits, boutiques, Kinshasa...',
                      style: PremiumTheme.body.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [PremiumTheme.blue, PremiumTheme.blueGlow]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickPills extends StatelessWidget {
  const _QuickPills();

  @override
  Widget build(BuildContext context) {
    const pills = [
      ('🔥 Officiel', PremiumTheme.gold),
      ('💳 Mobile Money', PremiumTheme.emerald),
      ('🇨🇩 100% RDC', Colors.white),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: pills.map((p) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                p.$1,
                style: PremiumTheme.label.copyWith(color: p.$2, fontSize: 11),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon, this.badge = 0, this.onTap});
  final IconData icon;
  final int badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          if (badge > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  badge > 9 ? '9+' : '$badge',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
