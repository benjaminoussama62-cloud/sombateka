import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design system premium SombaTeka — cohérent sur toute l'app.
class PremiumTheme {
  static const Color navy = Color(0xFF0B1538);
  static const Color navyLight = Color(0xFF152454);
  static const Color blue = Color(0xFF2563EB);
  static const Color blueGlow = Color(0xFF3B82F6);
  static const Color emerald = Color(0xFF10B981);
  static const Color gold = Color(0xFFFBBF24);
  static const Color surface = Color(0xFFF8FAFC);
  static const Color card = Colors.white;
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);

  static TextStyle get display => GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        letterSpacing: -0.5,
      );

  static TextStyle get h1 => GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: textDark,
      );

  static TextStyle get body => GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: textMuted,
      );

  static TextStyle get label => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: textMuted,
        letterSpacing: 0.4,
      );

  static BoxDecoration heroGradient = const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0B1538), Color(0xFF1E3A8A), Color(0xFF2563EB)],
    ),
  );

  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: const Color(0xFF2563EB).withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static BorderRadius get radiusLg => BorderRadius.circular(20);
  static BorderRadius get radiusMd => BorderRadius.circular(14);
}
