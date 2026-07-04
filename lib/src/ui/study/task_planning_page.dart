import 'package:flutter/material.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/study_sub_task_item.dart';
import '../../models/study_task_item.dart';
import '../../theme/app_theme.dart';
import '../shared/common_widgets.dart';

class TaskPlanningPage extends StatelessWidget {
  const TaskPlanningPage({
    super.key,
    required this.isDarkMode,
    required this.controller,
    this.onOpenTasks,
    this.onOpenOverdueTasks,
  });

  final bool isDarkMode;
  final AppDataController controller;
  final VoidCallback? onOpenTasks;
  final VoidCallback? onOpenOverdueTasks;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final tasks = controller.studyTasks;
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final tomorrow = today.add(const Duration(days: 1));
        final weekEnd = today.add(const Duration(days: 7));

        final overdueTasks = tasks
            .where(
              (t) =>
                  t.effectiveStatus != StudyTaskStatus.completed &&
                  t.deadline.isBefore(today),
            )
            .toList()
          ..sort((a, b) => a.deadline.compareTo(b.deadline));
        final todayTasks = tasks
            .where(
              (t) =>
                  t.effectiveStatus != StudyTaskStatus.completed &&
                  !t.deadline.isBefore(today) &&
                  t.deadline.isBefore(tomorrow),
            )
            .toList()
          ..sort((a, b) => a.deadline.compareTo(b.deadline));
        final weekTasks = tasks
            .where(
              (t) =>
                  t.effectiveStatus != StudyTaskStatus.completed &&
                  !t.deadline.isBefore(tomorrow) &&
                  t.deadline.isBefore(weekEnd),
            )
            .toList()
          ..sort((a, b) => a.deadline.compareTo(b.deadline));

