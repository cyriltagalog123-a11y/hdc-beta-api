import 'package:flutter/material.dart';

import 'hdc_colors.dart';
import 'hdc_spacing.dart';

class HDCTheme {
  HDCTheme._();

  static final ColorScheme _colorScheme = ColorScheme.fromSeed(
    seedColor: HDCColors.secondary,
    brightness: Brightness.light,
    primary: HDCColors.primary,
    onPrimary: HDCColors.textLight,
    secondary: HDCColors.secondary,
    onSecondary: HDCColors.textLight,
    tertiary: HDCColors.accent,
    error: HDCColors.danger,
    surface: HDCColors.surface,
    onSurface: HDCColors.textPrimary,
    outline: HDCColors.border,
    outlineVariant: HDCColors.divider,
  );

  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: _colorScheme,
      scaffoldBackgroundColor: HDCColors.background,
      visualDensity: VisualDensity.standard,
    );

    final textTheme = base.textTheme.copyWith(
      displaySmall: const TextStyle(
        fontSize: 42,
        height: 1.05,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.2,
        color: HDCColors.textPrimary,
      ),
      headlineLarge: const TextStyle(
        fontSize: 32,
        height: 1.12,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.72,
        color: HDCColors.textPrimary,
      ),
      headlineMedium: const TextStyle(
        fontSize: 26,
        height: 1.16,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.42,
        color: HDCColors.textPrimary,
      ),
      titleLarge: const TextStyle(
        fontSize: 20,
        height: 1.22,
        fontWeight: FontWeight.w800,
        color: HDCColors.textPrimary,
      ),
      titleMedium: const TextStyle(
        fontSize: 16,
        height: 1.3,
        fontWeight: FontWeight.w800,
        color: HDCColors.textPrimary,
      ),
      bodyLarge: const TextStyle(
        fontSize: 16,
        height: 1.5,
        color: HDCColors.textPrimary,
      ),
      bodyMedium: const TextStyle(
        fontSize: 14,
        height: 1.48,
        color: HDCColors.textSecondary,
      ),
      bodySmall: const TextStyle(
        fontSize: 12,
        height: 1.42,
        color: HDCColors.textMuted,
      ),
      labelLarge: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.08,
      ),
      labelMedium: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.18,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      canvasColor: HDCColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: HDCColors.primaryDeep,
        foregroundColor: HDCColors.textLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 70,
        titleTextStyle: TextStyle(
          color: HDCColors.textLight,
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.25,
        ),
      ),
      cardTheme: CardThemeData(
        color: HDCColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: HDCColors.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HDCSpacing.radiusMedium),
          side: const BorderSide(color: HDCColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: HDCColors.divider,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: HDCColors.secondary,
          foregroundColor: HDCColors.textLight,
          disabledBackgroundColor: HDCColors.border,
          disabledForegroundColor: HDCColors.textMuted,
          elevation: 0,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: HDCColors.secondary,
          foregroundColor: HDCColors.textLight,
          shadowColor: HDCColors.shadowStrong,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: HDCColors.primary,
          backgroundColor: HDCColors.surface,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          side: const BorderSide(color: HDCColors.borderStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: HDCColors.secondaryDark,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: HDCColors.surfaceInteractive,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        labelStyle: const TextStyle(color: HDCColors.textSecondary),
        floatingLabelStyle: const TextStyle(
          color: HDCColors.secondaryDark,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: const TextStyle(color: HDCColors.textMuted),
        helperStyle: const TextStyle(color: HDCColors.textMuted),
        prefixIconColor: HDCColors.textSecondary,
        suffixIconColor: HDCColors.textSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: HDCColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: HDCColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: HDCColors.focusRing, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: HDCColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: HDCColors.danger, width: 2),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: HDCColors.surfaceInteractive,
        selectedColor: HDCColors.secondary.withValues(alpha: 0.12),
        side: const BorderSide(color: HDCColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HDCSpacing.radiusPill),
        ),
        labelStyle: const TextStyle(
          color: HDCColors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: HDCColors.primaryDeep,
        contentTextStyle: const TextStyle(color: HDCColors.textLight),
        actionTextColor: HDCColors.accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: HDCColors.secondary,
        linearTrackColor: HDCColors.surfaceStrong,
        circularTrackColor: HDCColors.surfaceStrong,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: HDCColors.primaryDeep,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(color: HDCColors.textLight),
      ),
      navigationDrawerTheme: const NavigationDrawerThemeData(
        backgroundColor: HDCColors.primaryDeep,
        surfaceTintColor: Colors.transparent,
        indicatorColor: HDCColors.primarySoft,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: HDCColors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HDCSpacing.radiusLarge),
          side: const BorderSide(color: HDCColors.border),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: HDCColors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      focusColor: HDCColors.focusRing.withValues(alpha: 0.16),
      hoverColor: HDCColors.secondary.withValues(alpha: 0.065),
      splashColor: HDCColors.accent.withValues(alpha: 0.12),
    );
  }
}
