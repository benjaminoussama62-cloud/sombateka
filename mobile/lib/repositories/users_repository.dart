import 'package:dio/dio.dart';
import 'dart:typed_data';

import 'package:http_parser/http_parser.dart';

import '../core/api/api_client.dart';
import '../services/data_service.dart';

class UsersRepository {
  UsersRepository(this._api);
  final ApiClient _api;

  Map<String, dynamic> _userFromResponse(Map<String, dynamic>? data) {
    return Map<String, dynamic>.from((data?['user'] as Map?) ?? {});
  }

  Future<Map<String, dynamic>> updateProfile({String? displayName, String? phoneE164, String? profileBio}) async {
    final r = await _api.patch<Map<String, dynamic>>(
      '/users/me',
      data: {
        if (displayName != null) 'display_name': displayName,
        if (phoneE164 != null) 'phone_e164': phoneE164,
        if (profileBio != null) 'profile_bio': profileBio,
      },
    );
    return _userFromResponse(r.data);
  }

  Future<Map<String, dynamic>> setAccountPassword(String password) async {
    final r = await _api.post<Map<String, dynamic>>(
      '/users/me/password',
      data: {'password': password},
    );
    return _userFromResponse(r.data);
  }

  Future<Map<String, dynamic>> uploadAvatarFile(String filePath) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final r = await _api.dio.post<Map<String, dynamic>>('/users/me/avatar', data: form);
    return _userFromResponse(r.data);
  }

  Future<Map<String, dynamic>> uploadAvatarBytes({
    required Uint8List bytes,
    required String filename,
    String contentType = 'image/jpeg',
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename, contentType: MediaType.parse(contentType)),
    });
    final r = await _api.dio.post<Map<String, dynamic>>('/users/me/avatar', data: form);
    return _userFromResponse(r.data);
  }

  Future<Map<String, dynamic>> deleteAvatar() async {
    final r = await _api.delete<Map<String, dynamic>>('/users/me/avatar');
    return _userFromResponse(r.data);
  }

  Future<void> updatePrivacy({
    bool? profilePublic,
    bool? showPhone,
    bool? allowMessages,
  }) async {
    await _api.patch('/users/me/privacy', data: {
      if (profilePublic != null) 'privacy_profile_public': profilePublic,
      if (showPhone != null) 'privacy_show_phone': showPhone,
      if (allowMessages != null) 'privacy_allow_messages': allowMessages,
    });
  }

  Future<List<Map<String, dynamic>>> fetchBlocked() async {
    final r = await _api.get<Map<String, dynamic>>('/users/me/blocked');
    final items = (r.data?['items'] as List?) ?? [];
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> deleteAccount() async {
    await _api.delete('/users/me', data: {'confirm': true});
  }

  Future<Map<String, dynamic>> sendEmailVerificationCode() async {
    final r = await _api.post<Map<String, dynamic>>('/users/me/email/verify/send');
    return Map<String, dynamic>.from(r.data ?? {});
  }

  Future<Map<String, dynamic>> verifyEmailWithCode(String code) async {
    final r = await _api.post<Map<String, dynamic>>(
      '/users/me/email/verify',
      data: {'code': DataService.normalizeOtpCode(code)},
    );
    return _userFromResponse(r.data);
  }

  Future<Map<String, dynamic>?> fetchPublicProfile(int userId) async {
    try {
      final r = await _api.get<Map<String, dynamic>>('/users/$userId/public');
      final data = Map<String, dynamic>.from(r.data ?? {});
      final avatar = data['avatar_url']?.toString();
      final logo = data['official_logo_url']?.toString();
      if (avatar != null && avatar.isNotEmpty) {
        data['avatar_url'] = _api.absoluteUrl(avatar);
      }
      if (logo != null && logo.isNotEmpty) {
        data['official_logo_url'] = _api.absoluteUrl(logo);
      }
      final listings = (data['listings'] as List?) ?? [];
      data['listings'] = listings.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        final img = m['primary_image_url']?.toString();
        if (img != null && img.isNotEmpty) {
          m['primary_image_url'] = _api.absoluteUrl(img);
        }
        return m;
      }).toList();
      return data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}
