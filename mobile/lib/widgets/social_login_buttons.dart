import 'package:flutter/material.dart';

/// Boutons Google / Apple adaptés mobile (pleine largeur, zone tactile 52px).
class SocialLoginButtons extends StatelessWidget {
  const SocialLoginButtons({
    super.key,
    required this.onGoogle,
    required this.onApple,
    this.loading = false,
    this.compact = false,
  });

  final VoidCallback? onGoogle;
  final VoidCallback? onApple;
  final bool loading;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SocialButton(
          label: 'Continuer avec Google',
          icon: Icons.g_mobiledata_rounded,
          background: Colors.white,
          foreground: const Color(0xFF1F2937),
          border: const Color(0xFFE5E7EB),
          onTap: loading ? null : onGoogle,
        ),
        SizedBox(height: compact ? 10 : 12),
        _SocialButton(
          label: 'Continuer avec Apple',
          icon: Icons.apple_rounded,
          background: Colors.black,
          foreground: Colors.white,
          border: Colors.black,
          onTap: loading ? null : onApple,
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.border,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final Color border;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foreground, size: 26),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
