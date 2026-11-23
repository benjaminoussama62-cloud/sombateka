/// Anti-capture login/register — Flutter
///
/// Android: FLAG_SECURE via screen_protector — bloque screenshots/recording.
/// iOS: deliberately not blocked, so App Review and normal iOS workflows can capture
/// the real login/register experience.
///
/// pubspec: screen_protector: ^1.4.5
library;

import 'package:flutter/foundation.dart';
import 'package:screen_protector/screen_protector.dart';

class CyberScreenShield {
  CyberScreenShield._();

  static Future<void> enable() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform == TargetPlatform.iOS) return;
    try {
      await ScreenProtector.preventScreenshotOn();
      await ScreenProtector.protectDataLeakageOn();
    } catch (e) {
      debugPrint('cyber-army screen shield enable failed: $e');
    }
  }

  static Future<void> disable() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform == TargetPlatform.iOS) return;
    try {
      await ScreenProtector.preventScreenshotOff();
      await ScreenProtector.protectDataLeakageOff();
    } catch (e) {
      debugPrint('cyber-army screen shield disable failed: $e');
    }
  }
}
