import 'package:flutter/material.dart';

import '../theme/premium_theme.dart';
import '../widgets/sombateka_wordmark.dart';
import '../widgets/st_icon.dart';

/// Navigation latérale gauche — navigateur PC (marketplace desktop).
class WebDesktopNav extends StatelessWidget {
  const WebDesktopNav({
    super.key,
    required this.currentIndex,
    required this.messageBadge,
    required this.onTap,
    this.showEspacePro = false,
  });

  final int currentIndex;
  final int messageBadge;
  final ValueChanged<int> onTap;

  /// Affiche l'entrée « Espace Pro » pour les vendeurs officiels.
  final bool showEspacePro;

  static const _width = 248.0;

  @override
  Widget build(BuildContext context) {
    final items = <({int index, IconData icon, IconData active, String label})>[
      (index: 0, icon: Icons.home_outlined, active: Icons.home_rounded, label: 'Accueil'),
      if (showEspacePro)
        (index: 5, icon: Icons.storefront_outlined, active: Icons.storefront_rounded, label: 'Espace Pro')
      else
        (index: 1, icon: Icons.shopping_bag_outlined, active: Icons.shopping_bag_rounded, label: 'Panier'),
      if (showEspacePro)
        (index: 1, icon: Icons.shopping_bag_outlined, active: Icons.shopping_bag_rounded, label: 'Panier'),
      (index: 3, icon: Icons.chat_outlined, active: Icons.chat_rounded, label: 'Messages'),
      (index: 4, icon: Icons.person_outline_rounded, active: Icons.person_rounded, label: 'Profil'),
    ];

    return Container(
      width: _width,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: PremiumTheme.navy.withValues(alpha: 0.08)),
        ),
        boxShadow: [
          BoxShadow(
            color: PremiumTheme.navy.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              decoration: const StGlowDecoration(),
              child: const SombaTekaWordmark(
                iconSize: 40,
                fontSize: 22,
                animate: false,
                onDarkBackground: true,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Text(
                'Marketplace RDC',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SellButton(
                active: currentIndex == 2,
                onTap: () => onTap(2),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'MENU',
                style: PremiumTheme.label.copyWith(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  color: PremiumTheme.textMuted.withValues(alpha: 0.7),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  ...items.map((item) {
                    final badge = item.index == 3 ? messageBadge : 0;
                    return _NavTile(
                      label: item.label,
                      icon: item.icon,
                      activeIcon: item.active,
                      selected: currentIndex == item.index,
                      badge: badge,
                      onTap: () => onTap(item.index),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _SellButton extends StatelessWidget {
  const _SellButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: active
                  ? [PremiumTheme.emerald, const Color(0xFF059669)]
                  : [PremiumTheme.blue, PremiumTheme.navyLight],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: PremiumTheme.blue.withValues(alpha: active ? 0.25 : 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Vendre un article',
                  style: PremiumTheme.h1.copyWith(color: Colors.white, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? PremiumTheme.blue.withValues(alpha: 0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: selected
                  ? Border.all(color: PremiumTheme.blue.withValues(alpha: 0.2))
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 22,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: selected ? PremiumTheme.blue : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AppIcon(
                      selected ? activeIcon : icon,
                      size: 22,
                      color: selected ? PremiumTheme.blue : PremiumTheme.textMuted,
                    ),
                    if (badge > 0)
                      Positioned(
                        top: -5,
                        right: -8,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            badge > 9 ? '9+' : '$badge',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? PremiumTheme.navy : PremiumTheme.textMuted,
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
}
