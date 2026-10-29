import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/premium_theme.dart';
import 'auth_provider_icon.dart';

/// Bouton compact (accueil) — logo authentique + libellé, adapté mobile / desktop.
class AuthProviderChip extends StatefulWidget {
  const AuthProviderChip({
    super.key,
    required this.kind,
    required this.onTap,
    this.compact = false,
    this.desktop = false,
    this.enabled = true,
  });

  final AuthProviderKind kind;
  final VoidCallback? onTap;
  final bool compact;
  final bool desktop;
  final bool enabled;

  @override
  State<AuthProviderChip> createState() => _AuthProviderChipState();
}

class _AuthProviderChipState extends State<AuthProviderChip> with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1, end: 0.96).animate(CurvedAnimation(parent: _press, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  bool get _isApple => widget.kind == AuthProviderKind.apple;

  @override
  Widget build(BuildContext context) {
    final h = widget.desktop ? 56.0 : (widget.compact ? 48.0 : 52.0);
    final iconSize = widget.desktop ? 24.0 : 20.0;
    final bg = _isApple ? Colors.black : Colors.white;
    final fg = _isApple ? Colors.white : const Color(0xFF1F2937);
    final border = _isApple ? Colors.black87 : Colors.white.withValues(alpha: 0.2);

    return GestureDetector(
      onTapDown: widget.enabled && widget.onTap != null ? (_) => _press.forward() : null,
      onTapUp: widget.enabled && widget.onTap != null ? (_) => _press.reverse() : null,
      onTapCancel: () => _press.reverse(),
      onTap: widget.enabled && widget.onTap != null
          ? () {
              HapticFeedback.lightImpact();
              widget.onTap!();
            }
          : null,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: widget.enabled ? 1 : 0.45,
          child: Container(
            height: h,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(widget.desktop ? 16 : 14),
              border: Border.all(color: border, width: 1.2),
              boxShadow: [
                if (!_isApple)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: widget.desktop ? 16 : 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AuthProviderIcon(
                  kind: widget.kind,
                  size: iconSize,
                  color: _isApple ? Colors.white : null,
                ),
                SizedBox(width: widget.desktop ? 10 : 7),
                Flexible(
                  child: Text(
                    authProviderLabel(widget.kind, compact: true),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: widget.desktop ? 14 : 13,
                      fontWeight: FontWeight.w700,
                      color: fg,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton pleine largeur (écran connexion / inscription).
class AuthProviderWideButton extends StatefulWidget {
  const AuthProviderWideButton({
    super.key,
    required this.kind,
    required this.onTap,
    this.loading = false,
    this.height = 52,
  });

  final AuthProviderKind kind;
  final VoidCallback? onTap;
  final bool loading;
  final double height;

  @override
  State<AuthProviderWideButton> createState() => _AuthProviderWideButtonState();
}

class _AuthProviderWideButtonState extends State<AuthProviderWideButton> with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(vsync: this, duration: const Duration(milliseconds: 90));
    _scale = Tween<double>(begin: 1, end: 0.985).animate(CurvedAnimation(parent: _press, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  bool get _isApple => widget.kind == AuthProviderKind.apple;
  bool get _enabled => widget.onTap != null && !widget.loading;

  @override
  Widget build(BuildContext context) {
    final bg = _isApple ? Colors.black : Colors.white;
    final fg = _isApple ? Colors.white : const Color(0xFF1F2937);
    final border = _isApple ? Colors.black : const Color(0xFFE5E7EB);

    // Un seul gestionnaire de tap (pas GestureDetector + InkWell) — sinon
    // les clics PWA/web sont souvent avalés ou doublés.
    return ScaleTransition(
      scale: _scale,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: _enabled ? 1 : 0.5,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          elevation: _isApple ? 0 : 1,
          shadowColor: Colors.black12,
          child: InkWell(
            onTapDown: _enabled ? (_) => _press.forward() : null,
            onTapUp: _enabled ? (_) => _press.reverse() : null,
            onTapCancel: () => _press.reverse(),
            onTap: _enabled
                ? () {
                    HapticFeedback.lightImpact();
                    widget.onTap!();
                  }
                : null,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              height: widget.height,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border, width: 1.5),
              ),
              child: widget.loading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: _isApple ? Colors.white : PremiumTheme.blue,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AuthProviderIcon(
                          kind: widget.kind,
                          size: 22,
                          color: _isApple ? Colors.white : null,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          authProviderLabel(widget.kind),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: fg,
                            letterSpacing: 0.15,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Grille / rangée de chips avec animation d'entrée décalée.
class AuthProviderChipRow extends StatelessWidget {
  const AuthProviderChipRow({
    super.key,
    required this.providers,
    required this.onProviderTap,
    this.desktop = false,
    this.compact = false,
    this.enabled = true,
    this.staggerController,
  });

  final List<AuthProviderKind> providers;
  final void Function(AuthProviderKind kind)? onProviderTap;
  final bool desktop;
  final bool compact;
  final bool enabled;
  final Animation<double>? staggerController;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < providers.length; i++) ...[
          if (i > 0) SizedBox(width: desktop ? 12 : (compact ? 8 : 10)),
          Expanded(child: _animatedChip(i, providers[i])),
        ],
      ],
    );
  }

  Widget _animatedChip(int index, AuthProviderKind kind) {
    Widget chip = AuthProviderChip(
      kind: kind,
      desktop: desktop,
      compact: compact,
      enabled: enabled,
      onTap: onProviderTap != null ? () => onProviderTap!(kind) : null,
    );
    if (staggerController == null) return chip;
    final start = index * 0.12;
    final end = (start + 0.55).clamp(0.0, 1.0);
    return AnimatedBuilder(
      animation: staggerController!,
      builder: (_, child) {
        final t = Curves.easeOutCubic.transform(
          ((staggerController!.value - start) / (end - start)).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 14),
            child: child,
          ),
        );
      },
      child: chip,
    );
  }
}

/// Rangée horizontale de boutons larges (desktop connexion).
class AuthProviderWideRow extends StatelessWidget {
  const AuthProviderWideRow({
    super.key,
    required this.providers,
    required this.onGoogle,
    this.onApple,
    this.onEmail,
    this.loading = false,
    this.cguAccepted = true,
  });

  final List<AuthProviderKind> providers;
  final VoidCallback? onGoogle;
  final VoidCallback? onApple;
  final VoidCallback? onEmail;
  final bool loading;
  final bool cguAccepted;

  VoidCallback? _handler(AuthProviderKind k) {
    if (!cguAccepted || loading) return null;
    return switch (k) {
      AuthProviderKind.google => onGoogle,
      AuthProviderKind.apple => onApple,
      AuthProviderKind.email => onEmail,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (providers.length <= 1) {
      final k = providers.first;
      return AuthProviderWideButton(kind: k, onTap: _handler(k), loading: loading);
    }
    return Row(
      children: [
        for (var i = 0; i < providers.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: AuthProviderWideButton(
              kind: providers[i],
              onTap: _handler(providers[i]),
              loading: loading,
              height: 50,
            ),
          ),
        ],
      ],
    );
  }
}
