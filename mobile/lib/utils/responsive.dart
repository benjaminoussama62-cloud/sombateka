import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'pwa.dart';

/// Helpers for consistent layout across phone sizes (iPhone SE → Pro Max, Android).
class Responsive {
  static double width(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static double height(BuildContext context) =>
      MediaQuery.sizeOf(context).height;

  static bool isCompact(BuildContext context) => width(context) < 360;

  static bool isTablet(BuildContext context) => width(context) >= 600;

  /// Navigateur desktop (pas PWA mobile) — layout marketplace pleine largeur.
  static bool isDesktopWeb(BuildContext context) {
    if (!kIsWeb || pwaIsStandalone()) return false;
    return width(context) >= 768;
  }

  /// Safari/Chrome mobile dans le navigateur (pas app installée) — barre URL visible.
  static bool isMobileWebBrowser(BuildContext context) {
    if (!kIsWeb || pwaIsStandalone()) return false;
    return width(context) < 768;
  }

  /// Largeur max du contenu liste (grilles, flux) — centré sur desktop.
  static const double maxContentWidth = 1240;

  /// Largeur max du contenu lecture (fiche produit) — confort de lecture.
  static const double maxDetailWidth = 1080;

  /// Product grids: 2 cols phones → 6 cols grand écran web.
  static int productGridColumns(BuildContext context) {
    final w = width(context);
    if (w >= 1400) return 6;
    if (w >= 1100) return 5;
    if (w >= 900) return 4;
    if (w >= 600) return 3;
    return 2;
  }

  static double productGridAspectRatio(BuildContext context) {
    if (isCompact(context)) return 0.68;
    if (isTablet(context)) return 0.75;
    if (isDesktopWeb(context)) return 0.78;
    return 0.72;
  }

  static EdgeInsets screenPadding(BuildContext context) {
    final w = width(context);
    if (isDesktopWeb(context) && w >= 1400) {
      return const EdgeInsets.symmetric(horizontal: 48);
    }
    if (isDesktopWeb(context)) return const EdgeInsets.symmetric(horizontal: 32);
    if (w < 360) return const EdgeInsets.symmetric(horizontal: 12);
    return const EdgeInsets.symmetric(horizontal: 16);
  }
}
