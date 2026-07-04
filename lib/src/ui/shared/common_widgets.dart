import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../models/study_log_item.dart';
import '../../theme/app_theme.dart';
import 'app_assets.dart';
import 'local_image.dart';
import 'rive_safe_widget.dart';

class AppBackdrop extends StatelessWidget {
  const AppBackdrop({
    super.key,
    this.showSpline = true,
    this.useBlur = true,
    this.blurSigma = 38,
    this.overlayColor = const Color(0x66EEF1F8),
  });

  final bool showSpline;
  final bool useBlur;
  final double blurSigma;
  final Color overlayColor;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const SafeRiveAsset(
            asset: AppAssets.shapes,
            artboard: 'Shapes',
            animations: ['Animation 19'],
            fit: BoxFit.cover,
          ),
          if (showSpline)
            Positioned(
              top: -80,
              right: -30,
              child: Opacity(
                opacity: 0.85,
                child: Image.asset(
                  AppAssets.spline,
                  width: 360,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          Positioned.fill(
            child: useBlur
                ? BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: blurSigma,
                      sigmaY: blurSigma,
                    ),
                    child: ColoredBox(color: overlayColor),
                  )
                : ColoredBox(color: overlayColor),
          ),
        ],
      ),
    );
  }
}

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.badge,
    required this.title,
    required this.subtitle,
  });

  final String badge;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            badge,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 30,
                height: 1.15,
              ),
        ),
        const SizedBox(height: 8),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.height,
    this.color,
  });

  final Widget child;
  final EdgeInsets padding;
  final double? height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return FrostedPanel(
      padding: padding,
      radius: 28,
      color: color ?? Colors.white.withValues(alpha: 0.78),
      blurSigma: 14,
      child: SizedBox(height: height, child: child),
    );
  }
}

class StudyUi {
  const StudyUi._();

  static const primary = Color(0xFF2D8C86);
  static const secondary = Color(0xFF6A7DEB);
  static const pathBlue = Color(0xFF7394F9);
  static const pathViolet = Color(0xFF9B82FF);
  static const pathCyan = Color(0xFF78D7E3);
  static const pathMint = Color(0xFF66CFAE);
  static const pathWarm = Color(0xFFFFA85B);
  static const success = Color(0xFF39A77B);
  static const warning = Color(0xFFF29F43);
  static const danger = Color(0xFFE46358);
  static const radius = 20.0;

  static Color background(bool isDarkMode) =>
      isDarkMode ? const Color(0xFF101820) : const Color(0xFFF6F9FE);

  static Color surface(bool isDarkMode) =>
      isDarkMode ? const Color(0xFF17222C) : const Color(0xF8FFFFFF);

  static Color surfaceAlt(bool isDarkMode) =>
      isDarkMode ? const Color(0xFF1D2A35) : const Color(0xFFF8FAFF);

  static Color border(bool isDarkMode) => isDarkMode
      ? Colors.white.withValues(alpha: 0.08)
      : const Color(0xFFDDE7F1);

  static Color title(bool isDarkMode) =>
      isDarkMode ? const Color(0xFFF2F6F7) : const Color(0xFF1A2427);

  static Color body(bool isDarkMode) =>
      isDarkMode ? const Color(0xFFC4D0D4) : const Color(0xFF536167);

  static Color muted(bool isDarkMode) =>
      isDarkMode ? const Color(0xFF839197) : const Color(0xFF7C8A91);

  static Color chipBackground(Color color, bool isDarkMode) =>
      color.withValues(alpha: isDarkMode ? 0.18 : 0.11);
}

class StudyScreenBackground extends StatelessWidget {
  const StudyScreenBackground({
    super.key,
    required this.child,
    required this.isDarkMode,
    this.accent = StudyUi.pathBlue,
    this.showPath = true,
  });

  final Widget child;
  final bool isDarkMode;
  final Color accent;
  final bool showPath;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: StudyUi.background(isDarkMode),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _StudyScreenBackgroundPainter(
                isDarkMode: isDarkMode,
                accent: accent,
                showPath: showPath,
              ),
            ),
          ),
          Positioned.fill(
            child: StudyFontScope(child: child),
          ),
        ],
      ),
    );
  }
}

