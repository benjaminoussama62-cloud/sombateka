import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Fournisseur d'authentification (logos officiels SVG).
enum AuthProviderKind { google, apple, email }

class AuthProviderIcon extends StatelessWidget {
  const AuthProviderIcon({
    super.key,
    required this.kind,
    this.size = 22,
    this.color,
  });

  final AuthProviderKind kind;
  final double size;
  /// Couleur du logo Apple (blanc sur fond noir, noir sur fond clair).
  final Color? color;

  static String _asset(AuthProviderKind k) => switch (k) {
        AuthProviderKind.google => 'assets/brands/google.svg',
        AuthProviderKind.apple => 'assets/brands/apple.svg',
        AuthProviderKind.email => 'assets/brands/email.svg',
      };

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      _asset(kind),
      width: size,
      height: size,
      colorFilter: kind == AuthProviderKind.apple && color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
      placeholderBuilder: (_) => SizedBox(width: size, height: size),
      errorBuilder: (_, __, ___) => Icon(
        switch (kind) {
          AuthProviderKind.google => Icons.g_mobiledata_rounded,
          AuthProviderKind.apple => Icons.apple,
          AuthProviderKind.email => Icons.mail_outline_rounded,
        },
        size: size,
        color: color ?? (kind == AuthProviderKind.apple ? Colors.white : const Color(0xFF4285F4)),
      ),
    );
  }
}

/// Libellés conformes aux guidelines Google / Apple.
String authProviderLabel(AuthProviderKind kind, {bool compact = false}) {
  return switch (kind) {
    AuthProviderKind.google => compact ? 'Google' : 'Continuer avec Google',
    AuthProviderKind.apple => compact ? 'Apple' : 'Continuer avec Apple',
    AuthProviderKind.email => compact ? 'E-mail' : 'Continuer avec e-mail',
  };
}

AuthProviderKind? authProviderFromName(String name) {
  return switch (name) {
    'google' => AuthProviderKind.google,
    'apple' => AuthProviderKind.apple,
    'email' => AuthProviderKind.email,
    _ => null,
  };
}
