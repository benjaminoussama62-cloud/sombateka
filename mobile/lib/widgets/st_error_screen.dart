import 'package:flutter/material.dart';

import '../utils/st_web_splash.dart';
import 'auth_hero_background.dart';
import 'sombateka_wordmark.dart';

/// Écran d'erreur brandé — remplace l'ErrorWidget invisible en release.
/// Un crash de build ne doit JAMAIS laisser un écran navy vide.
class StErrorScreen extends StatelessWidget {
  const StErrorScreen({super.key});

  static void install() {
    ErrorWidget.builder = (_) => const StErrorScreen();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthHeroBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SombaTekaWordmark(iconSize: 64, fontSize: 28, animate: false),
                const SizedBox(height: 20),
                const Text(
                  'Un problème est survenu',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Rechargez la page pour continuer.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: stReloadPage,
                  icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                  label: const Text(
                    'Recharger',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
