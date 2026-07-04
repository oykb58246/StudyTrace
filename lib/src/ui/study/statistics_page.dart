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
              .where(
                (l) =>
                    l.date.year == day.year &&
                    l.date.month == day.month &&
                    l.date.day == day.day,
              )
              .length;
          dailyCounts[dayKey] = count;
        }

        final completed =
            tasks.where((t) => t.status == StudyTaskStatus.completed).length;
        final total = tasks.length;
        final completionRate = total > 0 ? completed / total : 0.0;

        return RefreshIndicator(
          onRefresh: controller.load,
          child: StudyScreenBackground(
            isDarkMode: isDarkMode,
            accent: accent,
            child: ListView(
              key: const Key('page_statistics'),
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 124),
              children: [
                StudyPathHero(
                  isDarkMode: isDarkMode,
                  accent: accent,
                  badge: '近 7 天',
                  title: '最近这周学得怎么样',
                  subtitle: '看看这一周哪里学得稳，哪里可以少掉队一点。',
                  icon: Icons.analytics_rounded,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: StudyPathMetricPill(
                              label: '近 7 天记录',
                              value: '${recentLogs.length}',
                              icon: Icons.timeline_rounded,
                              color: StudyUi.pathCyan,
                              isDarkMode: isDarkMode,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StudyPathMetricPill(
                              label: '完成进度',
                              value: '${(completionRate * 100).toInt()}%',
                              icon: Icons.trending_up_rounded,
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
                              label: '留下的学习痕迹',
                              value: '${logs.length}',
                              icon: Icons.menu_book_rounded,
                              color: StudyUi.secondary,
                              isDarkMode: isDarkMode,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StudyPathMetricPill(
                              label: '学过的课程',
                              value: '${courseLogCount.length}',
                              icon: Icons.school_rounded,
                              color: accent,
                              isDarkMode: isDarkMode,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _StatisticsSectionHeader(
                  title: '这一周的学习节奏',
                  subtitle: '看这一周哪几天学得多，哪几天节奏掉下来了',
                  icon: Icons.bar_chart_rounded,
                  color: accent,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(height: 12),
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
                                final day = now.subtract(
                                    Duration(days: 6 - value.toInt()));
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
                        barTouchData: BarTouchData(enabled: false),
                      ),
                    ),
                  ),
                ),
                if (courseLogCount.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _StatisticsSectionHeader(
                    title: '时间主要花在哪些课',
                    subtitle: '看看最近主要把时间放在哪几门课上',
                    icon: Icons.pie_chart_rounded,
                    color: StudyUi.secondary,
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 12),
                  StudyCard(
                    child: SizedBox(
                      height: 220,
                      child: PieChart(
                        PieChartData(
                          sections: _buildPieSections(courseLogCount),
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
                    children: _buildLegend(courseLogCount),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  double _maxY(Map<int, int> counts) {
    final max = counts.values.isEmpty
        ? 1
        : counts.values.reduce((a, b) => a > b ? a : b);
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

class _StatisticsSectionHeader extends StatelessWidget {
  const _StatisticsSectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isDarkMode,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        StudyGlassIconNode(
          icon: icon,
          accent: color,
          size: 34,
          iconSize: 16,
          isDarkMode: isDarkMode,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: StudyUi.title(isDarkMode),
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: StudyUi.body(isDarkMode),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
