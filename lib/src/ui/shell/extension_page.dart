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
    var result = logs.toList(); // 确保是可修改的列表
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
    // 按 date 倒序排列（最新的在前）
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => widget.controller.notifyListeners(),
      child: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final accent = StudyUi.primary;
        final isDarkMode = widget.isDarkMode;
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
                color: StudyUi.title(isDarkMode),
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            // Search bar
            TextField(
              key: const Key('log_search_field'),
              onChanged: (v) => setState(() => _searchQuery = v),
              style: TextStyle(
                color: StudyUi.title(isDarkMode),
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: '搜索课程、内容、问题或思考...',
                hintStyle: TextStyle(
                  color: StudyUi.muted(isDarkMode),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: StudyUi.muted(isDarkMode),
                  size: 22,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          color: StudyUi.muted(isDarkMode),
                          size: 20,
                        ),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                filled: true,
                fillColor: StudyUi.surfaceAlt(isDarkMode),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: StudyUi.border(isDarkMode)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: StudyUi.border(isDarkMode)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: StudyUi.primary),
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
                      child: GestureDetector(
                        onTap: () => setState(() => _courseFilter = null),
                        child: StudyStatusChip(
                          label: '全部课程',
                          color: StudyUi.primary,
                          selected: _courseFilter == null,
                        ),
                      ),
                    ),
                    ...availableCourses.map((c) {
                      final selected = _courseFilter == c;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(
                              () => _courseFilter = selected ? null : c),
                          child: StudyStatusChip(
                            label: c,
                            color: StudyUi.secondary,
                            selected: selected,
                          ),
                        ),
                      );
                    }),
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
                  backgroundColor: accent,
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
              StudyEmptyState.logs(
                key: const Key('logs_empty_state'),
                actionLabel: '添加记录',
                onAction: () => _showLogForm(context),
              )
            else if (logs.isEmpty)
              const StudyEmptyState.logs(
                key: const Key('logs_filter_empty_state'),
                title: '没有匹配的记录',
                message: '试着清空课程筛选，或换一个关键词搜索。',
                compact: true,
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
    ),
    );
  }

  void _showLogForm(BuildContext context) {
    final accent = widget.controller.primaryColor;
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
                      color:
                          widget.isDarkMode ? Colors.white24 : Colors.black26,
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
                          : accent,
                      side: BorderSide(
                        color: widget.isDarkMode
                            ? Colors.white24
                            : accent.withValues(alpha: 0.2),
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
                      if (picked != null && ctx.mounted) {
                        setSheetState(() => selectedDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today_rounded, size: 18),
                    label: Text(_fmtDate(selectedDate)),
                  ),
                ),
                const SizedBox(height: 14),
                _LogFormField(
                  label: '所属课程',
                  child: _LogCourseSelector(
                    isDarkMode: widget.isDarkMode,
                    controller: courseController,
                    allCourses: widget.controller.allCourses,
                    onSelectionChanged: (course) {
                      setSheetState(() => courseController.text = course);
                    },
                    accentColor: accent,
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
                    decoration: _logInputDeco('今天学了什么...', widget.isDarkMode),
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
                    decoration: _logInputDeco('遇到什么困难...', widget.isDarkMode),
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
                    decoration: _logInputDeco('有什么感悟...', widget.isDarkMode),
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
                    decoration: _logInputDeco('后续安排...', widget.isDarkMode),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      if (courseController.text.trim().isEmpty) {
                        StudyToast.show(ctx, '请至少填写课程名称');
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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

class _LogCourseSelector extends StatefulWidget {
  final bool isDarkMode;
  final TextEditingController controller;
  final List<String> allCourses;
  final ValueChanged<String> onSelectionChanged;
  final Color accentColor;

  const _LogCourseSelector({
    required this.isDarkMode,
    required this.controller,
    required this.allCourses,
    required this.onSelectionChanged,
    required this.accentColor,
  });

  @override
  State<_LogCourseSelector> createState() => _LogCourseSelectorState();
}

class _LogCourseSelectorState extends State<_LogCourseSelector> {
  bool _showDropdown = false;
  late List<String> _suggestions;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateSuggestions);
    _updateSuggestions();
  }

  @override
  void didUpdateWidget(_LogCourseSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.allCourses != widget.allCourses) {
      _updateSuggestions();
    }
  }

  void _updateSuggestions() {
    final query = widget.controller.text.toLowerCase();
    _suggestions = widget.allCourses
        .where(
          (c) => c.toLowerCase().contains(query) && c.toLowerCase() != query,
        )
        .toList();
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateSuggestions);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          style: TextStyle(
            color: widget.isDarkMode ? Colors.white : AppColors.ink,
          ),
          onChanged: (_) {
            _updateSuggestions();
            setState(() => _showDropdown = true);
          },
          decoration: InputDecoration(
            hintText: '选择或输入课程名...',
            hintStyle: TextStyle(
              color: widget.isDarkMode
                  ? Colors.white.withValues(alpha: 0.4)
                  : Colors.black26,
            ),
            filled: true,
            fillColor: widget.isDarkMode
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFF2F5FC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            suffixIcon: widget.controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      widget.controller.clear();
                      _updateSuggestions();
                    },
                  )
                : null,
          ),
        ),
        if (_showDropdown && _suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: widget.isDarkMode ? const Color(0xFF242B37) : Colors.white,
              border: Border.all(
                color: widget.isDarkMode
                    ? Colors.white12
                    : const Color(0xFFE0E0E0),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _suggestions
                  .take(5)
                  .map(
                    (course) => InkWell(
                      onTap: () {
                        widget.controller.text = course;
                        widget.onSelectionChanged(course);
                        setState(() => _showDropdown = false);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: course != _suggestions.last
                              ? Border(
                                  bottom: BorderSide(
                                    color: widget.isDarkMode
                                        ? Colors.white12
                                        : const Color(0xFFE0E0E0),
                                  ),
                                )
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.book_rounded,
                              size: 16,
                              color: widget.accentColor,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                course,
                                style: TextStyle(
                                  color: widget.isDarkMode
                                      ? Colors.white
                                      : AppColors.ink,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
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
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);

    return StudyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: StudyUi.chipBackground(StudyUi.secondary, isDarkMode),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _fmtDate(log.date),
                  style: const TextStyle(
                    color: StudyUi.secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  log.courseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                key: Key('log_delete_${log.id}'),
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: StudyUi.muted(isDarkMode),
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
              '遇到的问题',
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
              '思考与收获',
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
              '下一步计划',
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
