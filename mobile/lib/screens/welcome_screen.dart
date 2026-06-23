import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/premium_theme.dart';
import '../utils/constants.dart';
import '../widgets/sombateka_wordmark.dart';

class _WelcomeSlide {
  const _WelcomeSlide({
    required this.emoji,
    required this.title,
    required this.body,
    required this.accent,
  });

  final String emoji;
  final String title;
  final String body;
  final Color accent;
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  late final AnimationController _fade;
  late final AnimationController _slide;
  final PageController _page = PageController();
  Timer? _autoTimer;
  int _index = 0;

  static const _slides = [
    _WelcomeSlide(
      emoji: '🛍️',
      title: 'Votre marketplace RDC',
      body: 'Mode, tech, maison, véhicules… Des milliers d\'annonces près de chez vous, particuliers et boutiques pro.',
      accent: PremiumTheme.blue,
    ),
    _WelcomeSlide(
      emoji: '💳',
      title: 'Paiement Mobile Money',
      body: 'Achetez en confiance, séquestre sécurisé et reversement vendeur le lendemain ouvré.',
      accent: PremiumTheme.emerald,
    ),
    _WelcomeSlide(
      emoji: '✅',
      title: 'Boutiques certifiées',
      body: 'Vendeurs officiels vérifiés, remise par QR et messagerie dédiée après chaque commande.',
      accent: Color(0xFF93C5FD),
    ),
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
    _slide = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..forward();
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_page.hasClients) return;
      final next = (_index + 1) % _slides.length;
      _page.animateToPage(
        next,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _onPageChanged(int i) {
    setState(() => _index = i);
    _startAutoSlide();
  }

  void _skipToAuth() {
    HapticFeedback.lightImpact();
    Navigator.pushNamed(context, AppRoutes.auth);
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _fade.dispose();
    _slide.dispose();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(decoration: PremiumTheme.heroGradient),
          Positioned(top: -80, right: -40, child: _orb(200, PremiumTheme.blue.withValues(alpha: 0.18))),
          Positioned(bottom: 120, left: -60, child: _orb(180, PremiumTheme.emerald.withValues(alpha: 0.12))),
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                    child: Row(
                      children: [
                        const Spacer(),
                        TextButton(
                          onPressed: _skipToAuth,
                          child: Text('Passer l\'intro', style: PremiumTheme.label.copyWith(color: Colors.white70)),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Center(
                      child: SombaTekaWordmark(iconSize: 72, fontSize: 36, animate: true),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: PageView.builder(
                      controller: _page,
                      physics: const BouncingScrollPhysics(),
                      onPageChanged: _onPageChanged,
                      itemCount: _slides.length,
                      itemBuilder: (_, i) => _slideCard(_slides[i], i == _index),
                    ),
                  ),
                  _dots(),
                  const SizedBox(height: 20),
                  SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
                      CurvedAnimation(parent: _slide, curve: Curves.easeOutCubic),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          _cta(
                            label: '🚀 Créer un compte',
                            filled: true,
                            onTap: () => Navigator.pushNamed(context, AppRoutes.auth),
                          ),
                          const SizedBox(height: 12),
                          _cta(
                            label: 'J\'ai déjà un compte',
                            filled: false,
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRoutes.auth,
                              arguments: {'mode': 'login'},
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '🇨🇩 ${AppStrings.country}',
                            style: PremiumTheme.label.copyWith(color: Colors.white38, fontSize: 10),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slideCard(_WelcomeSlide s, bool active) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 280),
      opacity: active ? 1 : 0.55,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 280),
        scale: active ? 1 : 0.96,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: s.accent.withValues(alpha: 0.18),
                  border: Border.all(color: Colors.white24, width: 2),
                  boxShadow: [
                    BoxShadow(color: s.accent.withValues(alpha: 0.2), blurRadius: 24, offset: const Offset(0, 8)),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(s.emoji, style: const TextStyle(fontSize: 48)),
              ),
              const SizedBox(height: 24),
              Text(s.title, style: PremiumTheme.display.copyWith(fontSize: 24), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                s.body,
                style: PremiumTheme.body.copyWith(color: Colors.white70, fontSize: 15, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_slides.length, (i) {
        return GestureDetector(
          onTap: () => _page.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == _index ? 28 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == _index ? Colors.white : Colors.white24,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }),
    );
  }

  Widget _cta({required String label, required bool filled, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: filled ? Colors.white : Colors.transparent,
          foregroundColor: filled ? PremiumTheme.navy : Colors.white,
          elevation: filled ? 6 : 0,
          side: filled ? null : const BorderSide(color: Colors.white38),
          shape: RoundedRectangleBorder(borderRadius: PremiumTheme.radiusLg),
        ),
        child: Text(
          label,
          style: PremiumTheme.h1.copyWith(fontSize: 16, color: filled ? PremiumTheme.navy : Colors.white),
        ),
      ),
    );
  }

  Widget _orb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
