import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Scroll + drag fiables sur PWA / Safari / Chrome mobile.
class StWebScrollBehavior extends MaterialScrollBehavior {
  const StWebScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    if (kIsWeb) {
      return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
    }
    return super.getScrollPhysics(context);
  }
}