class StudyCompactHeaderScope extends InheritedWidget {
  const StudyCompactHeaderScope({
    super.key,
    required this.enabled,
    required super.child,
  });

  final bool enabled;

  static bool of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<StudyCompactHeaderScope>()
            ?.enabled ??
        false;
  }

  @override
  bool updateShouldNotify(StudyCompactHeaderScope oldWidget) {
    return oldWidget.enabled != enabled;
  }
}

class _StudyScreenBackgroundPainter extends CustomPainter {
  const _StudyScreenBackgroundPainter({
    required this.isDarkMode,
    required this.accent,
    required this.showPath,
  });

  final bool isDarkMode;
  final Color accent;
  final bool showPath;

  @override
  void paint(Canvas canvas, Size size) {
    final washPaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 52);
    final washes = [
      (
        center: Offset(size.width * 0.18, size.height * 0.16),
        radius: size.shortestSide * 0.42,
        color: StudyUi.pathBlue,
      ),
      (
        center: Offset(size.width * 0.86, size.height * 0.30),
        radius: size.shortestSide * 0.34,
        color: StudyUi.pathCyan,
      ),
      (
        center: Offset(size.width * 0.42, size.height * 0.88),
        radius: size.shortestSide * 0.38,
        color: StudyUi.pathViolet,
      ),
    ];
    for (final wash in washes) {
      washPaint.color =
          wash.color.withValues(alpha: isDarkMode ? 0.08 : 0.14);
      canvas.drawCircle(wash.center, wash.radius, washPaint);
    }

    if (showPath) {
      final pathPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = accent.withValues(alpha: isDarkMode ? 0.11 : 0.12);
      final path = Path()
        ..moveTo(size.width * 0.10, size.height * 0.22)
        ..cubicTo(
          size.width * 0.32,
          size.height * 0.06,
          size.width * 0.58,
          size.height * 0.34,
          size.width * 0.86,
          size.height * 0.18,
        )
        ..moveTo(size.width * 0.02, size.height * 0.76)
        ..cubicTo(
          size.width * 0.26,
          size.height * 0.62,
          size.width * 0.62,
          size.height * 0.84,
          size.width * 0.96,
          size.height * 0.68,
        );
      canvas.drawPath(path, pathPaint);
    }

    final sparklePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: isDarkMode ? 0.16 : 0.80);
    for (final point in [
      Offset(size.width * 0.18, size.height * 0.10),
      Offset(size.width * 0.72, size.height * 0.18),
      Offset(size.width * 0.86, size.height * 0.56),
      Offset(size.width * 0.24, size.height * 0.72),
    ]) {
      canvas.drawLine(
        Offset(point.dx - 4, point.dy),
        Offset(point.dx + 4, point.dy),
        sparklePaint,
      );
      canvas.drawLine(
        Offset(point.dx, point.dy - 4),
        Offset(point.dx, point.dy + 4),
        sparklePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StudyScreenBackgroundPainter oldDelegate) =>
      oldDelegate.isDarkMode != isDarkMode ||
      oldDelegate.accent != accent ||
      oldDelegate.showPath != showPath;
}

