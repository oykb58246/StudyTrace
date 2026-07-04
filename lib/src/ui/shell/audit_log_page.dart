import 'package:flutter/material.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/ai_action_record.dart';
import '../../services/ai_tool_registry.dart';
import '../../theme/app_theme.dart';
import '../shared/app_assets.dart';
import '../shared/common_widgets.dart';

/// 失败记录的重试回调。由 AppShell 注入实现：将 `AiActionRecord` 重建成
/// `AiAppAction` 再交给全局 executor 执行。
typedef OnRetryRecord = Future<void> Function(AiActionRecord record);

class AuditLogPage extends StatelessWidget {
  const AuditLogPage({
    super.key,
    required this.isDarkMode,
    required this.controller,
    this.onRetry,
  });

  final bool isDarkMode;
  final AppDataController controller;
  final OnRetryRecord? onRetry;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final records = controller.recentActionRecords.reversed.toList();
        final textColor = StudyUi.title(isDarkMode);
        final bodyColor = StudyUi.body(isDarkMode);

        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 124),
            children: [
              _AuditHero(
                records: records,
                isDarkMode: isDarkMode,
                onClear: records.isEmpty ? null : () => _clearRecords(context),
              ),
              const SizedBox(height: 12),
              _AuditModeSwitch(isDarkMode: isDarkMode),
              const SizedBox(height: 16),
              if (records.isEmpty)
                const StudyEmptyState(
                  asset: AppAssets.uiRefreshFeatureAssistant,
                  title: '暂无整理记录',
                  message: '用学习整理保存任务、闪卡、笔记或学迹后，过程会显示在这里，方便回看和重试。',
                  compact: true,
                )
              else
                ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 10),
                    child: Text(
                      '最近整理',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: AppTypography.title,
                      ),
                    ),
                  ),
                  ...records.map((record) => _RecordCard(
                        record: record,
                        isDarkMode: isDarkMode,
                        bodyColor: bodyColor,
                        textColor: textColor,
                        onRetry: onRetry,
                      )),
                ],
              const SizedBox(height: 14),
              _AuditSafetyCard(isDarkMode: isDarkMode),
            ],
          ),
        );
      },
    );
  }

  void _clearRecords(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _AuditDangerDialog(
        isDarkMode: isDarkMode,
        title: '清空整理记录',
        message: '这会清空当前设备上的整理历史，不会删除你的学习笔记、任务或闪卡。',
        confirmLabel: '清空',
        onConfirm: () {
          controller.clearActionRecords();
          Navigator.of(ctx).pop();
        },
      ),
    );
  }
}

