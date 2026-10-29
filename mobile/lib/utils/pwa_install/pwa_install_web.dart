// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

const _dismissKey = 'st_pwa_install_dismissed';
// v2 : nouvelle clé — réinitialise les fermetures de l'ancienne bannière.
const _storeBannerDismissKey = 'st_store_banner_dismissed_v2';
// Après fermeture, la bannière revient au bout de 7 jours (pas définitif).
const _storeBannerDismissTtlMs = 7 * 24 * 60 * 60 * 1000;

double jsSafeInset(String key) {
  try {
    final raw = (html.window as dynamic).stSafeInsets;
    if (raw == null) return 0;
    final v = raw[key];
    if (v is num) return v.toDouble();
  } catch (_) {}
  return 0;
}

bool pwaShouldOfferInstall() {
  if (_isStandalone()) return false;
  if (!_isIos()) return false;
  if (html.window.localStorage[_dismissKey] == '1') return false;
  return true;
}

bool pwaIsStandalone() => _isStandalone();

void pwaDismissInstallOffer() {
  html.window.localStorage[_dismissKey] = '1';
}

bool pwaIsIosWeb() => _isIos();

bool pwaIsAndroidWeb() {
  final ua = html.window.navigator.userAgent.toLowerCase();
  return ua.contains('android');
}

/// Vrai sur un navigateur mobile (smartphone/tablette) — pas desktop.
bool pwaIsMobileWeb() => _isIos() || pwaIsAndroidWeb();

/// Bannière « Télécharger l'app » : uniquement mobile web, hors mode standalone.
bool storeBannerShouldShow() {
  if (_isStandalone()) return false;
  if (!pwaIsMobileWeb()) return false;
  final dismissedAt =
      int.tryParse(html.window.localStorage[_storeBannerDismissKey] ?? '');
  if (dismissedAt != null &&
      DateTime.now().millisecondsSinceEpoch - dismissedAt <
          _storeBannerDismissTtlMs) {
    return false;
  }
  return true;
}

void storeBannerDismiss() {
  html.window.localStorage[_storeBannerDismissKey] =
      '${DateTime.now().millisecondsSinceEpoch}';
}

bool _isStandalone() {
  try {
    final standalone = (html.window as dynamic).stPwaStandalone;
    if (standalone == true) return true;
  } catch (_) {}
  try {
    if (html.window.matchMedia('(display-mode: standalone)').matches) return true;
    if (html.window.matchMedia('(display-mode: fullscreen)').matches) return true;
    if (html.window.matchMedia('(display-mode: minimal-ui)').matches) return true;
  } catch (_) {}
  try {
    final nav = html.window.navigator as dynamic;
    if (nav.standalone == true) return true;
  } catch (_) {}
  return false;
}

bool _isIos() {
  final nav = html.window.navigator;
  final ua = nav.userAgent.toLowerCase();
  if (ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod')) {
    return true;
  }
  // iPadOS 13+ : Safari envoie un UA "Macintosh" en mode bureau — seul
  // maxTouchPoints > 1 le distingue d'un vrai Mac.
  if (ua.contains('macintosh') && (nav.maxTouchPoints ?? 0) > 1) return true;
  return false;
}
