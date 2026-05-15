import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF6C63FF);
  static const primaryDark = Color(0xFF4B44CC);
  static const secondary = Color(0xFF00D4AA);
  static const error = Color(0xFFFF4D6D);
  static const warning = Color(0xFFFFB703);
  static const background = Color(0xFF0F0F1A);
  static const surface = Color(0xFF1A1A2E);
  static const surfaceVariant = Color(0xFF252540);
  static const onPrimary = Color(0xFFFFFFFF);
  static const onBackground = Color(0xFFE8E8F0);
  static const onSurface = Color(0xFFB0B0C8);
}

ThemeData buildAppTheme() {
  const colorScheme = ColorScheme.dark(
    primary: AppColors.primary,
    secondary: AppColors.secondary,
    error: AppColors.error,
    background: AppColors.background,
    surface: AppColors.surface,
    onPrimary: AppColors.onPrimary,
    onBackground: AppColors.onBackground,
    onSurface: AppColors.onSurface,
  );

  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.onBackground,
      elevation: 0,
      centerTitle: false,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    cardTheme: CardTheme(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
