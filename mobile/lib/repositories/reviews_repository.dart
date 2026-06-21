import '../core/api/api_client.dart';

class ReviewsRepository {
  ReviewsRepository(this._api);
  final ApiClient _api;

  Future<Map<String, dynamic>> fetchSummary(int userId) async {
    final r = await _api.get<Map<String, dynamic>>('/reviews/users/$userId/summary');
    return Map<String, dynamic>.from(r.data ?? {});
  }

  Future<List<Map<String, dynamic>>> fetchForUser(int userId) async {
    final r = await _api.get<Map<String, dynamic>>('/reviews/users/$userId');
    final items = (r.data?['items'] as List?) ?? [];
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> fetchForListing(int listingId) async {
    final r = await _api.get<Map<String, dynamic>>('/reviews/listings/$listingId');
    return Map<String, dynamic>.from(r.data ?? {});
  }

  Future<Map<String, dynamic>?> fetchEligibility(int listingId) async {
    try {
      final r = await _api.get<Map<String, dynamic>>('/reviews/listings/$listingId/eligibility');
      return Map<String, dynamic>.from(r.data ?? {});
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasReviewForListing(int listingId) async {
    try {
      final r = await _api.get<Map<String, dynamic>>('/reviews/listings/$listingId/mine');
      return r.data?['has_review'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> submit({
    required int listingId,
    required int rating,
    String? comment,
  }) async {
    await _api.post('/reviews/', data: {
      'listing_id': listingId,
      'rating': rating,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
  }
}
