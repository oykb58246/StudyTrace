import 'package:flutter/material.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/study_sub_task_item.dart';
import '../../models/study_task_item.dart';
import '../shared/common_widgets.dart';

class TaskPlanningPage extends StatelessWidget {
  const TaskPlanningPage({
    super.key,
    required this.isDarkMode,
    required this.controller,
  });

  final bool isDarkMode;
  final AppDataController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final tasks = controller.studyTasks;
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final weekEnd = today.add(const Duration(days: 7));

        final overdueTasks = tasks
            .where((t) =>
                t.effectiveStatus != StudyTaskStatus.completed &&
                t.deadline.isBefore(now))
            .toList();
        final todayTasks = tasks
            .where((t) =>
                t.effectiveStatus != StudyTaskStatus.completed &&
                !t.deadline.isBefore(today) &&
                t.deadline.isBefore(today.add(const Duration(days: 1))))
            .toList();
        final weekTasks = tasks
            .where((t) =>
                t.effectiveStatus != StudyTaskStatus.completed &&
                !t.deadline.isBefore(today.add(const Duration(days: 1))) &&
                t.deadline.isBefore(weekEnd))
            .toList();

        const accent = StudyUi.primary;
        final textColor = StudyUi.title(isDarkMode);
        final bodyColor = StudyUi.body(isDarkMode);

        return RefreshIndicator(
          onRefresh: () async => controller.notifyListeners(),
          child: ListView(
          key: const Key('page_task_planning'),
          padding: const EdgeInsets.fromLTRB(22, 82, 22, 124),
          children: [
            Text('任务编排', style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${tasks.where((t) => t.effectiveStatus != StudyTaskStatus.completed).length} 项未完成，${overdueTasks.length} 项逾期',
                style: TextStyle(color: bodyColor, fontSize: 13)),
            const SizedBox(height: 18),
            // Overdue section
            if (overdueTasks.isNotEmpty) ...[
              _sectionHeader('逾期任务', StudyUi.danger, textColor),
              const SizedBox(height: 10),
              ...overdueTasks.map((t) => _planTaskCard(t, isDarkMode, textColor, bodyColor, accent)),
              const SizedBox(height: 18),
            ],
            // Today
            if (todayTasks.isNotEmpty) ...[
              _sectionHeader('今日待办', StudyUi.warning, textColor),
              const SizedBox(height: 10),
              ...todayTasks.map((t) => _planTaskCard(t, isDarkMode, textColor, bodyColor, accent)),
              const SizedBox(height: 18),
            ],
            // This week
            if (weekTasks.isNotEmpty) ...[
              _sectionHeader('本周待办', StudyUi.secondary, textColor),
              const SizedBox(height: 10),
              ...weekTasks.map((t) => _planTaskCard(t, isDarkMode, textColor, bodyColor, accent)),
            ],
            if (overdueTasks.isEmpty && todayTasks.isEmpty && weekTasks.isEmpty)
              const StudyEmptyState.tasks(
                title: '近期没有待办任务',
                message: '新增任务并设置截止时间后，今天、本周和逾期任务会自动归到这里。',
                compact: true,
              ),
          ],
          ), // RefreshIndicator
        );
      },
    );
  }
}

Widget _sectionHeader(String title, Color color, Color textColor) {
  return Row(
    children: [
      Container(width: 4, height: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(title, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w700)),
    ],
  );
}

Widget _planTaskCard(StudyTaskItem task, bool isDarkMode, Color textColor, Color bodyColor, Color accent) {
  final progress = task.progress;
  final progressColor =
      task.effectiveStatus == StudyTaskStatus.completed
          ? StudyUi.success
          : task.deadline.isBefore(DateTime.now())
              ? StudyUi.danger
              : accent;

  return StudyCard(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(task.title, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            Text('${(progress * 100).toInt()}%', style: TextStyle(color: progressColor, fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 4),
        Text('截止：${_taskFmtDate(task.deadline)}  ·  ${task.courseName}', style: TextStyle(color: bodyColor, fontSize: 11)),
        if (task.isTaskSet && task.subTasks.isNotEmpty) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: progress, backgroundColor: isDarkMode ? Colors.white12 : const Color(0xFFE8EBF5), color: progressColor, minHeight: 4),
          ),
          const SizedBox(height: 6),
          ...task.subTasks.take(4).map((st) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    Icon(st.status == SubTaskStatus.completed ? Icons.check_circle : Icons.radio_button_unchecked, size: 14, color: st.status == SubTaskStatus.completed ? progressColor : bodyColor),
                    const SizedBox(width: 6),
                    Expanded(child: Text(st.title, style: TextStyle(color: bodyColor, fontSize: 12, decoration: st.status == SubTaskStatus.completed ? TextDecoration.lineThrough : null), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              )),
          if (task.subTasks.length > 4)
            Text('  还有 ${task.subTasks.length - 4} 个子任务...', style: TextStyle(color: bodyColor, fontSize: 11)),
        ],
      ],
    ),
  );
}

String _taskFmtDate(DateTime d) {
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '${d.month}/${d.day} $h:$m';
}
