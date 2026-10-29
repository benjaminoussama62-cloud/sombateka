import 'package:flutter/material.dart';

/// Crédit développeur — toujours en bas des écrans d'accueil / intro.
class StFooterCredit extends StatelessWidget {
  const StFooterCredit({super.key});

  static const label = 'devalpha1';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 10),
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: Colors.white.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}
