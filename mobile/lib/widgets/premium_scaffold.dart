import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/premium_theme.dart';
import '../utils/constants.dart';

/// En-tête gradient cohérent sur toute l'app (style marketplace premium).
class PremiumPageHeader extends StatelessWidget {
  const PremiumPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.emoji,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? trailing;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: PremiumTheme.heroGradient,
      child: SafeArea(
        bottom: false,
        minimum: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leading ??
                  IconButton(
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        Navigator.pushReplacementNamed(context, AppRoutes.main);
                      }
                    },
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  ),
              if (emoji != null) ...[
                Container(
                  margin: const EdgeInsets.only(top: 6, right: 10),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(emoji!, style: const TextStyle(fontSize: 22)),
                ),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: PremiumTheme.display.copyWith(fontSize: 22)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: PremiumTheme.body.copyWith(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

/// Scaffold standard SombaTeka — fond surface + contenu scrollable.
class PremiumScreen extends StatelessWidget {
  const PremiumScreen({
    super.key,
    required this.header,
    required this.body,
    this.bottom,
    this.floatingActionButton,
  });

  final Widget header;
  final Widget body;
  final Widget? bottom;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumTheme.surface,
      floatingActionButton: floatingActionButton,
      body: Column(
        children: [
          header,
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: bottom,
    );
  }
}

/// Carte blanche avec ombre douce.
class PremiumCard extends StatelessWidget {
  const PremiumCard({super.key, required this.child, this.padding, this.onTap});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: PremiumTheme.radiusMd,
        boxShadow: PremiumTheme.softShadow,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap!();
        },
        borderRadius: PremiumTheme.radiusMd,
        child: card,
      ),
    );
  }
}

/// Bandeau info sécurité / confiance.
class PremiumTrustBanner extends StatelessWidget {
  const PremiumTrustBanner({super.key, required this.text, this.icon = Icons.verified_user_rounded});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: PremiumTheme.emerald.withValues(alpha: 0.08),
        border: Border.all(color: PremiumTheme.emerald.withValues(alpha: 0.25)),
        borderRadius: PremiumTheme.radiusMd,
      ),
      child: Row(
        children: [
          Icon(icon, color: PremiumTheme.emerald, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: PremiumTheme.label.copyWith(fontSize: 12, color: PremiumTheme.textDark)),
          ),
        ],
      ),
    );
  }
}
