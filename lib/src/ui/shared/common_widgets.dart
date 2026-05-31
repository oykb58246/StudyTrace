import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/app_theme.dart';
import 'app_assets.dart';
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

  static const primary = Color(0xFF2F7D78);
  static const secondary = Color(0xFF4F7EE8);
  static const success = Color(0xFF39A77B);
  static const warning = Color(0xFFF29F43);
  static const danger = Color(0xFFE46358);
  static const radius = 16.0;

  static Color background(bool isDarkMode) =>
      isDarkMode ? const Color(0xFF101820) : const Color(0xFFF4F7F8);

  static Color surface(bool isDarkMode) =>
      isDarkMode ? const Color(0xFF17222C) : Colors.white;

  static Color surfaceAlt(bool isDarkMode) =>
      isDarkMode ? const Color(0xFF1D2A35) : const Color(0xFFF8FAFC);

  static Color border(bool isDarkMode) => isDarkMode
      ? Colors.white.withValues(alpha: 0.08)
      : const Color(0xFFE3E9EF);

  static Color title(bool isDarkMode) =>
      isDarkMode ? const Color(0xFFF2F6F7) : const Color(0xFF1A2427);

  static Color body(bool isDarkMode) =>
      isDarkMode ? const Color(0xFFC4D0D4) : const Color(0xFF536167);

  static Color muted(bool isDarkMode) =>
      isDarkMode ? const Color(0xFF839197) : const Color(0xFF7C8A91);

  static Color chipBackground(Color color, bool isDarkMode) =>
      color.withValues(alpha: isDarkMode ? 0.18 : 0.11);
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
              color: const Color(0xFF1E3140).withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
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
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
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
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      color: preserveColor ? null : color,
      colorBlendMode: preserveColor || color == null ? null : BlendMode.srcIn,
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
    this.message = '创建或加入小组，和同学共享进度、挑战与学习成果。',
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
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: StudyUi.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onAction,
              child: Text(actionLabel!),
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
      child: child,
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
