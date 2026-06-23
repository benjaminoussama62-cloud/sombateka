import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/premium_theme.dart';
import '../utils/constants.dart';
import 'sombateka_wordmark.dart';

/// En-tête accueil premium — logo, actions, recherche (sans répétition panier).
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
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: SombaTekaWordmark(iconSize: 36, fontSize: 20, animate: false),
                  ),
                  _IconChip(
                    icon: Icons.shopping_bag_outlined,
                    badge: cartCount,
                    onTap: onCartTap,
                    tooltip: 'Panier',
                  ),
                  const SizedBox(width: 8),
                  _IconChip(
                    icon: Icons.notifications_outlined,
                    badge: notificationCount,
                    onTap: onNotificationTap ?? () {},
                    tooltip: 'Notifications',
                  ),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 20),
                Text(
                  '$greeting 👋',
                  style: PremiumTheme.display.copyWith(fontSize: 28, height: 1.1),
                ),
                const SizedBox(height: 6),
                Text(
                  AppStrings.tagline,
                  style: PremiumTheme.body.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: PremiumTheme.radiusLg,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
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
                    Text('Rechercher un article', style: PremiumTheme.label.copyWith(color: PremiumTheme.textDark)),
                    Text(
                      'Texte, boutique ou photo 📷',
                      style: PremiumTheme.body.copyWith(fontSize: 12, color: PremiumTheme.textMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [PremiumTheme.emerald, Color(0xFF059669)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 20),
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
      ('🏪 Boutiques pro', Colors.white),
      ('💳 Paiement sécurisé', PremiumTheme.emerald),
      ('🇨🇩 100 % RDC', Color(0xFFBFDBFE)),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: pills.map((p) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
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
  const _IconChip({
    required this.icon,
    this.badge = 0,
    this.onTap,
    this.tooltip,
  });
  final IconData icon;
  final int badge;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap?.call();
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Colors.white24),
              ),
              child: Icon(icon, color: Colors.white, size: 21),
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
      ),
    );
  }
}
