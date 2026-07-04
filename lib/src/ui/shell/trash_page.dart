import 'package:flutter/material.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/trash_item.dart';
import '../../theme/app_theme.dart';
import '../shared/app_assets.dart';
import '../shared/common_widgets.dart';

class TrashPage extends StatelessWidget {
  const TrashPage({
    super.key,
    required this.isDarkMode,
    required this.controller,
    this.previewItems,
  });

  final bool isDarkMode;
  final AppDataController controller;
  final List<TrashItem>? previewItems;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final items = previewItems ?? controller.trashItems;
        final textColor = StudyUi.title(isDarkMode);
        final previewOnly = previewItems != null;

        return RefreshIndicator(
          onRefresh: previewOnly ? () async {} : controller.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 124),
            children: [
              _TrashHero(
                items: items,
                isDarkMode: isDarkMode,
                onEmptyAll: items.isEmpty ? null : () => _emptyAll(context),
              ),
              const SizedBox(height: 12),
              _TrashModeSwitch(isDarkMode: isDarkMode),
              const SizedBox(height: 16),
              if (items.isEmpty)
                const StudyEmptyState(
                  asset: AppAssets.uiRefreshFeatureArchive,
                  title: '回收站为空',
                  message: '删除的任务、日志、笔记和闪卡会先放在这里，方便你恢复。',
                  compact: true,
                )
              else
                ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 10),
                    child: Text(
                      '可恢复内容',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: AppTypography.title,
                      ),
                    ),
                  ),
                  ...items.map((item) => _TrashCard(
                        item: item,
                        isDarkMode: isDarkMode,
                        textColor: textColor,
                        controller: controller,
                        previewOnly: previewOnly,
                      )),
                ],
              const SizedBox(height: 14),
              _TrashSafetyCard(isDarkMode: isDarkMode),
            ],
          ),
        );
      },
    );
  }

  void _emptyAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _TrashDangerDialog(
        isDarkMode: isDarkMode,
        title: '清空回收站',
        message: '确定要永久删除回收站中的所有内容吗？删除后不会再进入回收站，也无法恢复。',
        confirmLabel: '清空',
        onConfirm: () {
          if (previewItems == null) {
            controller.emptyTrash();
          }
          Navigator.of(ctx).pop();
          if (previewItems != null) {
            StudyToast.show(context, '预览数据不会修改');
          }
        },
      ),
    );
  }
}

