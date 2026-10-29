import 'package:flutter/material.dart';

import '../theme/premium_theme.dart';

/// Badge compte vérifié / non vérifié (profils, annonces, chat).
class AccountVerificationBadge extends StatelessWidget {
  const AccountVerificationBadge({
    super.key,
    required this.verified,
    this.compact = false,
    this.lightOnDark = false,
    this.prominent = false,
  });

  final bool verified;
  final bool compact;
  final bool lightOnDark;
  /// Contraste fort sur fond sombre (profil public).
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final Color border;

    if (verified) {
      bg = lightOnDark ? PremiumTheme.emerald.withValues(alpha: 0.28) : const Color(0xFFDCFCE7);
      fg = lightOnDark ? const Color(0xFFBBF7D0) : const Color(0xFF166534);
      border = fg.withValues(alpha: 0.35);
    } else if (prominent || lightOnDark) {
      bg = const Color(0xFFEA580C);
      fg = Colors.white;
      border = Colors.white.withValues(alpha: 0.45);
    } else {
      bg = const Color(0xFFFFF7ED);
      fg = const Color(0xFF9A3412);
      border = const Color(0xFFFDBA74);
    }

    final icon = verified ? Icons.verified_rounded : Icons.warning_amber_rounded;
    final label = verified ? 'Compte vérifié' : 'Compte non vérifié';
    final fontSize = prominent ? 13.0 : (compact ? 9.0 : 11.0);
    final iconSize = prominent ? 18.0 : (compact ? 12.0 : 14.0);
    final hPad = prominent ? 14.0 : (compact ? 6.0 : 10.0);
    final vPad = prominent ? 7.0 : (compact ? 2.0 : 4.0);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(prominent ? 24 : 20),
        border: Border.all(color: border, width: prominent ? 1.5 : 1),
        boxShadow: prominent && !verified
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2))]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: fg),
          SizedBox(width: prominent ? 8 : 4),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: fg,
              letterSpacing: prominent ? 0.2 : 0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bandeau visible sous l'en-tête profil public (mobile + PC).
class AccountVerificationNotice extends StatelessWidget {
  const AccountVerificationNotice({super.key, required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    if (verified) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF97316), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFEA580C), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Compte non vérifié',
                  style: PremiumTheme.h1.copyWith(fontSize: 14, color: const Color(0xFF9A3412)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ce vendeur n\'a pas encore confirmé son compte SombaTeka. Restez prudent avant un paiement hors app.',
                  style: PremiumTheme.body.copyWith(fontSize: 12, height: 1.35, color: const Color(0xFF7C2D12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
