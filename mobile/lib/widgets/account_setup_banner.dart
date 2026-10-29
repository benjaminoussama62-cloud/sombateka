import 'package:flutter/material.dart';

import '../theme/premium_theme.dart';
import '../utils/constants.dart';

/// Bandeau invitant à finaliser le compte (téléphone + mot de passe).
class AccountSetupBanner extends StatelessWidget {
  const AccountSetupBanner({
    super.key,
    required this.needsPhone,
    required this.needsPassword,
    required this.onTap,
  });

  final bool needsPhone;
  final bool needsPassword;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final missing = <String>[
      if (needsPhone) 'numéro de téléphone',
      if (needsPassword) 'mot de passe',
    ];
    final label = missing.join(' et ');

    return Material(
      color: const Color(0xFFFFF7ED),
      borderRadius: PremiumTheme.radiusMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: PremiumTheme.radiusMd,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: PremiumTheme.radiusMd,
            border: Border.all(color: const Color(0xFFFDBA74)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFFEA580C), size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Finalisez votre compte',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF9A3412),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ajoutez votre $label pour publier et contacter les acheteurs en toute sécurité.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[800], height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Compléter maintenant →',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