class _TrashModeSwitch extends StatelessWidget {
  const _TrashModeSwitch({required this.isDarkMode});

  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      padding: const EdgeInsets.all(6),
      color: StudyUi.surface(isDarkMode)
          .withValues(alpha: isDarkMode ? 0.76 : 0.86),
      borderColor: Colors.white.withValues(alpha: isDarkMode ? 0.08 : 0.70),
      child: Row(
        children: [
          Expanded(
            child: _TrashModeItem(
              icon: Icons.history_rounded,
              label: '整理记录',
              selected: false,
              isDarkMode: isDarkMode,
            ),
          ),
          Expanded(
            child: _TrashModeItem(
              icon: Icons.restore_from_trash_rounded,
              label: '回收站',
              selected: true,
              isDarkMode: isDarkMode,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrashModeItem extends StatelessWidget {
  const _TrashModeItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.isDarkMode,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF4BC4A1);
    return Container(
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected
            ? StudyUi.chipBackground(accent, isDarkMode)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: selected ? accent : StudyUi.muted(isDarkMode),
            size: 18,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: selected ? StudyUi.title(isDarkMode) : StudyUi.body(isDarkMode),
              fontSize: 13,
              fontWeight: AppTypography.title,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrashSafetyCard extends StatelessWidget {
  const _TrashSafetyCard({required this.isDarkMode});

  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      padding: const EdgeInsets.all(16),
      color: StudyUi.chipBackground(StudyUi.pathCyan, isDarkMode),
      borderColor: StudyUi.pathCyan.withValues(alpha: isDarkMode ? 0.22 : 0.16),
      child: Row(
        children: [
          StudyGlassIconNode(
            icon: Icons.shield_rounded,
            accent: StudyUi.pathCyan,
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
                  '数据安全保护中',
                  style: TextStyle(
                    color: StudyUi.title(isDarkMode),
                    fontSize: 15,
                    fontWeight: AppTypography.title,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '删除内容会先进入回收站，恢复前不会影响其他学习路径。',
                  style: TextStyle(
                    color: StudyUi.body(isDarkMode),
                    fontSize: 12,
                    height: 1.4,
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

class _TrashHero extends StatelessWidget {
  const _TrashHero({
    required this.items,
    required this.isDarkMode,
    required this.onEmptyAll,
  });

  final List<TrashItem> items;
  final bool isDarkMode;
  final VoidCallback? onEmptyAll;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF4BC4A1);
    final typeCount = items.map((item) => item.entityTypeLabel).toSet().length;

    return StudyPathHero(
      isDarkMode: isDarkMode,
      accent: accent,
      badge: '恢复管理',
      title: '回收站',
      subtitle: '找回误删的学习内容，确认不再需要时再安静清理。',
      icon: Icons.restore_from_trash_rounded,
      steps: const ['暂存', '查看', '恢复', '清理'],
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StudyPathMetricPill(
                  label: '可恢复',
                  value: '${items.length}',
                  icon: Icons.restore_rounded,
                  color: accent,
                  isDarkMode: isDarkMode,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StudyPathMetricPill(
                  label: '类型',
                  value: '$typeCount',
                  icon: Icons.category_rounded,
                  color: StudyUi.pathCyan,
                  isDarkMode: isDarkMode,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _TrashActionPill(
            label: '清空回收站',
            icon: Icons.delete_forever_rounded,
            accent: const Color(0xFFEF6850),
            isDarkMode: isDarkMode,
            onTap: onEmptyAll,
          ),
        ],
      ),
    );
  }
}

class _TrashActionPill extends StatelessWidget {
  const _TrashActionPill({
    required this.label,
    required this.icon,
    required this.accent,
    required this.isDarkMode,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final bool isDarkMode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.52 : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: StudyUi.chipBackground(accent, isDarkMode),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: accent.withValues(alpha: disabled ? 0.10 : 0.22),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: disabled ? StudyUi.muted(isDarkMode) : accent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: disabled
                        ? StudyUi.muted(isDarkMode)
                        : StudyUi.title(isDarkMode),
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
  }
}

class _TrashCard extends StatelessWidget {
  const _TrashCard({
    required this.item,
    required this.isDarkMode,
    required this.textColor,
    required this.controller,
    required this.previewOnly,
  });

  final TrashItem item;
  final bool isDarkMode;
  final Color textColor;
  final AppDataController controller;
  final bool previewOnly;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: StudyCard(
        color: StudyUi.surface(isDarkMode)
            .withValues(alpha: isDarkMode ? 0.82 : 0.90),
        borderColor: const Color(0xFF4BC4A1).withValues(alpha: 0.16),
        child: Column(
          children: [
            Row(
              children: [
                StudyGlassIconNode(
                  icon: Icons.inventory_2_rounded,
                  accent: const Color(0xFF4BC4A1),
                  size: 42,
                  iconSize: 18,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFEF6850).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.entityTypeLabel,
                            style: const TextStyle(
                              color: Color(0xFFEF6850),
                              fontSize: 11,
                              fontWeight: AppTypography.title,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: AppTypography.title,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                        '删除于 ${_fmtTime(item.deletedAt)}',
                        style: TextStyle(
                          color: StudyUi.muted(isDarkMode),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Spacer(),
                _TrashCardAction(
                  icon: Icons.restore_rounded,
                  label: '恢复',
                  color: const Color(0xFF4BC4A1),
                  isDarkMode: isDarkMode,
                  onPressed: () {
                    if (previewOnly) {
                      StudyToast.show(context, '预览数据不会修改');
                      return;
                    }
                    controller.restoreFromTrash(item.id);
                  },
                ),
                const SizedBox(width: 8),
                _TrashCardAction(
                  icon: Icons.delete_forever_rounded,
                  label: '永久删除',
                  color: const Color(0xFFEF6850),
                  isDarkMode: isDarkMode,
                  onPressed: () => _deletePermanently(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _deletePermanently(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _TrashDangerDialog(
        isDarkMode: isDarkMode,
        title: '永久删除「${item.title}」',
        message: '删除后不会再进入回收站，也无法恢复。',
        confirmLabel: '删除',
        onConfirm: () {
          if (!previewOnly) {
            controller.deleteTrashItemPermanently(item.id);
          }
          Navigator.of(ctx).pop();
          if (previewOnly) {
            StudyToast.show(context, '预览数据不会修改');
          }
        },
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _TrashCardAction extends StatelessWidget {
  const _TrashCardAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDarkMode,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool isDarkMode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: StudyUi.chipBackground(color, isDarkMode),
            borderRadius: BorderRadius.circular(999),
            border:
                Border.all(color: color.withValues(alpha: isDarkMode ? 0.24 : 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: AppTypography.title,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrashDangerDialog extends StatelessWidget {
  const _TrashDangerDialog({
    required this.isDarkMode,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onConfirm,
  });

  final bool isDarkMode;
  final String title;
  final String message;
  final String confirmLabel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: StudyCard(
        padding: const EdgeInsets.all(18),
        color: StudyUi.surface(isDarkMode)
            .withValues(alpha: isDarkMode ? 0.94 : 0.96),
        borderColor: Colors.white.withValues(alpha: isDarkMode ? 0.10 : 0.72),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StudyGlassIconNode(
                  icon: Icons.delete_forever_rounded,
                  accent: StudyUi.danger,
                  size: 42,
                  iconSize: 20,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: StudyUi.title(isDarkMode),
                      fontSize: 17,
                      fontWeight: AppTypography.title,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                color: StudyUi.body(isDarkMode),
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _TrashDialogActionPill(
                    label: '取消',
                    color: StudyUi.pathBlue,
                    isDarkMode: isDarkMode,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TrashDialogActionPill(
                    label: confirmLabel,
                    color: StudyUi.danger,
                    isDarkMode: isDarkMode,
                    filled: true,
                    onTap: onConfirm,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrashDialogActionPill extends StatelessWidget {
  const _TrashDialogActionPill({
    required this.label,
    required this.color,
    required this.isDarkMode,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final Color color;
  final bool isDarkMode;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? Colors.white : color;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? color : StudyUi.chipBackground(color, isDarkMode),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: filled
                ? Colors.white.withValues(alpha: isDarkMode ? 0.12 : 0.36)
                : color.withValues(alpha: isDarkMode ? 0.24 : 0.18),
          ),
        ),
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
    );
  }
}
