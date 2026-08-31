import 'package:flutter/material.dart';

/// Shared HelpDesk Connect color tokens.
///
/// Build 23 keeps the trusted navy foundation while adding a cyan "signal"
/// layer and warmer operational accents. Screens should use these semantic
/// tokens instead of introducing isolated colors.
class HDCColors {
  HDCColors._();

  // Brand and navigation.
  static const Color primary = Color(0xFF0A2342);
  static const Color primaryDeep = Color(0xFF041426);
  static const Color primarySoft = Color(0xFF12365D);
  static const Color secondary = Color(0xFF1769E0);
  static const Color secondaryDark = Color(0xFF0E4FAE);
  static const Color accent = Color(0xFF28C7F7);
  static const Color signal = Color(0xFF52E0C4);
  static const Color warm = Color(0xFFFFB45A);

  // Backgrounds and surfaces.
  static const Color background = Color(0xFFF2F6FA);
  static const Color backgroundAlt = Color(0xFFE9F0F7);
  static const Color surface = Colors.white;
  static const Color surfaceMuted = Color(0xFFF7F9FC);
  static const Color surfaceStrong = Color(0xFFE8F0F8);
  static const Color surfaceDark = Color(0xFF0B2948);

  // Text.
  static const Color textPrimary = Color(0xFF132A44);
  static const Color textSecondary = Color(0xFF5B6D82);
  static const Color textMuted = Color(0xFF7F8EA1);
  static const Color textLight = Colors.white;

  // Status.
  static const Color success = Color(0xFF168A68);
  static const Color warning = Color(0xFFD77A13);
  static const Color danger = Color(0xFFC93D4B);
  static const Color info = Color(0xFF1769E0);

  // Structure.
  static const Color border = Color(0xFFD8E2EC);
  static const Color borderStrong = Color(0xFFB8C8D8);
  static const Color divider = Color(0xFFE4EBF2);
  static const Color shadow = Color(0x1A071B33);
  static const Color shadowStrong = Color(0x29071B33);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary],
  );

  static const LinearGradient signalGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondary, accent],
  );
}
