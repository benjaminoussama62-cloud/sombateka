import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/api/token_storage.dart';
import '../core/offline/offline_cache.dart';
import '../services/data_service.dart';

class AuthRepository {
  AuthRepository(this._api, this._tokens);

  final ApiClient _api;
  final TokenStorage _tokens;

  Future<Map<String, dynamic>> sendOtp(String phoneE164) async {
    final r = await _api.post<Map<String, dynamic>>('/auth/otp/send', data: {'phone_e164': phoneE164});
    return Map<String, dynamic>.from(r.data ?? {});
  }

  Future<Map<String, dynamic>> sendEmailOtp(String email, {String? displayName}) async {
    final r = await _api.post<Map<String, dynamic>>(
      '/auth/email/otp/send',
      data: {
        'email': email.trim(),
        if (displayName != null && displayName.trim().isNotEmpty) 'display_name': displayName.trim(),
      },
    );
    return Map<String, dynamic>.from(r.data ?? {});
  }

  Future<void> verifyOtp(String phoneE164, String code) async {
    final phone = DataService.normalizePhoneE164(phoneE164);
    final normalizedCode = DataService.normalizeOtpCode(code);
    try {
      final r = await _api.post<Map<String, dynamic>>(
        '/auth/otp/verify',
        data: {'phone_e164': phone, 'code': normalizedCode},
      );
      final token = r.data?['access_token'] as String?;
      if (token == null) throw Exception('Token manquant');
      await _tokens.saveToken(token);
    } on DioException catch (e) {
      final detail = e.response?.data;
      if (detail is Map && detail['detail'] != null) {
        throw Exception(detail['detail'].toString());
      }
      rethrow;
    }
  }

  Future<void> verifyEmailOtp(String email, String code) async {
    final normalizedCode = DataService.normalizeOtpCode(code);
    try {
      final r = await _api.post<Map<String, dynamic>>(
        '/auth/email/otp/verify',
        data: {'email': email.trim(), 'code': normalizedCode},
      );
      final token = r.data?['access_token'] as String?;
      if (token == null) throw Exception('Token manquant');
      await _tokens.saveToken(token);
    } on DioException catch (e) {
      final detail = e.response?.data;
      if (detail is Map && detail['detail'] != null) {
        throw Exception(detail['detail'].toString());
      }
      rethrow;
    }
  }

  Future<void> socialLogin({
    required String provider,
    required String subject,
    String? email,
    String? displayName,
  }) async {
    final r = await _api.post<Map<String, dynamic>>(
      '/auth/social/login',
      data: {
        'provider': provider,
        'subject': subject,
        if (email != null) 'email': email,
        if (displayName != null) 'display_name': displayName,
      },
    );
    final token = r.data?['access_token'] as String?;
    if (token == null) throw Exception('Connexion refusée');
    await _tokens.saveToken(token);
  }

  /// Connexion dev (backend: allow_dev_password_login + password "dev").
  Future<void> devLogin(String phoneE164, {String password = 'developer'}) async {
    final r = await _api.post<Map<String, dynamic>>(
      '/auth/dev/login',
      data: {'phone_e164': phoneE164, 'password': password},
    );
    final token = r.data?['access_token'] as String?;
    if (token == null) {
      throw Exception(r.data?['detail']?.toString() ?? 'Connexion refusée');
    }
    await _tokens.saveToken(token);
  }

  Future<Map<String, dynamic>> fetchMe() async {
    final r = await _api.get<Map<String, dynamic>>('/auth/me');
    final user = Map<String, dynamic>.from((r.data?['user'] as Map?) ?? {});
    await OfflineCache.cacheUser(user);
    return user;
  }

  Future<bool> hasSession() => _tokens.isLoggedIn();

  Future<void> logout() async {
    await _tokens.clear();
  }
}
