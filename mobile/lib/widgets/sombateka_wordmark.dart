import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/premium_theme.dart';

/// Précharge les polices premium avant le premier rendu (évite flash / carré vide).
Future<void> preloadPremiumFonts() async {
  try {
    await GoogleFonts.pendingFonts([
      GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
      GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
      GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
      GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
      GoogleFonts.inter(fontWeight: FontWeight.w500),
      GoogleFonts.inter(fontWeight: FontWeight.w600),
      GoogleFonts.inter(fontWeight: FontWeight.w700),
      GoogleFonts.inter(fontWeight: FontWeight.w800),
    ]);
  } catch (_) {}
}

/// Sac blanc + étoile jaune + « SombaTeka » — sans image, avec animations.
class SombaTekaWordmark extends StatefulWidget {
  const SombaTekaWordmark({
    super.key,
    this.iconSize = 64,
    this.fontSize = 34,
    this.animate = false,
    this.onDarkBackground = true,
  });

  final double iconSize;
  final double fontSize;
  final bool animate;
  /// `true` = fond bleu/sombre (texte blanc). `false` = fond clair (texte navy).
  final bool onDarkBackground;

  @override
  State<SombaTekaWordmark> createState() => _SombaTekaWordmarkState();
}

class _SombaTekaWordmarkState extends State<SombaTekaWordmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _starPulse;

  @override
  void initState() {
    super.initState();
    _starPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    if (widget.animate) {
      _starPulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _starPulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gap = widget.iconSize * 0.18;
    final titleColor = widget.onDarkBackground ? Colors.white : PremiumTheme.navy;
    final bag = _buildBagIcon(strokeColor: widget.onDarkBackground ? Colors.white : PremiumTheme.navy);
    final title = Text(
      'SombaTeka',
      style: PremiumTheme.display.copyWith(
        fontSize: widget.fontSize,
        fontWeight: FontWeight.w800,
        color: titleColor,
        letterSpacing: -0.4,
        height: 1,
        fontFamilyFallback: const ['Segoe UI', 'system-ui', 'Roboto', 'sans-serif'],
        shadows: widget.onDarkBackground
            ? const [Shadow(color: Color(0x40000000), blurRadius: 12, offset: Offset(0, 4))]
            : null,
      ),
    );

    final animatedTitle = widget.animate
        ? title
            .animate()
            .fadeIn(duration: 120.ms, curve: Curves.easeOut)
        : title;

    // FittedBox évite le débordement jaune/noir sur petits écrans (splash, auth).
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          bag,
          SizedBox(width: gap),
          animatedTitle,
        ],
      ),
    );
  }

  Widget _buildBagIcon({required Color strokeColor}) {
    final size = widget.iconSize;
    final icon = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 1.15,
            height: size * 1.15,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: PremiumTheme.gold.withValues(alpha: 0.22),
                  blurRadius: size * 0.35,
                  spreadRadius: size * 0.02,
                ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: _starPulse,
            builder: (_, __) {
              final t = widget.animate ? 0.85 + (_starPulse.value * 0.15) : 1.0;
              return RepaintBoundary(
                child: CustomPaint(
                  size: Size(size, size),
                  painter: _BagStarPainter(
                    strokeColor: strokeColor,
                    starColor: PremiumTheme.gold,
                    starGlowColor: Color.lerp(
                      PremiumTheme.gold,
                      const Color(0xFFFFF3B0),
                      _starPulse.value * 0.35,
                    )!,
                    strokeWidth: size * 0.065,
                    starScale: t,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );

    if (!widget.animate) return icon;

    return icon.animate().fadeIn(duration: 120.ms, curve: Curves.easeOut);
  }
}

class _BagStarPainter extends CustomPainter {
  _BagStarPainter({
    required this.strokeColor,
    required this.starColor,
    required this.starGlowColor,
    required this.strokeWidth,
    this.starScale = 1,
  });

  final Color strokeColor;
  final Color starColor;
  final Color starGlowColor;
  final double strokeWidth;
  final double starScale;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Sac droit + anse + étoile sur le bord haut-droit — identique à l'icône Play Store
    // (géométrie portée de scripts/generate_store_assets.py::_draw_brand_mark).
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.12, h * 0.239, w * 0.76, h * 0.723),
      Radius.circular(w * 0.087),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.fill,
    );

    canvas.drawArc(
      Rect.fromLTRB(w * 0.229, h * 0.058, w * 0.771, h * 0.383),
      200 * math.pi / 180,
      140 * math.pi / 180,
      false,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    final center = Offset(w * 0.7356, h * 0.311);
    final outer = w * 0.130 * starScale;
    final inner = w * 0.058 * starScale;

    canvas.drawPath(
      _starPath(center: center, outerRadius: outer * 1.35, innerRadius: inner * 1.35),
      Paint()
        ..color = starGlowColor.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    canvas.drawPath(
      _starPath(center: center, outerRadius: outer, innerRadius: inner),
      Paint()
        ..color = starColor
        ..style = PaintingStyle.fill,
    );
  }

  Path _starPath({
    required Offset center,
    required double outerRadius,
    required double innerRadius,
  }) {
    const points = 5;
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final angle = (i * math.pi / points) - math.pi / 2;
      final radius = i.isEven ? outerRadius : innerRadius;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _BagStarPainter old) =>
      old.strokeColor != strokeColor ||
      old.starColor != starColor ||
      old.starGlowColor != starGlowColor ||
      old.strokeWidth != strokeWidth ||
      old.starScale != starScale;
}
