import 'package:flutter/foundation.dart';

/// Parse deep-link produit depuis l’URL web (?listing=id ou /annonce/{id}-…).
int? parseListingIdFromUri(Uri uri) {
  final q = uri.queryParameters['listing'] ?? uri.queryParameters['id'];
  if (q != null) {
    final id = int.tryParse(q);
    if (id != null && id > 0) return id;
  }
  final segs = uri.pathSegments;
  if (segs.isNotEmpty && (segs.first == 'annonce' || segs.first == 'listing' || segs.first == 'product')) {
    if (segs.length >= 2) {
      final raw = segs[1].split('-').first;
      final id = int.tryParse(raw);
      if (id != null && id > 0) return id;
    }
  }
  return null;
}

/// URI courante (web uniquement).
int? currentWebListingId() {
  if (!kIsWeb) return null;
  try {
    return parseListingIdFromUri(Uri.base);
  } catch (_) {
    return null;
  }
}
