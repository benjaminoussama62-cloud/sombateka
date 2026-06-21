import 'package:dio/dio.dart';

/// Message lisible à partir d'une erreur API (Dio ou autre).
String friendlyApiError(Object error, {String fallback = 'Une erreur est survenue'}) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String && detail.trim().isNotEmpty) return detail.trim();
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] != null) {
          return first['msg'].toString();
        }
      }
    }
    final code = error.response?.statusCode;
    if (code == 400) return 'Requête invalide. Vérifiez les informations.';
    if (code == 403) return 'Action non autorisée.';
    if (code == 404) return 'Élément introuvable.';
  }
  final raw = error.toString();
  if (raw.contains('listing_id requis') || raw.contains('Annonce introuvable')) {
    return 'Ouvrez la discussion depuis la fiche de l\'annonce.';
  }
  if (raw.contains('n\'appartient pas à ce vendeur') || raw.contains('ne correspond pas')) {
    return 'Cette annonce ne correspond pas à ce contact.';
  }
  return fallback;
}
