import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/study_task_item.dart';
import '../../services/ai_exceptions.dart';
import '../../services/ai_study_service.dart';
import '../../theme/app_theme.dart';
import '../shared/app_assets.dart';
import '../shared/common_widgets.dart';

class LearningDashboardPage extends StatelessWidget {
  const LearningDashboardPage({
    super.key,
    required this.isDarkMode,
    required this.controller,
    this.onOpenTasks,
    this.onOpenOverdueTasks,
    this.onOpenLogs,
    this.onOpenLearningMoments,
    this.onOpenTaskPlanning,
    this.onOpenKnowledgeMap,
    this.onOpenWeeklyReview,
  });

  final bool isDarkMode;
  final AppDataController controller;
  final VoidCallback? onOpenTasks;
  final VoidCallback? onOpenOverdueTasks;
  final VoidCallback? onOpenLogs;
  final VoidCallback? onOpenLearningMoments;
  final VoidCallback? onOpenTaskPlanning;
  final VoidCallback? onOpenKnowledgeMap;
  final VoidCallback? onOpenWeeklyReview;

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
        final completedTasks = tasks
            .where((t) => t.effectiveStatus == StudyTaskStatus.completed)
            .length;
        final overdueTasks = tasks
            .where((t) =>
                t.effectiveStatus != StudyTaskStatus.completed &&
                t.deadline.isBefore(now))
            .length;
        final totalSubTasks =
            tasks.fold<int>(0, (sum, t) => sum + t.totalCount);
        final completedSubTasks =
            tasks.fold<int>(0, (sum, t) => sum + t.completedCount);
        final recentLogs = logs.where((l) => !l.date.isBefore(weekAgo)).length;
        final monthLogs = logs
            .where(
                (l) => !l.date.isBefore(now.subtract(const Duration(days: 30))))
            .length;

        // Weekly trend
        final weeklyData = <int>[];
        for (var d = 6; d >= 0; d--) {
          final day = now.subtract(Duration(days: d));
          weeklyData.add(logs.where((l) => _sameDay(l.date, day)).length);
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
          monthlyData.add(logs
              .where((l) => !l.date.isBefore(start) && l.date.isBefore(end))
              .length);
          weekLabels.add('${start.month}/${start.day}');
        }

        const accent = StudyUi.primary;
        final textColor = StudyUi.title(isDarkMode);
        final bodyColor = StudyUi.body(isDarkMode);
        final nextStepAction = _DashboardNextStepAction.resolve(
          overdueTasks: overdueTasks,
          recentLogs: recentLogs,
          totalTasks: totalTasks,
          completedTasks: completedTasks,
          reports: reports.length,
          notes: controller.studyNotes.length,
          onOpenOverdueTasks: onOpenOverdueTasks,
          onOpenTasks: onOpenTasks,
          onOpenLogs: onOpenLogs,
          onOpenLearningMoments: onOpenLearningMoments,
          onOpenTaskPlanning: onOpenTaskPlanning,
        );

