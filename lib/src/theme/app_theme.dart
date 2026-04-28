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

class AppColors {
  static const background = Color(0xFFEEF1F8);
  static const ink = Color(0xFF1D1B4B);
  static const body = Color(0xFF6F6C90);
  static const muted = Color(0xFF9F9DBA);
  static const accent = Color(0xFFF77D8E);
  static const accentDeep = Color(0xFF8B2192);
  static const accentLight = Color(0xFFEF6850);
  static const shell = Color(0xFF17203A);
  static const surface = Color(0xFFF7F8FC);
}
