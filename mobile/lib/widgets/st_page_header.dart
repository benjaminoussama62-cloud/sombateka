import 'package:flutter/material.dart';

import '../theme/premium_theme.dart';
import 'st_safe_area.dart';

/// En-tête unifié — même rendu que Panier / Paramètres (WhatsApp, Wildberries).
class StPageHeader extends StatelessWidget {
  const StPageHeader({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: PremiumTheme.heroGradient,
      child: StSafeTop(
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
