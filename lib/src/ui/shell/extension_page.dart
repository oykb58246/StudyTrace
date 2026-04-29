import 'package:flutter/material.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/study_log_item.dart';
import '../../theme/app_theme.dart';
import '../shared/common_widgets.dart';

class StudyLogsPage extends StatefulWidget {
  const StudyLogsPage({
    super.key,
    required this.isDarkMode,
    required this.controller,
  });

  final bool isDarkMode;
  final AppDataController controller;

  @override
  State<StudyLogsPage> createState() => _StudyLogsPageState();
}

class _StudyLogsPageState extends State<StudyLogsPage> {
  String _searchQuery = '';
  String? _courseFilter;

  List<StudyLogItem> _filteredLogs(List<StudyLogItem> logs) {
    var result = logs;
    if (_courseFilter != null) {
      result = result.where((l) => l.courseName == _courseFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((l) =>
              l.courseName.toLowerCase().contains(q) ||
              l.content.toLowerCase().contains(q) ||
              l.problems.toLowerCase().contains(q) ||
              l.thoughts.toLowerCase().contains(q))
          .toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final allLogs = widget.controller.studyLogs;
        final logs = _filteredLogs(allLogs);
        final availableCourses = widget.controller.courseNames;

        return ListView(
          key: const Key('page_study_logs'),
          padding: const EdgeInsets.fromLTRB(22, 94, 22, 124),
          children: [
            Text(
              '学习记录',
              style: TextStyle(
                color: widget.isDarkMode ? Colors.white : Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            // Search bar
            TextField(
              key: const Key('log_search_field'),
              onChanged: (v) => setState(() => _searchQuery = v),
              style: TextStyle(
                color: widget.isDarkMode ? Colors.white : AppColors.ink,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: '搜索课程、内容、问题或思考...',
                hintStyle: TextStyle(
                  color: widget.isDarkMode
                      ? Colors.white.withValues(alpha: 0.4)
                      : AppColors.muted,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: widget.isDarkMode ? Colors.white54 : AppColors.muted,
                  size: 22,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          color: widget.isDarkMode
                              ? Colors.white54
                              : AppColors.muted,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                filled: true,
                fillColor: widget.isDarkMode
                    ? Colors.white.withValues(alpha: 0.06)
                    : const Color(0xFFF2F5FC),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (availableCourses.isNotEmpty) ...[
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text('全部课程',
                            style: TextStyle(fontSize: 12,
                                color: widget.isDarkMode
                                    ? Colors.white : AppColors.ink)),
                        selected: _courseFilter == null,
                        selectedColor:
                            const Color(0xFF7040F2).withValues(alpha: 0.22),
                        checkmarkColor: const Color(0xFF7040F2),
                        backgroundColor: widget.isDarkMode
                            ? const Color(0xFF2A3040)
                            : const Color(0xFFEEF1FA),
                        side: BorderSide.none,
                        onSelected: (_) => setState(() => _courseFilter = null),
                      ),
                    ),
                    ...availableCourses.map((c) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(c,
                                style: TextStyle(fontSize: 12,
                                    color: widget.isDarkMode
                                        ? Colors.white : AppColors.ink)),
                            selected: _courseFilter == c,
                            selectedColor: const Color(0xFF7394F9)
                                .withValues(alpha: 0.22),
                            checkmarkColor: const Color(0xFF7394F9),
                            backgroundColor: widget.isDarkMode
                                ? const Color(0xFF2A3040)
                                : const Color(0xFFEEF1FA),
                            side: BorderSide.none,
                            onSelected: (sel) {
                              setState(
                                  () => _courseFilter = sel ? c : null);
                            },
                          ),
                        )),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                key: const Key('add_log_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7040F2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 0,
                ),
                onPressed: () => _showLogForm(context),
                icon: const Icon(Icons.edit_note_rounded, size: 20),
                label: const Text(
                  '添加学习记录',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (allLogs.isEmpty)
              GlassCard(
                key: const Key('logs_empty_state'),
                color: widget.isDarkMode
                    ? const Color(0xFF242B37).withValues(alpha: 0.9)
                    : null,
                child: Text(
                  '还没有学习记录。每天记录学习内容，周报会自动汇总。',
                  style: TextStyle(
                    color: widget.isDarkMode
                        ? const Color(0xFFC2C8D6)
                        : AppColors.body,
                    height: 1.55,
                  ),
                ),
              )
            else if (logs.isEmpty)
              GlassCard(
                key: const Key('logs_filter_empty_state'),
                color: widget.isDarkMode
                    ? const Color(0xFF242B37).withValues(alpha: 0.9)
                    : null,
                child: Text(
                  '没有匹配的学习记录。尝试调整筛选条件或搜索关键词。',
                  style: TextStyle(
                    color: widget.isDarkMode
                        ? const Color(0xFFC2C8D6)
                        : AppColors.body,
                    height: 1.55,
                  ),
                ),
              )
            else
              for (final log in logs) ...[
                _LogCard(
                  key: Key('log_item_${log.id}'),
                  log: log,
                  isDarkMode: widget.isDarkMode,
                  onDelete: () => widget.controller.deleteStudyLog(log.id),
                ),
                if (log != logs.last) const SizedBox(height: 12),
              ],
          ],
        );
      },
    );
  }

  void _showLogForm(BuildContext context) {
    final courseController = TextEditingController();
    final contentController = TextEditingController();
    final problemsController = TextEditingController();
    final thoughtsController = TextEditingController();
    final nextPlanController = TextEditingController();
    var selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.92,
            decoration: BoxDecoration(
              color: widget.isDarkMode
                  ? const Color(0xFF1A1F2E)
                  : const Color(0xFFF5F7FF),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 34),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: widget.isDarkMode
                          ? Colors.white24
                          : Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '添加学习记录',
                  style: TextStyle(
                    color: widget.isDarkMode ? Colors.white : AppColors.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                _LogFormField(
                  label: '日期',
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: widget.isDarkMode
                          ? Colors.white
                          : const Color(0xFF7040F2),
                      side: BorderSide(
                        color: widget.isDarkMode
                            ? Colors.white24
                            : const Color(0x337040F2),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setSheetState(() => selectedDate = picked);
                      }
                    },
                    icon:
                        const Icon(Icons.calendar_today_rounded, size: 18),
                    label: Text(_fmtDate(selectedDate)),
                  ),
                ),
                const SizedBox(height: 14),
                _LogFormField(
                  label: '所属课程',
                  child: TextField(
                    controller: courseController,
                    style: TextStyle(
                      color: widget.isDarkMode ? Colors.white : AppColors.ink,
                    ),
                    decoration: _logInputDeco('例如：高等数学', widget.isDarkMode),
                  ),
                ),
                const SizedBox(height: 14),
                _LogFormField(
                  label: '今日学习内容',
                  child: TextField(
                    controller: contentController,
                    maxLines: 3,
                    style: TextStyle(
                      color: widget.isDarkMode ? Colors.white : AppColors.ink,
                    ),
                    decoration:
                        _logInputDeco('今天学了什么...', widget.isDarkMode),
                  ),
                ),
                const SizedBox(height: 14),
                _LogFormField(
                  label: '遇到的问题',
                  child: TextField(
                    controller: problemsController,
                    maxLines: 2,
                    style: TextStyle(
                      color: widget.isDarkMode ? Colors.white : AppColors.ink,
                    ),
                    decoration:
                        _logInputDeco('遇到什么困难...', widget.isDarkMode),
                  ),
                ),
                const SizedBox(height: 14),
                _LogFormField(
                  label: '思考与收获',
                  child: TextField(
                    controller: thoughtsController,
                    maxLines: 2,
                    style: TextStyle(
                      color: widget.isDarkMode ? Colors.white : AppColors.ink,
                    ),
                    decoration:
                        _logInputDeco('有什么感悟...', widget.isDarkMode),
                  ),
                ),
                const SizedBox(height: 14),
                _LogFormField(
                  label: '下一步计划',
                  child: TextField(
                    controller: nextPlanController,
                    maxLines: 2,
                    style: TextStyle(
                      color: widget.isDarkMode ? Colors.white : AppColors.ink,
                    ),
                    decoration:
                        _logInputDeco('后续安排...', widget.isDarkMode),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7040F2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      if (courseController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('请至少填写课程名称')),
                        );
                        return;
                      }
                      await widget.controller.addStudyLog(
                        date: selectedDate,
                        courseName: courseController.text.trim(),
                        content: contentController.text.trim(),
                        problems: problemsController.text.trim(),
                        thoughts: thoughtsController.text.trim(),
                        nextPlan: nextPlanController.text.trim(),
                      );
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                    child: const Text(
                      '保存记录',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  InputDecoration _logInputDeco(String? hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark
            ? Colors.white.withValues(alpha: 0.4)
            : Colors.black.withValues(alpha: 0.35),
      ),
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : const Color(0xFFF2F5FC),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  String _fmtDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _LogFormField extends StatelessWidget {
  const _LogFormField({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({
    super.key,
    required this.log,
    required this.isDarkMode,
    required this.onDelete,
  });

  final StudyLogItem log;
  final bool isDarkMode;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final titleColor = isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor = isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;

    return GlassCard(
      color: isDarkMode
          ? const Color(0xFF242B37).withValues(alpha: 0.9)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x197394F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _fmtDate(log.date),
                  style: const TextStyle(
                    color: Color(0xFF7394F9),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                log.courseName,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              IconButton(
                key: Key('log_delete_${log.id}'),
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: isDarkMode ? Colors.white54 : AppColors.muted,
                  size: 20,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (log.content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(log.content, style: TextStyle(color: bodyColor, height: 1.5)),
          ],
          if (log.problems.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '❓ 遇到的问题',
              style: TextStyle(
                color: titleColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(log.problems,
                style: TextStyle(color: bodyColor, height: 1.45)),
          ],
          if (log.thoughts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '💡 思考与收获',
              style: TextStyle(
                color: titleColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(log.thoughts,
                style: TextStyle(color: bodyColor, height: 1.45)),
          ],
          if (log.nextPlan.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '📋 下一步计划',
              style: TextStyle(
                color: titleColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(log.nextPlan,
                style: TextStyle(color: bodyColor, height: 1.45)),
          ],
        ],
      ),
    );
  }
}

String _fmtDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
