import 'dart:ui';

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
  final _searchController = TextEditingController();
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

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: widget.controller.load,
      child: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final accent = StudyUi.primary;
        final isDarkMode = widget.isDarkMode;
        final allLogs = widget.controller.studyLogs;
        final logs = _filteredLogs(allLogs);
        final availableCourses = widget.controller.courseNames;
        final compactHeader = StudyCompactHeaderScope.of(context);

        return ListView(
          key: const Key('page_study_logs'),
          padding: EdgeInsets.fromLTRB(22, compactHeader ? 8 : 54, 22, 124),
          children: [
            StudyPathHero(
              isDarkMode: isDarkMode,
              accent: accent,
              badge: '学习记录',
              title: '把今天学过的沉淀下来',
              subtitle: '按课程记录内容、难点、收获和下一步，方便复盘时快速回看。',
              icon: Icons.edit_note_rounded,
              steps: const ['记录', '难点', '收获', '下一步'],
              child: Row(
                children: [
                  Expanded(
                    child: StudyPathMetricPill(
                      label: '总记录',
                      value: '${allLogs.length}',
                      icon: Icons.library_books_rounded,
                      color: accent,
                      isDarkMode: isDarkMode,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StudyPathMetricPill(
                      label: '筛选结果',
                      value: '${logs.length}',
                      icon: Icons.manage_search_rounded,
                      color: StudyUi.secondary,
                      isDarkMode: isDarkMode,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Search bar
            TextField(
              key: const Key('log_search_field'),
              controller: _searchController,
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
                    ? Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _LogIconButton(
                          icon: Icons.clear_rounded,
                          color: StudyUi.muted(isDarkMode),
                          isDarkMode: isDarkMode,
                          tooltip: '清空搜索',
                          onPressed: _clearSearch,
                        ),
                      )
                    : null,
                filled: true,
                fillColor: StudyUi.surfaceAlt(isDarkMode).withValues(
                  alpha: isDarkMode ? 0.72 : 0.88,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  borderSide:
                      BorderSide(color: accent.withValues(alpha: 0.50)),
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
            _LogActionButton(
              key: const Key('add_log_button'),
              icon: Icons.edit_note_rounded,
              label: '添加学习记录',
              color: accent,
              isDarkMode: isDarkMode,
              expand: true,
              onPressed: () => _showLogForm(context),
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
                key: Key('logs_filter_empty_state'),
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
          return _LogSheetSurface(
            isDarkMode: widget.isDarkMode,
            accent: accent,
            height: MediaQuery.of(ctx).size.height * 0.92,
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
                Row(
                  children: [
                    StudyGlassIconNode(
                      icon: Icons.edit_note_rounded,
                      accent: accent,
                      size: 44,
                      iconSize: 19,
                      isDarkMode: widget.isDarkMode,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '添加学习记录',
                        style: TextStyle(
                          color: StudyUi.title(widget.isDarkMode),
                          fontSize: 22,
                          fontWeight: AppTypography.hero,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _LogFormField(
                  label: '日期',
                  child: _LogActionButton(
                    icon: Icons.calendar_today_rounded,
                    label: _fmtDate(selectedDate),
                    color: accent,
                    isDarkMode: widget.isDarkMode,
                    filled: false,
                    expand: true,
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
                      color: StudyUi.title(widget.isDarkMode),
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
                      color: StudyUi.title(widget.isDarkMode),
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
                      color: StudyUi.title(widget.isDarkMode),
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
                      color: StudyUi.title(widget.isDarkMode),
                    ),
                    decoration: _logInputDeco('后续安排...', widget.isDarkMode),
                  ),
                ),
                const SizedBox(height: 22),
                _LogActionButton(
                  icon: Icons.save_rounded,
                  label: '保存记录',
                  color: accent,
                  isDarkMode: widget.isDarkMode,
                  expand: true,
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
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  InputDecoration _logInputDeco(String? hint, bool isDark) {
    final accent = widget.controller.primaryColor;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: StudyUi.muted(isDark),
      ),
      filled: true,
      fillColor: StudyUi.surfaceAlt(isDark).withValues(
        alpha: isDark ? 0.72 : 0.88,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: StudyUi.border(isDark)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: StudyUi.border(isDark)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: accent.withValues(alpha: 0.50)),
      ),
    );
  }

  String _fmtDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _LogSheetSurface extends StatelessWidget {
  const _LogSheetSurface({
    required this.isDarkMode,
    required this.accent,
    required this.height,
    required this.child,
  });

  final bool isDarkMode;
  final Color accent;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: StudyUi.background(isDarkMode).withValues(
                alpha: isDarkMode ? 0.94 : 0.90,
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(30)),
              border: Border(
                top: BorderSide(
                  color:
                      Colors.white.withValues(alpha: isDarkMode ? 0.08 : 0.70),
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: isDarkMode ? 0.16 : 0.10),
                  blurRadius: 28,
                  offset: const Offset(0, -12),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _LogActionButton extends StatelessWidget {
  const _LogActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.isDarkMode,
    required this.onPressed,
    this.filled = true,
    this.expand = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool isDarkMode;
  final VoidCallback? onPressed;
  final bool filled;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final foreground = filled
        ? Colors.white
        : (disabled ? StudyUi.muted(isDarkMode) : color);
    final background = filled
        ? color.withValues(alpha: disabled ? 0.48 : 1)
        : StudyUi.chipBackground(color, isDarkMode);
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: disabled ? null : onPressed,
        child: Ink(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: filled
                  ? Colors.white.withValues(alpha: disabled ? 0.08 : 0.18)
                  : color.withValues(alpha: disabled ? 0.10 : 0.22),
            ),
            boxShadow: [
              if (filled && !disabled && !isDarkMode)
                BoxShadow(
                  color: color.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
            ],
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foreground, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: AppTypography.title,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class _LogIconButton extends StatelessWidget {
  const _LogIconButton({
    super.key,
    required this.icon,
    required this.color,
    required this.isDarkMode,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final Color color;
  final bool isDarkMode;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: 36,
      height: 36,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onPressed,
          child: Ink(
            decoration: BoxDecoration(
              color: StudyUi.chipBackground(color, isDarkMode),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: color.withValues(alpha: 0.18)),
            ),
            child: Center(child: Icon(icon, color: color, size: 18)),
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
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
            color: StudyUi.title(widget.isDarkMode),
          ),
          onChanged: (_) {
            _updateSuggestions();
            setState(() => _showDropdown = true);
          },
          decoration: InputDecoration(
            hintText: '选择或输入课程名...',
            hintStyle: TextStyle(
              color: StudyUi.muted(widget.isDarkMode),
            ),
            filled: true,
            fillColor: StudyUi.surfaceAlt(widget.isDarkMode).withValues(
              alpha: widget.isDarkMode ? 0.72 : 0.88,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: StudyUi.border(widget.isDarkMode)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: StudyUi.border(widget.isDarkMode)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: widget.accentColor.withValues(alpha: 0.50),
              ),
            ),
            suffixIcon: widget.controller.text.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _LogIconButton(
                      icon: Icons.close_rounded,
                      color: StudyUi.muted(widget.isDarkMode),
                      isDarkMode: widget.isDarkMode,
                      tooltip: '清空课程',
                      onPressed: () {
                        widget.controller.clear();
                        _updateSuggestions();
                      },
                    ),
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
                                  color: StudyUi.title(widget.isDarkMode),
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
                    fontWeight: AppTypography.hero,
                  ),
                ),
              ),
              _LogIconButton(
                key: Key('log_delete_${log.id}'),
                icon: Icons.delete_outline_rounded,
                color: StudyUi.muted(isDarkMode),
                isDarkMode: isDarkMode,
                tooltip: '删除记录',
                onPressed: onDelete,
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
