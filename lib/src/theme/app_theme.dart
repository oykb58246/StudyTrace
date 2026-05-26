import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.light,
    ),
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: AppColors.ink,
      titleTextStyle: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 20,
        color: AppColors.ink,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0x1A1D1B4B),
      thickness: 1,
      space: 1,
    ),
    textTheme: base.textTheme.copyWith(
      headlineLarge: const TextStyle(
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      headlineMedium: const TextStyle(
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      titleLarge: const TextStyle(
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      bodyLarge: const TextStyle(
        color: AppColors.body,
        height: 1.5,
      ),
      bodyMedium: const TextStyle(
        color: AppColors.body,
        height: 1.5,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      hintStyle: const TextStyle(
        color: AppColors.muted,
        fontWeight: FontWeight.w400,
      ),
    ),
    splashFactory: InkSparkle.splashFactory,
  );
}

ThemeData buildDarkAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBackground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
    ),
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: AppColors.darkInk,
      titleTextStyle: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 20,
        color: AppColors.darkInk,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: Colors.white.withValues(alpha: 0.08),
      thickness: 1,
      space: 1,
    ),
    textTheme: base.textTheme.copyWith(
      headlineLarge: const TextStyle(
        fontWeight: FontWeight.w700,
        color: AppColors.darkInk,
      ),
      headlineMedium: const TextStyle(
        fontWeight: FontWeight.w700,
        color: AppColors.darkInk,
      ),
      titleLarge: const TextStyle(
        fontWeight: FontWeight.w700,
        color: AppColors.darkInk,
      ),
      bodyLarge: const TextStyle(
        color: AppColors.darkBody,
        height: 1.5,
      ),
      bodyMedium: const TextStyle(
        color: AppColors.darkBody,
        height: 1.5,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF242B37),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      hintStyle: const TextStyle(
        color: AppColors.darkMuted,
        fontWeight: FontWeight.w400,
      ),
    ),
    splashFactory: InkSparkle.splashFactory,
  );
}

class AppColors {
  // Light theme colors
  static const background = Color(0xFFEEF1F8);
  static const ink = Color(0xFF1D1B4B);
  static const body = Color(0xFF6F6C90);
  static const muted = Color(0xFF9F9DBA);
  static const accent = Color(0xFFF77D8E);
  static const accentDeep = Color(0xFF8B2192);
  static const accentLight = Color(0xFFEF6850);
  static const shell = Color(0xFF17203A);
  static const surface = Color(0xFFF7F8FC);

  // Dark theme colors
  static const darkBackground = Color(0xFF05070D);
  static const darkInk = Color(0xFFE8ECF4);
  static const darkBody = Color(0xFFC2C8D6);
  static const darkMuted = Color(0xFF6B7280);
  static const darkSurface = Color(0xFF141923);
  static const darkCard = Color(0xFF1E2430);

  /// 根据深色模式返回对应颜色
  static Color inkColor(bool isDark) => isDark ? darkInk : ink;
  static Color bodyColor(bool isDark) => isDark ? darkBody : body;
  static Color mutedColor(bool isDark) => isDark ? darkMuted : muted;
  static Color bgColor(bool isDark) => isDark ? darkBackground : background;
  static Color surfaceColor(bool isDark) => isDark ? darkSurface : surface;
  static Color cardColor(bool isDark) => isDark ? darkCard : Colors.white;
}
