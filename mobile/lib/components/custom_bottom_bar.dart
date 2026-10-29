import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/premium_theme.dart';
import '../utils/responsive.dart';
import '../widgets/st_icon.dart';
import '../widgets/st_safe_area.dart';

/// Barre de navigation basse — compacte, style Meta (Instagram / WhatsApp).
class CustomBottomBar extends StatefulWidget {
  const CustomBottomBar({
    super.key,
    required this.currentIndex,
    this.messageBadge = 0,
    required this.onTap,
    this.showEspacePro = false,
  });

  final int currentIndex;
  final int messageBadge;
  final ValueChanged<int> onTap;

  /// Vendeur officiel : remplace Panier par Boutique (Espace Pro).
  /// Le panier reste accessible depuis l'accueil.
  final bool showEspacePro;

  @override
  State<CustomBottomBar> createState() => _CustomBottomBarState();
}

class _CustomBottomBarState extends State<CustomBottomBar> with TickerProviderStateMixin {
  late List<AnimationController> _animationControllers;
  late List<Animation<double>> _scaleAnimations;

  @override
  void initState() {
    super.initState();
    _animationControllers = List.generate(
      5,
      (_) => AnimationController(vsync: this, duration: const Duration(milliseconds: 180)),
    );
    _scaleAnimations = _animationControllers
        .map((c) => Tween<double>(begin: 1, end: 1.08).animate(CurvedAnimation(parent: c, curve: Curves.easeOut)))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _animationControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _onTapSlot(int slot, int pageIndex) async {
    HapticFeedback.selectionClick();
    widget.onTap(pageIndex);
    _animationControllers[slot].forward();
    await Future.delayed(const Duration(milliseconds: 120));
    _animationControllers[slot].reverse();
  }

  @override
  Widget build(BuildContext context) {
    final compact = Responsive.isCompact(context);
    final iconSize = compact ? 22.0 : 24.0;
    final labelSize = compact ? 9.5 : 10.5;
    final sideIndex = widget.showEspacePro ? 5 : 1;
    final sideSelected = widget.currentIndex == sideIndex;

    return Material(
      color: Colors.white,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
        ),
        child: StSafeBottom(
          child: SizedBox(
            height: PremiumTheme.bottomNavContentHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _navItem(0, 0, Icons.home_outlined, Icons.home_rounded, 'Accueil', iconSize, labelSize),
                _navItem(
                  1,
                  sideIndex,
                  widget.showEspacePro ? Icons.storefront_outlined : Icons.shopping_bag_outlined,
                  widget.showEspacePro ? Icons.storefront_rounded : Icons.shopping_bag_rounded,
                  widget.showEspacePro ? 'Boutique' : 'Panier',
                  iconSize,
                  labelSize,
                  forceActive: sideSelected,
                ),
                _publishButton(),
                _navItem(3, 3, Icons.chat_outlined, Icons.chat_rounded, 'Messages', iconSize, labelSize, badge: widget.messageBadge),
                _navItem(4, 4, Icons.person_outline_rounded, Icons.person_rounded, 'Profil', iconSize, labelSize),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    int slot,
    int pageIndex,
    IconData icon,
    IconData activeIcon,
    String label,
    double iconSize,
    double labelSize, {
    int badge = 0,
    bool? forceActive,
  }) {
    final active = forceActive ?? widget.currentIndex == pageIndex;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onTapSlot(slot, pageIndex),
          child: AnimatedBuilder(
            animation: _scaleAnimations[slot],
            builder: (_, __) => Transform.scale(
              scale: _scaleAnimations[slot].value,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AppIcon(
                        active ? activeIcon : icon,
                        size: iconSize,
                        color: active ? PremiumTheme.blue : PremiumTheme.textMuted,
                      ),
                      if (badge > 0)
                        Positioned(
                          top: -5,
                          right: -7,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                            child: Text(
                              badge > 9 ? '9+' : '$badge',
                              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: labelSize,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? PremiumTheme.navy : PremiumTheme.textMuted,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _publishButton() {
    final active = widget.currentIndex == 2;
    final size = PremiumTheme.bottomNavFabSize;

    return SizedBox(
      width: size + 8,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onTapSlot(2, 2),
            customBorder: const CircleBorder(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: active ? PremiumTheme.emerald : PremiumTheme.blue,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: PremiumTheme.blue.withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: AppIcon(
                Icons.add_rounded,
                size: 26,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
