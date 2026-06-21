import '../core/api/api_client.dart';

class NotificationsRepository {
  NotificationsRepository(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> fetchAll() async {
    final r = await _api.get<Map<String, dynamic>>('/notifications');
    return Map<String, dynamic>.from(r.data ?? {'items': [], 'unread_count': 0});
  }

  Future<void> markRead(int id) async {
    await _api.patch<Map<String, dynamic>>('/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await _api.post<Map<String, dynamic>>('/notifications/read-all');
  }
}
