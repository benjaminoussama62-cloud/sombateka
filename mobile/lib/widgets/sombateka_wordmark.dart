import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/premium_theme.dart';

/// Sac blanc + étoile jaune + « SombaTeka » — sans image, avec animations.
class SombaTekaWordmark extends StatefulWidget {
  const SombaTekaWordmark({
    super.key,
    this.iconSize = 64,
    this.fontSize = 34,
    this.animate = true,
  });

  final double iconSize;
  final double fontSize;
  final bool animate;

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
    final bag = _buildBagIcon();
    final title = Text(
      'SombaTeka',
      style: PremiumTheme.display.copyWith(
        fontSize: widget.fontSize,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        letterSpacing: -0.4,
        height: 1,
        shadows: const [
          Shadow(color: Color(0x40000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
    );

    final animatedTitle = widget.animate
        ? title
            .animate(delay: 380.ms)
            .fadeIn(duration: 550.ms, curve: Curves.easeOut)
            .slideX(begin: 0.22, end: 0, duration: 650.ms, curve: Curves.easeOutCubic)
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

  Widget _buildBagIcon() {
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
                    strokeColor: Colors.white,
                    starColor: PremiumTheme.gold,
                    starGlowColor: Color.lerp(
                      PremiumTheme.gold,
                      const Color(0xFFFFF3B0),
                      _starPulse.value * 0.35,
                    )!,
                    strokeWidth: size * 0.055,
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

    return icon
        .animate()
        .scale(
          begin: const Offset(0.4, 0.4),
          end: const Offset(1, 1),
          duration: 750.ms,
          curve: Curves.elasticOut,
        )
        .fadeIn(duration: 400.ms);
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

    final stroke = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final handle = Path()
      ..moveTo(w * 0.32, h * 0.22)
      ..cubicTo(w * 0.32, h * 0.05, w * 0.68, h * 0.05, w * 0.68, h * 0.22);
    canvas.drawPath(handle, stroke);

    final bodyLeft = w * 0.16;
    final bodyTop = h * 0.28;
    final bodyW = w * 0.68;
    final bodyH = h * 0.62;
    final radius = w * 0.11;

    canvas.drawLine(Offset(w * 0.32, h * 0.22), Offset(bodyLeft, bodyTop), stroke);
    canvas.drawLine(Offset(w * 0.68, h * 0.22), Offset(bodyLeft + bodyW, bodyTop), stroke);

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(bodyLeft, bodyTop, bodyW, bodyH),
      Radius.circular(radius),
    );
    canvas.drawRRect(body, stroke);

    final center = Offset(w * 0.5, h * 0.57);
    final outer = w * 0.19 * starScale;
    final inner = w * 0.075 * starScale;

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
