import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF6C63FF);
  static const primaryLight = Color(0xFF8B84FF);
  static const primaryDark = Color(0xFF4B44CC);
  static const secondary = Color(0xFF00B894);
  static const secondaryDark = Color(0xFF00A884);
  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const success = Color(0xFF10B981);
  static const info = Color(0xFF0EA5E9);
  static const background = Color(0xFFF5F6FC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF0F1FA);
  static const surfaceHighlight = Color(0xFFE8EAF6);
  static const onPrimary = Color(0xFFFFFFFF);
  static const onBackground = Color(0xFF1A1A2E);
  static const onSurface = Color(0xFF64748B);
  static const divider = Color(0xFFE2E4F0);
}

abstract final class AppGradients {
  static const primary = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF9C4DCC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const secondary = LinearGradient(
    colors: [Color(0xFF00B894), Color(0xFF0096C7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const wallet = LinearGradient(
    colors: [Color(0xFF3D3A8C), Color(0xFF1A1760)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const walletCard = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF4A3AB5), Color(0xFF1F1846)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.5, 1.0],
  );

  static const background = LinearGradient(
    colors: [Color(0xFFF5F6FC), Color(0xFFEEF0FA)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const logistics = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF5B52E0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

abstract final class AppShadows {
  static List<BoxShadow> primary = [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.25),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> secondary = [
    BoxShadow(
      color: AppColors.secondary.withValues(alpha: 0.2),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> card = [
    BoxShadow(
      color: const Color(0xFF6C63FF).withValues(alpha: 0.08),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
}

ThemeData buildAppTheme() {
  const colorScheme = ColorScheme.light(
    primary: AppColors.primary,
    secondary: AppColors.secondary,
    error: AppColors.error,
    surface: AppColors.surface,
    onPrimary: AppColors.onPrimary,
    onSurface: AppColors.onSurface,
    onSurfaceVariant: AppColors.onSurface,
  );

  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.onBackground,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w700,
        fontSize: 18,
        color: AppColors.onBackground,
        letterSpacing: -0.3,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 16,
          letterSpacing: 0.2,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 54),
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      labelStyle: const TextStyle(color: AppColors.onSurface, fontSize: 15),
      hintStyle: const TextStyle(color: AppColors.onSurface),
      prefixIconColor: AppColors.onSurface,
      suffixIconColor: AppColors.onSurface,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.divider),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceVariant,
      selectedColor: AppColors.primary.withValues(alpha: 0.12),
      labelStyle: const TextStyle(
        color: AppColors.onBackground,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      side: const BorderSide(color: AppColors.divider),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
      space: 0,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
  );
}
