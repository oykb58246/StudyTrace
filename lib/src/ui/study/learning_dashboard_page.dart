import 'package:fl_chart/fl_chart.dart';
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

        final accent = controller.primaryColor;
        final textColor = isDarkMode ? Colors.white : AppColors.ink;
        final bodyColor =
            isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;

        return RefreshIndicator(
          onRefresh: () async => controller.notifyListeners(),
          child: ListView(
          key: const Key('page_learning_dashboard'),
          padding: const EdgeInsets.fromLTRB(22, 82, 22, 124),
          children: [
            Text('学习数据看板',
                style: TextStyle(
                    color: textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    '总记录',
                    '${logs.length}',
                    const Color(0xFF7394F9),
                    isDarkMode,
                    textColor,
                    bodyColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    '总任务',
                    '$totalTasks',
                    accent,
                    isDarkMode,
                    textColor,
                    bodyColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    '完成率',
                    totalTasks > 0
                        ? '${(completedTasks * 100 ~/ totalTasks)}%'
                        : '-',
                    const Color(0xFF4BC4A1),
                    isDarkMode,
                    textColor,
                    bodyColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Stats grid
            Row(
              children: [
                Expanded(child: _statCard('子任务', '$completedSubTasks/$totalSubTasks', accent, isDarkMode, textColor, bodyColor)),
                const SizedBox(width: 12),
                Expanded(child: _statCard('课程', '${courseCount.length}', const Color(0xFF4BC4A1), isDarkMode, textColor, bodyColor)),
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
                Expanded(child: _statCard('已完成', '$completedTasks', const Color(0xFF4BC4A1), isDarkMode, textColor, bodyColor)),
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
                            color: accent,
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
              Text('近 7 天学习记录', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              GlassCard(
                color: isDarkMode ? const Color(0xFF242B37).withValues(alpha: 0.9) : null,
                child: SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: _weeklyMaxY(weeklyData),
                      barGroups: _buildWeeklyBarGroups(weeklyData, accent),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 1,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (value, meta) {
                              if (value == value.roundToDouble()) {
                                return Text(
                                  '${value.toInt()}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDarkMode
                                        ? Colors.white38
                                        : AppColors.muted,
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final day = now.subtract(
                                Duration(days: 6 - value.toInt()),
                              );
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  '${day.month}/${day.day}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDarkMode
                                        ? Colors.white38
                                        : AppColors.muted,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barTouchData: BarTouchData(enabled: true),
                    ),
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
                child: SizedBox(
                  height: 220,
                  child: PieChart(
                    PieChartData(
                      sections: _buildPieSections(courseCount),
                      centerSpaceRadius: 50,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 8,
                children: _buildLegend(courseCount, bodyColor),
              ),
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
                                  decoration: BoxDecoration(color: accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                                  child: Text('${e.value}条', style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ],
          ), // RefreshIndicator
        );
      },
    );
  }

  double _weeklyMaxY(List<int> counts) {
    final max = counts.isEmpty ? 1 : counts.reduce((a, b) => a > b ? a : b);
    return (max + 1).toDouble();
  }

  List<BarChartGroupData> _buildWeeklyBarGroups(List<int> counts, Color accent) {
    return counts.asMap().entries.map((entry) {
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: entry.value.toDouble(),
            color: accent,
            width: 20,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(6),
            ),
          ),
        ],
      );
    }).toList();
  }

  List<PieChartSectionData> _buildPieSections(Map<String, int> data) {
    final colors = _chartColors;
    final total = data.values.fold<int>(0, (a, b) => a + b).toDouble();

    return data.entries.toList().asMap().entries.map((entry) {
      final i = entry.key;
      final e = entry.value;
      final percentage = total > 0 ? (e.value / total * 100) : 0.0;
      return PieChartSectionData(
        color: colors[i % colors.length],
        value: e.value.toDouble(),
        title: '${percentage.toInt()}%',
        titleStyle: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        radius: 60,
      );
    }).toList();
  }

  List<Widget> _buildLegend(Map<String, int> data, Color bodyColor) {
    final colors = _chartColors;
    return data.entries.toList().asMap().entries.map((entry) {
      final i = entry.key;
      final e = entry.value;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: colors[i % colors.length],
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${e.key} (${e.value})',
            style: TextStyle(
              fontSize: 12,
              color: bodyColor,
            ),
          ),
        ],
      );
    }).toList();
  }

  List<Color> get _chartColors => [
        controller.primaryColor,
        const Color(0xFF7394F9),
        const Color(0xFF4BC4A1),
        const Color(0xFFF8AA5B),
        const Color(0xFFF77D8E),
        const Color(0xFF8C7CFF),
        const Color(0xFF4CB9FF),
      ];
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
