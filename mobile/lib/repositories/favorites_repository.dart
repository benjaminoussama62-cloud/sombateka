import '../core/api/api_client.dart';

class FavoritesRepository {
  FavoritesRepository(this._api);
  final ApiClient _api;

  Future<void> add(int listingId) => _api.post('/favorites/$listingId');
  Future<void> remove(int listingId) => _api.delete('/favorites/$listingId');

  Future<List<int>> listIds() async {
    try {
      final r = await _api.get<Map<String, dynamic>>('/favorites');
      final items = (r.data?['items'] as List?) ?? [];
      return items.map((e) => (e as Map)['id'] as int).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> listItems() async {
    try {
      final r = await _api.get<Map<String, dynamic>>('/favorites');
      final items = (r.data?['items'] as List?) ?? [];
      return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }
}
