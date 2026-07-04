import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/study_log_item.dart';
import '../../models/study_task_item.dart';
import '../../models/weekly_report_item.dart';
import '../../services/report_export_service.dart';
import '../../theme/app_theme.dart';
import '../shared/app_assets.dart';
import '../shared/common_widgets.dart';
import '../shared/markdown_styles.dart';

class CourseArchivePage extends StatelessWidget {
  const CourseArchivePage({
    super.key,
    required this.isDarkMode,
    required this.controller,
    required this.onViewCourse,
  });

  final bool isDarkMode;
  final AppDataController controller;
  final void Function(String courseName) onViewCourse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        const accent = StudyUi.pathBlue;
        final courses = controller.courseNames;
        final allReports = controller.weeklyReports;
        // 按 createdAt 倒序排列（最新的在前）
        final reports = List<WeeklyReportItem>.from(allReports)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final totalTasks = courses.fold<int>(
          0,
          (sum, course) => sum + controller.tasksForCourse(course).length,
        );
        final totalLogs = courses.fold<int>(
          0,
          (sum, course) => sum + controller.logsForCourse(course).length,
        );

        return RefreshIndicator(
          onRefresh: controller.load,
          child: StudyScreenBackground(
            isDarkMode: isDarkMode,
            accent: accent,
            child: ListView(
              key: const Key('page_course_archive'),
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 124),
              children: [
                _archiveHero(
                  courseCount: courses.length,
                  reportCount: reports.length,
                  taskCount: totalTasks,
                  logCount: totalLogs,
                ),
                const SizedBox(height: 18),
                StudySectionHeader(
                  title: '课程路径',
                  subtitle: '按课程回到任务、复盘和学习记录。',
                  trailing: _ArchiveIconButton(
                    tooltip: '添加课程',
                    onPressed: () => _showAddCourseDialog(context),
                    icon: Icons.add_rounded,
                    accent: accent,
                    isDarkMode: isDarkMode,
                  ),
                ),
                const SizedBox(height: 14),
                if (courses.isEmpty)
                  const StudyEmptyState(
                    key: Key('courses_empty_state'),
                    asset: AppAssets.uiRefreshFeatureArchive,
                    title: '还没有课程归档',
                    message: '添加学习任务或学习记录时填写课程名，这里会自动汇总。',
                    compact: true,
                  )
                else ...[
                  _courseArchiveTimeline(context, courses),
                  const SizedBox(height: 12),
                  _courseArchivePreviewCard(context, courses.first),
                ],
                const SizedBox(height: 24),
                StudySectionHeader(
                  title: '每周回顾',
                  subtitle: reports.isEmpty
                      ? '首页整理每周回顾后，会自动进入这条复盘时间线。'
                      : '${reports.length} 份回顾，考前可以快速翻看。',
                ),
                const SizedBox(height: 14),
                if (reports.isEmpty)
                  StudyCard(
                    key: const Key('reports_empty_state'),
                    child: Text(
                      '暂无保存的每周回顾。在首页整理后保存，就会出现在这里。',
                      style: TextStyle(
                        color: StudyUi.body(isDarkMode),
                        height: 1.55,
                      ),
                    ),
                  )
                else ...[
                  _reportActionBar(context, reports),
                  const SizedBox(height: 12),
                  for (var i = 0; i < reports.length; i++) ...[
                    _weeklyReportCard(context, reports[i]),
                    if (i != reports.length - 1) const SizedBox(height: 12),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _archiveHero({
    required int courseCount,
    required int reportCount,
    required int taskCount,
    required int logCount,
  }) {
    const accent = StudyUi.pathBlue;
    return StudyPathHero(
      isDarkMode: isDarkMode,
      accent: accent,
      badge: '学习资料管家',
      title: '课程归档',
      subtitle: '课程、每周回顾和资料按课程名归档，期末复盘时从这里回到完整学习记录。',
      icon: Icons.inventory_2_rounded,
      steps: const ['课程', '回顾', '复盘'],
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StudyPathMetricPill(
                  label: '课程',
                  value: '$courseCount',
                  icon: Icons.school_rounded,
                  color: accent,
                  isDarkMode: isDarkMode,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StudyPathMetricPill(
                  label: '每周回顾',
                  value: '$reportCount',
                  icon: Icons.summarize_rounded,
                  color: StudyUi.pathViolet,
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
                  label: '任务',
                  value: '$taskCount',
                  icon: Icons.checklist_rounded,
                  color: StudyUi.pathMint,
                  isDarkMode: isDarkMode,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StudyPathMetricPill(
                  label: '记录',
                  value: '$logCount',
                  icon: Icons.auto_stories_rounded,
                  color: StudyUi.pathCyan,
                  isDarkMode: isDarkMode,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _courseArchiveTimeline(BuildContext context, List<String> courses) {
    const accent = StudyUi.pathBlue;
    return StudyCard(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      radius: 28,
      borderColor: accent.withValues(alpha: isDarkMode ? 0.18 : 0.14),
      child: Column(
        children: [
          for (var i = 0; i < courses.length; i++)
            _courseArchiveCard(
              context,
              course: courses[i],
              index: i,
              isFirst: i == 0,
              isLast: i == courses.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _courseArchivePreviewCard(BuildContext context, String course) {
    final tasks = controller.tasksForCourse(course);
    final logs = controller.logsForCourse(course);
    final progress = _courseProgress(tasks, logs.length);
    final latestLog = logs.isEmpty ? null : logs.first;
    final pendingCount = tasks
        .where((task) => task.effectiveStatus != StudyTaskStatus.completed)
        .length;
    final completedSteps = tasks.fold<int>(
      0,
      (sum, task) => sum + task.completedCount,
    );
    final totalSteps = tasks.fold<int>(
      0,
      (sum, task) => sum + task.totalCount,
    );

    return StudyCard(
      padding: const EdgeInsets.all(16),
      radius: 26,
      borderColor: StudyUi.pathViolet.withValues(alpha: isDarkMode ? 0.18 : 0.14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '课程详情',
                style: TextStyle(
                  color: StudyUi.title(isDarkMode),
                  fontSize: 17,
                  fontWeight: AppTypography.hero,
                ),
              ),
              const Spacer(),
              BadgePill(
                label: progress >= 1 ? '已归档' : '进行中',
                background: StudyUi.chipBackground(
                  progress >= 1 ? StudyUi.pathMint : StudyUi.pathBlue,
                  isDarkMode,
                ),
                foreground: progress >= 1 ? StudyUi.pathMint : StudyUi.pathBlue,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      StudyUi.pathBlue.withValues(alpha: isDarkMode ? 0.22 : 0.18),
                      StudyUi.pathViolet.withValues(alpha: isDarkMode ? 0.18 : 0.12),
                      StudyUi.pathCyan.withValues(alpha: isDarkMode ? 0.16 : 0.10),
                    ],
                  ),
                  border: Border.all(color: StudyUi.border(isDarkMode)),
                ),
                child: Center(
                  child: StudyGlassIconNode(
                    icon: _courseIcon(0),
                    accent: StudyUi.pathBlue,
                    size: 52,
                    iconSize: 23,
                    isDarkMode: isDarkMode,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: StudyUi.title(isDarkMode),
                        fontSize: 19,
                        fontWeight: AppTypography.hero,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      latestLog == null
                          ? '最近进展会在完成复盘后出现'
                          : '最近进展：${_clipCourseText(latestLog.content, 28)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: StudyUi.body(isDarkMode),
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 6,
                              backgroundColor: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.10)
                                  : const Color(0xFFE7ECFF),
                              color: StudyUi.pathViolet,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${(progress * 100).round()}%',
                          style: TextStyle(
                            color: StudyUi.title(isDarkMode),
                            fontWeight: AppTypography.title,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _CoursePreviewMetric(
                label: '任务',
                value: '${tasks.length}',
                icon: Icons.checklist_rounded,
                color: StudyUi.pathViolet,
                isDarkMode: isDarkMode,
              ),
              _CoursePreviewMetric(
                label: '待推进',
                value: '$pendingCount',
                icon: Icons.play_arrow_rounded,
                color: StudyUi.pathWarm,
                isDarkMode: isDarkMode,
              ),
              _CoursePreviewMetric(
                label: '步骤',
                value: totalSteps == 0 ? '0' : '$completedSteps/$totalSteps',
                icon: Icons.route_rounded,
                color: StudyUi.pathMint,
                isDarkMode: isDarkMode,
              ),
              _CoursePreviewMetric(
                label: '记录',
                value: '${logs.length}',
                icon: Icons.auto_stories_rounded,
                color: StudyUi.pathCyan,
                isDarkMode: isDarkMode,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ArchiveActionPill(
            icon: Icons.add_circle_outline_rounded,
            label: '打开课程',
            accent: StudyUi.pathBlue,
            isDarkMode: isDarkMode,
            isFilled: true,
            expand: true,
            onPressed: () => onViewCourse(course),
          ),
        ],
      ),
    );
  }

  Widget _courseArchiveCard(
    BuildContext context, {
    required String course,
    required int index,
    required bool isFirst,
    required bool isLast,
  }) {
    const accents = [
      StudyUi.pathBlue,
      StudyUi.pathViolet,
      StudyUi.pathCyan,
      StudyUi.pathMint,
    ];
    final accent = accents[index % accents.length];
    final icon = _courseIcon(index);
    final tasks = controller.tasksForCourse(course);
    final logs = controller.logsForCourse(course);
    final taskCount = tasks.length;
    final logCount = logs.length;
    final latestDate = _latestCourseDate(tasks, logs);
    final progress = _courseProgress(tasks, logCount);
    final completedCount = tasks
        .where((task) => task.effectiveStatus == StudyTaskStatus.completed)
        .length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('course_item_$course'),
        borderRadius: BorderRadius.circular(22),
        onTap: () => onViewCourse(course),
        onLongPress: () => _showDeleteCourseConfirm(context, course),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 68,
                height: 92,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: isFirst ? 46 : 0,
                      bottom: isLast ? 46 : 0,
                      child: Container(
                        width: 2,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              accent.withValues(alpha: 0.18),
                              StudyUi.pathCyan.withValues(alpha: 0.28),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 4,
                      child: StudyGlassIconNode(
                        icon: icon,
                        accent: accent,
                        size: 54,
                        iconSize: 22,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                    Positioned(
                      left: 30,
                      top: isFirst ? 8 : 2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.82),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.44),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
                  decoration: BoxDecoration(
                    color: StudyUi.surface(isDarkMode)
                        .withValues(alpha: isDarkMode ? 0.64 : 0.74),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: accent.withValues(alpha: isDarkMode ? 0.20 : 0.16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              course,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: StudyUi.title(isDarkMode),
                                fontSize: 17,
                                fontWeight: AppTypography.hero,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              latestDate == null
                                  ? '最近学习 待开始'
                                  : '最近学习 ${_fmtDate(latestDate)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: StudyUi.body(isDarkMode),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                BadgePill(
                                  label: taskCount == 0
                                      ? '0 个任务'
                                      : '$completedCount/$taskCount 任务',
                                  background: StudyUi.chipBackground(
                                    accent,
                                    isDarkMode,
                                  ),
                                  foreground: accent,
                                ),
                                BadgePill(
                                  label: '$logCount 条记录',
                                  background: StudyUi.chipBackground(
                                    StudyUi.pathCyan,
                                    isDarkMode,
                                  ),
                                  foreground: StudyUi.pathCyan,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: StudyUi.chipBackground(accent, isDarkMode),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: accent.withValues(alpha: 0.18)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(progress * 100).round()}%',
                              style: TextStyle(
                                color: accent,
                                fontSize: 12,
                                fontWeight: AppTypography.hero,
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 3,
                                backgroundColor: accent.withValues(alpha: 0.12),
                                valueColor: AlwaysStoppedAnimation<Color>(accent),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: StudyUi.muted(isDarkMode),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reportActionBar(
    BuildContext context,
    List<WeeklyReportItem> reports,
  ) {
    const accent = StudyUi.pathViolet;
    return StudyCard(
      padding: const EdgeInsets.all(12),
      borderColor: accent.withValues(alpha: isDarkMode ? 0.18 : 0.14),
      child: Row(
        children: [
          Expanded(
            child: _ArchiveActionPill(
              icon: Icons.copy_all_rounded,
              label: '复制全部回顾',
              accent: accent,
              isDarkMode: isDarkMode,
              expand: true,
              onPressed: () => _copyAllReports(context, reports),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ArchiveActionPill(
              icon: Icons.description_rounded,
              label: '保存为文档',
              accent: accent,
              isDarkMode: isDarkMode,
              expand: true,
              onPressed: () => _exportAllReportsMarkdown(context, reports),
            ),
          ),
        ],
      ),
    );
  }

  Widget _weeklyReportCard(BuildContext context, WeeklyReportItem report) {
    const accent = StudyUi.pathViolet;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('report_item_${report.id}'),
        borderRadius: BorderRadius.circular(24),
        onTap: () => _showReportDetail(context, report),
        child: StudyCard(
          padding: const EdgeInsets.all(16),
          radius: 22,
          borderColor: accent.withValues(alpha: isDarkMode ? 0.18 : 0.14),
          child: Row(
            children: [
              StudyGlassIconNode(
                icon: Icons.summarize_rounded,
                accent: accent,
                size: 48,
                iconSize: 21,
                isDarkMode: isDarkMode,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_fmtDate(report.startDate)} - ${_fmtDate(report.endDate)}',
                      style: TextStyle(
                        color: StudyUi.title(isDarkMode),
                        fontSize: 15,
                        fontWeight: AppTypography.hero,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${report.sourceLogIds.length} 条学习记录汇总',
                      style: TextStyle(
                        color: StudyUi.body(isDarkMode),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: StudyUi.muted(isDarkMode),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyAllReports(
    BuildContext context,
    List<WeeklyReportItem> reports,
  ) {
    final allContent = reports
        .map(
          (report) =>
              '--- ${_fmtDate(report.startDate)} ~ ${_fmtDate(report.endDate)} ---\n${report.content}',
        )
        .join('\n\n');
    Clipboard.setData(ClipboardData(text: allContent));
    StudyToast.show(context, '全部回顾已复制到剪贴板');
  }

  void _showReportDetail(BuildContext context, WeeklyReportItem report) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (detailContext) => Scaffold(
          backgroundColor: StudyUi.background(isDarkMode),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: StudyUi.title(isDarkMode),
            elevation: 0,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StudyGlassIconNode(
                  icon: Icons.summarize_rounded,
                  accent: StudyUi.pathViolet,
                  size: 32,
                  iconSize: 16,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(width: 10),
                const Text(
                  '每周回顾详情',
                  style: TextStyle(fontWeight: AppTypography.title),
                ),
              ],
            ),
            actions: [
              _ArchiveIconButton(
                icon: Icons.copy_rounded,
                tooltip: '复制回顾',
                accent: StudyUi.pathViolet,
                isDarkMode: isDarkMode,
                onPressed: () => _copyReportContent(detailContext, report),
              ),
              _ArchiveIconButton(
                icon: Icons.description_rounded,
                tooltip: '保存为文档',
                accent: StudyUi.pathViolet,
                isDarkMode: isDarkMode,
                onPressed: () => _exportReport(
                  detailContext,
                  report,
                  asPdf: false,
                ),
              ),
              _ArchiveIconButton(
                icon: Icons.picture_as_pdf_rounded,
                tooltip: '保存为 PDF',
                accent: StudyUi.pathViolet,
                isDarkMode: isDarkMode,
                onPressed: () => _exportReport(
                  detailContext,
                  report,
                  asPdf: true,
                ),
              ),
            ],
          ),
          body: StudyScreenBackground(
            isDarkMode: isDarkMode,
            accent: StudyUi.pathViolet,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: StudyCard(
                child: MarkdownBody(
                  data: report.content,
                  selectable: true,
                  styleSheet: buildStudyMarkdownStyleSheet(
                    isDarkMode: isDarkMode,
                    bodyHeight: 1.65,
                  ),
                  extensionSet: studyMarkdownExtensionSet,
                  builders: buildStudyMarkdownBuilders(
                    isDarkMode: isDarkMode,
                    bodyFontSize: 14,
                  ),
                  sizedImageBuilder: (config) => buildStudyMarkdownImage(
                    config.uri,
                    config.title,
                    config.alt,
                    isDarkMode: isDarkMode,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _copyReportContent(BuildContext context, WeeklyReportItem report) {
    Clipboard.setData(ClipboardData(text: report.content));
    StudyToast.show(context, '每周回顾已复制到剪贴板');
  }

  Future<void> _exportReport(
    BuildContext context,
    WeeklyReportItem report, {
    required bool asPdf,
  }) async {
    try {
      final service = const ReportExportService();
      final file = asPdf
          ? await service.exportWeeklyReportPdf(report)
          : await service.exportWeeklyReportMarkdown(report);
      if (!context.mounted) return;
      await _showExportResult(
        context,
        kind: asPdf ? 'PDF' : '文档',
        path: file.path,
      );
    } catch (error) {
      if (!context.mounted) return;
      _showExportError(context, error);
    }
  }

  Future<void> _exportAllReportsMarkdown(
    BuildContext context,
    List<WeeklyReportItem> reports,
  ) async {
    try {
      final service = const ReportExportService();
      final file = await service.exportAllReportsMarkdown(reports);
      if (!context.mounted) return;
      await _showExportResult(
        context,
        kind: '全部回顾文档',
        path: file.path,
      );
    } catch (error) {
      if (!context.mounted) return;
      _showExportError(context, error);
    }
  }

  Future<void> _showExportResult(
    BuildContext context, {
    required String kind,
    required String path,
  }) async {
    await Clipboard.setData(ClipboardData(text: path));
    if (!context.mounted) return;
    StudyToast.show(context, '已保存 $kind，保存位置已复制');
  }

  void _showExportError(BuildContext context, Object error) {
    if (!context.mounted) return;
    StudyToast.dialog(
      context,
      title: '保存失败',
      message: '这次没有保存成功，请稍后再试。',
    );
  }

  void _showAddCourseDialog(BuildContext context) {
    final accent = controller.primaryColor;
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => _ArchiveDialogSurface(
        isDarkMode: isDarkMode,
        accent: accent,
        icon: Icons.add_rounded,
        title: '添加课程',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              style: TextStyle(color: StudyUi.title(isDarkMode)),
              decoration: _archiveInputDecoration(
                hintText: '课程名称',
                accent: accent,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _ArchiveActionPill(
                  icon: Icons.close_rounded,
                  label: '取消',
                  accent: StudyUi.muted(isDarkMode),
                  isDarkMode: isDarkMode,
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                const Spacer(),
                _ArchiveActionPill(
                  icon: Icons.check_rounded,
                  label: '添加',
                  accent: accent,
                  isDarkMode: isDarkMode,
                  isFilled: true,
                  onPressed: () {
                    final name = ctrl.text.trim();
                    if (name.isNotEmpty) {
                      controller.addCourse(name);
                    }
                    Navigator.of(ctx).pop();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteCourseConfirm(BuildContext context, String course) {
    showDialog(
      context: context,
      builder: (ctx) => _ArchiveDialogSurface(
        isDarkMode: isDarkMode,
        accent: StudyUi.danger,
        icon: Icons.delete_outline_rounded,
        title: '删除课程',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '确定删除课程「$course」吗？\n\n仅删除课程标签，不会删除已有的任务和日志。',
              style: TextStyle(
                color: StudyUi.body(isDarkMode),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _ArchiveActionPill(
                  icon: Icons.close_rounded,
                  label: '取消',
                  accent: StudyUi.muted(isDarkMode),
                  isDarkMode: isDarkMode,
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                const Spacer(),
                _ArchiveActionPill(
                  icon: Icons.delete_rounded,
                  label: '删除',
                  accent: StudyUi.danger,
                  isDarkMode: isDarkMode,
                  isFilled: true,
                  onPressed: () {
                    controller.deleteCourse(course);
                    Navigator.of(ctx).pop();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _archiveInputDecoration({
    required String hintText,
    required Color accent,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: StudyUi.muted(isDarkMode)),
      filled: true,
      fillColor: StudyUi.surfaceAlt(isDarkMode),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: StudyUi.border(isDarkMode)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: StudyUi.border(isDarkMode)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: accent.withValues(alpha: 0.42)),
      ),
    );
  }
}

class CourseDetailPage extends StatelessWidget {
  const CourseDetailPage({
    super.key,
    required this.courseName,
    required this.isDarkMode,
    required this.controller,
  });

  final String courseName;
  final bool isDarkMode;
  final AppDataController controller;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.load,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          const accent = StudyUi.pathBlue;
          final tasks = controller.tasksForCourse(courseName);
          final logs = controller.logsForCourse(courseName);

          return Scaffold(
            backgroundColor: StudyUi.background(isDarkMode),
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              foregroundColor: StudyUi.title(isDarkMode),
              elevation: 0,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StudyGlassIconNode(
                    icon: Icons.school_rounded,
                    accent: accent,
                    size: 32,
                    iconSize: 16,
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      courseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: AppTypography.title),
                    ),
                  ),
                ],
              ),
            ),
            body: StudyScreenBackground(
              isDarkMode: isDarkMode,
              accent: accent,
              child: ListView(
                key: const Key('page_course_detail'),
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 40),
                children: [
                  _detailHero(tasks.length, logs.length),
                  const SizedBox(height: 14),
                  _courseOverviewCard(tasks, logs),
                  const SizedBox(height: 18),
                  StudySectionHeader(
                    title: '相关任务',
                    subtitle: tasks.isEmpty
                        ? '该课程还没有任务，后续安排会显示在这里。'
                        : '${tasks.length} 项安排，按课程资料线索收纳。',
                  ),
                  const SizedBox(height: 12),
                  if (tasks.isEmpty)
                    StudyCard(
                      child: Text(
                        '该课程暂无相关任务。',
                        style: TextStyle(color: StudyUi.body(isDarkMode)),
                      ),
                    )
                  else
                    for (var i = 0; i < tasks.length; i++) ...[
                      _taskArchiveCard(tasks[i], index: i),
                      if (i != tasks.length - 1) const SizedBox(height: 10),
                    ],
                  const SizedBox(height: 18),
                  StudySectionHeader(
                    title: '学习记录',
                    subtitle: logs.isEmpty
                        ? '完成复盘后，会沉淀为这门课的记录。'
                        : '${logs.length} 条复盘记录，可打开查看详情。',
                  ),
                  const SizedBox(height: 12),
                  if (logs.isEmpty)
                    StudyCard(
                      child: Text(
                        '该课程暂无学习记录。',
                        style: TextStyle(color: StudyUi.body(isDarkMode)),
                      ),
                    )
                  else
                    for (final log in logs) ...[
                      StudyLogSummaryCard(
                        log: log,
                        isDarkMode: isDarkMode,
                        showCourse: false,
                        maxLines: 2,
                        onTap: () => showStudyLogDetailDialog(context, log),
                      ),
                      if (log != logs.last) const SizedBox(height: 10),
                    ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _courseOverviewCard(
    List<StudyTaskItem> tasks,
    List<StudyLogItem> logs,
  ) {
    final progress = _courseProgress(tasks, logs.length);
    final latestLog = logs.isEmpty ? null : logs.first;
    final latestDate = _latestCourseDate(tasks, logs);
    final pendingCount = tasks
        .where((task) => task.effectiveStatus != StudyTaskStatus.completed)
        .length;
    final completedSteps = tasks.fold<int>(
      0,
      (sum, task) => sum + task.completedCount,
    );
    final totalSteps = tasks.fold<int>(
      0,
      (sum, task) => sum + task.totalCount,
    );

    return StudyCard(
      padding: const EdgeInsets.all(16),
      radius: 26,
      borderColor: StudyUi.pathBlue.withValues(alpha: isDarkMode ? 0.18 : 0.14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '这门课的学习路径',
                style: TextStyle(
                  color: StudyUi.title(isDarkMode),
                  fontSize: 17,
                  fontWeight: AppTypography.hero,
                ),
              ),
              const Spacer(),
              BadgePill(
                label: latestDate == null ? '待学习' : _fmtDate(latestDate),
                background: StudyUi.chipBackground(StudyUi.pathBlue, isDarkMode),
                foreground: StudyUi.pathBlue,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      StudyUi.pathBlue.withValues(alpha: isDarkMode ? 0.22 : 0.18),
                      StudyUi.pathCyan.withValues(alpha: isDarkMode ? 0.16 : 0.10),
                    ],
                  ),
                  border: Border.all(color: StudyUi.border(isDarkMode)),
                ),
                child: Center(
                  child: StudyGlassIconNode(
                    icon: Icons.route_rounded,
                    accent: StudyUi.pathBlue,
                    size: 50,
                    iconSize: 22,
                    isDarkMode: isDarkMode,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '最近进展',
                      style: TextStyle(
                        color: StudyUi.title(isDarkMode),
                        fontSize: 15,
                        fontWeight: AppTypography.title,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      latestLog == null
                          ? '完成复盘后，这里会显示这门课最近沉淀的内容。'
                          : _clipCourseText(latestLog.content, 44),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: StudyUi.body(isDarkMode),
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 6,
                              backgroundColor: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.10)
                                  : const Color(0xFFE7ECFF),
                              color: StudyUi.pathBlue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${(progress * 100).round()}%',
                          style: TextStyle(
                            color: StudyUi.title(isDarkMode),
                            fontWeight: AppTypography.title,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _CoursePreviewMetric(
                label: '任务',
                value: '${tasks.length}',
                icon: Icons.checklist_rounded,
                color: StudyUi.pathViolet,
                isDarkMode: isDarkMode,
              ),
              _CoursePreviewMetric(
                label: '待推进',
                value: '$pendingCount',
                icon: Icons.play_arrow_rounded,
                color: StudyUi.pathWarm,
                isDarkMode: isDarkMode,
              ),
              _CoursePreviewMetric(
                label: '步骤',
                value: totalSteps == 0 ? '0' : '$completedSteps/$totalSteps',
                icon: Icons.route_rounded,
                color: StudyUi.pathMint,
                isDarkMode: isDarkMode,
              ),
              _CoursePreviewMetric(
                label: '记录',
                value: '${logs.length}',
                icon: Icons.auto_stories_rounded,
                color: StudyUi.pathCyan,
                isDarkMode: isDarkMode,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailHero(int taskCount, int logCount) {
    const accent = StudyUi.pathBlue;
    return StudyPathHero(
      isDarkMode: isDarkMode,
      accent: accent,
      badge: '课程详情',
      title: courseName,
      subtitle: '把这门课的任务、复盘和学习记录收在同一条资料路径里。',
      icon: Icons.school_rounded,
      steps: const ['任务', '记录', '回看'],
      child: Row(
        children: [
          Expanded(
            child: StudyPathMetricPill(
              label: '相关任务',
              value: '$taskCount',
              icon: Icons.checklist_rounded,
              color: StudyUi.pathMint,
              isDarkMode: isDarkMode,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StudyPathMetricPill(
              label: '学习记录',
              value: '$logCount',
              icon: Icons.auto_stories_rounded,
              color: StudyUi.pathCyan,
              isDarkMode: isDarkMode,
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskArchiveCard(StudyTaskItem task, {required int index}) {
    final status = task.effectiveStatus;
    final accent = _taskAccent(status, index);
    return StudyCard(
      padding: const EdgeInsets.all(16),
      radius: 22,
      borderColor: accent.withValues(alpha: isDarkMode ? 0.18 : 0.14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StudyGlassIconNode(
            icon: task.type.icon,
            accent: accent,
            size: 44,
            iconSize: 19,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: StudyUi.title(isDarkMode),
                          fontSize: 16,
                          fontWeight: AppTypography.hero,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    BadgePill(
                      label: status.label,
                      background: StudyUi.chipBackground(accent, isDarkMode),
                      foreground: accent,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    BadgePill(
                      label: task.type.label,
                      background: StudyUi.chipBackground(
                        StudyUi.pathBlue,
                        isDarkMode,
                      ),
                      foreground: StudyUi.pathBlue,
                    ),
                    BadgePill(
                      label: '截止 ${_fmtDate(task.deadline)}',
                      background: StudyUi.chipBackground(
                        StudyUi.pathWarm,
                        isDarkMode,
                      ),
                      foreground: StudyUi.pathWarm,
                    ),
                  ],
                ),
                if (task.note.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    task.note.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: StudyUi.body(isDarkMode),
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
                if (task.isTaskSet) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: task.progress.clamp(0.0, 1.0).toDouble(),
                      minHeight: 6,
                      backgroundColor: isDarkMode
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFE7ECFF),
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${task.completedCount}/${task.totalCount} 个步骤完成',
                    style: TextStyle(
                      color: StudyUi.muted(isDarkMode),
                      fontSize: 11,
                      fontWeight: AppTypography.title,
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

  Color _taskAccent(StudyTaskStatus status, int index) {
    if (status == StudyTaskStatus.completed) return StudyUi.pathMint;
    if (status == StudyTaskStatus.inProgress) return StudyUi.pathCyan;
    const accents = [StudyUi.pathBlue, StudyUi.pathViolet, StudyUi.pathWarm];
    return accents[index % accents.length];
  }
}

class _CoursePreviewMetric extends StatelessWidget {
  const _CoursePreviewMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDarkMode,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 76, maxWidth: 104),
      padding: const EdgeInsets.fromLTRB(10, 11, 10, 10),
      decoration: BoxDecoration(
        color: StudyUi.surface(isDarkMode)
            .withValues(alpha: isDarkMode ? 0.62 : 0.70),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StudyGlassIconNode(
            icon: icon,
            accent: color,
            size: 34,
            iconSize: 16,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: StudyUi.title(isDarkMode),
              fontSize: 18,
              fontWeight: AppTypography.hero,
            ),
          ),
          const SizedBox(height: 2),
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
        ],
      ),
    );
  }
}

IconData _courseIcon(int index) {
  const icons = [
    Icons.calculate_rounded,
    Icons.eco_rounded,
    Icons.science_rounded,
    Icons.menu_book_rounded,
    Icons.biotech_rounded,
    Icons.architecture_rounded,
  ];
  return icons[index % icons.length];
}

DateTime? _latestCourseDate(
  List<StudyTaskItem> tasks,
  List<StudyLogItem> logs,
) {
  DateTime? latest;
  for (final log in logs) {
    if (latest == null || log.date.isAfter(latest)) latest = log.date;
  }
  for (final task in tasks) {
    if (latest == null || task.updatedAt.isAfter(latest)) latest = task.updatedAt;
  }
  return latest;
}

double _courseProgress(List<StudyTaskItem> tasks, int logCount) {
  if (tasks.isEmpty) {
    if (logCount == 0) return 0;
    final logOnlyProgress = 0.28 + logCount.clamp(0, 4).toDouble() * 0.12;
    return logOnlyProgress.clamp(0.0, 0.76).toDouble();
  }
  final taskProgress =
      tasks.fold<double>(0, (sum, task) => sum + task.progress) / tasks.length;
  final logBoost = logCount.clamp(0, 4).toDouble() * 0.04;
  return (taskProgress * 0.84 + logBoost).clamp(0.0, 1.0).toDouble();
}

String _clipCourseText(String value, int maxLength) {
  final trimmed = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (trimmed.isEmpty) return '这门课还没有可展示的进展。';
  if (trimmed.length <= maxLength) return trimmed;
  return '${trimmed.substring(0, maxLength)}...';
}

class _ArchiveIconButton extends StatelessWidget {
  const _ArchiveIconButton({
    required this.icon,
    required this.tooltip,
    required this.accent,
    required this.isDarkMode,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color accent;
  final bool isDarkMode;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: enabled ? 1 : 0.48,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onPressed,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: enabled
                  ? StudyUi.chipBackground(accent, isDarkMode)
                  : StudyUi.surfaceAlt(isDarkMode),
              shape: BoxShape.circle,
              border: Border.all(
                color: enabled
                    ? accent.withValues(alpha: isDarkMode ? 0.24 : 0.18)
                    : StudyUi.border(isDarkMode),
              ),
            ),
            child: Icon(
              icon,
              color: enabled ? accent : StudyUi.muted(isDarkMode),
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

class _ArchiveActionPill extends StatelessWidget {
  const _ArchiveActionPill({
    required this.icon,
    required this.label,
    required this.accent,
    required this.isDarkMode,
    required this.onPressed,
    this.isFilled = false,
    this.expand = false,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final bool isDarkMode;
  final VoidCallback? onPressed;
  final bool isFilled;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foreground = isFilled ? Colors.white : accent;
    return Opacity(
      opacity: enabled ? 1 : 0.48,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Container(
          width: expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: isFilled ? accent : StudyUi.chipBackground(accent, isDarkMode),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isFilled
                  ? Colors.white.withValues(alpha: isDarkMode ? 0.12 : 0.38)
                  : accent.withValues(alpha: isDarkMode ? 0.24 : 0.18),
            ),
            boxShadow: isFilled
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: isDarkMode ? 0.18 : 0.24),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foreground, size: 17),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: AppTypography.emphasis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArchiveDialogSurface extends StatelessWidget {
  const _ArchiveDialogSurface({
    required this.isDarkMode,
    required this.accent,
    required this.icon,
    required this.title,
    required this.child,
  });

  final bool isDarkMode;
  final Color accent;
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: StudyUi.surface(isDarkMode),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: StudyUi.border(isDarkMode)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: isDarkMode ? 0.18 : 0.14),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StudyGlassIconNode(
                  icon: icon,
                  accent: accent,
                  size: 40,
                  iconSize: 18,
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
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

String _fmtDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
