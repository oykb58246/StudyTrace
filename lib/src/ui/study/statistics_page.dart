import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/study_task_item.dart';
import '../shared/common_widgets.dart';

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({
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
        const accent = StudyUi.primary;
        final logs = controller.studyLogs;
        final tasks = controller.studyTasks;

        final now = DateTime.now();
        final weekAgo = now.subtract(const Duration(days: 7));
        final recentLogs =
            logs.where((l) => !l.date.isBefore(weekAgo)).toList();

        final courseLogCount = <String, int>{};
        for (final log in logs) {
          final course = log.courseName.isEmpty ? '未归类' : log.courseName;
          courseLogCount[course] = (courseLogCount[course] ?? 0) + 1;
        }

        final dailyCounts = <int, int>{};
        for (int i = 6; i >= 0; i--) {
          final day = now.subtract(Duration(days: i));
          final dayKey = day.day;
          final count = recentLogs
              .where((l) =>
                  l.date.year == day.year &&
                  l.date.month == day.month &&
                  l.date.day == day.day)
              .length;
          dailyCounts[dayKey] = count;
        }

        final completed =
            tasks.where((t) => t.status == StudyTaskStatus.completed).length;
        final total = tasks.length;
        final completionRate = total > 0 ? completed / total : 0.0;

        return RefreshIndicator(
          onRefresh: () async => controller.notifyListeners(),
          child: ListView(
          key: const Key('page_statistics'),
          padding: const EdgeInsets.fromLTRB(22, 82, 22, 124),
          children: [
            Text(
              '学习统计',
              style: TextStyle(
                color: StudyUi.title(isDarkMode),
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            // Stat cards row
            Row(
              children: [
                _StatCard(
                  label: '总记录',
                  value: '${logs.length}',
                  icon: Icons.menu_book_rounded,
                  color: StudyUi.secondary,
                ),
                const SizedBox(width: 10),
                _StatCard(
                  label: '总任务',
                  value: '$total',
                  icon: Icons.checklist_rounded,
                  color: accent,
                ),
                const SizedBox(width: 10),
                _StatCard(
                  label: '完成率',
                  value: '${(completionRate * 100).toInt()}%',
                  icon: Icons.trending_up_rounded,
                  color: StudyUi.success,
                ),
              ],
            ),
            const SizedBox(height: 22),
            // Course distribution pie chart
            if (courseLogCount.isNotEmpty) ...[
              Text(
                '课程分布',
                style: TextStyle(
                  color: StudyUi.title(isDarkMode),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              StudyCard(
                child: SizedBox(
                  height: 220,
                  child: PieChart(
                    PieChartData(
                      sections:
                          _buildPieSections(courseLogCount),
                      centerSpaceRadius: 50,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Legend
              Wrap(
                spacing: 14,
                runSpacing: 8,
                children: _buildLegend(courseLogCount),
              ),
              const SizedBox(height: 22),
            ],
            // Weekly bar chart
            Text(
              '近 7 天学习记录',
              style: TextStyle(
                  color: StudyUi.title(isDarkMode),
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            StudyCard(
              child: SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: _maxY(dailyCounts),
                    barGroups: _buildBarGroups(dailyCounts),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 1,
                      getDrawingHorizontalLine: (value) => FlLine(
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
                                  color: StudyUi.muted(isDarkMode),
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
                            final day =
                                now.subtract(Duration(days: 6 - value.toInt()));
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                '${day.month}/${day.day}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: StudyUi.muted(isDarkMode),
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
          ), // RefreshIndicator
        );
      },
    );
  }

  double _maxY(Map<int, int> counts) {
    final max = counts.values.isEmpty ? 1 : counts.values.reduce(
      (a, b) => a > b ? a : b,
    );
    return (max + 1).toDouble();
  }

  List<PieChartSectionData> _buildPieSections(Map<String, int> data) {
    const accent = StudyUi.primary;
    final colors = [
      accent,
      StudyUi.secondary,
      StudyUi.success,
      StudyUi.warning,
      StudyUi.danger,
      StudyUi.primary,
      const Color(0xFF4CB9FF),
    ];
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

  List<Widget> _buildLegend(Map<String, int> data) {
    const accent = StudyUi.primary;
    final colors = [
      accent,
      StudyUi.secondary,
      StudyUi.success,
      StudyUi.warning,
      StudyUi.danger,
      StudyUi.primary,
      const Color(0xFF4CB9FF),
    ];
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
              color: StudyUi.body(isDarkMode),
            ),
          ),
        ],
      );
    }).toList();
  }

  List<BarChartGroupData> _buildBarGroups(Map<int, int> counts) {
    const accent = StudyUi.primary;
    return counts.entries.toList().asMap().entries.map((entry) {
      final i = entry.key;
      final e = entry.value;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: e.value.toDouble(),
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
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: StudyMetricTile(
        label: label,
        value: value,
        icon: icon,
        color: color,
      ),
    );
  }
}
