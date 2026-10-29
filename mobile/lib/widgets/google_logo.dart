import 'package:flutter/material.dart';

import 'brand/auth_provider_icon.dart';

/// Rétrocompat — délègue au logo Google SVG officiel.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return AuthProviderIcon(kind: AuthProviderKind.google, size: size);
  }
}
