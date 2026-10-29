import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/premium_theme.dart';
import '../utils/pwa_install/pwa_install.dart';

/// URL publique de la fiche Google Play.
const kPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=com.sombateka.st';

/// Annonce « Télécharger l'app » — web mobile uniquement.
///
/// Rendu : modale centrée (style desktop), affichée une fois par période
/// de 7 jours. Aucun élément n'est injecté en haut de la page.
///
/// Android → badge officiel Google Play → fiche Play Store.
/// iOS     → badge officiel App Store → note « Bientôt » dans la modale.
class StoreAppBanner extends StatefulWidget {
  const StoreAppBanner({super.key});

  @override
  State<StoreAppBanner> createState() => _StoreAppBannerState();
}

class _StoreAppBannerState extends State<StoreAppBanner> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb || !storeBannerShouldShow()) return;
    // Laisser la page se peindre avant d'ouvrir la modale.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted || _shown) return;
      _shown = true;
      _showStoreModal();
    });
  }

  void _showStoreModal() {
    final isAndroid = pwaIsAndroidWeb();
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fermer',
      barrierColor: Colors.black.withValues(alpha: 0.62),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (ctx, anim, _) => _StoreModal(
        isAndroid: isAndroid,
        onDismiss: () {
          storeBannerDismiss();
          Navigator.of(ctx).pop();
        },
      ),
      transitionBuilder: (ctx, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _StoreModal extends StatelessWidget {
  const _StoreModal({required this.isAndroid, required this.onDismiss});

  final bool isAndroid;
  final VoidCallback onDismiss;

  Future<void> _openPlayStore() async {
    try {
      await launchUrl(
        Uri.parse(kPlayStoreUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: PremiumTheme.navy.withValues(alpha: 0.22),
                    blurRadius: 48,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  children: [
                    // Liseré signature en haut — navy -> or.
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 4,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [PremiumTheme.navy, PremiumTheme.gold],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 30, 24, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _AppIconBadge(),
                          const SizedBox(height: 18),
                          const Text(
                            'L’application SombaTeka',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: PremiumTheme.navy,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isAndroid
                                ? 'Achetez et vendez plus vite : notifications '
                                      'instantanées, messagerie fluide et '
                                      'expérience native.'
                                : 'L’application iPhone arrive très '
                                      'prochainement sur l’App Store. '
                                      'Restez connectés.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: PremiumTheme.navy.withValues(alpha: 0.62),
                              fontSize: 13.5,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _storeBadge(),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: onDismiss,
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  PremiumTheme.navy.withValues(alpha: 0.45),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                            ),
                            child: const Text(
                              'Plus tard',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Material(
                        color: PremiumTheme.navy.withValues(alpha: 0.06),
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: onDismiss,
                          customBorder: const CircleBorder(),
                          child: Padding(
                            padding: const EdgeInsets.all(7),
                            child: Icon(
                              Icons.close_rounded,
                              color: PremiumTheme.navy.withValues(alpha: 0.55),
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _storeBadge() {
    if (isAndroid) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () {
              _openPlayStore();
              onDismiss();
            },
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/stores/google-play-badge-fr.png',
              height: 52,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  _fallbackBadge('Disponible sur Google Play'),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: 0.45,
                child: SvgPicture.asset(
                  'assets/stores/app-store-badge-fr.svg',
                  height: 34,
                  placeholderBuilder: (_) =>
                      _fallbackBadge('Télécharger dans l’App Store'),
                ),
              ),
              const SizedBox(width: 8),
              _soonTag(),
            ],
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          'assets/stores/app-store-badge-fr.svg',
          height: 52,
          placeholderBuilder: (_) =>
              _fallbackBadge('Télécharger dans l’App Store'),
        ),
        const SizedBox(height: 10),
        _soonTag(),
      ],
    );
  }

  Widget _soonTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: PremiumTheme.gold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: PremiumTheme.gold.withValues(alpha: 0.5)),
      ),
      child: const Text(
        'BIENTÔT',
        style: TextStyle(
          color: PremiumTheme.gold,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _fallbackBadge(String label) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AppIconBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: PremiumTheme.navy.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.asset(
          'assets/icon/app_icon.png',
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.shopping_bag_rounded,
            size: 48,
            color: PremiumTheme.navy,
          ),
        ),
      ),
    );
  }
}
