import 'package:flutter/material.dart';

import '../theme/premium_theme.dart';
import '../utils/constants.dart';

/// Styles publication — texte toujours lisible (noir sur fond clair).
class PublishFieldStyles {
  PublishFieldStyles._();

  static TextStyle get label => PremiumTheme.label.copyWith(
        color: PremiumTheme.textDark,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      );

  static TextStyle get hint => TextStyle(color: PremiumTheme.textMuted, fontSize: 14);

  static TextStyle get input => const TextStyle(
        color: PremiumTheme.textDark,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get chipLabel => const TextStyle(
        color: PremiumTheme.textDark,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get chipLabelSelected => const TextStyle(
        color: PremiumTheme.textDark,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      );

  static InputDecoration decoration(String hintText) => InputDecoration(
        hintText: hintText,
        hintStyle: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: PremiumTheme.radiusMd,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: PremiumTheme.radiusMd,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: PremiumTheme.radiusMd,
          borderSide: const BorderSide(color: PremiumTheme.blue, width: 2),
        ),
      );
}
