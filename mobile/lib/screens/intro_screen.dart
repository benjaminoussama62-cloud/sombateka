import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/premium_theme.dart';
import '../utils/constants.dart';
import '../utils/responsive.dart';
import '../utils/st_web_splash.dart';
import '../widgets/auth_hero_background.dart';
import '../widgets/intro_emoji.dart';
import '../widgets/sombateka_wordmark.dart';
import '../widgets/st_footer_credit.dart';
import '../widgets/st_safe_area.dart';
import 'package:flutter/foundation.dart';

class _IntroSlide {
  const _IntroSlide({
    required this.emoji,
    required this.title,
    required this.body,
    required this.highlights,
  });

  final String emoji;
  final String title;
  final String body;
  final List<String> highlights;
}

/// Introduction SombaTeka — carousel plein écran, puis « Commencer » → écran connexion.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _page = PageController();
  Timer? _autoTimer;
  int _index = 0;

  static const _slides = [
    _IntroSlide(
      emoji: '🛍️',
      title: 'La marketplace de la RDC',
      body:
          'Achetez et vendez mode, tech, maison, véhicules et bien plus — à Kinshasa et dans toute la République.',
      highlights: [
        'Des milliers d\'annonces dans les 26 provinces',
        'Recherche par catégorie, prix et localisation',
        'Particuliers et boutiques certifiées réunis',
        'Publiez votre annonce en quelques minutes',
      ],
    ),
    _IntroSlide(
      emoji: '🔒',
      title: 'Compte sécurisé',
      body: 'Votre identité est protégée dès l\'inscription — connexion simple, rapide et fiable.',
      highlights: [
        'E-mail, téléphone (+243) et mot de passe',
        'Connexion Google ou Apple en un clic',
        'Vérification du compte par e-mail',
        'Finalisez votre profil en toute sécurité',
      ],
    ),
    _IntroSlide(
      emoji: '💬',
      title: 'Achetez en confiance',
      body:
          'Contactez les vendeurs via la messagerie sécurisée. Les boutiques officielles sont vérifiées (KYC) — échangez, convenez, puis rencontrez-vous en toute sérénité.',
      highlights: [
        'Badge « Boutique officielle » sur les fiches certifiées',
        'Messagerie liée à chaque annonce, suivi clair',
        'Conseils de prudence : lieu public, inspection avant paiement',
        'Signalement et centre d\'aide SombaTeka 7j/7',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _startAutoSlide();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (kIsWeb) stHideHtmlSplash();
      });
      if (mounted) IntroEmoji.precacheAll(context);
    });
  }

  void _startAutoSlide() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_page.hasClients) return;
      final next = (_index + 1) % _slides.length;
      _page.animateToPage(next, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    });
  }

  void _onPageChanged(int i) {
    setState(() => _index = i);
    _startAutoSlide();
  }

  void _goWelcome() {
    HapticFeedback.mediumImpact();
    Navigator.pushReplacementNamed(context, AppRoutes.welcome);
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = Responsive.isCompact(context);
    final desktop = Responsive.isDesktopWeb(context);

    return Scaffold(
      body: AuthHeroBackground(
        child: StSafeTop(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(24, desktop ? 20 : 12, 24, compact ? 8 : 10),
                child: Center(
                  child: SombaTekaWordmark(
                    iconSize: desktop ? 68 : (compact ? 50 : 58),
                    fontSize: desktop ? 36 : (compact ? 26 : 30),
                    animate: false,
                  ),
                ),
              ),
              SizedBox(height: compact ? 6 : 10),
              Expanded(
                child: PageView.builder(
                  controller: _page,
                  onPageChanged: _onPageChanged,
                  itemCount: _slides.length,
                  itemBuilder: (_, i) => _slideCard(_slides[i], desktop: desktop, compact: compact),
                ),
              ),
              _dots(),
              Padding(
                padding: EdgeInsets.fromLTRB(24, 12, 24, 4),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: desktop ? 360 : double.infinity),
                    child: FilledButton(
                      onPressed: _goWelcome,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: PremiumTheme.navy,
                        padding: EdgeInsets.symmetric(vertical: desktop ? 16 : 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text(
                        'Commencer',
                        style: PremiumTheme.h1.copyWith(
                          color: PremiumTheme.navy,
                          fontSize: desktop ? 17 : 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const StFooterCredit(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slideCard(_IntroSlide slide, {required bool desktop, required bool compact}) {
    final emojiSize = desktop ? 56.0 : (compact ? 44.0 : 50.0);
    final textMaxWidth = desktop ? 480.0 : 320.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: desktop ? 40 : 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: textMaxWidth),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IntroEmoji(emoji: slide.emoji, size: emojiSize),
                    SizedBox(height: compact ? 14 : 18),
                    Text(
                      slide.title,
                      textAlign: TextAlign.center,
                      style: PremiumTheme.display.copyWith(
                        fontSize: desktop ? 28 : (compact ? 20 : 24),
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: compact ? 8 : 10),
                    Text(
                      slide.body,
                      textAlign: TextAlign.center,
                      style: PremiumTheme.body.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: desktop ? 15 : (compact ? 12 : 13),
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: compact ? 10 : 14),
                    ...slide.highlights.map(
                      (line) => _highlightLine(line, desktop: desktop, compact: compact),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _highlightLine(String line, {required bool desktop, required bool compact}) {
    final bodyStyle = PremiumTheme.body.copyWith(
      color: Colors.white.withValues(alpha: 0.92),
      fontSize: desktop ? 13 : (compact ? 11 : 12),
      height: 1.3,
      fontWeight: FontWeight.w600,
    );
    final bulletSize = desktop ? 16.0 : 14.0;
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 5 : 7),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: desktop ? 420 : 280),
          child: Text.rich(
            TextSpan(
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: IntroEmoji(emoji: '✅', size: bulletSize),
                ),
                TextSpan(text: '  $line', style: bodyStyle),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _dots() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_slides.length, (i) {
          final active = i == _index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: active ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.white.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(8),
            ),
          );
        }),
      ),
    );
  }
}
