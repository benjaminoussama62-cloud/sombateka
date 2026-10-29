import 'package:flutter/material.dart';
import '../theme/premium_theme.dart';
import '../utils/constants.dart';
import 'user_avatar.dart';
import 'account_verification_badge.dart';

/// Bandeau profil — bleu opaque, hors scroll, paint forcé (web/PWA).
class PremiumProfileHeader extends StatelessWidget {
  const PremiumProfileHeader({
    super.key,
    required this.name,
    required this.phone,
    required this.city,
    required this.status,
    this.avatarUrl,
    this.onSettings,
    this.onAvatarTap,
    this.averageRating = 0,
    this.reviewCount = 0,
    this.accountVerified = false,
  });

  final String name;
  final String phone;
  final String city;
  final String status;
  final String? avatarUrl;
  final VoidCallback? onSettings;
  final VoidCallback? onAvatarTap;
  final double averageRating;
  final int reviewCount;
  final bool accountVerified;

  static const Color _bg = Color(0xFF0D1B4B);

  @override
  Widget build(BuildContext context) {
    final isOfficial = status == AppStatus.official || status == 'official_seller';
    final topInset = MediaQuery.viewPaddingOf(context).top;

    // Triple couche de couleur : évite le flash blanc CanvasKit/HTML sur web.
    return Material(
      color: _bg,
      elevation: 2,
      shadowColor: Colors.black54,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: _bg),
        child: Container(
          width: double.infinity,
          decoration: PremiumTheme.heroGradient,
          padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text(
                    'Mon profil',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onSettings,
                    icon: const Icon(Icons.settings_rounded, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [PremiumTheme.gold, Color(0xFFF59E0B)]),
                ),
                child: UserAvatar(
                  imageUrl: avatarUrl,
                  name: name,
                  radius: 44,
                  onTap: onAvatarTap,
                  showEditBadge: onAvatarTap != null,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                phone,
                style: const TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500),
              ),
              if (city.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  '$city, RDC',
                  style: const TextStyle(fontSize: 13, color: Colors.white54),
                ),
              ],
              if (reviewCount > 0) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ...List.generate(5, (i) {
                      final filled = i < averageRating.round().clamp(0, 5);
                      return Icon(
                        filled ? Icons.star_rounded : Icons.star_border_rounded,
                        color: PremiumTheme.gold,
                        size: 18,
                      );
                    }),
                    const SizedBox(width: 8),
                    Text(
                      '${averageRating.toStringAsFixed(1)} · $reviewCount avis',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              if (!isOfficial) ...[
                AccountVerificationBadge(verified: accountVerified, lightOnDark: true),
                const SizedBox(height: 8),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isOfficial ? PremiumTheme.gold.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isOfficial ? PremiumTheme.gold : Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isOfficial ? Icons.verified_rounded : Icons.person_rounded,
                      size: 16,
                      color: isOfficial ? PremiumTheme.gold : Colors.white70,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOfficial ? 'Vendeur officiel' : 'Compte particulier',
                      style: TextStyle(
                        color: isOfficial ? PremiumTheme.gold : Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
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
