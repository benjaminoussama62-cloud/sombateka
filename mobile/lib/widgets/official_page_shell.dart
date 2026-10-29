import 'package:flutter/material.dart';

import '../theme/premium_theme.dart';
import '../utils/responsive.dart';
import 'st_safe_area.dart';

/// Coque commune parcours vendeur officiel — retour + largeur confortable PC / mobile.
class OfficialPageShell extends StatelessWidget {
  const OfficialPageShell({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.onBack,
    this.backgroundColor = const Color(0xFFF4F6FB),
    this.maxContentWidth = 880,
    this.bottomBar,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onBack;
  final Color backgroundColor;
  final double maxContentWidth;
  final Widget? bottomBar;

  void _handleBack(BuildContext context) {
    if (onBack != null) {
      onBack!();
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final desktop = Responsive.isDesktopWeb(context);
    final pad = Responsive.screenPadding(context);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: PremiumTheme.heroGradient,
            child: StSafeTop(
              child: Padding(
                padding: EdgeInsets.fromLTRB(desktop ? 12 : 4, 8, desktop ? 24 : 16, 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxContentWidth),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Retour',
                          onPressed: () => _handleBack(context),
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: PremiumTheme.display.copyWith(fontSize: desktop ? 22 : 20, color: Colors.white),
                              ),
                              if (subtitle != null && subtitle!.isNotEmpty)
                                Text(
                                  subtitle!,
                                  style: PremiumTheme.body.copyWith(fontSize: 12, color: Colors.white70),
                                ),
                            ],
                          ),
                        ),
                        if (trailing != null) trailing!,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: pad.horizontal / 2),
                  child: child,
                ),
              ),
            ),
          ),
          if (bottomBar != null)
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: bottomBar!,
              ),
            ),
        ],
      ),
    );
  }
}
