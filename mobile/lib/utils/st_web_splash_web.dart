import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Masque le splash HTML via le DOM (fiable meme si l'interop globale echoue).
void stHideHtmlSplash() {
  try {
    final splash = web.document.getElementById('st-splash');
    if (splash != null && splash is web.HTMLElement) {
      splash.style
        ..setProperty('pointer-events', 'none')
        ..setProperty('display', 'none')
        ..setProperty('opacity', '0');
      splash.remove();
      return;
    }
  } catch (_) {}
  try {
    _hideStSplashJs();
  } catch (_) {}
}

@JS('hideStSplash')
external void _hideStSplashJs();

/// Recharge la page (écran d'erreur web).
void stReloadPage() {
  try {
    web.window.location.reload();
  } catch (_) {}
}
