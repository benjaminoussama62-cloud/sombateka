import '../core/api/api_client.dart';

class CategoriesRepository {
  CategoriesRepository(this._api);

  final ApiClient _api;

  Future<List<Map<String, dynamic>>> fetchCategories() async {
    final r = await _api.get<Map<String, dynamic>>('/categories');
    final items = (r.data?['items'] as List?) ?? [];
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
