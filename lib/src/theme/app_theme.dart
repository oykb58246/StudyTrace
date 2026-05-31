import 'package:flutter/material.dart';

class AppTypography {
  const AppTypography._();

  static const sans = 'StudyTraceSans';
  static const display = 'StudyTraceDisplay';
  static const mono = 'monospace';
  static const fontFallbacks = <String>[
    'PingFang SC',
    'Microsoft YaHei',
    'Noto Sans CJK SC',
    'Noto Sans SC',
    'Source Han Sans SC',
    'Apple Color Emoji',
    'Segoe UI Emoji',
    'Noto Color Emoji',
    'sans-serif',
  ];
  static const monoFallbacks = <String>[
    'JetBrains Mono',
    'Consolas',
    'Menlo',
    'Monaco',
    'PingFang SC',
    'Microsoft YaHei',
    'Noto Sans CJK SC',
    'Apple Color Emoji',
    'Segoe UI Emoji',
    'Noto Color Emoji',
    'monospace',
  ];

  static const regular = FontWeight.w400;
  static const medium = FontWeight.w600;
  static const title = FontWeight.w600;
  static const emphasis = FontWeight.w600;
  static const hero = FontWeight.w700;
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: AppTypography.sans,
    fontFamilyFallback: AppTypography.fontFallbacks,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.studyPrimary,
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
        fontFamily: AppTypography.sans,
        fontFamilyFallback: AppTypography.fontFallbacks,
        fontWeight: AppTypography.title,
        fontSize: 20,
        color: AppColors.ink,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0x1A1D1B4B),
      thickness: 1,
      space: 1,
    ),
    textTheme: _buildTextTheme(base.textTheme, AppColors.ink, AppColors.body),
    primaryTextTheme: _buildTextTheme(
      base.primaryTextTheme,
      AppColors.ink,
      AppColors.body,
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
        fontWeight: AppTypography.regular,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE3E9EF)),
      ),
      textStyle: const TextStyle(
        color: AppColors.ink,
        fontSize: 14,
        fontWeight: AppTypography.medium,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      titleTextStyle: const TextStyle(
        color: AppColors.ink,
        fontSize: 18,
        fontWeight: AppTypography.hero,
      ),
      contentTextStyle: const TextStyle(
        color: AppColors.body,
        fontSize: 14,
        height: 1.5,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      modalBackgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
          fontWeight: AppTypography.emphasis,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: Color(0xFFE3E9EF)),
        textStyle: const TextStyle(
          fontWeight: AppTypography.emphasis,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        textStyle: const TextStyle(
          fontWeight: AppTypography.emphasis,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.ink,
        textStyle: const TextStyle(
          fontWeight: AppTypography.emphasis,
          fontSize: 14,
        ),
      ),
    ),
    splashFactory: InkSparkle.splashFactory,
  );
}

TextTheme _buildTextTheme(TextTheme base, Color titleColor, Color bodyColor) {
  final themed = base.apply(
    fontFamily: AppTypography.sans,
    fontFamilyFallback: AppTypography.fontFallbacks,
    bodyColor: bodyColor,
    displayColor: titleColor,
  );
  return themed.copyWith(
        headlineLarge: themed.headlineLarge?.copyWith(
          fontWeight: AppTypography.hero,
          color: titleColor,
        ),
        headlineMedium: themed.headlineMedium?.copyWith(
          fontWeight: AppTypography.title,
          color: titleColor,
        ),
        titleLarge: themed.titleLarge?.copyWith(
          fontWeight: AppTypography.title,
          color: titleColor,
        ),
        bodyLarge: themed.bodyLarge?.copyWith(
          color: bodyColor,
          height: 1.5,
        ),
        bodyMedium: themed.bodyMedium?.copyWith(
          color: bodyColor,
          height: 1.5,
        ),
      );
}

ThemeData buildDarkAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: AppTypography.sans,
    fontFamilyFallback: AppTypography.fontFallbacks,
    scaffoldBackgroundColor: AppColors.darkBackground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.studyPrimary,
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
        fontFamily: AppTypography.sans,
        fontFamilyFallback: AppTypography.fontFallbacks,
        fontWeight: AppTypography.title,
        fontSize: 20,
        color: AppColors.darkInk,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: Colors.white.withValues(alpha: 0.08),
      thickness: 1,
      space: 1,
    ),
    textTheme: _buildDarkTextTheme(base.textTheme),
    primaryTextTheme: _buildDarkTextTheme(base.primaryTextTheme),
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
        fontWeight: AppTypography.regular,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.darkCard,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      textStyle: const TextStyle(
        color: AppColors.darkInk,
        fontSize: 14,
        fontWeight: AppTypography.medium,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.darkCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      titleTextStyle: const TextStyle(
        color: AppColors.darkInk,
        fontSize: 18,
        fontWeight: AppTypography.hero,
      ),
      contentTextStyle: const TextStyle(
        color: AppColors.darkBody,
        fontSize: 14,
        height: 1.5,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.darkCard,
      modalBackgroundColor: AppColors.darkCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.darkInk,
        foregroundColor: AppColors.darkBackground,
        textStyle: const TextStyle(
          fontWeight: AppTypography.emphasis,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.darkInk,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        textStyle: const TextStyle(
          fontWeight: AppTypography.emphasis,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.darkInk,
        foregroundColor: AppColors.darkBackground,
        surfaceTintColor: Colors.transparent,
        textStyle: const TextStyle(
          fontWeight: AppTypography.emphasis,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.darkInk,
        textStyle: const TextStyle(
          fontWeight: AppTypography.emphasis,
          fontSize: 14,
        ),
      ),
    ),
    splashFactory: InkSparkle.splashFactory,
  );
}

TextTheme _buildDarkTextTheme(TextTheme base) {
  final themed = base.apply(
    fontFamily: AppTypography.sans,
    fontFamilyFallback: AppTypography.fontFallbacks,
    bodyColor: AppColors.darkBody,
    displayColor: AppColors.darkInk,
  );
  return themed.copyWith(
        headlineLarge: themed.headlineLarge?.copyWith(
          fontWeight: AppTypography.hero,
          color: AppColors.darkInk,
        ),
        headlineMedium: themed.headlineMedium?.copyWith(
          fontWeight: AppTypography.title,
          color: AppColors.darkInk,
        ),
        titleLarge: themed.titleLarge?.copyWith(
          fontWeight: AppTypography.title,
          color: AppColors.darkInk,
        ),
        bodyLarge: themed.bodyLarge?.copyWith(
          color: AppColors.darkBody,
          height: 1.5,
        ),
        bodyMedium: themed.bodyMedium?.copyWith(
          color: AppColors.darkBody,
          height: 1.5,
        ),
      );
}

TextStyle appCodeTextStyle({
  required Color color,
  Color? backgroundColor,
  double fontSize = 13,
  double height = 1.5,
}) {
  return TextStyle(
    color: color,
    backgroundColor: backgroundColor,
    fontFamily: AppTypography.mono,
    fontFamilyFallback: AppTypography.monoFallbacks,
    fontSize: fontSize,
    height: height,
  );
}

class AppColors {
  // Light theme colors
  static const background = Color(0xFFEEF1F8);
  static const ink = Color(0xFF1D1B4B);
  static const body = Color(0xFF6F6C90);
  static const muted = Color(0xFF9F9DBA);
  static const studyPrimary = Color(0xFF2F7D78);
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
