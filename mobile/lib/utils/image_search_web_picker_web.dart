import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'image_search_helper.dart';

/// Sélecteur fichier natif HTML — fiable sur Safari/Chrome/PWA web.
/// Évite le bug iOS Safari "Blob revoked" de image_picker_for_web :
/// le File est lu directement via FileReader, sans URL objet intermédiaire.
Future<({Uint8List bytes, String filename})?> pickImageViaHtmlInput({
  int maxBytes = kMaxImageSearchBytes,
}) async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/jpeg,image/png,image/webp,image/*'
    ..multiple = false;

  input.style.display = 'none';
  html.document.body?.append(input);

  final completer = Completer<({Uint8List bytes, String filename})?>();

  void cleanup() {
    try {
      input.remove();
    } catch (_) {}
  }

  Uint8List? _bytesFromReaderResult(Object? raw) {
    if (raw is ByteBuffer) return raw.asUint8List();
    if (raw is Uint8List) return raw;
    if (raw is TypedData) {
      return raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes);
    }
    return null;
  }

  input.onChange.listen((_) async {
    try {
      final file = input.files?.first;
      if (file == null) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoadEnd.first;
      if (reader.error != null) {
        throw StateError('Lecture photo échouée — réessayez');
      }
      final bytes = _bytesFromReaderResult(reader.result);
      if (bytes == null || bytes.isEmpty) {
        throw StateError('Photo illisible — choisissez une autre image');
      }
      if (bytes.length > maxBytes) {
        final mb = (maxBytes / (1024 * 1024)).round();
        throw StateError('Image trop lourde (max $mb Mo)');
      }
      var name = file.name.trim();
      if (name.isEmpty) name = 'recherche.jpg';
      // Force extension connue pour le Content-Type multipart
      final lower = name.toLowerCase();
      if (!lower.endsWith('.jpg') &&
          !lower.endsWith('.jpeg') &&
          !lower.endsWith('.png') &&
          !lower.endsWith('.webp')) {
        name = '$name.jpg';
      }
      if (!completer.isCompleted) {
        completer.complete((bytes: bytes, filename: name));
      }
    } catch (e) {
      if (!completer.isCompleted) completer.completeError(e);
    } finally {
      cleanup();
    }
  });

  // Déclencher le dialogue fichier (geste utilisateur requis)
  Future.microtask(() => input.click());

  Future.delayed(const Duration(seconds: 120), () {
    if (!completer.isCompleted) {
      cleanup();
      completer.complete(null);
    }
  });

  return completer.future;
}
