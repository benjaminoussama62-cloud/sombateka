import 'package:flutter/material.dart';
import '../theme/premium_theme.dart';
import '../utils/constants.dart';

/// Informations sur les moyens de paiement Mobile Money supportés.
class PaymentSettingsScreen extends StatelessWidget {
  const PaymentSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumTheme.surface,
      appBar: AppBar(
        title: const Text('Paiement Mobile Money'),
        backgroundColor: Colors.white,
        foregroundColor: PremiumTheme.textDark,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _providerCard(
            icon: Icons.phone_android_rounded,
            title: 'MTN Mobile Money',
            color: const Color(0xFFFFCB05),
            details: 'Paiement sécurisé via API MTN. Composez le code USSD affiché après commande.',
          ),
          _providerCard(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Orange Money',
            color: const Color(0xFFFF6600),
            details: 'Paiement sécurisé via API Orange. Validation sur votre téléphone.',
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Comment ça marche', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                SizedBox(height: 10),
                Text(
                  '1. Achetez chez un vendeur officiel certifié\n'
                  '2. Choisissez MTN ou Orange lors du paiement\n'
                  '3. Validez sur votre téléphone (USSD ou lien)\n'
                  '4. Recevez un code de remise pour l\'échange\n'
                  '5. Confirmez la réception pour libérer le paiement',
                  style: TextStyle(color: AppColors.textSecondary, height: 1.5, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Les paiements C2C entre particuliers se font hors application. '
            'Le paiement in-app avec séquestre est réservé aux vendeurs officiels.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _providerCard({
    required IconData icon,
    required String title,
    required Color color,
    required String details,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.2), child: Icon(icon, color: color)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(details, style: const TextStyle(fontSize: 13)),
        trailing: const Icon(Icons.check_circle_rounded, color: AppColors.secondary),
      ),
    );
  }
}
