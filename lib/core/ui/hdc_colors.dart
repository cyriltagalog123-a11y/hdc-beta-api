import 'package:flutter/material.dart';

/// Shared HelpDesk Connect color tokens.
///
/// Build 25 keeps the trusted navy foundation while making the product feel
/// more like one connected technical workspace. Screens should use these
/// semantic tokens instead of introducing isolated colors.
class HDCColors {
  HDCColors._();

  // Brand and navigation.
  static const Color primary = Color(0xFF082744);
  static const Color primaryDeep = Color(0xFF031522);
  static const Color primarySoft = Color(0xFF123B63);
  static const Color secondary = Color(0xFF0C6FF2);
  static const Color secondaryDark = Color(0xFF0A4FAB);
  static const Color accent = Color(0xFF22D3FF);
  static const Color electric = Color(0xFF5E8BFF);
  static const Color signal = Color(0xFF4BE5C2);
  static const Color warm = Color(0xFFFFB454);

  // Backgrounds and surfaces.
  static const Color background = Color(0xFFF1F6FA);
  static const Color backgroundAlt = Color(0xFFE8F0F7);
  static const Color backgroundGlow = Color(0xFFDDEEFF);
  static const Color surface = Colors.white;
  static const Color surfaceMuted = Color(0xFFF7FAFC);
  static const Color surfaceStrong = Color(0xFFE7EFF7);
  static const Color surfaceRaised = Color(0xFFFBFDFF);
  static const Color surfaceInteractive = Color(0xFFF0F6FC);
  static const Color surfaceDark = Color(0xFF0A2B48);
  static const Color panelDark = Color(0xFF071F35);

  // Text.
  static const Color textPrimary = Color(0xFF102B43);
  static const Color textSecondary = Color(0xFF526B80);
  static const Color textMuted = Color(0xFF7A8EA1);
  static const Color textLight = Colors.white;

  // Status.
  static const Color success = Color(0xFF13866A);
  static const Color warning = Color(0xFFD97C16);
  static const Color danger = Color(0xFFC93D4B);
  static const Color info = Color(0xFF0C6FF2);

  // Structure.
  static const Color border = Color(0xFFD4E0EA);
  static const Color borderStrong = Color(0xFFAFC3D4);
  static const Color divider = Color(0xFFE2EAF1);
  static const Color focusRing = Color(0xFF22BFEA);
  static const Color shadow = Color(0x18031B2F);
  static const Color shadowStrong = Color(0x2B031B2F);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDeep, primary, secondary],
    stops: [0, 0.58, 1],
  );

  static const LinearGradient signalGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondary, electric, accent],
    stops: [0, 0.58, 1],
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [surfaceRaised, surface, Color(0xFFF4F9FD)],
  );
}
