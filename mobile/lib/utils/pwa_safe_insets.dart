import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'pwa.dart';
import 'pwa_install/pwa_insets_stub.dart' if (dart.library.js_interop) 'pwa_install/pwa_install_web.dart';

/// Safe areas PWA — une seule source (évite double padding en haut).
class PwaSafeInsets {
  PwaSafeInsets._();

  static double _js(String key) {
    if (!kIsWeb) return 0;
    return jsSafeInset(key);
  }

  static double topOf(MediaQueryData mq) {
    if (!kIsWeb || !pwaIsStandalone()) return mq.viewPadding.top;
    if (mq.viewPadding.top > 0) return mq.viewPadding.top;
    final jsTop = _js('top');
    if (jsTop > 0) return jsTop;
    return 0;
  }

  /// Inset bas — barre home iPhone / gestes Android (PWA installée uniquement).
  static double bottomOf(MediaQueryData mq) {
    if (!kIsWeb) {
      final v = mq.viewPadding.bottom;
      return v > 0 ? v : mq.padding.bottom;
    }
    // Navigateur (Safari/Chrome) : pas de padding supplémentaire — la barre URL suffit.
    if (!pwaIsStandalone()) return 0;
    var bottom = mq.viewPadding.bottom;
    if (bottom > 0) return bottom;
    bottom = mq.padding.bottom;
    if (bottom > 0) return bottom;
    final jsBottom = _js('bottom');
    if (jsBottom > 0) return jsBottom;
    return 0;
  }

  static EdgeInsets effectivePadding(MediaQueryData mq) => mq.padding;
}
