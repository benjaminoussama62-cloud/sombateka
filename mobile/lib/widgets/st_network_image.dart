import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../utils/constants.dart';

/// Image réseau avec cache disque/mémoire — affichage instantané au retour sur un écran.
class StNetworkImage extends StatelessWidget {
  const StNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholderColor = const Color(0xFFF1F5F9),
    this.errorIcon = Icons.image_outlined,
    this.errorIconSize = 28,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Color placeholderColor;
  final IconData errorIcon;
  final double errorIconSize;

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) {
      return _placeholder();
    }
    final image = CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      memCacheWidth: width != null ? (width! * 2).round() : null,
      memCacheHeight: height != null ? (height! * 2).round() : null,
      placeholder: (_, __) => ColoredBox(color: placeholderColor),
      errorWidget: (_, __, ___) => _placeholder(showIcon: true),
    );
    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }

  Widget _placeholder({bool showIcon = false}) {
    return ColoredBox(
      color: placeholderColor,
      child: showIcon
          ? Center(
              child: Icon(errorIcon, size: errorIconSize, color: AppColors.textSecondary),
            )
          : null,
    );
  }
}