        return RefreshIndicator(
          onRefresh: controller.load,
          child: StudyScreenBackground(
            isDarkMode: isDarkMode,
            accent: accent,
            child: ListView(
              key: const Key('page_learning_dashboard'),
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 124),
              children: [
                StudyPathHero(
                  isDarkMode: isDarkMode,
                  accent: accent,
                  badge: '本周状态',
                  title: '先看这周学得怎么样',
                  subtitle: '这里先给你一个本周状态，再往下看任务推进、学习趋势和课程分布。',
                  icon: Icons.query_stats_rounded,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: StudyPathMetricPill(
                              label: '累计记录',
                              value: '${logs.length}',
                              icon: Icons.menu_book_rounded,
                              color: StudyUi.secondary,
                              isDarkMode: isDarkMode,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StudyPathMetricPill(
                              label: '完成率',
                              value: totalTasks > 0
                                  ? '${(completedTasks * 100 ~/ totalTasks)}%'
                                  : '-',
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
                              label: '连续学习',
                              value: '${controller.studyStreak}天',
                              icon: Icons.local_fire_department_rounded,
                              color: StudyUi.warning,
                              isDarkMode: isDarkMode,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StudyPathMetricPill(
                              label: '近 7 天',
                              value: '$recentLogs条',
                              icon: Icons.timeline_rounded,
                              color: StudyUi.pathCyan,
                              isDarkMode: isDarkMode,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _DashboardNextStepCard(
                        action: nextStepAction,
                        isDarkMode: isDarkMode,
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: StudyStatusChip(
                          label: '展开学习建议',
                          icon: Icons.lightbulb_rounded,
                          color: accent,
                          selected: true,
                          onTap: () => _showAiAnalysisSheet(
                            context,
                            isDarkMode: isDarkMode,
                            summary: _buildDashboardSummary(
                              totalLogs: logs.length,
                              totalTasks: totalTasks,
                              completedTasks: completedTasks,
                              overdueTasks: overdueTasks,
                              totalSubTasks: totalSubTasks,
                              completedSubTasks: completedSubTasks,
                              recentLogs: recentLogs,
                              monthLogs: monthLogs,
                              courseDist: courseCount,
                              weeklyData: weeklyData,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _DashboardShortcutRow(
                  isDarkMode: isDarkMode,
                  onOpenKnowledgeMap: onOpenKnowledgeMap,
                  onOpenWeeklyReview: onOpenWeeklyReview,
                  onOpenLearningMoments: onOpenLearningMoments,
                ),
                const SizedBox(height: 12),
                _DashboardInsightCard(
                  insight: recentLogs == 0
                      ? '这周还没有学习记录，先补一次复盘，下面的趋势就会慢慢清楚起来。'
                      : overdueTasks > 0
                          ? '这周已经有 $recentLogs 条记录，先把 $overdueTasks 项超时任务收回来，再继续保持节奏。'
                          : '这周已经有 $recentLogs 条记录，任务完成率 ${totalTasks > 0 ? (completedTasks * 100 ~/ totalTasks) : 0}%，继续照这个节奏往前推。',
                  isDarkMode: isDarkMode,
                  onTap: () => _showAiAnalysisSheet(
                    context,
                    isDarkMode: isDarkMode,
                    summary: _buildDashboardSummary(
                      totalLogs: logs.length,
                      totalTasks: totalTasks,
                      completedTasks: completedTasks,
                      overdueTasks: overdueTasks,
                      totalSubTasks: totalSubTasks,
                      completedSubTasks: completedSubTasks,
                      recentLogs: recentLogs,
                      monthLogs: monthLogs,
                      courseDist: courseCount,
                      weeklyData: weeklyData,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _DashboardPathCard(
                  totalLogs: logs.length,
                  totalTasks: totalTasks,
                  completedTasks: completedTasks,
                  reviewCount: reports.length,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DashboardSummaryCard(
                        label: '任务推进',
                        value: totalTasks > 0
                            ? '${(completedTasks * 100 ~/ totalTasks)}%'
                            : '-',
                        caption:
                            '已完成 $completedTasks / $totalTasks，子任务 $completedSubTasks / $totalSubTasks',
                        icon: Icons.route_rounded,
                        accent: accent,
                        isDarkMode: isDarkMode,
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DashboardSummaryCard(
                        label: '回看沉淀',
                        value:
                            '${reports.length + controller.studyNotes.length}',
                        caption:
                            '周报 ${reports.length} · 笔记 ${controller.studyNotes.length} · 课程 ${courseCount.length}',
                        icon: Icons.auto_stories_rounded,
                        accent: StudyUi.secondary,
                        isDarkMode: isDarkMode,
                        compact: true,
                      ),
                    ),
                  ],
                ),
                if (totalSubTasks > 0) ...[
                  const SizedBox(height: 12),
                  StudyCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('子任务进度',
                                  style: TextStyle(
                                      color: textColor,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text('$completedSubTasks / $totalSubTasks 完成',
                                  style: TextStyle(
                                      color: bodyColor, fontSize: 13)),
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
                                value: totalSubTasks > 0
                                    ? completedSubTasks / totalSubTasks
                                    : 0,
                                strokeWidth: 5,
                                backgroundColor: isDarkMode
                                    ? Colors.white12
                                    : const Color(0xFFE8EBF5),
                                color: accent,
                              ),
                              Text(
                                  '${totalSubTasks > 0 ? (completedSubTasks * 100 ~/ totalSubTasks) : 0}%',
                                  style: TextStyle(
                                      color: textColor,
                                      fontSize: 12,
                                      fontWeight: AppTypography.hero)),
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
                  Text('近 7 天学习记录',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  StudyCard(
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
                                    Duration(days: 6 - value.toInt()),
                                  );
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
                // Monthly trend bar
                if (monthLogs > 0) ...[
                  const SizedBox(height: 22),
                  Text('近4周学习趋势',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  StudyCard(
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
                                  Text('${monthlyData[i]}',
                                      style: TextStyle(
                                          color: bodyColor, fontSize: 11)),
                                  const SizedBox(height: 4),
                                  Container(
                                    height: (monthlyData[i] /
                                            (monthlyData.reduce(
                                                    (a, b) => a > b ? a : b) +
                                                1)) *
                                        70,
                                    decoration: BoxDecoration(
                                      color: StudyUi.secondary
                                          .withValues(alpha: 0.55),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(weekLabels[i],
                                      style: TextStyle(
                                          color: bodyColor, fontSize: 9)),
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
                  Text('课程分布',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  StudyCard(
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
                  StudyCard(
                    child: Column(
                      children: courseCount.entries
                          .take(8)
                          .map((e) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                        child: Text(e.key,
                                            style: TextStyle(
                                                color: textColor,
                                                fontSize: 13))),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: accent.withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      child: Text('${e.value}条',
                                          style: TextStyle(
                                              color: accent,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          ), // StudyScreenBackground
        );
      },
    );
  }

  double _weeklyMaxY(List<int> counts) {
    final max = counts.isEmpty ? 1 : counts.reduce((a, b) => a > b ? a : b);
    return (max + 1).toDouble();
  }

  List<BarChartGroupData> _buildWeeklyBarGroups(
      List<int> counts, Color accent) {
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
        const Color(0xFF2F7D78),
        const Color(0xFF4CB9FF),
      ];

  List<String> _buildDashboardSummary({
    required int totalLogs,
    required int totalTasks,
    required int completedTasks,
    required int overdueTasks,
    required int totalSubTasks,
    required int completedSubTasks,
    required int recentLogs,
    required int monthLogs,
    required Map<String, int> courseDist,
    required List<int> weeklyData,
  }) {
    final pct = totalTasks > 0
        ? ((completedTasks / totalTasks) * 100).toStringAsFixed(0)
        : '0';
    final subPct = totalSubTasks > 0
        ? ((completedSubTasks / totalSubTasks) * 100).toStringAsFixed(0)
        : '0';
    final topCourses = (courseDist.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(3)
        .map((e) => '${e.key}: ${e.value} 条')
        .join('、');
    return [
      '学习记录总数：$totalLogs（近 7 天 $recentLogs、近 30 天 $monthLogs）',
      '任务总数：$totalTasks，完成率 $pct%，已逾期 $overdueTasks',
      '子任务：$completedSubTasks / $totalSubTasks（$subPct%）',
      '课程分布（Top 3）：${topCourses.isEmpty ? "无" : topCourses}',
      '近 7 天每日日志数：${weeklyData.join(" / ")}',
    ];
  }

  void _showAiAnalysisSheet(
    BuildContext context, {
    required bool isDarkMode,
    required List<String> summary,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AiDashboardAnalysisSheet(
        isDarkMode: isDarkMode,
        summary: summary,
        aiService: controller.aiStudyService,
      ),
    );
  }
}

class _DashboardNextStepAction {
  const _DashboardNextStepAction({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String eyebrow;
  final String title;
  final String description;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  static _DashboardNextStepAction resolve({
    required int overdueTasks,
    required int recentLogs,
    required int totalTasks,
    required int completedTasks,
    required int reports,
    required int notes,
    VoidCallback? onOpenOverdueTasks,
    VoidCallback? onOpenTasks,
    VoidCallback? onOpenLogs,
    VoidCallback? onOpenLearningMoments,
    VoidCallback? onOpenTaskPlanning,
  }) {
    if (overdueTasks > 0) {
      return _DashboardNextStepAction(
        eyebrow: '先收回来',
        title: '$overdueTasks 项任务需要先处理',
        description: '把最早截止的一项先拉回节奏，再继续看下面的数据。',
        label: '处理过期任务',
        icon: Icons.warning_amber_rounded,
        color: StudyUi.danger,
        onTap: onOpenOverdueTasks ?? onOpenTasks,
      );
    }
    if (recentLogs == 0) {
      return _DashboardNextStepAction(
        eyebrow: '先留一条记录',
        title: '这周还没有学习记录',
        description: '补一次复盘或学习记录，趋势和课程分布才会慢慢清楚。',
        label: '记录一次学习',
        icon: Icons.edit_note_rounded,
        color: StudyUi.pathBlue,
        onTap: onOpenLogs,
      );
    }
    if (totalTasks == 0) {
      return _DashboardNextStepAction(
        eyebrow: '先排一个小任务',
        title: '给这周放一个能完成的小目标',
        description: '从一个课程任务开始，后面就能把记录、专注和回看串起来。',
        label: '安排一个任务',
        icon: Icons.add_task_rounded,
        color: StudyUi.pathViolet,
        onTap: onOpenTaskPlanning ?? onOpenTasks,
      );
    }
    if (completedTasks < totalTasks) {
      return _DashboardNextStepAction(
        eyebrow: '继续往前推',
        title: '把一个任务推进到下一小步',
        description: '任务清单里可以改状态、看拆分步骤，也能先处理临近截止的内容。',
        label: '打开任务清单',
        icon: Icons.flag_rounded,
        color: StudyUi.primary,
        onTap: onOpenTasks ?? onOpenTaskPlanning,
      );
    }
    if (reports + notes > 0) {
      return _DashboardNextStepAction(
        eyebrow: '回看沉淀',
        title: '把最近整理过的内容回看一遍',
        description: '学迹里能看到学习记录、笔记和阶段回顾，方便找下一步。',
        label: '回看学迹',
        icon: Icons.auto_stories_rounded,
        color: StudyUi.secondary,
        onTap: onOpenLearningMoments,
      );
    }
    return _DashboardNextStepAction(
      eyebrow: '保持节奏',
      title: '这周节奏不错，继续整理下一步',
      description: '可以回到学习流程，给接下来的一两天排一个更清楚的小安排。',
      label: '整理下一步',
      icon: Icons.route_rounded,
      color: StudyUi.pathMint,
      onTap: onOpenTaskPlanning ?? onOpenTasks ?? onOpenLogs,
    );
  }
}

class _DashboardNextStepCard extends StatelessWidget {
  const _DashboardNextStepCard({
    required this.action,
    required this.isDarkMode,
  });

  final _DashboardNextStepAction action;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      padding: const EdgeInsets.all(13),
      borderColor: action.color.withValues(alpha: isDarkMode ? 0.24 : 0.14),
      child: Row(
        children: [
          StudyGlassIconNode(
            icon: action.icon,
            accent: action.color,
            size: 42,
            iconSize: 19,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.eyebrow,
                  style: TextStyle(
                    color: action.color,
                    fontSize: 11,
                    fontWeight: AppTypography.title,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  action.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: StudyUi.title(isDarkMode),
                    fontSize: 14,
                    fontWeight: AppTypography.hero,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  action.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: StudyUi.body(isDarkMode),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          action.onTap == null
              ? BadgePill(
                  label: '状态提示',
                  background:
                      action.color.withValues(alpha: isDarkMode ? 0.18 : 0.10),
                  foreground: action.color,
                )
              : StudyActionPill(
                  icon: Icons.arrow_forward_rounded,
                  label: action.label,
                  color: action.color,
                  isDarkMode: isDarkMode,
                  filled: false,
                  onPressed: action.onTap,
                ),
        ],
      ),
    );
  }
}

class _DashboardPathCard extends StatelessWidget {
  const _DashboardPathCard({
    required this.totalLogs,
    required this.totalTasks,
    required this.completedTasks,
    required this.reviewCount,
    required this.isDarkMode,
  });

  final int totalLogs;
  final int totalTasks;
  final int completedTasks;
  final int reviewCount;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final items = [
      _DashboardPathItem(
          '学习', '$totalLogs', Icons.menu_book_rounded, StudyUi.pathBlue),
      _DashboardPathItem(
          '计划', '$totalTasks', Icons.flag_rounded, StudyUi.pathViolet),
      _DashboardPathItem(
          '完成', '$completedTasks', Icons.play_arrow_rounded, StudyUi.pathMint),
      _DashboardPathItem(
          '复盘', '$reviewCount', Icons.star_rounded, StudyUi.pathWarm),
    ];
    return StudyCard(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      borderColor: StudyUi.pathBlue.withValues(alpha: isDarkMode ? 0.18 : 0.12),
      child: SizedBox(
        height: 106,
        child: Stack(
          children: [
            Positioned(
              left: 34,
              right: 34,
              top: 27,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    colors: [
                      StudyUi.pathBlue.withValues(alpha: 0.58),
                      StudyUi.pathCyan.withValues(alpha: 0.58),
                      StudyUi.pathMint.withValues(alpha: 0.58),
                      StudyUi.pathWarm.withValues(alpha: 0.48),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (final item in items)
                  Expanded(
                    child: Column(
                      children: [
                        StudyGlassIconNode(
                          icon: item.icon,
                          accent: item.color,
                          size: 54,
                          iconSize: 22,
                          isDarkMode: isDarkMode,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: StudyUi.title(isDarkMode),
                            fontSize: 12,
                            fontWeight: AppTypography.title,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: item.color,
                            fontSize: 13,
                            fontWeight: AppTypography.hero,
                          ),
                        ),
                      ],
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

class _DashboardPathItem {
  const _DashboardPathItem(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _DashboardSummaryCard extends StatelessWidget {
  const _DashboardSummaryCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.accent,
    required this.isDarkMode,
    this.compact = false,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color accent;
  final bool isDarkMode;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      padding: EdgeInsets.all(compact ? 15 : 17),
      borderColor: accent.withValues(alpha: isDarkMode ? 0.24 : 0.14),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StudyGlassIconNode(
                  icon: icon,
                  accent: accent,
                  size: 38,
                  iconSize: 18,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(height: 12),
                _DashboardSummaryText(
                  label: label,
                  value: value,
                  caption: caption,
                  accent: accent,
                  isDarkMode: isDarkMode,
                ),
              ],
            )
          : Row(
              children: [
                StudyGlassIconNode(
                  icon: icon,
                  accent: accent,
                  size: 50,
                  iconSize: 23,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _DashboardSummaryText(
                    label: label,
                    value: value,
                    caption: caption,
                    accent: accent,
                    isDarkMode: isDarkMode,
                  ),
                ),
              ],
            ),
    );
  }
}

class _DashboardInsightCard extends StatelessWidget {
  const _DashboardInsightCard({
    required this.insight,
    required this.isDarkMode,
    required this.onTap,
  });

  final String insight;
  final bool isDarkMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      padding: const EdgeInsets.all(17),
      borderColor: StudyUi.pathMint.withValues(alpha: isDarkMode ? 0.22 : 0.14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StudyGlassIconNode(
                icon: Icons.lightbulb_rounded,
                accent: StudyUi.pathMint,
                size: 42,
                iconSize: 20,
                isDarkMode: isDarkMode,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '本周洞察',
                  style: TextStyle(
                    color: StudyUi.title(isDarkMode),
                    fontSize: 18,
                    fontWeight: AppTypography.hero,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            insight,
            style: TextStyle(
              color: StudyUi.body(isDarkMode),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          _DashboardActionPill(
            label: '展开建议',
            icon: Icons.chevron_right_rounded,
            accent: StudyUi.pathMint,
            isDarkMode: isDarkMode,
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

class _DashboardShortcutRow extends StatelessWidget {
  const _DashboardShortcutRow({
    required this.isDarkMode,
    required this.onOpenKnowledgeMap,
    required this.onOpenWeeklyReview,
    required this.onOpenLearningMoments,
  });

  final bool isDarkMode;
  final VoidCallback? onOpenKnowledgeMap;
  final VoidCallback? onOpenWeeklyReview;
  final VoidCallback? onOpenLearningMoments;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '继续看',
            style: TextStyle(
              color: StudyUi.title(isDarkMode),
              fontWeight: AppTypography.hero,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DashboardActionPill(
                label: '知识地图',
                icon: Icons.account_tree_rounded,
                accent: StudyUi.pathCyan,
                isDarkMode: isDarkMode,
                onTap: onOpenKnowledgeMap,
              ),
              _DashboardActionPill(
                label: '7天回顾',
                icon: Icons.inventory_2_rounded,
                accent: StudyUi.pathMint,
                isDarkMode: isDarkMode,
                onTap: onOpenWeeklyReview,
              ),
              _DashboardActionPill(
                label: '学迹动态',
                icon: Icons.dynamic_feed_rounded,
                accent: StudyUi.pathViolet,
                isDarkMode: isDarkMode,
                onTap: onOpenLearningMoments,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardSummaryText extends StatelessWidget {
  const _DashboardSummaryText({
    required this.label,
    required this.value,
    required this.caption,
    required this.accent,
    required this.isDarkMode,
  });

  final String label;
  final String value;
  final String caption;
  final Color accent;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: StudyUi.body(isDarkMode),
            fontSize: 12,
            fontWeight: AppTypography.title,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: StudyUi.title(isDarkMode),
            fontSize: 24,
            fontWeight: AppTypography.hero,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          caption,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: StudyUi.body(isDarkMode),
            fontSize: 11,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _AiDashboardAnalysisSheet extends StatefulWidget {
  const _AiDashboardAnalysisSheet({
    required this.isDarkMode,
    required this.summary,
    required this.aiService,
  });

  final bool isDarkMode;
  final List<String> summary;
  final AiStudyService aiService;

  @override
  State<_AiDashboardAnalysisSheet> createState() =>
      _AiDashboardAnalysisSheetState();
}

class _AiDashboardAnalysisSheetState extends State<_AiDashboardAnalysisSheet> {
  String _text = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reply = await widget.aiService.generateAssistantReply(
        input: '基于以下学习数据给出 3-5 条具体、可执行的学习建议，使用 Markdown 列表，每条不超过 30 字。',
        context: widget.summary,
        purpose: 'note',
      );
      if (!mounted) return;
      setState(() {
        _text = reply.trim();
        _loading = false;
      });
    } on AiServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '学习建议暂时没有整理成功，请稍后再试';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = StudyUi.title(widget.isDarkMode);
    final bodyColor = StudyUi.body(widget.isDarkMode);
    final size = MediaQuery.of(context).size;
    return Container(
      height: size.height * 0.7,
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.isDarkMode
              ? [
                  StudyUi.surface(true),
                  StudyUi.background(true),
                ]
              : [
                  Colors.white.withValues(alpha: 0.98),
                  StudyUi.background(false),
                ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: StudyUi.border(widget.isDarkMode),
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: widget.isDarkMode ? Colors.white24 : Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              StudyGlassIconNode(
                icon: Icons.lightbulb_rounded,
                asset: AppAssets.aiSuggestionIcon,
                accent: StudyUi.primary,
                size: 42,
                iconSize: 22,
                isDarkMode: widget.isDarkMode,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '学习建议',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: AppTypography.title,
                  ),
                ),
              ),
              _DashboardActionPill(
                label: '重新生成',
                icon: Icons.refresh_rounded,
                accent: StudyUi.primary,
                isDarkMode: widget.isDarkMode,
                onTap: _loading ? null : _fetch,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text('正在整理学习数据...',
                            style: TextStyle(color: bodyColor, fontSize: 13)),
                      ],
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            StudyGlassIconNode(
                              icon: Icons.error_outline_rounded,
                              accent: StudyUi.danger,
                              size: 54,
                              iconSize: 26,
                              isDarkMode: widget.isDarkMode,
                            ),
                            const SizedBox(height: 12),
                            Text(_error!,
                                style: TextStyle(
                                    color: bodyColor,
                                    fontSize: 13,
                                    height: 1.5),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            _DashboardActionPill(
                              label: '重试',
                              icon: Icons.refresh_rounded,
                              accent: StudyUi.primary,
                              isDarkMode: widget.isDarkMode,
                              onTap: _fetch,
                            ),
                          ],
                        ),
                      )
                    : Markdown(
                        data: _text.isEmpty ? '（暂时没有建议内容）' : _text,
                        styleSheet: MarkdownStyleSheet.fromTheme(
                          Theme.of(context).copyWith(
                            textTheme: Theme.of(context).textTheme.apply(
                                  bodyColor: bodyColor,
                                  displayColor: textColor,
                                ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _DashboardActionPill extends StatelessWidget {
  const _DashboardActionPill({
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
    final enabled = onTap != null;
    final fg = enabled ? accent : StudyUi.muted(isDarkMode);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: enabled
                ? StudyUi.chipBackground(accent, isDarkMode)
                : StudyUi.surfaceAlt(isDarkMode),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: enabled
                  ? accent.withValues(alpha: isDarkMode ? 0.34 : 0.22)
                  : StudyUi.border(isDarkMode),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg,
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
