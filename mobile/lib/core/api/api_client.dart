import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../config/api_config.dart';
import 'token_storage.dart';

class ApiClient {
  ApiClient(this._tokens) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl + ApiConfig.apiPrefix,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Accept': 'application/json'},
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokens.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final TokenStorage _tokens;
  late final Dio _dio;
  final _uuid = const Uuid();

  Dio get dio => _dio;

  String newIdempotencyKey() => _uuid.v4();

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) =>
      _dio.get<T>(path, queryParameters: query);

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool idempotent = false,
  }) async {
    final headers = <String, dynamic>{};
    if (idempotent) headers['X-Idempotency-Key'] = newIdempotencyKey();
    return _dio.post<T>(path, data: data, queryParameters: query, options: Options(headers: headers));
  }

  Future<Response<T>> patch<T>(String path, {dynamic data}) =>
      _dio.patch<T>(path, data: data);

  Future<Response<T>> delete<T>(String path, {dynamic data, Map<String, dynamic>? query}) =>
      _dio.delete<T>(path, data: data, queryParameters: query);

  String absoluteUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return ApiConfig.baseUrl + path;
  }
}
