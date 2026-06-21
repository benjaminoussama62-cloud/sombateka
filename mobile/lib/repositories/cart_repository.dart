import '../core/api/api_client.dart';

class CartRepository {
  CartRepository(this._api);
  final ApiClient _api;

  Future<List<Map<String, dynamic>>> listItems() async {
    try {
      final r = await _api.get<Map<String, dynamic>>('/cart');
      final items = (r.data?['items'] as List?) ?? [];
      return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<int> cartCount() async {
    try {
      final r = await _api.get<Map<String, dynamic>>('/cart');
      return (r.data?['count'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> add(int listingId, {int quantity = 1, String? variantSize, String? variantColor}) =>
      _api.post('/cart/$listingId', data: {
        'quantity': quantity,
        if (variantSize != null && variantSize.isNotEmpty) 'variant_size': variantSize,
        if (variantColor != null && variantColor.isNotEmpty) 'variant_color': variantColor,
      });

  Future<void> updateQty(int listingId, int quantity) async {
    if (quantity <= 0) {
      await remove(listingId);
      return;
    }
    await _api.patch('/cart/$listingId', data: {'quantity': quantity});
  }

  Future<void> remove(int listingId) => _api.delete('/cart/$listingId');
}
