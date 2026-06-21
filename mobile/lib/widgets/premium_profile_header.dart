import 'package:flutter/material.dart';
import '../theme/premium_theme.dart';
import '../utils/constants.dart';
import 'user_avatar.dart';

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

  @override
  Widget build(BuildContext context) {
    final isOfficial = status == AppStatus.official || status == 'official_seller';
    return Container(
      width: double.infinity,
      decoration: PremiumTheme.heroGradient,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            children: [
              Row(
                children: [
                  Text('Mon profil', style: PremiumTheme.display.copyWith(fontSize: 22)),
                  const Spacer(),
                  IconButton(
                    onPressed: onSettings,
                    icon: const Icon(Icons.settings_rounded, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [PremiumTheme.gold, Color(0xFFF59E0B)]),
                ),
                child: UserAvatar(
                  imageUrl: avatarUrl,
                  name: name,
                  radius: 48,
                  onTap: onAvatarTap,
                  showEditBadge: onAvatarTap != null,
                ),
              ),
              const SizedBox(height: 16),
              Text(name, style: PremiumTheme.display.copyWith(fontSize: 24)),
              const SizedBox(height: 6),
              Text(phone, style: PremiumTheme.body.copyWith(color: Colors.white70)),
              if (city.trim().isNotEmpty)
                Text('$city, RDC', style: PremiumTheme.body.copyWith(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 10),
              if (reviewCount > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ...List.generate(5, (i) {
                      final filled = i < averageRating.round().clamp(0, 5);
                      return Icon(
                        filled ? Icons.star_rounded : Icons.star_border_rounded,
                        color: PremiumTheme.gold,
                        size: 20,
                      );
                    }),
                    const SizedBox(width: 8),
                    Text(
                      '${averageRating.toStringAsFixed(1)} · $reviewCount avis',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
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
