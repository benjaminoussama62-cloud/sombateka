import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/premium_theme.dart';
import '../utils/constants.dart';
import '../widgets/st_icon.dart';
import 'st_safe_area.dart';

/// Salutation + pills (défile avec le contenu).
class HomeGreetingBar extends StatelessWidget {
  const HomeGreetingBar({
    super.key,
    this.onNotificationTap,
    this.notificationCount = 0,
  });

  final VoidCallback? onNotificationTap;
  final int notificationCount;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Bonjour' : hour < 18 ? 'Bon après-midi' : 'Bonsoir';

    return Container(
      width: double.infinity,
      decoration: PremiumTheme.homeHeaderDecoration,
      child: StSafeTop(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              greeting,
                              style: PremiumTheme.display.copyWith(fontSize: 26, height: 1.1),
                            ),
                            const SizedBox(width: 6),
                            const AppIcon(Icons.waving_hand, size: 22, color: Colors.white),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppStrings.tagline,
                          style: PremiumTheme.body.copyWith(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _IconChip(
                    icon: Icons.notifications_outlined,
                    badge: notificationCount,
                    onTap: onNotificationTap ?? () {},
                    tooltip: 'Notifications',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const HomeQuickPills(),
            ],
          ),
        ),
      ),
    );
  }
}

/// En-tête accueil : salutation défile + barre recherche collée (NestedScrollView).
class HomeCollapsingHeader {
  HomeCollapsingHeader._();

  static const double greetingBodyHeight = 118;

  static List<Widget> slivers({
    required BuildContext context,
    required bool innerBoxIsScrolled,
    required double topInset,
    VoidCallback? onNotificationTap,
    int notificationCount = 0,
    VoidCallback? onSearchTap,
    VoidCallback? onImageSearchTap,
  }) {
    return [
      SliverToBoxAdapter(
        child: HomeGreetingBar(
          onNotificationTap: onNotificationTap,
          notificationCount: notificationCount,
        ),
      ),
      SliverPersistentHeader(
        pinned: true,
        delegate: HomeSearchBarDelegate(
          topInset: topInset,
          elevated: innerBoxIsScrolled,
          onSearchTap: onSearchTap,
          onImageSearchTap: onImageSearchTap,
        ),
      ),
    ];
  }
}

/// Barre de recherche — reste collée en haut au scroll (style Wildberries).
class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({
    super.key,
    this.onSearchTap,
    this.onImageSearchTap,
    this.compact = false,
  });

  final VoidCallback? onSearchTap;
  final VoidCallback? onImageSearchTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PremiumTheme.homeHeaderColor,
      elevation: compact ? 2 : 0,
      shadowColor: Colors.black26,
      child: DecoratedBox(
        decoration: PremiumTheme.heroGradient,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, compact ? 6 : 0, 16, compact ? 8 : 10),
          child: HomeSmartSearchBar(onTap: onSearchTap, onCameraTap: onImageSearchTap),
        ),
      ),
    );
  }
}

class HomeSearchBarDelegate extends SliverPersistentHeaderDelegate {
  HomeSearchBarDelegate({
    required this.topInset,
    required this.onSearchTap,
    required this.onImageSearchTap,
    this.elevated = false,
  });

  final double topInset;
  final VoidCallback? onSearchTap;
  final VoidCallback? onImageSearchTap;
  final bool elevated;

  static const double barHeight = 64;
  static const double _barBodyHeight = 50;

  @override
  double get minExtent => _barBodyHeight + (elevated ? topInset : 0) + 14;

  @override
  double get maxExtent => minExtent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final pinned = elevated || overlapsContent;
    return Material(
      color: PremiumTheme.homeHeaderColor,
      elevation: pinned ? 3 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.14),
      child: DecoratedBox(
        decoration: PremiumTheme.heroGradient,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, pinned ? topInset + 6 : 6, 16, 8),
          child: HomeSmartSearchBar(onTap: onSearchTap, onCameraTap: onImageSearchTap),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant HomeSearchBarDelegate oldDelegate) =>
      oldDelegate.elevated != elevated ||
      oldDelegate.topInset != topInset ||
      oldDelegate.onSearchTap != onSearchTap ||
      oldDelegate.onImageSearchTap != onImageSearchTap;
}

/// En-tête complet (salutation + recherche + pills) — usage ponctuel.
class SmartHomeHeader extends StatelessWidget {
  const SmartHomeHeader({
    super.key,
    this.onSearchTap,
    this.onImageSearchTap,
    this.onNotificationTap,
    this.notificationCount = 0,
  });

  final VoidCallback? onSearchTap;
  final VoidCallback? onImageSearchTap;
  final VoidCallback? onNotificationTap;
  final int notificationCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        HomeGreetingBar(
          onNotificationTap: onNotificationTap,
          notificationCount: notificationCount,
        ),
        HomeSearchBar(
          onSearchTap: onSearchTap,
          onImageSearchTap: onImageSearchTap,
        ),
      ],
    );
  }
}

class HomeQuickPills extends StatelessWidget {
  const HomeQuickPills({super.key});

  @override
  Widget build(BuildContext context) {
    const pills = [
      ('Boutiques pro', Icons.storefront_rounded),
      ('Messagerie sécurisée', Icons.chat_bubble_outline_rounded),
      ('100 % RDC', Icons.flag_rounded),
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
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(p.$2, size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    p.$1,
                    style: PremiumTheme.label.copyWith(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class HomeSmartSearchBar extends StatelessWidget {
  const HomeSmartSearchBar({this.onTap, this.onCameraTap, super.key});

  final VoidCallback? onTap;
  final VoidCallback? onCameraTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (onTap != null) {
                    onTap!();
                  } else {
                    Navigator.pushNamed(context, AppRoutes.search);
                  }
                },
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      const AppIcon(Icons.search_rounded, color: PremiumTheme.textMuted, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Rechercher un article, boutique ou photo',
                          style: PremiumTheme.body.copyWith(fontSize: 14, color: PremiumTheme.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (onCameraTap != null) {
                    onCameraTap!();
                  } else {
                    Navigator.pushNamed(context, AppRoutes.search);
                  }
                },
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: PremiumTheme.blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: AppIcon(Icons.photo_camera_rounded, color: PremiumTheme.blue, size: 20),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
              child: AppIcon(icon, color: Colors.white, size: 21),
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
