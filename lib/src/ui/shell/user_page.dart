import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/app_data_controller.dart';
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
        final courses = controller.courseNames;
        final reports = controller.weeklyReports;

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
            Text(
              '课程列表',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
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
                    color: isDarkMode
                        ? const Color(0xFFC2C8D6)
                        : AppColors.body,
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
                              gradient: const LinearGradient(
                                colors: [Color(0xFF7040F2), Color(0xFF8D5EFF)],
                              ),
                            ),
                            child: const Icon(
                              Icons.school_rounded,
                              color: Colors.white,
                              size: 22,
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
                    color: isDarkMode
                        ? const Color(0xFFC2C8D6)
                        : AppColors.body,
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
                      foregroundColor: isDarkMode
                          ? Colors.white
                          : const Color(0xFF7040F2),
                      side: BorderSide(
                        color: isDarkMode
                            ? Colors.white24
                            : const Color(0x337040F2),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      final allContent = reports.map((r) =>
                          '--- ${_fmtDate(r.startDate)} ~ ${_fmtDate(r.endDate)} ---\n${r.content}').join('\n\n');
                      Clipboard.setData(ClipboardData(text: allContent));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('全部周报已复制到剪贴板')),
                      );
                    },
                    icon: const Icon(Icons.copy_all_rounded, size: 18),
                    label: const Text('复制全部周报',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              for (final report in reports) ...[
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: Key('report_item_${report.id}'),
                    borderRadius: BorderRadius.circular(28),
                    onTap: () => _showReportDetail(context, report.content),
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
                            child: const Icon(
                              Icons.article_rounded,
                              color: Color(0xFFF77D8E),
                              size: 22,
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

  void _showReportDetail(BuildContext context, String content) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor:
              isDarkMode ? const Color(0xFF141923) : const Color(0xFFF5F7FF),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: isDarkMode ? Colors.white : AppColors.ink,
            title: const Text('周报详情',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: GlassCard(
              color: isDarkMode
                  ? const Color(0xFF242B37).withValues(alpha: 0.92)
                  : null,
              child: Text(
                content,
                style: TextStyle(
                  color: isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body,
                  height: 1.65,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
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
        final tasks = controller.tasksForCourse(courseName);
        final logs = controller.logsForCourse(courseName);

        return Scaffold(
          backgroundColor: isDarkMode
              ? const Color(0xFF141923)
              : const Color(0xFFF5F7FF),
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
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF7040F2), Color(0xFF8D5EFF)],
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
                      color: isDarkMode
                          ? const Color(0xFFC2C8D6)
                          : AppColors.body,
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
                                color: isDarkMode
                                    ? Colors.white
                                    : AppColors.ink,
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
                            color: isDarkMode
                                ? Colors.white54
                                : AppColors.muted,
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
                      color: isDarkMode
                          ? const Color(0xFFC2C8D6)
                          : AppColors.body,
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
                                color: isDarkMode
                                    ? Colors.white
                                    : AppColors.ink,
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
