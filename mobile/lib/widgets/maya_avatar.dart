import 'package:flutter/material.dart';

import '../theme/premium_theme.dart';

/// Avatar Maya — assistante.
///
/// Vraie photo professionnelle (femme noire, cahier + stylo) ; le portrait
/// dessiné reste en fallback si l'asset est indisponible.
class MayaAvatar extends StatefulWidget {
  const MayaAvatar({
    super.key,
    this.size = 44,
    this.showPulse = true,
    this.showOnlineDot = true,
  });

  final double size;
  final bool showPulse;
  final bool showOnlineDot;

  @override
  State<MayaAvatar> createState() => _MayaAvatarState();
}

class _MayaAvatarState extends State<MayaAvatar> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _ring;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);
    _ring = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s + (widget.showPulse ? 10 : 0),
      height: s + (widget.showPulse ? 10 : 0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.showPulse)
            AnimatedBuilder(
              animation: _ring,
              builder: (_, __) {
                return Container(
                  width: s + 8 + _ring.value * 6,
                  height: s + 8 + _ring.value * 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: PremiumTheme.emerald.withValues(alpha: 0.25 + _ring.value * 0.2),
                      width: 2,
                    ),
                  ),
                );
              },
            ),
          Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1E293B),
              boxShadow: [
                BoxShadow(
                  color: PremiumTheme.blue.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/maya/maya_assistant.png',
                width: s,
                height: s,
                fit: BoxFit.cover,
                // Fallback : portrait dessiné si l'asset manque (build web
                // partiel, etc.) — jamais de case vide.
                errorBuilder: (_, __, ___) => CustomPaint(
                  size: Size(s, s),
                  painter: _MayaPortraitPainter(),
                ),
              ),
            ),
          ),
          if (widget.showOnlineDot)
            Positioned(
              right: widget.showPulse ? 4 : 0,
              bottom: widget.showPulse ? 4 : 0,
              child: Container(
                width: s * 0.26,
                height: s * 0.26,
                decoration: BoxDecoration(
                  color: PremiumTheme.emerald,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MayaPortraitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Fond doux
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFF334155), const Color(0xFF0F172A)],
      ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Cheveux
    final hair = Paint()..color = const Color(0xFF1A120B);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.34), width: w * 0.62, height: h * 0.38), hair);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.16, h * 0.08, w * 0.68, h * 0.42), Radius.circular(w * 0.2)),
      hair,
    );

    // Visage
    final skin = Paint()..color = const Color(0xFF6B4423);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.38), width: w * 0.44, height: h * 0.36), skin);

    // Yeux
    final eye = Paint()..color = const Color(0xFF1A120B);
    canvas.drawCircle(Offset(w * 0.42, h * 0.37), w * 0.028, eye);
    canvas.drawCircle(Offset(w * 0.58, h * 0.37), w * 0.028, eye);

    // Sourire
    canvas.drawArc(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.43), width: w * 0.14, height: h * 0.08),
      0.1,
      3.0,
      false,
      Paint()
        ..color = const Color(0xFF4A2C14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.018
        ..strokeCap = StrokeCap.round,
    );

    // Veste / blazer
    final jacket = Paint()..color = PremiumTheme.navy;
    final jacketPath = Path()
      ..moveTo(w * 0.12, h * 0.98)
      ..lineTo(w * 0.22, h * 0.52)
      ..lineTo(w * 0.38, h * 0.48)
      ..lineTo(w * 0.5, h * 0.56)
      ..lineTo(w * 0.62, h * 0.48)
      ..lineTo(w * 0.78, h * 0.52)
      ..lineTo(w * 0.88, h * 0.98)
      ..close();
    canvas.drawPath(jacketPath, jacket);

    // Col chemise blanc
    final collar = Paint()..color = Colors.white;
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.5, h * 0.52)
        ..lineTo(w * 0.42, h * 0.62)
        ..lineTo(w * 0.5, h * 0.68)
        ..lineTo(w * 0.58, h * 0.62)
        ..close(),
      collar,
    );

    // Cahier (main gauche)
    final bookRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.08, h * 0.58, w * 0.22, h * 0.28),
      Radius.circular(w * 0.03),
    );
    canvas.drawRRect(bookRect, Paint()..color = Colors.white);
    canvas.drawRRect(
      bookRect,
      Paint()
        ..color = const Color(0xFFCBD5E1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.012,
    );
    final linePaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = w * 0.008;
    for (var i = 0; i < 3; i++) {
      final y = h * 0.64 + i * h * 0.05;
      canvas.drawLine(Offset(w * 0.11, y), Offset(w * 0.27, y), linePaint);
    }

    // Stylo (main droite)
    final penBody = Paint()..color = PremiumTheme.gold;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.72, h * 0.55, w * 0.06, h * 0.22), Radius.circular(w * 0.02)),
      penBody,
    );
    canvas.drawCircle(Offset(w * 0.75, h * 0.54), w * 0.028, Paint()..color = const Color(0xFF1E293B));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.71, h * 0.74, w * 0.08, h * 0.04), Radius.circular(w * 0.015)),
      Paint()..color = const Color(0xFF64748B),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
