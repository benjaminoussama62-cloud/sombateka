import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../config/api_config.dart';
import 'token_storage.dart';

typedef SessionExpiredHandler = Future<void> Function();

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
        onError: (error, handler) async {
          // Session longue durée : sur 401, on tente un refresh transparent
          // puis on rejoue la requête — l'utilisateur ne voit jamais le login.
          if (error.response?.statusCode == 401 &&
              error.requestOptions.extra['__retried'] != true) {
            final refreshed = await _tryRefresh();
            if (refreshed) {
              try {
                final req = error.requestOptions;
                req.extra['__retried'] = true;
                final token = await _tokens.getToken();
                if (token != null) req.headers['Authorization'] = 'Bearer $token';
                return handler.resolve(await _dio.fetch(req));
              } catch (_) {
                // retombe sur le flux 401 classique ci-dessous
              }
            }
          }
          if (error.response?.statusCode == 401 && !_handling401) {
            _handling401 = true;
            try {
              final cb = onSessionExpired;
              if (cb != null) {
                await cb();
              } else {
                await _tokens.clear();
              }
            } catch (_) {
              await _tokens.clear();
            } finally {
              _handling401 = false;
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final TokenStorage _tokens;
  late final Dio _dio;
  final _uuid = const Uuid();
  bool _handling401 = false;

  /// Appelé une fois sur 401 (clear session / navigation).
  static SessionExpiredHandler? onSessionExpired;

  bool _refreshing = false;

  /// POST /auth/refresh — silencieux, sans interceptor (Dio nu).
  Future<bool> _tryRefresh() async {
    if (_refreshing) return false;
    _refreshing = true;
    try {
      final refresh = await _tokens.getRefreshToken();
      if (refresh == null || refresh.isEmpty) return false;
      final bare = Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl + ApiConfig.apiPrefix,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
      ));
      final r = await bare.post('/auth/refresh', data: {'refresh_token': refresh});
      final access = r.data?['access_token'] as String?;
      final newRefresh = r.data?['refresh_token'] as String?;
      if (access == null || access.isEmpty) return false;
      await _tokens.saveToken(access, refreshToken: newRefresh);
      return true;
    } catch (_) {
      return false;
    } finally {
      _refreshing = false;
    }
  }

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
