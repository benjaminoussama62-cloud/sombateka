import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/premium_theme.dart';
import '../utils/constants.dart';
import '../widgets/sombateka_wordmark.dart';

class _WelcomeSlide {
  const _WelcomeSlide({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
  });

  final IconData icon;
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
      icon: Icons.storefront_rounded,
      title: 'Votre marketplace RDC',
      body:
          'Des milliers d\'annonces près de chez vous : mode, tech, maison, véhicules et bien plus.',
      accent: PremiumTheme.gold,
    ),
    _WelcomeSlide(
      icon: Icons.account_balance_wallet_rounded,
      title: 'Mobile Money intégré',
      body:
          'Payez en confiance avec MTN, Orange et Moov. Reversement vendeur sécurisé dès le lendemain.',
      accent: PremiumTheme.emerald,
    ),
    _WelcomeSlide(
      icon: Icons.verified_user_rounded,
      title: 'Vendeurs certifiés',
      body:
          'Boutiques officielles vérifiées, remise par QR et messagerie directe après chaque achat.',
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
          Positioned(top: -80, right: -40, child: _orb(200, PremiumTheme.gold.withValues(alpha: 0.15))),
          Positioned(bottom: 120, left: -60, child: _orb(180, PremiumTheme.emerald.withValues(alpha: 0.12))),
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Center(
                      child: SombaTekaWordmark(iconSize: 64, fontSize: 34, animate: true),
                    ),
                  ),
                  const SizedBox(height: 20),
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
                            label: 'Créer un compte',
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
                            AppStrings.country,
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
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: s.accent.withValues(alpha: 0.2),
                  border: Border.all(color: Colors.white24),
                ),
                child: Icon(s.icon, size: 44, color: Colors.white),
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
              color: i == _index ? PremiumTheme.gold : Colors.white24,
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
