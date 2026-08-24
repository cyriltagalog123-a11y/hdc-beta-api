import 'package:flutter/material.dart';

import 'hdc_colors.dart';

class HDCTheme {
  HDCTheme._();

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,

    scaffoldBackgroundColor: HDCColors.background,

    colorScheme: ColorScheme.fromSeed(
      seedColor: HDCColors.primary,
      primary: HDCColors.primary,
      secondary: HDCColors.secondary,
      surface: HDCColors.surface,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: HDCColors.primary,
      foregroundColor: HDCColors.textLight,
      elevation: 0,
      centerTitle: false,
    ),

    cardTheme: CardThemeData(
      color: HDCColors.surface,
      elevation: 2,
      shadowColor: HDCColors.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: EdgeInsets.zero,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: HDCColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,

      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 16,
      ),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: HDCColors.border,
        ),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: HDCColors.border,
        ),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: HDCColors.primary,
          width: 2,
        ),
      ),
    ),

    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.bold,
        color: HDCColors.textPrimary,
      ),

      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: HDCColors.textPrimary,
      ),

      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: HDCColors.textPrimary,
      ),

      bodyLarge: TextStyle(
        fontSize: 16,
        color: HDCColors.textPrimary,
      ),

      bodyMedium: TextStyle(
        fontSize: 14,
        color: HDCColors.textSecondary,
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: HDCColors.primary,
      contentTextStyle: const TextStyle(
        color: Colors.white,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}