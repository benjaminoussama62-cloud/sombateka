import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/premium_theme.dart';

/// Fond pour welcome / auth / splash — paint statique frame 0, orbes ensuite.
class AuthHeroBackground extends StatefulWidget {
  const AuthHeroBackground({super.key, this.child});

  final Widget? child;

  @override
  State<AuthHeroBackground> createState() => _AuthHeroBackgroundState();
}

class _AuthHeroBackgroundState extends State<AuthHeroBackground>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;
  bool _animate = false;

  @override
  void initState() {
    super.initState();
    // Premier paint sans AnimationController.repeat() — évite frame jank + écran « vide ».
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))
        ..repeat();
      setState(() => _animate = true);
    });
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: _animate && _ctrl != null
              ? AnimatedBuilder(
                  animation: _ctrl!,
                  builder: (_, __) => _layers(_ctrl!.value * 2 * math.pi),
                )
              : _layers(0),
        ),
        if (widget.child != null) Positioned.fill(child: widget.child!),
      ],
    );
  }

  Widget _layers(double t) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF13295E),
                PremiumTheme.homeHeaderColor,
                Color(0xFF0A1436),
              ],
            ),
          ),
        ),
        Positioned(
          top: -60 + math.sin(t) * 18,
          left: -40 + math.cos(t * 0.7) * 12,
          child: _orb(220, PremiumTheme.blue.withValues(alpha: 0.28)),
        ),
        Positioned(
          bottom: 40 + math.cos(t * 0.9) * 20,
          right: -70 + math.sin(t * 0.5) * 16,
          child: _orb(260, PremiumTheme.emerald.withValues(alpha: 0.18)),
        ),
        Positioned(
          top: 120 + math.sin(t * 1.2) * 10,
          left: 40,
          child: _orb(90, Colors.white.withValues(alpha: 0.08)),
        ),
      ],
    );
  }

  Widget _orb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}
