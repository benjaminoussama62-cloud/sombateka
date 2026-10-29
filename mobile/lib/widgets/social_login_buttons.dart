import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../utils/responsive.dart';
import 'brand/auth_provider_icon.dart';
import 'brand/auth_provider_chip.dart';

/// Boutons Google / Apple pleine largeur — logos SVG authentiques.
class SocialLoginButtons extends StatelessWidget {
  const SocialLoginButtons({
    super.key,
    required this.onGoogle,
    this.onApple,
    this.loading = false,
    this.compact = false,
    this.showApple = true,
    this.layout = SocialLoginLayout.auto,
  });

  final VoidCallback? onGoogle;
  final VoidCallback? onApple;
  final bool loading;
  final bool compact;
  final bool showApple;
  final SocialLoginLayout layout;

  List<AuthProviderKind> _providers(BuildContext context) {
    final list = <AuthProviderKind>[];
    if (AppConfig.showGoogleLogin && onGoogle != null) list.add(AuthProviderKind.google);
    if (showApple && onApple != null) list.add(AuthProviderKind.apple);
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final providers = _providers(context);
    if (providers.isEmpty) return const SizedBox.shrink();

    final desktop = Responsive.isDesktopWeb(context);
    final useRow = layout == SocialLoginLayout.row || (layout == SocialLoginLayout.auto && desktop && providers.length >= 2);

    if (useRow) {
      return AuthProviderWideRow(
        providers: providers,
        onGoogle: onGoogle,
        onApple: onApple,
        loading: loading,
        cguAccepted: onGoogle != null || onApple != null,
      );
    }

    return Column(
      children: [
        for (var i = 0; i < providers.length; i++) ...[
          if (i > 0) SizedBox(height: compact ? 10 : 12),
          AuthProviderWideButton(
            kind: providers[i],
            onTap: providers[i] == AuthProviderKind.google ? onGoogle : onApple,
            loading: loading,
          ),
        ],
      ],
    );
  }
}

enum SocialLoginLayout { auto, column, row }

/// Providers visibles selon plateforme (accueil + connexion).
List<AuthProviderKind> authProvidersForPlatform(BuildContext context) {
  if (Responsive.isDesktopWeb(context)) {
    return [
      if (AppConfig.showGoogleLogin || kIsWeb) AuthProviderKind.google,
      AuthProviderKind.email,
      if (AppConfig.socialAuthEnabled) AuthProviderKind.apple,
    ];
  }
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    return [
      if (AppConfig.showAppleLogin) AuthProviderKind.apple,
      AuthProviderKind.email,
    ];
  }
  return [
    if (AppConfig.showGoogleLogin) AuthProviderKind.google,
    AuthProviderKind.email,
  ];
}

bool authProvidersIncludeSocial(List<AuthProviderKind> providers) {
  return providers.contains(AuthProviderKind.google) || providers.contains(AuthProviderKind.apple);
}
