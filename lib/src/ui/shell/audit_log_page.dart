import 'package:flutter/material.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/ai_action_record.dart';
import '../../services/ai_tool_registry.dart';
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
          onRefresh: () async => controller.notifyListeners(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 94, 22, 124),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'AI操作记录',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                const StudyEmptyState(
                  asset: AppAssets.uiRefreshFeatureAssistant,
                  title: '暂无AI操作记录',
                  message: '通过学习对话让AI执行操作后，记录会显示在这里。',
                  compact: true,
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
        content: const Text('这将清空所有AI操作记录，不可恢复。'),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    actionTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
