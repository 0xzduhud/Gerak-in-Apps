import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFFE86542);
  static const Color secondary = Color(0xFFFD9557);
  static const Color tertiary = Color(0xFFEE2011);
  static const Color neutral = Color(0xFF171132);

  // Turunan dari neutral
  static const Color surface = Color(0xFF221C45);
  static const Color surfaceHigh = Color(0xFF2D2658);
  static const Color outline = Color(0xFF433B73);
  static const Color textPrimary = Color(0xFFF6F1FF);
  static const Color textSecondary = Color(0xFFB9B2D6);
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.neutral,
      secondary: AppColors.secondary,
      onSecondary: AppColors.neutral,
      tertiary: AppColors.tertiary,
      onTertiary: Colors.white,
      error: AppColors.tertiary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      outline: AppColors.outline,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.neutral,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.neutral,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.outline),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.22),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.neutral,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surfaceHigh,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.secondary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        labelStyle: const TextStyle(color: AppColors.secondary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.neutral,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}