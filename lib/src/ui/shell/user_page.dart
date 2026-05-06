import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:lottie/lottie.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/weekly_report_item.dart';
import '../../services/report_export_service.dart';
import '../../theme/app_theme.dart';
import '../shared/common_widgets.dart';

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
        final accent = controller.primaryColor;
        final courses = controller.courseNames;
        final allReports = controller.weeklyReports;
        // 按 createdAt 倒序排列（最新的在前）
        final reports = List<WeeklyReportItem>.from(allReports)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return ListView(
          key: const Key('page_course_archive'),
          padding: const EdgeInsets.fromLTRB(22, 94, 22, 124),
          children: [
            Text(
              '课程归档',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            // --- Course List ---
            Row(
              children: [
                Text(
                  '课程列表',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton.filledTonal(
                  tooltip: '添加课程',
                  onPressed: () => _showAddCourseDialog(context),
                  icon: const Icon(Icons.add_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (courses.isEmpty)
              GlassCard(
                key: const Key('courses_empty_state'),
                color: isDarkMode
                    ? const Color(0xFF242B37).withValues(alpha: 0.9)
                    : null,
                child: Text(
                  '尚无双课程。添加学习任务或学习记录时填写课程名，这里会自动汇总。',
                  style: TextStyle(
                    color:
                        isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body,
                    height: 1.55,
                  ),
                ),
              )
            else
              for (final course in courses) ...[
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: Key('course_item_$course'),
                    borderRadius: BorderRadius.circular(28),
                    onTap: () => onViewCourse(course),
                    onLongPress: () =>
                        _showDeleteCourseConfirm(context, course),
                    child: GlassCard(
                      color: isDarkMode
                          ? const Color(0xFF242B37).withValues(alpha: 0.9)
                          : null,
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: LinearGradient(
                                colors: [accent, const Color(0xFF8D5EFF)],
                              ),
                            ),
                            child: ColorFiltered(
                              colorFilter: const ColorFilter.mode(
                                Colors.white,
                                BlendMode.srcIn,
                              ),
                              child: Lottie.asset(
                                'assets/icons/lordicon/book.json',
                                width: 22,
                                height: 22,
                                animate: false,
                                frameRate: FrameRate.max,
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
                                  style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.white
                                        : AppColors.ink,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${controller.tasksForCourse(course).length} 个任务 · ${controller.logsForCourse(course).length} 条记录',
                                  style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.white54
                                        : AppColors.muted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color:
                                isDarkMode ? Colors.white54 : AppColors.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (course != courses.last) const SizedBox(height: 12),
              ],
            const SizedBox(height: 24),
            // --- Historical Weekly Reports ---
            Text(
              '历史周报',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            if (reports.isEmpty)
              GlassCard(
                key: const Key('reports_empty_state'),
                color: isDarkMode
                    ? const Color(0xFF242B37).withValues(alpha: 0.9)
                    : null,
                child: Text(
                  '暂无保存的周报。在首页生成周报后保存，就会出现在这里。',
                  style: TextStyle(
                    color:
                        isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body,
                    height: 1.55,
                  ),
                ),
              )
            else ...[
              // Export all reports button
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          isDarkMode ? Colors.white : accent,
                      side: BorderSide(
                        color: isDarkMode
                            ? Colors.white24
                            : accent.withValues(alpha: 0.2),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      final allContent = reports
                          .map((r) =>
                              '--- ${_fmtDate(r.startDate)} ~ ${_fmtDate(r.endDate)} ---\n${r.content}')
                          .join('\n\n');
                      Clipboard.setData(ClipboardData(text: allContent));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('全部周报已复制到剪贴板')),
                      );
                    },
                    icon: const Icon(Icons.copy_all_rounded, size: 18),
                    label: const Text('复制全部周报',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDarkMode ? Colors.white : accent,
                      side: BorderSide(
                        color: isDarkMode
                            ? Colors.white24
                            : accent.withValues(alpha: 0.2),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => _exportAllReportsMarkdown(
                      context,
                      reports,
                    ),
                    icon: const Icon(Icons.description_rounded, size: 18),
                    label: const Text(
                      '导出全部 Markdown',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              for (final report in reports) ...[
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: Key('report_item_${report.id}'),
                    borderRadius: BorderRadius.circular(28),
                    onTap: () => _showReportDetail(context, report),
                    child: GlassCard(
                      color: isDarkMode
                          ? const Color(0xFF242B37).withValues(alpha: 0.9)
                          : null,
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: const Color(0x19F77D8E),
                            ),
                            child: Lottie.asset(
                              'assets/icons/lordicon/route.json',
                              width: 22,
                              height: 22,
                              animate: false,
                              frameRate: FrameRate.max,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_fmtDate(report.startDate)} - ${_fmtDate(report.endDate)}',
                                  style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.white
                                        : AppColors.ink,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${report.sourceLogIds.length} 条学习记录汇总',
                                  style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.white54
                                        : AppColors.muted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color:
                                isDarkMode ? Colors.white54 : AppColors.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (report != reports.last) const SizedBox(height: 12),
              ],
            ],
          ],
        );
      },
    );
  }

  void _showReportDetail(BuildContext context, WeeklyReportItem report) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (detailContext) => Scaffold(
          backgroundColor:
              isDarkMode ? const Color(0xFF141923) : const Color(0xFFF5F7FF),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: isDarkMode ? Colors.white : AppColors.ink,
            title: const Text('周报详情',
                style: TextStyle(fontWeight: FontWeight.w800)),
            actions: [
              IconButton(
                icon: const Icon(Icons.copy_rounded),
                tooltip: '复制周报',
                onPressed: () => _copyReportContent(detailContext, report),
              ),
              IconButton(
                icon: const Icon(Icons.description_rounded),
                tooltip: '导出 Markdown',
                onPressed: () => _exportReport(
                  detailContext,
                  report,
                  asPdf: false,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_rounded),
                tooltip: '导出 PDF',
                onPressed: () => _exportReport(
                  detailContext,
                  report,
                  asPdf: true,
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: GlassCard(
              color: isDarkMode
                  ? const Color(0xFF242B37).withValues(alpha: 0.92)
                  : null,
              child: MarkdownBody(
                data: report.content,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color:
                        isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body,
                    height: 1.65,
                    fontSize: 14,
                  ),
                  h1: TextStyle(
                    color: isDarkMode ? Colors.white : AppColors.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                  h2: TextStyle(
                    color: isDarkMode ? Colors.white : AppColors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                  h3: TextStyle(
                    color: isDarkMode ? Colors.white : AppColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                  em: TextStyle(
                    color:
                        isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body,
                    fontStyle: FontStyle.italic,
                  ),
                  strong: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : AppColors.ink,
                  ),
                  blockquote: TextStyle(
                    color: isDarkMode ? Colors.white54 : AppColors.muted,
                    fontSize: 14,
                  ),
                  code: TextStyle(
                    backgroundColor:
                        isDarkMode ? Colors.black26 : const Color(0xFFE8ECFF),
                    color: isDarkMode
                        ? const Color(0xFFB0E0E6)
                        : const Color(0xFF5A67D8),
                    fontFamily: 'monospace',
                    fontSize: 13,
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('周报已复制到剪贴板')),
    );
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
      await _showExportResult(
        context,
        kind: asPdf ? 'PDF' : 'Markdown',
        path: file.path,
      );
    } catch (error) {
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
      await _showExportResult(
        context,
        kind: '全部 Markdown',
        path: file.path,
      );
    } catch (error) {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已导出 $kind，文件路径已复制：$path')),
    );
  }

  void _showExportError(BuildContext context, Object error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('导出失败：$error')),
    );
  }

  void _showAddCourseDialog(BuildContext context) {
    final accent = controller.primaryColor;
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('添加课程'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '课程名称',
            filled: true,
            fillColor: isDarkMode
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFF2F5FC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                controller.addCourse(name);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showDeleteCourseConfirm(BuildContext context, String course) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('删除课程'),
        content: Text('确定删除课程「$course」吗？\n\n仅删除课程标签，不会删除已有的任务和日志。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF6850),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              controller.deleteCourse(course);
              Navigator.of(ctx).pop();
            },
            child: const Text('删除'),
          ),
        ],
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
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final accent = controller.primaryColor;
        final tasks = controller.tasksForCourse(courseName);
        final logs = controller.logsForCourse(courseName);

        return Scaffold(
          backgroundColor:
              isDarkMode ? const Color(0xFF141923) : const Color(0xFFF5F7FF),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: isDarkMode ? Colors.white : AppColors.ink,
            title: Text(courseName,
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          body: ListView(
            key: const Key('page_course_detail'),
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 40),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [accent, const Color(0xFF8D5EFF)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BadgePill(
                      label: '课程详情',
                      background: Color(0x33FFFFFF),
                      foreground: Colors.white,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      courseName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${tasks.length} 个任务 · ${logs.length} 条学习记录',
                      style: const TextStyle(
                        color: Color(0xD9FFFFFF),
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '相关任务',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (tasks.isEmpty)
                GlassCard(
                  color: isDarkMode
                      ? const Color(0xFF242B37).withValues(alpha: 0.9)
                      : null,
                  child: Text(
                    '该课程暂无相关任务。',
                    style: TextStyle(
                      color:
                          isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body,
                    ),
                  ),
                )
              else
                for (final task in tasks) ...[
                  GlassCard(
                    color: isDarkMode
                        ? const Color(0xFF242B37).withValues(alpha: 0.9)
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              task.title,
                              style: TextStyle(
                                color:
                                    isDarkMode ? Colors.white : AppColors.ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            BadgePill(
                              label: task.status.label,
                              background: const Color(0x197394F9),
                              foreground: const Color(0xFF7394F9),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${task.type.label} · 截止：$_fmtDate(task.deadline)',
                          style: TextStyle(
                            color:
                                isDarkMode ? Colors.white54 : AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (task != tasks.last) const SizedBox(height: 10),
                ],
              const SizedBox(height: 18),
              Text(
                '学习记录',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (logs.isEmpty)
                GlassCard(
                  color: isDarkMode
                      ? const Color(0xFF242B37).withValues(alpha: 0.9)
                      : null,
                  child: Text(
                    '该课程暂无学习记录。',
                    style: TextStyle(
                      color:
                          isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body,
                    ),
                  ),
                )
              else
                for (final log in logs) ...[
                  GlassCard(
                    color: isDarkMode
                        ? const Color(0xFF242B37).withValues(alpha: 0.9)
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _fmtDate(log.date),
                              style: TextStyle(
                                color:
                                    isDarkMode ? Colors.white : AppColors.ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        if (log.content.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            log.content,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDarkMode
                                  ? const Color(0xFFC2C8D6)
                                  : AppColors.body,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (log != logs.last) const SizedBox(height: 10),
                ],
            ],
          ),
        );
      },
    );
  }
}

String _fmtDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
