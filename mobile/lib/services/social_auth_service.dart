import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/app_services.dart';
import '../services/data_service.dart';

/// Connexion Google / Apple (mode dev : API /auth/social/login).
class SocialAuthService {
  SocialAuthService._();
  static final instance = SocialAuthService._();

  Future<void> signInWithGoogle(BuildContext context) async {
    await _signIn(
      context,
      provider: 'google',
      title: 'Google',
      icon: Icons.g_mobiledata_rounded,
    );
  }

  Future<void> signInWithApple(BuildContext context) async {
    await _signIn(
      context,
      provider: 'apple',
      title: 'Apple',
      icon: Icons.apple_rounded,
    );
  }

  Future<void> _signIn(
    BuildContext context, {
    required String provider,
    required String title,
    required IconData icon,
  }) async {
    if (!context.mounted) return;

    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottom = MediaQuery.paddingOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Icon(icon, size: 40),
                const SizedBox(height: 12),
                Text(
                  'Connexion $title',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  kIsWeb
                      ? 'Sur iPhone : utilisez Safari. En dev, confirmez votre email.'
                      : 'Confirmez pour créer ou ouvrir votre compte.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nom (optionnel)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: provider == 'apple'
                        ? 'votre@icloud.com'
                        : 'vous@gmail.com',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: () {
                      final email = emailCtrl.text.trim();
                      if (email.isEmpty || !email.contains('@')) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Entrez un email valide')),
                        );
                        return;
                      }
                      Navigator.pop(ctx, true);
                    },
                    child: const Text('Continuer', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (ok != true || !context.mounted) {
      nameCtrl.dispose();
      emailCtrl.dispose();
      return;
    }

    final email = emailCtrl.text.trim();
    final displayName = nameCtrl.text.trim().isNotEmpty
        ? nameCtrl.text.trim()
        : email.split('@').first;
    nameCtrl.dispose();
    emailCtrl.dispose();

    final subject = '$provider:$email';

    await AppServices.instance.auth.socialLogin(
      provider: provider,
      subject: subject,
      email: email,
      displayName: displayName,
    );
    await DataService().refreshUser();
    await DataService().refreshListings();
  }
}