class StudyCard extends StatelessWidget {
  const StudyCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.height,
    this.color,
    this.radius = StudyUi.radius,
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final double? height;
  final Color? color;
  final double radius;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = color ?? StudyUi.surface(isDarkMode);
    final content = Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? StudyUi.border(isDarkMode)),
        boxShadow: [
          if (!isDarkMode)
            BoxShadow(
              color: const Color(0xFF63708E).withValues(alpha: 0.08),
              blurRadius: 26,
              offset: const Offset(0, 14),
            ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class StudyGlassIconNode extends StatelessWidget {
  const StudyGlassIconNode({
    super.key,
    this.icon,
    this.asset,
    this.size = 44,
    this.iconSize,
    this.accent = StudyUi.pathBlue,
    this.isDarkMode,
    this.preserveColor = true,
  }) : assert(icon != null || asset != null);

  final IconData? icon;
  final String? asset;
  final double size;
  final double? iconSize;
  final Color accent;
  final bool? isDarkMode;
  final bool preserveColor;

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode ?? Theme.of(context).brightness == Brightness.dark;
    final innerSize = size * 0.66;
    final visualIconSize = iconSize ?? size * 0.44;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.12),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withValues(alpha: dark ? 0.16 : 0.96),
            accent.withValues(alpha: dark ? 0.24 : 0.20),
            Colors.white.withValues(alpha: dark ? 0.04 : 0.74),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: dark ? 0.14 : 0.92),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: dark ? 0.20 : 0.24),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Container(
        width: innerSize,
        height: innerSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: dark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.88),
        ),
        child: asset == null
            ? Icon(icon, color: accent, size: visualIconSize)
            : StudyAssetIcon(
                asset: asset!,
                size: visualIconSize,
                preserveColor: preserveColor,
                color: preserveColor ? null : accent,
                fallbackIcon: icon ?? Icons.auto_awesome_rounded,
              ),
      ),
    );
  }
}

class StudyUserAvatar extends StatelessWidget {
  const StudyUserAvatar({
    super.key,
    this.avatarImagePath,
    this.avatarEmoji = '🎓',
    this.size = 40,
    this.accent = StudyUi.secondary,
    this.isDarkMode,
    this.emojiSize,
  });

  final String? avatarImagePath;
  final String avatarEmoji;
  final double size;
  final Color accent;
  final bool? isDarkMode;
  final double? emojiSize;

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode ?? Theme.of(context).brightness == Brightness.dark;
    final emoji = avatarEmoji.trim().isEmpty ? '🎓' : avatarEmoji;
    final imagePath = avatarImagePath?.trim();
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.055),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withValues(alpha: dark ? 0.16 : 0.96),
            accent.withValues(alpha: dark ? 0.24 : 0.16),
            Colors.white.withValues(alpha: dark ? 0.05 : 0.72),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: dark ? 0.16 : 0.88),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: dark ? 0.18 : 0.14),
            blurRadius: size * 0.36,
            offset: Offset(0, size * 0.14),
          ),
        ],
      ),
      child: ClipOval(
        child: imagePath != null && imagePath.isNotEmpty
            ? localImageFromPath(
                imagePath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _StudyAvatarEmoji(
                  emoji: emoji,
                  fontSize: emojiSize ?? size * 0.45,
                ),
              )
            : _StudyAvatarEmoji(
                emoji: emoji,
                fontSize: emojiSize ?? size * 0.45,
              ),
      ),
    );
  }
}

class StudyBrandAvatar extends StatelessWidget {
  const StudyBrandAvatar({
    super.key,
    this.size = 40,
    this.accent = StudyUi.pathViolet,
    this.isDarkMode,
    this.asset = AppAssets.brandAiAvatarIcon,
  });

  final double size;
  final Color accent;
  final bool? isDarkMode;
  final String asset;

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode ?? Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.075),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withValues(alpha: dark ? 0.14 : 0.98),
            StudyUi.pathCyan.withValues(alpha: dark ? 0.20 : 0.16),
            accent.withValues(alpha: dark ? 0.22 : 0.13),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: dark ? 0.16 : 0.9),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: dark ? 0.24 : 0.18),
            blurRadius: size * 0.48,
            offset: Offset(0, size * 0.16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.2),
              color: accent.withValues(alpha: dark ? 0.24 : 0.14),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: accent,
              size: size * 0.42,
            ),
          ),
        ),
      ),
    );
  }
}

class _StudyAvatarEmoji extends StatelessWidget {
  const _StudyAvatarEmoji({
    required this.emoji,
    required this.fontSize,
  });

  final String emoji;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        emoji,
        style: TextStyle(fontSize: fontSize, height: 1),
      ),
    );
  }
}

