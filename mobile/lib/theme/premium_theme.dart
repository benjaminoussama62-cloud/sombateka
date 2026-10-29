import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design system premium SombaTeka — cohérent sur toute l'app.
class PremiumTheme {
  static const Color navy = Color(0xFF0B1538);
  static const Color navyLight = Color(0xFF152454);
  static const Color blue = Color(0xFF2563EB);
  static const Color blueGlow = Color(0xFF3B82F6);
  static const Color emerald = Color(0xFF10B981);
  static const Color gold = Color(0xFFFBBF24);
  static const Color surface = Color(0xFFF8FAFC);
  static const Color card = Colors.white;
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);

  static TextStyle get display => GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        letterSpacing: -0.5,
      );

  static TextStyle get h1 => GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: textDark,
      );

  static TextStyle get body => GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: textMuted,
      );

  static TextStyle get label => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: textMuted,
        letterSpacing: 0.4,
      );

  /// En-tête accueil — navy de base (visible sous les halos).
  static const Color homeHeaderColor = Color(0xFF0D1B4B);

  /// @deprecated Préférer [homeHeaderColor] pour l'accueil.
  static const Color headerBg = homeHeaderColor;

  static Decoration get homeHeaderDecoration => const StGlowDecoration();

  static Decoration heroGradient = const StGlowDecoration();

  /// Hauteur contenu barre basse (hors safe area) — aligné apps Meta (~49–52 px).
  static const double bottomNavContentHeight = 50.0;
  static const double bottomNavFabSize = 42.0;

  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: const Color(0xFF2563EB).withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static BorderRadius get radiusLg => BorderRadius.circular(20);
  static BorderRadius get radiusMd => BorderRadius.circular(14);
}

/// Décor signature SombaTeka — navy + halos bleu / émeraude (identité visuelle).
/// Utilisable partout où une `Decoration` est attendue :
/// headers, cards promo, sheets, écrans d'accueil — rendu uniforme.
class StGlowDecoration extends Decoration {
  const StGlowDecoration({this.borderRadius, this.boxShadow});

  final BorderRadius? borderRadius;
  final List<BoxShadow>? boxShadow;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _StGlowPainter(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StGlowDecoration &&
          other.borderRadius == borderRadius &&
          other.boxShadow == boxShadow);

  @override
  int get hashCode => Object.hash(borderRadius, boxShadow);
}

class _StGlowPainter extends BoxPainter {
  _StGlowPainter(this._deco);

  final StGlowDecoration _deco;

  void _glow(Canvas canvas, Rect rect, Alignment center, Color color, double alpha) {
    final radius = rect.longestSide * 0.75;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center.withinRect(rect), radius: radius));
    canvas.drawRect(rect, paint);
  }

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null || size.isEmpty) return;
    final rect = offset & size;
    final radius = _deco.borderRadius;
    RRect? rrect;
    canvas.save();
    if (radius != null) {
      rrect = radius.toRRect(rect);
      final shadows = _deco.boxShadow;
      if (shadows != null) {
        for (final s in shadows) {
          canvas.drawRRect(
            rrect.shift(s.offset).inflate(s.spreadRadius),
            Paint()
              ..color = s.color
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.blurRadius / 2),
          );
        }
      }
      canvas.clipRRect(rrect);
    }
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF13295E), PremiumTheme.homeHeaderColor, Color(0xFF0A1436)],
        ).createShader(rect),
    );
    _glow(canvas, rect, const Alignment(-0.9, -0.85), PremiumTheme.blueGlow, 0.30);
    _glow(canvas, rect, const Alignment(0.95, 0.9), PremiumTheme.emerald, 0.22);
    canvas.restore();
  }
}
