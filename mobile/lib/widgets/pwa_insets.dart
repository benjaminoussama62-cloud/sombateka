import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/pwa.dart';
import '../utils/pwa_safe_insets.dart';

/// Padding haut PWA (une fois) — Safari navigateur garde [SafeArea] natif.
class PwaTopInset extends StatelessWidget {
  const PwaTopInset({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb && pwaIsStandalone()) {
      final top = PwaSafeInsets.topOf(MediaQuery.of(context));
      if (top > 0) {
        return Padding(padding: EdgeInsets.only(top: top), child: child);
      }
    }
    return SafeArea(bottom: false, minimum: EdgeInsets.zero, child: child);
  }
}

/// Padding bas PWA (barre nav, saisie chat).
class PwaBottomInset extends StatelessWidget {
  const PwaBottomInset({
    super.key,
    required this.child,
    this.extra = 8,
    this.color,
  });

  final Widget child;
  final double extra;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    Widget body = child;
    if (kIsWeb && pwaIsStandalone()) {
      final bottom = PwaSafeInsets.bottomOf(MediaQuery.of(context)) + extra;
      body = Padding(padding: EdgeInsets.only(bottom: bottom), child: child);
    } else {
      body = SafeArea(top: false, minimum: EdgeInsets.zero, child: child);
    }
    if (color != null) return ColoredBox(color: color!, child: body);
    return body;
  }
}
