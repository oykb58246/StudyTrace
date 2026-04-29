import 'package:flutter/material.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/study_task_item.dart';
import '../../theme/app_theme.dart';
import '../shared/common_widgets.dart';

class LearningDashboardPage extends StatelessWidget {
  const LearningDashboardPage({
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
        final logs = controller.studyLogs;
        final reports = controller.weeklyReports;
        final now = DateTime.now();
        final weekAgo = now.subtract(const Duration(days: 7));

        final totalTasks = tasks.length;
        final completedTasks =
            tasks.where((t) => t.effectiveStatus == StudyTaskStatus.completed).length;
        final overdueTasks = tasks
            .where((t) =>
                t.effectiveStatus != StudyTaskStatus.completed &&
                t.deadline.isBefore(now))
            .length;
        final totalSubTasks = tasks.fold<int>(
            0, (sum, t) => sum + t.totalCount);
        final completedSubTasks = tasks.fold<int>(
            0, (sum, t) => sum + t.completedCount);
        final recentLogs =
            logs.where((l) => !l.date.isBefore(weekAgo)).length;
        final monthLogs =
            logs.where((l) => !l.date.isBefore(now.subtract(const Duration(days: 30)))).length;

        // Weekly trend
        final weeklyData = <int>[];
        for (var d = 6; d >= 0; d--) {
          final day = now.subtract(Duration(days: d));
          weeklyData.add(
              logs.where((l) => _sameDay(l.date, day)).length);
        }

        // Course count (used in stats below)
        final courseCount = <String, int>{};
        for (final log in logs) {
          final c = log.courseName.isEmpty ? '未归类' : log.courseName;
          courseCount[c] = (courseCount[c] ?? 0) + 1;
        }

        // Monthly trend (4 weeks)
        final monthlyData = <int>[];
        final weekLabels = <String>[];
        for (var w = 3; w >= 0; w--) {
          final end = now.subtract(Duration(days: w * 7));
          final start = end.subtract(const Duration(days: 7));
          monthlyData.add(logs.where((l) => !l.date.isBefore(start) && l.date.isBefore(end)).length);
          weekLabels.add('${start.month}/${start.day}');
        }

        final textColor = isDarkMode ? Colors.white : AppColors.ink;
        final bodyColor =
            isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;

        return ListView(
          key: const Key('page_learning_dashboard'),
          padding: const EdgeInsets.fromLTRB(22, 82, 22, 124),
          children: [
            Text('学习数据看板',
                style: TextStyle(
                    color: textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            // Stats grid
            Row(
              children: [
                Expanded(child: _statCard('总任务', '$totalTasks', const Color(0xFF7040F2), isDarkMode, textColor, bodyColor)),
                const SizedBox(width: 12),
                Expanded(child: _statCard('完成率', totalTasks > 0 ? '${(completedTasks * 100 ~/ totalTasks)}%' : '-', const Color(0xFF4BC4A1), isDarkMode, textColor, bodyColor)),
                const SizedBox(width: 12),
                Expanded(child: _statCard('逾期', '$overdueTasks', const Color(0xFFEF6850), isDarkMode, textColor, bodyColor)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _statCard('连续打卡', '${controller.studyStreak}天', const Color(0xFFFF6B35), isDarkMode, textColor, bodyColor)),
                const SizedBox(width: 12),
                Expanded(child: _statCard('近7天', '$recentLogs条', const Color(0xFF7394F9), isDarkMode, textColor, bodyColor)),
                const SizedBox(width: 12),
                Expanded(child: _statCard('近30天', '$monthLogs条', const Color(0xFFF8AA5B), isDarkMode, textColor, bodyColor)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _statCard('AI周报', '${reports.length}', const Color(0xFF8C7CFF), isDarkMode, textColor, bodyColor)),
                const SizedBox(width: 12),
                Expanded(child: _statCard('笔记', '${controller.studyNotes.length}', const Color(0xFF4CB9FF), isDarkMode, textColor, bodyColor)),
                const SizedBox(width: 12),
                Expanded(child: _statCard('课程', '${courseCount.length}', const Color(0xFF4BC4A1), isDarkMode, textColor, bodyColor)),
              ],
            ),
            if (totalSubTasks > 0) ...[
              const SizedBox(height: 12),
              GlassCard(
                color: isDarkMode ? const Color(0xFF242B37).withValues(alpha: 0.9) : null,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('子任务进度', style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('$completedSubTasks / $totalSubTasks 完成', style: TextStyle(color: bodyColor, fontSize: 13)),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: totalSubTasks > 0 ? completedSubTasks / totalSubTasks : 0,
                            strokeWidth: 5,
                            backgroundColor: isDarkMode ? Colors.white12 : const Color(0xFFE8EBF5),
                            color: const Color(0xFF7040F2),
                          ),
                          Text('${totalSubTasks > 0 ? (completedSubTasks * 100 ~/ totalSubTasks) : 0}%',
                              style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Weekly trend bar
            if (recentLogs > 0) ...[
              const SizedBox(height: 22),
              Text('近7天学习趋势', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              GlassCard(
                color: isDarkMode ? const Color(0xFF242B37).withValues(alpha: 0.9) : null,
                child: SizedBox(
                  height: 140,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < weeklyData.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('${weeklyData[i]}', style: TextStyle(color: bodyColor, fontSize: 11)),
                              const SizedBox(height: 4),
                              Container(
                                height: (weeklyData[i] / (weeklyData.reduce((a, b) => a > b ? a : b) + 1)) * 90,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7040F2).withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            // Monthly trend bar
            if (monthLogs > 0) ...[
              const SizedBox(height: 22),
              Text('近4周学习趋势', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              GlassCard(
                color: isDarkMode ? const Color(0xFF242B37).withValues(alpha: 0.9) : null,
                child: SizedBox(
                  height: 120,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < monthlyData.length; i++) ...[
                        if (i > 0) const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('${monthlyData[i]}', style: TextStyle(color: bodyColor, fontSize: 11)),
                              const SizedBox(height: 4),
                              Container(
                                height: (monthlyData[i] / (monthlyData.reduce((a, b) => a > b ? a : b) + 1)) * 70,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8C7CFF).withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(weekLabels[i], style: TextStyle(color: bodyColor, fontSize: 9)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            // Course distribution
            if (courseCount.isNotEmpty) ...[
              const SizedBox(height: 22),
              Text('课程分布', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              GlassCard(
                color: isDarkMode ? const Color(0xFF242B37).withValues(alpha: 0.9) : null,
                child: Column(
                  children: courseCount.entries
                      .take(8)
                      .map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(child: Text(e.key, style: TextStyle(color: textColor, fontSize: 13))),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFF7040F2).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                                  child: Text('${e.value}条', style: const TextStyle(color: Color(0xFF7040F2), fontSize: 11, fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

Widget _statCard(String label, String value, Color color, bool isDarkMode, Color textColor, Color bodyColor) {
  return GlassCard(
    color: isDarkMode ? const Color(0xFF242B37).withValues(alpha: 0.9) : null,
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
    child: Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: bodyColor, fontSize: 11)),
      ],
    ),
  );
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
