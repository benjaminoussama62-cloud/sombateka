import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart';

/// Crée un [MultipartFile] compatible mobile **et** Flutter Web (sans dart:io).
MultipartFile buildImageMultipart({
  required Uint8List bytes,
  String filename = 'photo.jpg',
  String contentType = 'image/jpeg',
}) {
  final name = _safeFilename(filename);
  return MultipartFile.fromBytes(
    bytes,
    filename: name,
    contentType: _mediaType(contentType, name),
  );
}

String _safeFilename(String raw) {
  final base = raw.trim().isEmpty ? 'photo.jpg' : raw.trim();
  if (base.contains('.')) return base;
  return '$base.jpg';
}

MediaType _mediaType(String contentType, String filename) {
  final ct = contentType.toLowerCase();
  final fn = filename.toLowerCase();
  if (ct.contains('png') || fn.endsWith('.png')) return MediaType('image', 'png');
  if (ct.contains('webp') || fn.endsWith('.webp')) return MediaType('image', 'webp');
  return MediaType('image', 'jpeg');
}

/// Sur le web, [filePath] ne doit jamais être utilisé pour un upload.
void assertWebImageBytes(Uint8List? bytes) {
  if (kIsWeb && (bytes == null || bytes.isEmpty)) {
    throw StateError('Image introuvable — réessayez avec une autre photo');
  }
}
