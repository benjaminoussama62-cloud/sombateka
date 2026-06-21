import '../core/api/api_client.dart';

class OrdersRepository {
  OrdersRepository(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> createOrder(
    int listingId, {
    String? variantSize,
    String? variantColor,
    int quantity = 1,
    String paymentChannel = 'mobile_money',
  }) async {
    final r = await _api.post<Map<String, dynamic>>('/orders/', data: {
      'listing_id': listingId,
      if (variantSize != null && variantSize.isNotEmpty) 'variant_size': variantSize,
      if (variantColor != null && variantColor.isNotEmpty) 'variant_color': variantColor,
      'quantity': quantity,
      'payment_channel': paymentChannel,
    });
    return Map<String, dynamic>.from(r.data ?? {});
  }

  Future<Map<String, dynamic>> payOrder(int orderId, String provider) async {
    final r = await _api.post<Map<String, dynamic>>(
      '/orders/$orderId/pay',
      data: {'provider': provider},
    );
    return Map<String, dynamic>.from(r.data ?? {});
  }

  Future<List<Map<String, dynamic>>> listMyOrders() async {
    final r = await _api.get<Map<String, dynamic>>('/orders/mine');
    final items = (r.data?['items'] as List?) ?? [];
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> getHandoverCode(int orderId) async {
    final r = await _api.get<Map<String, dynamic>>('/orders/$orderId/handover');
    return Map<String, dynamic>.from(r.data ?? {});
  }

  Future<Map<String, dynamic>> getOrder(int orderId) async {
    final r = await _api.get<Map<String, dynamic>>('/orders/$orderId');
    return Map<String, dynamic>.from(r.data ?? {});
  }

  Future<Map<String, dynamic>> confirmReceipt(int orderId) async {
    final r = await _api.post<Map<String, dynamic>>('/orders/$orderId/confirm-receipt');
    return Map<String, dynamic>.from(r.data ?? {});
  }

  Future<void> openDispute(int orderId, {required String reason, String? details}) async {
    await _api.post('/orders/$orderId/dispute', data: {
      'reason': reason,
      if (details != null) 'details': details,
    });
  }
}
