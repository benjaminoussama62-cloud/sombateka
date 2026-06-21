import '../core/api/api_client.dart';

class SupportRepository {
  SupportRepository(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> fetchContact() async {
    final r = await _api.get<Map<String, dynamic>>('/support/contact');
    return Map<String, dynamic>.from(r.data ?? {});
  }
}
