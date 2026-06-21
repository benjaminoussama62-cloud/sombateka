import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../core/api/api_client.dart';

class UsersRepository {
  UsersRepository(this._api);
  final ApiClient _api;

  Map<String, dynamic> _userFromResponse(Map<String, dynamic>? data) {
    return Map<String, dynamic>.from((data?['user'] as Map?) ?? {});
  }

  Future<Map<String, dynamic>> updateProfile({String? displayName}) async {
    final r = await _api.patch<Map<String, dynamic>>(
      '/users/me',
      data: {if (displayName != null) 'display_name': displayName},
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
}
