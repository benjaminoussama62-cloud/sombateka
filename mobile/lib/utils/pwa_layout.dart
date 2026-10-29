import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'pwa.dart';

/// Mise en page PWA iPhone / Android (standalone) — safe areas + largeur max.
class PwaLayout {
  PwaLayout._();

  static EdgeInsets viewInsets(BuildContext context) {
    final v = MediaQuery.viewPaddingOf(context);
    return EdgeInsets.fromLTRB(v.left, v.top, v.right, v.bottom);
  }

  static double maxContentWidth(BuildContext context) {
    if (!kIsWeb) return double.infinity;
    if (isDesktopWeb(context)) return double.infinity;
    return MediaQuery.sizeOf(context).width;
  }

  static bool isDesktopWeb(BuildContext context) {
    if (!kIsWeb || pwaIsStandalone()) return false;
    return MediaQuery.sizeOf(context).width >= 768;
  }

  static EdgeInsets screenPadding(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;
    return EdgeInsets.symmetric(horizontal: compact ? 12 : 16);
  }

  /// Enveloppe écran web : safe area + fond navy + contenu centré optionnel.
  static Widget screen({
    required BuildContext context,
    required Widget child,
    Color background = const Color(0xFF0D1B4B),
    bool centerContent = false,
    bool topSafe = true,
    bool bottomSafe = false,
  }) {
    Widget body = child;
    if (centerContent && kIsWeb) {
      body = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth(context)),
          child: body,
        ),
      );
    }
    if (!kIsWeb) return body;
    return ColoredBox(
      color: background,
      child: SafeArea(
        top: topSafe,
        bottom: bottomSafe,
        left: true,
        right: true,
        child: body,
      ),
    );
  }
}
