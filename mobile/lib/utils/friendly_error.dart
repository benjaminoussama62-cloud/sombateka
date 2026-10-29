/// Transforme une erreur technique en message utilisateur sûr.
///
/// Règle : JAMAIS d'internes exposés à l'utilisateur (Blob, HTTP, URI,
/// stack trace, types Dart…). Seuls les messages métier (FR, lisibles,
/// venant du backend ou de validations) sont affichés tels quels.
library;

import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import 'api_errors.dart';

final _techPattern = RegExp(
  r'(blob|revoked|http[s]?://|status ?code|\b40[0-9]\b|\b50[0-9]\b|socket|xhr|xmlhttp|'
  r'typeerror|stack|dart:|is not a subtype|handshake|certificate|utf8|codec|'
  r'instance of|nosuchmethod|assertion|_internal|lateinitializ|rangeerror|'
  r'platformexception|domexception|js error|abort|timeout|deadline|'
  r'connection refused|session_required|_token\b|jwt\b|\bnull\b)',
  caseSensitive: false,
);

/// Message sûr à afficher — jamais de détails techniques.
String friendlyError(
  Object? e, {
  String fallback = "Une erreur est survenue. Réessayez.",
}) {
  if (e == null) return fallback;
  // Garder la trace interne pour le debug (console/Sentry) — jamais à l'écran.
  developer.log('Erreur capturée', name: 'friendlyError', error: e);

  // Erreurs HTTP : déléguer au helper API (extrait "detail" du backend).
  if (e is DioException) return friendlyApiError(e, fallback: fallback);

  var msg = e.toString().trim();
  for (final p in const ['Exception: ', 'DioException: ', 'StateError: ']) {
    if (msg.startsWith(p)) {
      msg = msg.substring(p.length).trim();
      break;
    }
  }

  // Trop long, technique ou contenant du code → message générique.
  if (msg.isEmpty || msg.length > 140 || _techPattern.hasMatch(msg)) {
    return fallback;
  }
  // N'accepter que du texte lisible (lettres FR, ponctuation, chiffres).
  final readable = RegExp(r"^[A-Za-zÀ-ÖØ-öø-ÿ0-9 .,;:!?''()\-/€$%+«»]+$");
  if (!readable.hasMatch(msg)) return fallback;
  return msg;
}
