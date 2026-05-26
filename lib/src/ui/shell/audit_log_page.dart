import 'package:flutter/material.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/ai_action_record.dart';
import '../../theme/app_theme.dart';
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
        final textColor = isDarkMode ? Colors.white : AppColors.ink;
        final bodyColor = isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;

        return RefreshIndicator(
          onRefresh: () async => controller.notifyListeners(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 94, 22, 124),
            children: [
              Row(
                children: [
                  Text(
                    'AI 操作记录',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (records.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => _clearRecords(context),
                      icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                      label: const Text('清空记录'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFEF6850),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (records.isEmpty)
                GlassCard(
                  color: isDarkMode
                      ? const Color(0xFF242B37).withValues(alpha: 0.9)
                      : null,
                  child: Text(
                    '暂无 AI 操作记录。',
                    style: TextStyle(color: bodyColor, height: 1.55),
                  ),
                )
              else
                ...records.map((record) => _RecordCard(
                      record: record,
                      isDarkMode: isDarkMode,
                      bodyColor: bodyColor,
                      textColor: textColor,
                      onRetry: onRetry,
                    )),
            ],
          ),
        );
      },
    );
  }

  void _clearRecords(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空操作记录'),
        content: const Text('这将清空所有 AI 操作记录，不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              controller.clearActionRecords();
              Navigator.of(ctx).pop();
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF6850)),
            child: const Text('清空'),
          ),
        ],
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
      AiActionStatus.executed => const Color(0xFF4BC4A1),
      AiActionStatus.failed => const Color(0xFFEF6850),
      AiActionStatus.cancelled => const Color(0xFFB0B8CC),
      AiActionStatus.pending => const Color(0xFFF8AA5B),
      AiActionStatus.confirmed => const Color(0xFF7394F9),
    };
    final canRetry = record.status == AiActionStatus.failed &&
        widget.onRetry != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        color: isDarkMode
            ? const Color(0xFF242B37).withValues(alpha: 0.9)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    record.toolId,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
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
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (record.targetTitle != null || record.targetId != null) ...[
              const SizedBox(height: 4),
              Text(
                '目标：${record.targetTitle ?? record.targetId}',
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
                record.errorMessage!,
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
                    color: isDarkMode ? Colors.white38 : Colors.black38,
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                if (canRetry)
                  TextButton.icon(
                    onPressed: _retrying ? null : _retry,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: _retrying
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 14),
                    label: Text(_retrying ? '重试中...' : '重试'),
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
}
