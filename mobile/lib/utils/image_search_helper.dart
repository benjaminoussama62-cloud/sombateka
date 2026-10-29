import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/premium_theme.dart';
import '../widgets/st_safe_area.dart';
import 'image_search_web_picker_stub.dart'
    if (dart.library.js_interop) 'image_search_web_picker_web.dart';

/// Taille max upload recherche visuelle (5 Mo) — aligné sécurité backend.
const int kMaxImageSearchBytes = 5 * 1024 * 1024;

/// Choisit une photo pour la recherche visuelle (caméra mobile, galerie partout).
Future<({Uint8List bytes, String filename})?> pickImageForSearch(BuildContext context) async {
  if (kIsWeb) {
    return pickImageViaHtmlInput();
  }

  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => StSafeBottom(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recherche par photo', style: PremiumTheme.h1.copyWith(fontSize: 18)),
            const SizedBox(height: 6),
            Text(
              'Cadrez un seul produit — SombaTeka compare forme, couleurs et textures.',
              style: PremiumTheme.body.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded, color: PremiumTheme.blue),
              title: const Text('Prendre une photo'),
              subtitle: const Text('Android & iPhone'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: PremiumTheme.navy),
              title: const Text('Choisir dans la galerie'),
              subtitle: const Text('Photos enregistrées'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    ),
  );
  if (source == null) return null;

  final picker = ImagePicker();
  final image = await picker.pickImage(
    source: source,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 88,
  );
  if (image == null) return null;

  final bytes = await image.readAsBytes();
  if (bytes.isEmpty) {
    throw StateError('Photo illisible — choisissez une autre image');
  }
  if (bytes.length > kMaxImageSearchBytes) {
    throw StateError('Image trop lourde (max 5 Mo) — réduisez la taille ou choisissez une autre photo');
  }

  final name = image.name.trim().isNotEmpty ? image.name.trim() : 'recherche.jpg';
  return (bytes: bytes, filename: name);
}