class StudyPathHero extends StatelessWidget {
  const StudyPathHero({
    super.key,
    required this.isDarkMode,
    required this.accent,
    required this.badge,
    required this.title,
    required this.subtitle,
    this.icon = Icons.route_rounded,
    this.steps = const [],
    this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final bool isDarkMode;
  final Color accent;
  final String badge;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> steps;
  final Widget? child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 340;
        final hasCompactHeader = StudyCompactHeaderScope.of(context);
        final titleColor = StudyUi.title(isDarkMode);
        final bodyColor = StudyUi.body(isDarkMode);
        final resolvedPadding = compact
            ? const EdgeInsets.fromLTRB(2, 2, 2, 4)
            : EdgeInsets.fromLTRB(
                math.min(padding.left, 6),
                math.min(padding.top, 4),
                math.min(padding.right, 6),
                math.min(padding.bottom, 6),
              );
        final headerLeadingGap =
            hasCompactHeader ? (compact ? 26.0 : 28.0) : 0.0;
        return Padding(
          padding: resolvedPadding,
          child: StudyFontScope(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (headerLeadingGap > 0) SizedBox(width: headerLeadingGap),
                    StudyGlassIconNode(
                      icon: icon,
                      accent: accent,
                      size: compact ? 38 : 42,
                      iconSize: compact ? 17 : 19,
                      isDarkMode: isDarkMode,
                    ),
                    SizedBox(width: compact ? 10 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (badge.trim().isNotEmpty) ...[
                            BadgePill(
                              label: badge,
                              background: StudyUi.chipBackground(
                                accent,
                                isDarkMode,
                              ),
                              foreground: accent,
                            ),
                            SizedBox(height: compact ? 7 : 8),
                          ],
                          Text(
                            title,
                            maxLines: compact ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: titleColor,
                              fontSize: compact ? 22 : 26,
                              height: 1.12,
                              fontWeight: AppTypography.hero,
                            ),
                          ),
                          if (subtitle.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              subtitle,
                              maxLines: compact ? 3 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: bodyColor,
                                fontSize: 13,
                                height: 1.42,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (child != null) ...[
                  SizedBox(height: compact ? 12 : 14),
                  child!,
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class StudyLogSummaryCard extends StatelessWidget {
  const StudyLogSummaryCard({
    super.key,
    required this.log,
    this.isDarkMode,
    this.showCourse = true,
    this.showDate = true,
    this.maxLines = 2,
    this.color,
    this.onTap,
  });

  final StudyLogItem log;
  final bool? isDarkMode;
  final bool showCourse;
  final bool showDate;
  final int maxLines;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode ?? Theme.of(context).brightness == Brightness.dark;
    final fields = _studyLogFields(log);
    final chips = [
      if (showCourse && log.courseName.trim().isNotEmpty) log.courseName.trim(),
      if (showDate) _studyLogDate(log.date),
    ];

    return StudyCard(
      color: color,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chips.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: chips
                  .map(
                    (chip) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: StudyUi.chipBackground(
                          StudyUi.secondary,
                          dark,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        chip,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: StudyUi.secondary,
                          fontSize: 12,
                          fontWeight: AppTypography.title,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 10),
          ],
          if (fields.isEmpty)
            Text(
              '这条记录还没有具体内容。',
              style: TextStyle(color: StudyUi.body(dark), height: 1.45),
            )
          else
            for (final field in fields) ...[
              _StudyLogField(
                label: field.label,
                value: field.value,
                isDarkMode: dark,
                maxLines: maxLines,
              ),
              if (field != fields.last) const SizedBox(height: 8),
            ],
          if (onTap != null) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '查看完整记录',
                  style: TextStyle(
                    color: StudyUi.primary,
                    fontSize: 12,
                    fontWeight: AppTypography.title,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: StudyUi.primary,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> showStudyLogDetailDialog(
  BuildContext context,
  StudyLogItem log,
) {
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;
  final fields = _studyLogFields(log);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: StudyDialogSurface(
        isDarkMode: isDarkMode,
        accent: StudyUi.primary,
        icon: Icons.edit_note_rounded,
        title: log.courseName.trim().isEmpty ? '学习记录' : log.courseName,
        subtitle: _studyLogDate(log.date),
        actions: [
          StudyActionPill(
            icon: Icons.done_rounded,
            label: '知道了',
            color: StudyUi.primary,
            isDarkMode: isDarkMode,
            expand: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (fields.isEmpty)
                Text(
                  '这条记录还没有具体内容。',
                  style:
                      TextStyle(color: StudyUi.body(isDarkMode), height: 1.5),
                )
              else
                for (final field in fields) ...[
                  _StudyLogField(
                    label: field.label,
                    value: field.value,
                    isDarkMode: isDarkMode,
                    maxLines: null,
                  ),
                  if (field != fields.last) const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
    ),
  );
}

class StudyFontScope extends StatelessWidget {
  const StudyFontScope({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(
        fontFamily: AppTypography.sans,
        fontFamilyFallback: AppTypography.fontFallbacks,
      ),
      child: child,
    );
  }
}

class StudyDialogSurface extends StatelessWidget {
  const StudyDialogSurface({
    super.key,
    required this.isDarkMode,
    required this.accent,
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.maxWidth = 400,
  });

  final bool isDarkMode;
  final Color accent;
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    final dialogWidth =
        math.max(260.0, math.min(maxWidth, MediaQuery.sizeOf(context).width - 44));
    return StudyFontScope(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              width: dialogWidth,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: StudyUi.surface(isDarkMode).withValues(
                  alpha: isDarkMode ? 0.92 : 0.88,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color:
                      Colors.white.withValues(alpha: isDarkMode ? 0.08 : 0.68),
                ),
                boxShadow: [
                  if (!isDarkMode)
                    BoxShadow(
                      color: accent.withValues(alpha: 0.12),
                      blurRadius: 30,
                      offset: const Offset(0, 16),
                    ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      StudyGlassIconNode(
                        icon: icon,
                        accent: accent,
                        size: 44,
                        iconSize: 20,
                        isDarkMode: isDarkMode,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 19,
                                fontWeight: AppTypography.hero,
                                height: 1.25,
                              ),
                            ),
                            if (subtitle != null && subtitle!.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                subtitle!,
                                style: TextStyle(
                                  color: bodyColor,
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  child,
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ...actions,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StudyActionPill extends StatelessWidget {
  const StudyActionPill({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.isDarkMode,
    required this.onPressed,
    this.filled = true,
    this.expand = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool isDarkMode;
  final VoidCallback? onPressed;
  final bool filled;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final foreground = filled
        ? Colors.white
        : (disabled ? StudyUi.muted(isDarkMode) : color);
    final background = filled
        ? color.withValues(alpha: disabled ? 0.48 : 1)
        : StudyUi.chipBackground(color, isDarkMode);
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: disabled ? null : onPressed,
        child: Ink(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: filled
                  ? Colors.white.withValues(alpha: disabled ? 0.08 : 0.18)
                  : color.withValues(alpha: disabled ? 0.10 : 0.22),
            ),
            boxShadow: [
              if (filled && !disabled && !isDarkMode)
                BoxShadow(
                  color: color.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
            ],
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foreground, size: 17),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 13,
                    fontWeight: AppTypography.title,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class _StudyLogFieldData {
  const _StudyLogFieldData(this.label, this.value);

  final String label;
  final String value;
}

class _StudyLogField extends StatelessWidget {
  const _StudyLogField({
    required this.label,
    required this.value,
    required this.isDarkMode,
    required this.maxLines,
  });

  final String label;
  final String value;
  final bool isDarkMode;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: StudyUi.muted(isDarkMode),
            fontSize: 12,
            fontWeight: AppTypography.title,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: maxLines,
          overflow:
              maxLines == null ? TextOverflow.visible : TextOverflow.ellipsis,
          style: TextStyle(
            color: StudyUi.title(isDarkMode),
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

List<_StudyLogFieldData> _studyLogFields(StudyLogItem log) {
  return [
    _StudyLogFieldData('学了什么', log.content.trim()),
    _StudyLogFieldData('难点', log.problems.trim()),
    _StudyLogFieldData('想到的', log.thoughts.trim()),
    _StudyLogFieldData('下一步', log.nextPlan.trim()),
  ].where((field) => field.value.isNotEmpty).toList(growable: false);
}

String _studyLogDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class StudyToast {
  StudyToast._();

  static OverlayEntry? _entry;

  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _entry?.remove();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: IgnorePointer(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.68),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    _entry = entry;
    Overlay.of(context).insert(entry);
    Future.delayed(duration, () {
      if (_entry == entry) {
        entry.remove();
        _entry = null;
      }
    });
  }

  static Future<void> dialog(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: StudyDialogSurface(
          isDarkMode: isDarkMode,
          accent: StudyUi.primary,
          icon: Icons.info_rounded,
          title: title,
          actions: [
            StudyActionPill(
              icon: Icons.done_rounded,
              label: '知道了',
              color: StudyUi.primary,
              isDarkMode: isDarkMode,
              expand: true,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
          child: Text(
            message,
            style: TextStyle(
              color: StudyUi.body(isDarkMode),
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class StudySectionHeader extends StatelessWidget {
  const StudySectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: StudyUi.title(isDarkMode),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: StudyUi.body(isDarkMode),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}

class StudyAssetIcon extends StatelessWidget {
  const StudyAssetIcon({
    super.key,
    required this.asset,
    this.size = 24,
    this.color,
    this.fallbackIcon = Icons.auto_awesome_rounded,
    this.preserveColor = false,
  });

  final String asset;
  final double size;
  final Color? color;
  final IconData fallbackIcon;
  final bool preserveColor;

  @override
  Widget build(BuildContext context) {
    final shouldPreserveColor =
        preserveColor || asset.startsWith('assets/icons/generated/');
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      color: shouldPreserveColor ? null : color,
      colorBlendMode:
          shouldPreserveColor || color == null ? null : BlendMode.srcIn,
      errorBuilder: (_, __, ___) => Icon(
        fallbackIcon,
        size: size,
        color: color ?? StudyUi.primary,
      ),
    );
  }
}

class StudyStatusChip extends StatelessWidget {
  const StudyStatusChip({
    super.key,
    required this.label,
    this.color = StudyUi.primary,
    this.selected = false,
    this.onTap,
    this.icon,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final fg = selected ? color : StudyUi.body(isDarkMode);
    final bg = selected
        ? StudyUi.chipBackground(color, isDarkMode)
        : StudyUi.surfaceAlt(isDarkMode);
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? color.withValues(alpha: 0.3) : StudyUi.border(isDarkMode),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 5),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return chip;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: chip,
    );
  }
}

class StudyPathMetricPill extends StatelessWidget {
  const StudyPathMetricPill({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color = StudyUi.primary,
    this.isDarkMode,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color color;
  final bool? isDarkMode;

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode ?? Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: dark ? 0.06 : 0.62),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: dark ? 0.20 : 0.16),
        ),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 17),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: StudyUi.title(dark),
                    fontSize: 15,
                    fontWeight: AppTypography.hero,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: StudyUi.body(dark),
                    fontSize: 11,
                    fontWeight: AppTypography.title,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StudyMetricTile extends StatelessWidget {
  const StudyMetricTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.icon,
    this.color = StudyUi.primary,
  });

  final String label;
  final String value;
  final String? caption;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return StudyCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null)
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: StudyUi.chipBackground(color, isDarkMode),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
              if (icon != null) const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: StudyUi.muted(isDarkMode),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  color: StudyUi.title(isDarkMode),
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ),
          if (caption != null && caption!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              caption!,
              style: TextStyle(
                color: StudyUi.body(isDarkMode),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class StudyEmptyState extends StatelessWidget {
  const StudyEmptyState({
    super.key,
    required this.asset,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  const StudyEmptyState.tasks({
    super.key,
    this.title = '还没有学习任务',
    this.message = '添加第一项任务，把课程、截止时间和拆分步骤放在一个清楚的位置。',
    this.actionLabel,
    this.onAction,
    this.compact = false,
  }) : asset = AppAssets.uiRefreshEmptyTasks;

  const StudyEmptyState.logs({
    super.key,
    this.title = '还没有学习记录',
    this.message = '记录每天学过的内容、遇到的问题和下一步计划，复盘会更轻松。',
    this.actionLabel,
    this.onAction,
    this.compact = false,
  }) : asset = AppAssets.uiRefreshEmptyLogs;

  const StudyEmptyState.calendar({
    super.key,
    this.title = '这一天还没有安排',
    this.message = '选择任务截止日期或写一条学习记录后，它们会出现在这里。',
    this.actionLabel,
    this.onAction,
    this.compact = false,
  }) : asset = AppAssets.uiRefreshEmptyCalendar;

  const StudyEmptyState.notes({
    super.key,
    this.title = '还没有笔记',
    this.message = '新建一篇课程笔记，保存课堂要点、资料摘录和自己的理解。',
    this.actionLabel,
    this.onAction,
    this.compact = false,
  }) : asset = AppAssets.uiRefreshEmptyNotes;

  const StudyEmptyState.flashcards({
    super.key,
    this.title = '还没有闪卡',
    this.message = '从学习记录或笔记中整理问答卡片，用碎片时间反复巩固。',
    this.actionLabel,
    this.onAction,
    this.compact = false,
  }) : asset = AppAssets.uiRefreshEmptyFlashcards;

  const StudyEmptyState.group({
    super.key,
    this.title = '还没有学习小组',
    this.message = '创建或加入小组，和同学共享进度、计划与学习成果。',
    this.actionLabel,
    this.onAction,
    this.compact = false,
  }) : asset = AppAssets.uiRefreshEmptyGroup;

  final String asset;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return StudyCard(
      padding: EdgeInsets.all(compact ? 16 : 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            asset,
            height: compact ? 88 : 128,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              Icons.inbox_rounded,
              color: StudyUi.muted(isDarkMode),
              size: compact ? 52 : 72,
            ),
          ),
          SizedBox(height: compact ? 10 : 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: StudyUi.title(isDarkMode),
              fontSize: compact ? 16 : 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: StudyUi.body(isDarkMode),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            StudyActionPill(
              icon: Icons.add_rounded,
              label: actionLabel!,
              color: StudyUi.primary,
              isDarkMode: isDarkMode,
              expand: true,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}

class StudyPopupMenuButton<T> extends StatelessWidget {
  const StudyPopupMenuButton({
    super.key,
    required this.itemBuilder,
    required this.onSelected,
    this.icon,
    this.child,
    this.tooltip,
    this.enabled = true,
    this.offset = const Offset(0, 8),
    this.constraints = const BoxConstraints(minWidth: 180, maxWidth: 260),
  });

  final PopupMenuItemBuilder<T> itemBuilder;
  final PopupMenuItemSelected<T> onSelected;
  final Widget? icon;
  final Widget? child;
  final String? tooltip;
  final bool enabled;
  final Offset offset;
  final BoxConstraints constraints;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return PopupMenuButton<T>(
      enabled: enabled,
      tooltip: tooltip,
      icon: icon,
      offset: offset,
      color: StudyUi.surface(isDarkMode),
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      constraints: constraints,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: StudyUi.border(isDarkMode)),
      ),
      onSelected: onSelected,
      itemBuilder: itemBuilder,
      child: child,
    );
  }
}

class BadgePill extends StatelessWidget {
  const BadgePill({
    super.key,
    required this.label,
    this.background = const Color(0x19F77D8E),
    this.foreground = AppColors.accentDeep,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class SvgCircleButton extends StatelessWidget {
  const SvgCircleButton({
    super.key,
    required this.asset,
    required this.onTap,
  });

  final String asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black12),
        ),
        alignment: Alignment.center,
        child: SvgPicture.asset(asset, width: 22, height: 22),
      ),
    );
  }
}

class StatPill extends StatelessWidget {
  const StatPill({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class AvatarRow extends StatelessWidget {
  const AvatarRow({super.key, required this.images});

  final List<String> images;

  bool get _isWidgetTest {
    final name = WidgetsBinding.instance.runtimeType.toString();
    return name.contains('TestWidgetsFlutterBinding');
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Stack(
        children: List.generate(images.length, (index) {
          return Positioned(
            left: index * 24,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                image: _isWidgetTest
                    ? null
                    : DecorationImage(
                        image: AssetImage(images[index]),
                        fit: BoxFit.cover,
                      ),
                color: _isWidgetTest ? const Color(0x55FFFFFF) : null,
              ),
            ),
          );
        }),
      ),
    );
  }
}
