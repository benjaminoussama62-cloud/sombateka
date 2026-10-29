import 'package:flutter/material.dart';

import 'responsive.dart';

/// Grille produits style marketplace (Wildberries) — cohérente sur tous les écrans.
class MarketplaceLayout {
  MarketplaceLayout._();

  static SliverGridDelegate productGridDelegate(BuildContext context) {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: Responsive.productGridColumns(context),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: Responsive.productGridAspectRatio(context),
    );
  }

  static EdgeInsets pagePadding(BuildContext context) => Responsive.screenPadding(context);

  /// Centre un widget dans une colonne de largeur max (desktop web).
  /// Sans effet sur mobile/tablette (largeur < [maxWidth]).
  static Widget centered(Widget child, {double maxWidth = Responsive.maxContentWidth}) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }

  /// Centre un sliver dans une largeur max (desktop web) — pour CustomScrollView.
  static Widget centeredSliver(Widget sliver, {double maxWidth = Responsive.maxContentWidth}) {
    return SliverConstrainedCrossAxis(maxExtent: maxWidth, sliver: sliver);
  }

  /// Centre horizontalement sans s'étirer en hauteur — pour bottomNavigationBar.
  /// (Un Center dans ce slot remplit tout l'écran : ne pas utiliser [centered] ici.)
  static Widget centeredBar(Widget child, {double maxWidth = Responsive.maxContentWidth}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        ),
      ],
    );
  }

  static int categoryColumns(BuildContext context) {
    final cols = Responsive.productGridColumns(context);
    if (cols >= 6) return 6;
    if (cols >= 4) return 4;
    return 3;
  }
}