class _AuditModeSwitch extends StatelessWidget {
  const _AuditModeSwitch({required this.isDarkMode});

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
            child: _AuditModeItem(
              icon: Icons.history_rounded,
              label: '整理记录',
              selected: true,
              isDarkMode: isDarkMode,
            ),
          ),
          Expanded(
            child: _AuditModeItem(
              icon: Icons.restore_from_trash_rounded,
              label: '回收站',
              selected: false,
              isDarkMode: isDarkMode,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditModeItem extends StatelessWidget {
  const _AuditModeItem({
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
    const accent = Color(0xFF7394F9);
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

class _AuditSafetyCard extends StatelessWidget {
  const _AuditSafetyCard({required this.isDarkMode});

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
            icon: Icons.verified_user_rounded,
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
                  '整理记录只用于回看和重试，你的学习内容仍按原位置保存。',
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

class _AuditHero extends StatelessWidget {
  const _AuditHero({
    required this.records,
    required this.isDarkMode,
    required this.onClear,
  });

  final List<AiActionRecord> records;
  final bool isDarkMode;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF7394F9);
    final done = records
        .where((record) => record.status == AiActionStatus.executed)
        .length;
    final retryable = records
        .where((record) => record.status == AiActionStatus.failed)
        .length;

    return StudyPathHero(
      isDarkMode: isDarkMode,
      accent: accent,
      badge: '记录管理',
      title: '整理记录',
      subtitle: '查看最近整理过什么、保存到哪里，必要时重新处理未完成内容。',
      icon: Icons.manage_history_rounded,
      steps: const ['最近整理', '查看详情', '重试', '清理'],
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StudyPathMetricPill(
                  label: '全部记录',
                  value: '${records.length}',
                  icon: Icons.history_rounded,
                  color: accent,
                  isDarkMode: isDarkMode,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StudyPathMetricPill(
                  label: '已完成',
                  value: '$done',
                  icon: Icons.check_circle_rounded,
                  color: StudyUi.success,
                  isDarkMode: isDarkMode,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StudyPathMetricPill(
                  label: '可重试',
                  value: '$retryable',
                  icon: Icons.refresh_rounded,
                  color: StudyUi.warning,
                  isDarkMode: isDarkMode,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroActionPill(
                  label: '清空记录',
                  icon: Icons.delete_sweep_rounded,
                  accent: const Color(0xFFEF6850),
                  isDarkMode: isDarkMode,
                  onTap: onClear,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroActionPill extends StatelessWidget {
  const _HeroActionPill({
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
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
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

class _RecordCard extends StatefulWidget {
  const _RecordCard({
    required this.record,
    required this.isDarkMode,
    required this.bodyColor,
    required this.textColor,
    this.onRetry,
  });

  final AiActionRecord record;
  final bool isDarkMode;
  final Color bodyColor;
  final Color textColor;
  final OnRetryRecord? onRetry;

  @override
  State<_RecordCard> createState() => _RecordCardState();
}

class _RecordCardState extends State<_RecordCard> {
  bool _retrying = false;

  AiActionRecord get record => widget.record;
  bool get isDarkMode => widget.isDarkMode;
  Color get bodyColor => widget.bodyColor;
  Color get textColor => widget.textColor;

  Future<void> _retry() async {
    final handler = widget.onRetry;
    if (handler == null || _retrying) return;
    setState(() => _retrying = true);
    try {
      await handler(record);
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (record.status) {
      AiActionStatus.executed => StudyUi.success,
      AiActionStatus.failed => StudyUi.danger,
      AiActionStatus.cancelled => const Color(0xFFB0B8CC),
      AiActionStatus.pending => StudyUi.warning,
      AiActionStatus.confirmed => StudyUi.secondary,
    };
    final canRetry = record.status == AiActionStatus.failed &&
        widget.onRetry != null;
    final actionTitle = AiToolRegistry.instance.userFacingLabel(record.toolId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: StudyCard(
        color: StudyUi.surface(isDarkMode)
            .withValues(alpha: isDarkMode ? 0.82 : 0.90),
        borderColor: statusColor.withValues(alpha: isDarkMode ? 0.22 : 0.16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StudyGlassIconNode(
                  icon: _statusIcon(record.status),
                  accent: statusColor,
                  size: 38,
                  iconSize: 17,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    actionTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: AppTypography.title,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    record.statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: AppTypography.title,
                    ),
                  ),
                ),
              ],
            ),
            if (record.targetTitle != null && record.targetTitle!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '整理对象：${record.targetTitle!.trim()}',
                style: TextStyle(color: bodyColor, fontSize: 12),
              ),
            ],
            if (record.resultMessage != null && record.resultMessage!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                record.resultMessage!,
                style: TextStyle(color: bodyColor, fontSize: 12),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (record.errorMessage != null && record.errorMessage!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '未完成：${_friendlyRecordError(record.errorMessage!)}',
                style: const TextStyle(color: Color(0xFFEF6850), fontSize: 12),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  _fmtTime(record.createdAt),
                  style: TextStyle(
                    color: StudyUi.muted(isDarkMode),
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                if (canRetry)
                  _RecordRetryPill(
                    isDarkMode: isDarkMode,
                    isBusy: _retrying,
                    onTap: _retrying ? null : _retry,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _friendlyRecordError(String message) {
    final raw = message.trim();
    final lower = raw.toLowerCase();
    if (raw.isEmpty) return '这次没有整理成功，可以稍后重试';
    if (lower.contains('targetid') ||
        lower.contains('http') ||
        lower.contains('exception') ||
        lower.contains('socket') ||
        lower.contains('server') ||
        raw.contains('服务器') ||
        raw.contains('后端')) {
      return '这次没有整理成功，可以稍后重试';
    }
    if (raw.length > 80) return '${raw.substring(0, 80)}...';
    return raw;
  }

  IconData _statusIcon(AiActionStatus status) {
    return switch (status) {
      AiActionStatus.executed => Icons.check_circle_rounded,
      AiActionStatus.failed => Icons.refresh_rounded,
      AiActionStatus.cancelled => Icons.remove_circle_outline_rounded,
      AiActionStatus.pending => Icons.hourglass_top_rounded,
      AiActionStatus.confirmed => Icons.task_alt_rounded,
    };
  }
}

class _RecordRetryPill extends StatelessWidget {
  const _RecordRetryPill({
    required this.isDarkMode,
    required this.isBusy,
    required this.onTap,
  });

  final bool isDarkMode;
  final bool isBusy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const accent = StudyUi.warning;
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.54 : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: StudyUi.chipBackground(accent, isDarkMode),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: accent.withValues(alpha: isDarkMode ? 0.24 : 0.18),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isBusy)
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                )
              else
                const Icon(Icons.refresh_rounded, color: accent, size: 14),
              const SizedBox(width: 5),
              Text(
                isBusy ? '重试中' : '重试',
                style: const TextStyle(
                  color: accent,
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

class _AuditDangerDialog extends StatelessWidget {
  const _AuditDangerDialog({
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
                  icon: Icons.delete_sweep_rounded,
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
                  child: _AuditDialogActionPill(
                    label: '取消',
                    color: StudyUi.pathBlue,
                    isDarkMode: isDarkMode,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AuditDialogActionPill(
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

class _AuditDialogActionPill extends StatelessWidget {
  const _AuditDialogActionPill({
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
