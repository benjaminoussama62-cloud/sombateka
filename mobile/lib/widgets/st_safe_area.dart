import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/pwa.dart';
import '../utils/pwa_safe_insets.dart';

/// Safe area cohérente — une seule couche, sans double padding PWA.
class StSafeTop extends StatelessWidget {
  const StSafeTop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(bottom: false, minimum: EdgeInsets.zero, child: child);
  }
}

class StBottomInset {
  StBottomInset._();

  static double of(BuildContext context) {
    return PwaSafeInsets.bottomOf(MediaQuery.of(context));
  }

  static EdgeInsets padding(
    BuildContext context, {
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) {
    return EdgeInsets.fromLTRB(left, top, right, bottom + of(context));
  }
}

class StSafeBottom extends StatelessWidget {
  const StSafeBottom({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb && !pwaIsStandalone()) {
      return child;
    }
    return SafeArea(top: false, minimum: EdgeInsets.zero, child: child);
  }
}
