import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'publish_field_styles.dart';
import '../theme/premium_theme.dart';
import '../utils/constants.dart';

/// Données photo pour publication (Web-safe, sans dart:io).
class PublishPhoto {
  PublishPhoto({required this.file, required this.bytes});
  final XFile file;
  final Uint8List bytes;
}

/// Grille d'aperçu photos — uniquement [Image.memory], jamais [Image.file].
class PublishPhotoGrid extends StatelessWidget {
  const PublishPhotoGrid({
    super.key,
    required this.photos,
    required this.onAdd,
    required this.onRemove,
    this.maxPhotos = 5,
  });

  final List<PublishPhoto> photos;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  final int maxPhotos;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Galerie (${photos.length}/$maxPhotos)', style: PublishFieldStyles.label.copyWith(fontSize: 15)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1,
          ),
          itemCount: photos.length < maxPhotos ? photos.length + 1 : maxPhotos,
          itemBuilder: (context, i) {
            if (i == photos.length && photos.length < maxPhotos) {
              return _AddPhotoTile(onTap: onAdd);
            }
            return Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: PremiumTheme.radiusMd,
                  child: _MemoryPhotoImage(bytes: photos[i].bytes),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => onRemove(i),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MemoryPhotoImage extends StatelessWidget {
  const _MemoryPhotoImage({required this.bytes});
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Image.memory(
      bytes,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => const ColoredBox(
        color: AppColors.border,
        child: Icon(Icons.broken_image_outlined, color: AppColors.textSecondary),
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: PremiumTheme.radiusMd,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: PremiumTheme.radiusMd,
            border: Border.all(color: PremiumTheme.blue.withValues(alpha: 0.4), width: 2),
            color: PremiumTheme.blue.withValues(alpha: 0.05),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo_rounded, color: PremiumTheme.blue, size: 32),
              SizedBox(height: 6),
              Text(
                'Ajouter',
                style: TextStyle(
                  color: PremiumTheme.blue,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