        const accent = StudyUi.pathViolet;
        final textColor = StudyUi.title(isDarkMode);
        final bodyColor = StudyUi.body(isDarkMode);
        final openCount = tasks
            .where((t) => t.effectiveStatus != StudyTaskStatus.completed)
            .length;
        final doneCount = tasks.length - openCount;
        final totalProgress =
            tasks.isEmpty ? 0.0 : (doneCount / tasks.length).clamp(0.0, 1.0);
        final focusTask = todayTasks.isNotEmpty
            ? todayTasks.first
            : weekTasks.isNotEmpty
                ? weekTasks.first
                : null;
        final focusLabel = todayTasks.isNotEmpty
            ? '今天先走这一小步'
            : weekTasks.isNotEmpty
                ? '这周先从这里开始'
                : '最近先补一个小任务';
        final focusAction = overdueTasks.isNotEmpty
            ? onOpenOverdueTasks ?? onOpenTasks
            : onOpenTasks;
        final focusActionLabel = overdueTasks.isNotEmpty
            ? '先处理最早截止'
            : focusTask == null
                ? '去任务清单补一项'
                : '打开任务清单';
        final compactHeader = StudyCompactHeaderScope.of(context);

        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            key: const Key('page_task_planning'),
            padding: EdgeInsets.fromLTRB(22, compactHeader ? 8 : 66, 22, 124),
            children: [
              StudyPathHero(
                isDarkMode: isDarkMode,
                accent: accent,
                badge: '任务安排',
                title: '先把最近要做的排清楚',
                subtitle: '把最近要做的事按轻重缓急放好，打开就知道先做哪一件。',
                icon: Icons.task_alt_rounded,
                child: Column(
                  children: [
                    Row(
                      children: [
                        _progressRing(
                          progress: totalProgress,
                          color: accent,
                          isDarkMode: isDarkMode,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  _summaryPill(
                                    label: '已完成',
                                    value: '$doneCount',
                                    color: StudyUi.pathViolet,
                                    isDarkMode: isDarkMode,
                                  ),
                                  const SizedBox(width: 8),
                                  _summaryPill(
                                    label: '待完成',
                                    value: '$openCount',
                                    color: StudyUi.pathMint,
                                    isDarkMode: isDarkMode,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _summaryPill(
                                    label: '先看这几项',
                                    value: '${overdueTasks.length}',
                                    color: overdueTasks.isEmpty
                                        ? StudyUi.pathBlue
                                        : StudyUi.danger,
                                    isDarkMode: isDarkMode,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: totalProgress,
                        minHeight: 6,
                        backgroundColor: isDarkMode
                            ? Colors.white.withValues(alpha: 0.10)
                            : const Color(0xFFE7ECFF),
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _taskPriorityHint(
                      task: focusTask,
                      label: focusLabel,
                      isDarkMode: isDarkMode,
                      textColor: textColor,
                      bodyColor: bodyColor,
                      accent: accent,
                      actionLabel: focusActionLabel,
                      onAction: focusAction,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (overdueTasks.isNotEmpty) ...[
                _overdueWarningCard(
                  overdueTasks.length,
                  overdueTasks.first,
                  isDarkMode,
                  textColor,
                  bodyColor,
                  onOpen: onOpenOverdueTasks ?? onOpenTasks,
                ),
                const SizedBox(height: 16),
              ],
              if (todayTasks.isNotEmpty) ...[
                _sectionHeader(
                  '今天截止',
                  '今天该推进的内容，做完会更轻松',
                  todayTasks.length,
                  StudyUi.pathViolet,
                  textColor,
                  bodyColor,
                ),
                const SizedBox(height: 10),
                ...todayTasks.map(
                  (t) => _planTaskCard(
                    t,
                    isDarkMode,
                    textColor,
                    bodyColor,
                    StudyUi.pathViolet,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (weekTasks.isNotEmpty) ...[
                _sectionHeader(
                  '本周安排',
                  '这几项是本周可以往前推的任务',
                  weekTasks.length,
                  StudyUi.pathBlue,
                  textColor,
                  bodyColor,
                ),
                const SizedBox(height: 10),
                ...weekTasks.map(
                  (t) => _planTaskCard(
                    t,
                    isDarkMode,
                    textColor,
                    bodyColor,
                    StudyUi.pathBlue,
                  ),
                ),
              ],
              if (overdueTasks.isEmpty &&
                  todayTasks.isEmpty &&
                  weekTasks.isEmpty)
                StudyEmptyState.tasks(
                  title: '这周没有待办任务',
                  message: '加上学习任务后，这里会帮你把今天和本周要做的事排出来。',
                  actionLabel: onOpenTasks == null ? null : '去任务清单',
                  onAction: onOpenTasks,
                  compact: true,
                ),
            ],
          ),
        );
      },
    );
  }
}

Widget _sectionHeader(
  String title,
  String subtitle,
  int count,
  Color color,
  Color textColor,
  Color bodyColor,
) {
  return Row(
    children: [
      StudyGlassIconNode(
        icon: Icons.route_rounded,
        accent: color,
        size: 30,
        iconSize: 14,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: textColor,
                fontSize: 17,
                fontWeight: AppTypography.hero,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(color: bodyColor, fontSize: 12),
            ),
          ],
        ),
      ),
      BadgePill(
        label: '$count 项',
        background: color.withValues(alpha: 0.12),
        foreground: color,
      ),
    ],
  );
}

Widget _overdueWarningCard(
  int count,
  StudyTaskItem firstTask,
  bool isDarkMode,
  Color textColor,
  Color bodyColor, {
  VoidCallback? onOpen,
}) {
  return StudyCard(
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        StudyGlassIconNode(
          icon: Icons.warning_amber_rounded,
          accent: StudyUi.danger,
          size: 40,
          iconSize: 18,
          isDarkMode: isDarkMode,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count 件事已经晚了，先挑最早的一件补上',
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: AppTypography.hero,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '最早一项：${firstTask.title} · 截止 ${_taskFmtDate(firstTask.deadline)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: bodyColor, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        onOpen == null
            ? BadgePill(
                label: '先放着',
                background: StudyUi.danger.withValues(alpha: 0.12),
                foreground: StudyUi.danger,
              )
            : StudyActionPill(
                icon: Icons.arrow_forward_rounded,
                label: '先处理',
                color: StudyUi.danger,
                isDarkMode: isDarkMode,
                filled: false,
                onPressed: onOpen,
              ),
      ],
    ),
  );
}

Widget _taskPriorityHint({
  required StudyTaskItem? task,
  required String label,
  required bool isDarkMode,
  required Color textColor,
  required Color bodyColor,
  required Color accent,
  required String actionLabel,
  VoidCallback? onAction,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: isDarkMode ? 0.05 : 0.62),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: accent.withValues(alpha: isDarkMode ? 0.18 : 0.12),
      ),
    ),
    child: Row(
      children: [
        StudyGlassIconNode(
          icon: task == null ? Icons.add_task_rounded : Icons.flag_rounded,
          accent: accent,
          size: 38,
          iconSize: 17,
          isDarkMode: isDarkMode,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: AppTypography.title,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                task?.title ?? '给今天补一个能完成的小任务',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: AppTypography.hero,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                task == null
                    ? '先从一件能收尾的小事开始，会更容易进入状态。'
                    : '${task.courseName.isEmpty ? task.type.label : task.courseName} · 截止 ${_taskFmtDate(task.deadline)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: bodyColor,
                  fontSize: 12,
                ),
              ),
              if (onAction != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: StudyActionPill(
                    icon: task == null
                        ? Icons.add_task_rounded
                        : Icons.arrow_forward_rounded,
                    label: actionLabel,
                    color: accent,
                    isDarkMode: isDarkMode,
                    filled: false,
                    onPressed: onAction,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _planTaskCard(
  StudyTaskItem task,
  bool isDarkMode,
  Color textColor,
  Color bodyColor,
  Color accent,
) {
  final progress = task.progress;
  final progressColor = task.effectiveStatus == StudyTaskStatus.completed
      ? StudyUi.success
      : task.deadline.isBefore(DateTime.now())
          ? StudyUi.danger
          : accent;

  return Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: StudyCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StudyGlassIconNode(
            icon: task.effectiveStatus == StudyTaskStatus.completed
                ? Icons.check_rounded
                : Icons.flag_rounded,
            accent: progressColor,
            size: 42,
            iconSize: 18,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(width: 12),
          BadgePill(
            label: task.effectiveStatus == StudyTaskStatus.completed
                ? '已完成'
                : '待推进',
            background: progressColor.withValues(alpha: 0.12),
            foreground: progressColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: AppTypography.hero,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    BadgePill(
                      label: '${(progress * 100).toInt()}%',
                      background: progressColor.withValues(alpha: 0.12),
                      foreground: progressColor,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '要在 ${_taskFmtDate(task.deadline)} 前完成 · ${task.courseName.isEmpty ? task.type.label : task.courseName}',
                  style: TextStyle(color: bodyColor, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (task.isTaskSet && task.subTasks.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor:
                          isDarkMode ? Colors.white12 : const Color(0xFFE8EBF5),
                      color: progressColor,
                      minHeight: 5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...task.subTasks.take(3).map(
                        (st) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(
                            children: [
                              Icon(
                                st.status == SubTaskStatus.completed
                                    ? Icons.check_circle_rounded
                                    : Icons.flag_outlined,
                                size: 14,
                                color: st.status == SubTaskStatus.completed
                                    ? progressColor
                                    : bodyColor,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  st.title,
                                  style: TextStyle(
                                    color: bodyColor,
                                    fontSize: 12,
                                    decoration:
                                        st.status == SubTaskStatus.completed
                                            ? TextDecoration.lineThrough
                                            : null,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  if (task.subTasks.length > 3)
                    Text(
                      '还有 ${task.subTasks.length - 3} 个小步骤',
                      style: TextStyle(color: bodyColor, fontSize: 11),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _progressRing({
  required double progress,
  required Color color,
  required bool isDarkMode,
}) {
  return SizedBox(
    width: 82,
    height: 82,
    child: Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 76,
          height: 76,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 7,
            backgroundColor: isDarkMode
                ? Colors.white.withValues(alpha: 0.10)
                : const Color(0xFFE7ECFF),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        Text(
          '${(progress * 100).round()}%',
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: AppTypography.hero,
          ),
        ),
      ],
    ),
  );
}

Widget _summaryPill({
  required String label,
  required String value,
  required Color color,
  required bool isDarkMode,
}) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDarkMode ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: StudyUi.muted(isDarkMode),
              fontSize: 11,
              fontWeight: AppTypography.title,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: AppTypography.hero,
            ),
          ),
        ],
      ),
    ),
  );
}

String _taskFmtDate(DateTime d) {
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '${d.month}/${d.day} $h:$m';
}
