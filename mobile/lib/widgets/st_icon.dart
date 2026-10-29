import 'package:flutter/material.dart';

/// Icônes Material partout (Safari, Chrome, PWA) — police préchargée dans index.html.
class StIcon extends StatelessWidget {
  const StIcon({
    super.key,
    required this.icon,
    this.size = 24,
    this.color,
    this.webGlyph,
  });

  final IconData icon;
  final double size;
  final Color? color;
  /// Conservé pour compatibilité ; ignoré (Material Icons utilisés partout).
  final String? webGlyph;

  factory StIcon.from(
    IconData icon, {
    Key? key,
    double size = 24,
    Color? color,
    String? webGlyph,
  }) {
    return StIcon(key: key, icon: icon, size: size, color: color, webGlyph: webGlyph);
  }

  @override
  Widget build(BuildContext context) => Icon(icon, size: size, color: color);
}

/// Remplace [Icon] — rendu identique sur tous les navigateurs.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.color,
    this.webGlyph,
  });

  final IconData icon;
  final double size;
  final Color? color;
  final String? webGlyph;

  @override
  Widget build(BuildContext context) => Icon(icon, size: size, color: color);
}
