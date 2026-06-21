import 'package:flutter/material.dart';

/// Helpers for consistent layout across phone sizes (iPhone SE → Pro Max, Android).
class Responsive {
  static double width(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static double height(BuildContext context) =>
      MediaQuery.sizeOf(context).height;

  static bool isCompact(BuildContext context) => width(context) < 360;

  static bool isTablet(BuildContext context) => width(context) >= 600;

  /// Product grids: 2 cols on phones, 3 on tablets, 4 on wide web.
  static int productGridColumns(BuildContext context) {
    final w = width(context);
    if (w >= 900) return 4;
    if (w >= 600) return 3;
    return 2;
  }

  static double productGridAspectRatio(BuildContext context) {
    if (isCompact(context)) return 0.68;
    if (isTablet(context)) return 0.75;
    return 0.72;
  }

  static EdgeInsets screenPadding(BuildContext context) {
    final h = width(context);
    if (h < 360) return const EdgeInsets.symmetric(horizontal: 12);
    return const EdgeInsets.symmetric(horizontal: 16);
  }
}
