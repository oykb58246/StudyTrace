import 'dart:ui';

import 'package:flutter/material.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/study_sub_task_item.dart';
import '../../models/study_task_item.dart';
import '../../theme/app_theme.dart';
import '../shared/common_widgets.dart';
import '../shared/page_wrapper.dart';

enum _TaskQuickFilter {
  overdue,
  dueSoon,
  inProgress,
  completed;

  String get label {
    switch (this) {
      case _TaskQuickFilter.overdue:
        return '已过期';
      case _TaskQuickFilter.dueSoon:
        return '24 小时内截止';
      case _TaskQuickFilter.inProgress:
        return '正在推进';
      case _TaskQuickFilter.completed:
        return '已完成';
    }
  }
}

DateTime _startOfDay(DateTime dateTime) {
  return DateTime(dateTime.year, dateTime.month, dateTime.day);
}

bool _isTaskOverdue(StudyTaskItem task, {DateTime? now}) {
  final today = _startOfDay(now ?? DateTime.now());
  return task.effectiveStatus != StudyTaskStatus.completed &&
      task.deadline.isBefore(today);
}

Color _taskQuickFilterColor(_TaskQuickFilter filter) {
  return switch (filter) {
    _TaskQuickFilter.overdue => StudyUi.danger,
    _TaskQuickFilter.dueSoon => StudyUi.pathWarm,
    _TaskQuickFilter.inProgress => StudyUi.pathViolet,
    _TaskQuickFilter.completed => StudyUi.pathMint,
  };
}

IconData _taskQuickFilterIcon(_TaskQuickFilter filter) {
  return switch (filter) {
    _TaskQuickFilter.overdue => Icons.warning_amber_rounded,
    _TaskQuickFilter.dueSoon => Icons.schedule_rounded,
    _TaskQuickFilter.inProgress => Icons.play_arrow_rounded,
    _TaskQuickFilter.completed => Icons.check_circle_rounded,
  };
}

class StudyTasksPage extends StatefulWidget {
  const StudyTasksPage({
    super.key,
    required this.isDarkMode,
    required this.controller,
    this.initialOverdueFilter = false,
  });

  final bool isDarkMode;
  final AppDataController controller;
  final bool initialOverdueFilter;

  @override
  State<StudyTasksPage> createState() => _StudyTasksPageState();
}

class _StudyTasksPageState extends State<StudyTasksPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  StudyTaskStatus? _statusFilter;
  StudyTaskType? _typeFilter;
  _TaskQuickFilter? _quickFilter;

  @override
  void initState() {
    super.initState();
    if (widget.initialOverdueFilter) {
      _quickFilter = _TaskQuickFilter.overdue;
    }
  }

  List<StudyTaskItem> _filteredTasks(List<StudyTaskItem> tasks) {
    var result = tasks.toList(); // 确保是可修改的列表
    if (_quickFilter != null) {
      result = _applyQuickFilter(result, _quickFilter!);
    }
    if (_statusFilter != null) {
      result = result.where((t) => t.effectiveStatus == _statusFilter).toList();
    }
    if (_typeFilter != null) {
      result = result.where((t) => t.type == _typeFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((t) =>
              t.title.toLowerCase().contains(q) ||
              t.courseName.toLowerCase().contains(q))
          .toList();
    }
    result.sort((a, b) {
      final aDone = a.status == StudyTaskStatus.completed ? 1 : 0;
      final bDone = b.status == StudyTaskStatus.completed ? 1 : 0;
      if (aDone != bDone) return aDone - bDone;
      final aDeadline = _earliestUnfinishedDeadline(a.subTasks, a.deadline);
      final bDeadline = _earliestUnfinishedDeadline(b.subTasks, b.deadline);
      return aDeadline.compareTo(bDeadline);
    });
    return result;
  }

  List<StudyTaskItem> _applyQuickFilter(
    List<StudyTaskItem> tasks,
    _TaskQuickFilter filter,
  ) {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    return switch (filter) {
      _TaskQuickFilter.overdue => tasks
          .where((task) => _isTaskOverdue(task, now: now))
          .toList(),
      _TaskQuickFilter.dueSoon => tasks
          .where(
            (task) =>
                task.effectiveStatus != StudyTaskStatus.completed &&
                !_isTaskOverdue(task, now: now) &&
                task.deadline.isBefore(tomorrow),
          )
          .toList(),
      _TaskQuickFilter.inProgress => tasks
          .where((task) => task.effectiveStatus == StudyTaskStatus.inProgress)
          .toList(),
      _TaskQuickFilter.completed => tasks
          .where((task) => task.effectiveStatus == StudyTaskStatus.completed)
          .toList(),
    };
  }

  void _setQuickFilter(_TaskQuickFilter filter) {
    setState(() {
      if (_quickFilter == filter) {
        _quickFilter = null;
      } else {
        _quickFilter = filter;
        _searchController.clear();
        _searchQuery = '';
        _statusFilter = null;
        _typeFilter = null;
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _quickFilter = null;
      _statusFilter = null;
      _typeFilter = null;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openTaskRoute(StudyTaskItem task) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) => PageWithBackButton(
          title: '完成路径',
          titleIcon: Icons.route_rounded,
          accent: StudyUi.pathViolet,
          isDarkMode: widget.isDarkMode,
          compactHeader: true,
          child: _TaskRouteDetailPage(
            taskId: task.id,
            controller: widget.controller,
            isDarkMode: widget.isDarkMode,
          ),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.04, 0.02),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  DateTime _earliestUnfinishedDeadline(
      List<StudySubTaskItem> subs, DateTime fallback) {
    DateTime earliest = fallback;
    for (final s in subs) {
      if (s.status != SubTaskStatus.completed &&
          s.deadline.isBefore(earliest)) {
        earliest = s.deadline;
      }
    }
    return earliest;
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
          final allTasks = widget.controller.studyTasks;
          final tasks = _filteredTasks(allTasks);
          final hasActiveFilters = _searchQuery.isNotEmpty ||
              _quickFilter != null ||
              _statusFilter != null ||
              _typeFilter != null;

          return ListView(
            key: const Key('page_study_tasks'),
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 124),
            children: [
              _tasksHero(allTasks, accent, isDarkMode),
              const SizedBox(height: 16),
              // Search bar
              TextField(
                key: const Key('task_search_field'),
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: TextStyle(
                  color: StudyUi.title(isDarkMode),
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: '搜索任务标题或课程...',
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
                          padding: const EdgeInsets.only(right: 6),
                          child: _TaskIconButton(
                            icon: Icons.clear_rounded,
                            accent: StudyUi.muted(isDarkMode),
                            isDarkMode: isDarkMode,
                            size: 34,
                            onPressed: _clearSearch,
                          ),
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
              const SizedBox(height: 10),
              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Quick filter chips
                    ...[_TaskQuickFilter.overdue].map((filter) {
                      final selected = _quickFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: StudyStatusChip(
                          label: filter.label,
                          color: _taskQuickFilterColor(filter),
                          selected: selected,
                          icon: _taskQuickFilterIcon(filter),
                          onTap: () => _setQuickFilter(filter),
                        ),
                      );
                    }),
                    const SizedBox(width: 4),
                    // Status filter chips
                    ...StudyTaskStatus.values.map((s) {
                      final selected = _statusFilter == s;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _quickFilter = null;
                            _statusFilter = selected ? null : s;
                          }),
                          child: StudyStatusChip(
                            label: s.label,
                            color: _taskStatusColor(s),
                            selected: selected,
                          ),
                        ),
                      );
                    }),
                    const SizedBox(width: 4),
                    // Type filter chips
                    ...StudyTaskType.values.map((t) {
                      final selected = _typeFilter == t;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _quickFilter = null;
                            _typeFilter = selected ? null : t;
                          }),
                          child: StudyStatusChip(
                            label: t.label,
                            color: StudyUi.secondary,
                            selected: selected,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              if (hasActiveFilters) ...[
                const SizedBox(height: 10),
                _ActiveTaskFiltersBanner(
                  isDarkMode: isDarkMode,
                  searchQuery: _searchQuery,
                  quickFilter: _quickFilter,
                  statusFilter: _statusFilter,
                  typeFilter: _typeFilter,
                  onClear: _clearFilters,
                ),
              ],
              const SizedBox(height: 14),
              if (allTasks.isEmpty)
                StudyEmptyState.tasks(
                  key: const Key('tasks_empty_state'),
                  actionLabel: '添加任务',
                  onAction: () => _showTaskForm(context),
                )
              else if (tasks.isEmpty)
                const StudyEmptyState.tasks(
                  key: Key('tasks_filter_empty_state'),
                  title: '没有匹配的任务',
                  message: '尝试调整筛选条件，或换一个课程、关键词再搜索。',
                  compact: true,
                )
              else
                for (final task in tasks) ...[
                  _TaskCard(
                    key: Key('task_item_${task.id}'),
                    task: task,
                    isDarkMode: widget.isDarkMode,
                    isOverdue: _isTaskOverdue(task),
                    onStatusChanged: (status) => widget.controller
                        .updateStudyTaskStatus(task.id, status),
                    onOpenDetail: () => _openTaskRoute(task),
                    onEdit: () => _showEditForm(context, task),
                    onRescheduleOverdue: () => _showEditForm(context, task),
                    onDismissOverdueWarning: () =>
                        _resolveOverdueWarning(task),
                    onDelete: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => _TaskDialogSurface(
                          isDarkMode: widget.isDarkMode,
                          icon: Icons.delete_outline_rounded,
                          accent: StudyUi.danger,
                          title: '删除任务',
                          subtitle: '这项安排会从当前学习路径里移除。',
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '确定要删除「${task.title}」吗？',
                                style: TextStyle(
                                  color: StudyUi.body(widget.isDarkMode),
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _TaskActionButton(
                                      icon: Icons.close_rounded,
                                      label: '取消',
                                      accent: StudyUi.muted(widget.isDarkMode),
                                      isDarkMode: widget.isDarkMode,
                                      expand: true,
                                      onPressed: () => Navigator.of(ctx).pop(),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _TaskActionButton(
                                      icon: Icons.delete_outline_rounded,
                                      label: '删除',
                                      accent: StudyUi.danger,
                                      isDarkMode: widget.isDarkMode,
                                      filled: true,
                                      expand: true,
                                      onPressed: () {
                                        widget.controller
                                            .deleteStudyTask(task.id);
                                        Navigator.of(ctx).pop();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    onSubTaskToggled: (idx, newStatus) {
                      final updated = task.subTasks.toList();
                      updated[idx] = updated[idx].copyWith(status: newStatus);
                      widget.controller.updateStudyTask(
                        task.id,
                        title: task.title,
                        type: task.type,
                        courseName: task.courseName,
                        deadline: task.deadline,
                        status: task.status,
                        note: task.note,
                        reminderTime: task.reminderTime,
                        subTasks: updated,
                      );
                    },
                  ),
                  if (task != tasks.last) const SizedBox(height: 12),
                ],
            ],
          );
        },
      ),
    );
  }

  Widget _tasksHero(
    List<StudyTaskItem> allTasks,
    Color accent,
    bool isDarkMode,
  ) {
    final unfinished = allTasks
        .where((task) => task.status != StudyTaskStatus.completed)
        .toList()
      ..sort((a, b) {
        final aDeadline = _earliestUnfinishedDeadline(a.subTasks, a.deadline);
        final bDeadline = _earliestUnfinishedDeadline(b.subTasks, b.deadline);
        return aDeadline.compareTo(bDeadline);
      });
    final inProgress = allTasks
        .where((task) => task.effectiveStatus == StudyTaskStatus.inProgress)
        .length;
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final dueSoon = unfinished
        .where((task) =>
            !_isTaskOverdue(task, now: now) && task.deadline.isBefore(tomorrow))
        .length;
    final completed = allTasks
        .where((task) => task.status == StudyTaskStatus.completed)
        .length;
    final focusTask = unfinished.isNotEmpty ? unfinished.first : null;
    return StudyPathHero(
      isDarkMode: isDarkMode,
      accent: accent,
      badge: '今日安排',
      title: '先看最近要处理什么',
      subtitle: '把还没完成、临近截止的事排在前面，打开就知道先推进哪一件。',
      icon: Icons.flag_rounded,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _TaskHeroMetric(
                  label: '24 小时内截止',
                  value: '$dueSoon项',
                  icon: Icons.schedule_rounded,
                  color: StudyUi.pathWarm,
                  isDarkMode: isDarkMode,
                  selected: _quickFilter == _TaskQuickFilter.dueSoon,
                  onTap: () => _setQuickFilter(_TaskQuickFilter.dueSoon),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TaskHeroMetric(
                  label: '正在推进',
                  value: '$inProgress项',
                  icon: Icons.play_arrow_rounded,
                  color: StudyUi.pathViolet,
                  isDarkMode: isDarkMode,
                  selected: _quickFilter == _TaskQuickFilter.inProgress,
                  onTap: () => _setQuickFilter(_TaskQuickFilter.inProgress),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TaskHeroMetric(
                  label: '已完成',
                  value: '$completed项',
                  icon: Icons.check_circle_rounded,
                  color: StudyUi.pathMint,
                  isDarkMode: isDarkMode,
                  selected: _quickFilter == _TaskQuickFilter.completed,
                  onTap: () => _setQuickFilter(_TaskQuickFilter.completed),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _TaskHeroFocusBanner(
            task: focusTask,
            isDarkMode: isDarkMode,
            onTap: focusTask == null ? null : () => _openTaskRoute(focusTask),
          ),
          const SizedBox(height: 12),
          _TaskActionButton(
            key: const Key('add_task_button'),
            icon: Icons.add_rounded,
            label: '新建任务',
            accent: accent,
            isDarkMode: isDarkMode,
            filled: true,
            expand: true,
            onPressed: () => _showTaskForm(context),
          ),
        ],
      ),
    );
  }

  Color _taskStatusColor(StudyTaskStatus status) {
    return switch (status) {
      StudyTaskStatus.completed => StudyUi.success,
      StudyTaskStatus.inProgress => StudyUi.warning,
      StudyTaskStatus.notStarted => StudyUi.secondary,
    };
  }

  void _showTaskForm(BuildContext context, [StudyTaskItem? existing]) {
    final accent = widget.controller.primaryColor;
    final isEditing = existing != null;
    final titleController = TextEditingController(text: existing?.title ?? '');
    final courseController =
        TextEditingController(text: existing?.courseName ?? '');
    final noteController = TextEditingController(text: existing?.note ?? '');
    var selectedType = existing?.type ?? StudyTaskType.other;
    var selectedStatus = existing?.status ?? StudyTaskStatus.notStarted;
    var deadline =
        existing?.deadline ?? DateTime.now().add(const Duration(days: 7));
    var reminderTime = existing?.reminderTime;
    final subTaskControllers = <TextEditingController>[];
    final subTaskDeadlines = <DateTime>[];
    var controllersDisposed = false;
    void disposeControllers() {
      if (controllersDisposed) return;
      controllersDisposed = true;
      titleController.dispose();
      courseController.dispose();
      noteController.dispose();
      for (final c in subTaskControllers) {
        c.dispose();
      }
    }

    if (existing?.subTasks != null) {
      for (final st in existing!.subTasks) {
        subTaskControllers.add(TextEditingController(text: st.title));
        subTaskDeadlines.add(st.deadline);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return _TaskSheetSurface(
            isDarkMode: widget.isDarkMode,
            heightFactor: 0.88,
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
                _TaskSheetTitle(
                  isDarkMode: widget.isDarkMode,
                  icon: isEditing
                      ? Icons.edit_note_rounded
                      : Icons.add_task_rounded,
                  accent: accent,
                  title: isEditing ? '编辑学习任务' : '添加学习任务',
                  subtitle: '把任务拆成可执行的下一步，方便专注和回看。',
                ),
                const SizedBox(height: 18),
                _FormField(
                  label: '任务标题',
                  child: TextField(
                    controller: titleController,
                    style: TextStyle(
                      color: widget.isDarkMode ? Colors.white : AppColors.ink,
                    ),
                    decoration: _inputDeco('例如：完成第三章习题', widget.isDarkMode),
                  ),
                ),
                const SizedBox(height: 14),
                _FormField(
                  label: '所属课程',
                  child: _CourseSelector(
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
                _FormField(
                  label: '任务类型',
                  child: _TaskTypeSelector(
                    selectedType: selectedType,
                    isDarkMode: widget.isDarkMode,
                    accent: StudyUi.secondary,
                    onChanged: (type) {
                      setSheetState(() => selectedType = type);
                    },
                  ),
                ),
                const SizedBox(height: 14),
                _FormField(
                  label: '状态',
                  child: _TaskStatusSelector(
                    selectedStatus: selectedStatus,
                    isDarkMode: widget.isDarkMode,
                    accent: accent,
                    onChanged: (status) {
                      setSheetState(() => selectedStatus = status);
                    },
                  ),
                ),
                const SizedBox(height: 14),
                _FormField(
                  label: '截止时间',
                  child: _TaskDateTimeButton(
                    icon: Icons.calendar_today_rounded,
                    label: _fmtDate(deadline),
                    accent: accent,
                    isDarkMode: widget.isDarkMode,
                    onPressed: () async {
                      final pickedDate = await showDatePicker(
                        context: ctx,
                        initialDate: deadline,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2030),
                      );
                      if (pickedDate == null) return;
                      if (!ctx.mounted) return;
                      final pickedTime = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(deadline),
                      );
                      if (pickedTime == null) return;
                      if (!ctx.mounted) return;
                      setSheetState(() {
                        deadline = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    },
                  ),
                ),
                const SizedBox(height: 14),
                _FormField(
                  label: '提醒时间（可选）',
                  child: _TaskDateTimeButton(
                    icon: Icons.notifications_active_rounded,
                    label: reminderTime != null
                        ? _fmtDate(reminderTime!)
                        : '不设置提醒',
                    accent: StudyUi.pathMint,
                    isDarkMode: widget.isDarkMode,
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: reminderTime ?? deadline,
                        firstDate: now,
                        lastDate: deadline,
                        helpText: '选择提醒日期',
                      );
                      if (picked == null) return;
                      if (!ctx.mounted) return;
                      final time = await showTimePicker(
                        context: ctx,
                        initialTime:
                            TimeOfDay.fromDateTime(reminderTime ?? deadline),
                        helpText: '选择提醒时间',
                      );
                      if (!ctx.mounted) return;
                      if (time != null) {
                        setSheetState(() {
                          reminderTime = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 14),
                _FormField(
                  label: '备注',
                  child: TextField(
                    controller: noteController,
                    maxLines: 3,
                    style: TextStyle(
                      color: widget.isDarkMode ? Colors.white : AppColors.ink,
                    ),
                    decoration: _inputDeco('可选备注...', widget.isDarkMode),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      '子任务 (${subTaskControllers.length})',
                      style: TextStyle(
                        color: widget.isDarkMode ? Colors.white : AppColors.ink,
                        fontSize: 16,
                        fontWeight: AppTypography.title,
                      ),
                    ),
                    const Spacer(),
                    _TaskActionButton(
                      icon: Icons.add_rounded,
                      label: '添加',
                      accent: accent,
                      isDarkMode: widget.isDarkMode,
                      onPressed: () {
                        setSheetState(() {
                          subTaskControllers.add(TextEditingController());
                          subTaskDeadlines.add(deadline);
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...List.generate(subTaskControllers.length, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: subTaskControllers[i],
                                style: TextStyle(
                                  color: widget.isDarkMode
                                      ? Colors.white
                                      : AppColors.ink,
                                  fontSize: 14,
                                ),
                                decoration: _inputDeco(
                                    '子任务 ${i + 1}', widget.isDarkMode),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: subTaskDeadlines[i],
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  if (!ctx.mounted) return;
                                  final time = await showTimePicker(
                                    context: ctx,
                                    initialTime: TimeOfDay.fromDateTime(
                                        subTaskDeadlines[i]),
                                  );
                                  if (!ctx.mounted ||
                                      i >= subTaskDeadlines.length) {
                                    return;
                                  }
                                  if (time != null) {
                                    setSheetState(() {
                                      subTaskDeadlines[i] = DateTime(
                                        picked.year,
                                        picked.month,
                                        picked.day,
                                        time.hour,
                                        time.minute,
                                      );
                                    });
                                  } else {
                                    setSheetState(() {
                                      subTaskDeadlines[i] = picked;
                                    });
                                  }
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: StudyUi.surfaceAlt(widget.isDarkMode),
                                ),
                                child: Icon(Icons.calendar_today_rounded,
                                    size: 18,
                                    color: StudyUi.muted(widget.isDarkMode)),
                              ),
                            ),
                            const SizedBox(width: 4),
                            _TaskIconButton(
                              icon: Icons.close_rounded,
                              accent: StudyUi.danger,
                              isDarkMode: widget.isDarkMode,
                              size: 38,
                              onPressed: () {
                                late final TextEditingController
                                    removedController;
                                setSheetState(() {
                                  removedController =
                                      subTaskControllers.removeAt(i);
                                  subTaskDeadlines.removeAt(i);
                                });
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  removedController.dispose();
                                });
                              },
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 4),
                          child: Text(
                            '要在 ${subTaskDeadlines[i].year}-'
                            '${subTaskDeadlines[i].month.toString().padLeft(2, '0')}-'
                            '${subTaskDeadlines[i].day.toString().padLeft(2, '0')} '
                            '${subTaskDeadlines[i].hour.toString().padLeft(2, '0')}:'
                            '${subTaskDeadlines[i].minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 11,
                              color: widget.isDarkMode
                                  ? Colors.white38
                                  : Colors.black38,
                            ),
                          ),
                        ),
                      ], // Column children
                    ), // Column
                  ); // Padding
                }),
                const SizedBox(height: 22),
                _TaskActionButton(
                  icon: Icons.save_rounded,
                  label: isEditing ? '更新任务' : '保存任务',
                  accent: accent,
                  isDarkMode: widget.isDarkMode,
                  filled: true,
                  expand: true,
                  onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) {
                      StudyToast.show(ctx, '请输入任务标题');
                      return;
                    }
                    // 构建子任务列表
                    final now = DateTime.now();
                    final subTasks = <StudySubTaskItem>[];
                    for (var i = 0; i < subTaskControllers.length; i++) {
                      final stTitle = subTaskControllers[i].text.trim();
                      if (stTitle.isNotEmpty) {
                        subTasks.add(StudySubTaskItem(
                          id: 'sub_${now.microsecondsSinceEpoch}_$i',
                          title: stTitle,
                          deadline: subTaskDeadlines[i],
                          createdAt: now,
                          updatedAt: now,
                        ));
                      }
                    }
                    final taskToEdit = existing;
                    if (isEditing && taskToEdit != null) {
                      await widget.controller.updateStudyTask(
                        taskToEdit.id,
                        title: title,
                        type: selectedType,
                        courseName: courseController.text.trim(),
                        deadline: deadline,
                        status: selectedStatus,
                        note: noteController.text.trim(),
                        reminderTime: reminderTime,
                        subTasks: subTasks,
                      );
                    } else {
                      await widget.controller.addStudyTask(
                        title: title,
                        type: selectedType,
                        courseName: courseController.text.trim(),
                        deadline: deadline,
                        status: selectedStatus,
                        note: noteController.text.trim(),
                        reminderTime: reminderTime,
                        subTasks: subTasks,
                      );
                    }
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(disposeControllers);
  }

  void _showEditForm(BuildContext context, StudyTaskItem task) {
    _showTaskForm(context, task);
  }

  Future<void> _resolveOverdueWarning(StudyTaskItem task) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _TaskDialogSurface(
        isDarkMode: widget.isDarkMode,
        icon: Icons.warning_amber_rounded,
        accent: StudyUi.danger,
        title: '处理过期提醒',
        subtitle: '过期提醒只会在任务仍未完成、仍保留在清单里时出现。',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '要怎样处理「${task.title}」？',
              style: TextStyle(
                color: StudyUi.body(widget.isDarkMode),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _TaskActionButton(
                    icon: Icons.check_circle_rounded,
                    label: '标记完成',
                    accent: StudyUi.success,
                    isDarkMode: widget.isDarkMode,
                    filled: true,
                    expand: true,
                    onPressed: () async {
                      await widget.controller.updateStudyTaskStatus(
                        task.id,
                        StudyTaskStatus.completed,
                      );
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();
                      if (!mounted) return;
                      StudyToast.show(context, '已标记完成，过期提醒已收起');
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TaskActionButton(
                    icon: Icons.delete_outline_rounded,
                    label: '删除任务',
                    accent: StudyUi.danger,
                    isDarkMode: widget.isDarkMode,
                    expand: true,
                    onPressed: () async {
                      await widget.controller.deleteStudyTask(task.id);
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();
                      if (!mounted) return;
                      StudyToast.show(context, '已删除任务，过期提醒已收起');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _TaskActionButton(
              icon: Icons.close_rounded,
              label: '先不处理',
              accent: StudyUi.muted(widget.isDarkMode),
              isDarkMode: widget.isDarkMode,
              expand: true,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String? hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: StudyUi.muted(isDark),
      ),
      filled: true,
      fillColor: StudyUi.surfaceAlt(isDark).withValues(alpha: 0.86),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: StudyUi.border(isDark)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: StudyUi.primary, width: 1.3),
      ),
    );
  }
}

class _TaskHeroFocusBanner extends StatelessWidget {
  const _TaskHeroFocusBanner({
    required this.task,
    required this.isDarkMode,
    required this.onTap,
  });

  final StudyTaskItem? task;
  final bool isDarkMode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = task == null ? StudyUi.pathBlue : StudyUi.pathWarm;
    final title = task == null ? '现在没有待完成任务' : task!.title;
    final subtitle = task == null
        ? '当前列表里没有待推进的安排，新建任务后会自动按截止时间排在前面。'
        : '${task!.courseName.isEmpty ? task!.type.label : task!.courseName} · 截止 ${_shortTaskDate(task!.deadline)}';
    return StudyCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      radius: 18,
      color: Colors.white.withValues(alpha: isDarkMode ? 0.05 : 0.62),
      borderColor: accent.withValues(alpha: isDarkMode ? 0.20 : 0.14),
      child: Row(
        children: [
          StudyGlassIconNode(
            icon: task == null ? Icons.done_all_rounded : Icons.flag_rounded,
            accent: accent,
            size: 38,
            iconSize: 17,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task == null ? '今天概览' : '现在先看这件事',
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: AppTypography.title,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
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
                  subtitle,
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
          if (task != null) ...[
            const SizedBox(width: 10),
            BadgePill(
              label: '看路线',
              background: accent.withValues(alpha: 0.12),
              foreground: accent,
            ),
          ],
        ],
      ),
    );
  }
}

class _ActiveTaskFiltersBanner extends StatelessWidget {
  const _ActiveTaskFiltersBanner({
    required this.isDarkMode,
    required this.searchQuery,
    required this.quickFilter,
    required this.statusFilter,
    required this.typeFilter,
    required this.onClear,
  });

  final bool isDarkMode;
  final String searchQuery;
  final _TaskQuickFilter? quickFilter;
  final StudyTaskStatus? statusFilter;
  final StudyTaskType? typeFilter;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final bodyColor = StudyUi.body(isDarkMode);
    return StudyCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderColor: StudyUi.pathBlue.withValues(alpha: isDarkMode ? 0.20 : 0.12),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  height: 32,
                  child: Center(
                    child: Text(
                      '当前筛选',
                      style: TextStyle(
                        color: bodyColor,
                        fontSize: 12,
                        height: 1,
                        fontWeight: AppTypography.title,
                      ),
                    ),
                  ),
                ),
                if (searchQuery.isNotEmpty)
                  BadgePill(
                    label: '搜索：$searchQuery',
                    background: StudyUi.pathBlue.withValues(alpha: 0.12),
                    foreground: StudyUi.pathBlue,
                  ),
                if (quickFilter != null)
                  BadgePill(
                    label: quickFilter!.label,
                    background: _taskQuickFilterColor(quickFilter!)
                        .withValues(alpha: 0.12),
                    foreground: _taskQuickFilterColor(quickFilter!),
                  ),
                if (statusFilter != null)
                  BadgePill(
                    label: statusFilter!.label,
                    background: StudyUi.pathWarm.withValues(alpha: 0.12),
                    foreground: StudyUi.pathWarm,
                  ),
                if (typeFilter != null)
                  BadgePill(
                    label: typeFilter!.label,
                    background: StudyUi.secondary.withValues(alpha: 0.12),
                    foreground: StudyUi.secondary,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _TaskIconButton(
            icon: Icons.restart_alt_rounded,
            accent: StudyUi.pathBlue,
            isDarkMode: isDarkMode,
            size: 34,
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}

String _shortTaskDate(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '${dateTime.month}/${dateTime.day} $hour:$minute';
}

class _TaskHeroMetric extends StatelessWidget {
  const _TaskHeroMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDarkMode,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDarkMode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label，$value',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 62),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: isDarkMode ? 0.18 : 0.12)
                  : Colors.white.withValues(alpha: isDarkMode ? 0.06 : 0.62),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: color.withValues(alpha: selected ? 0.42 : 0.18),
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: color, size: 17),
                    const SizedBox(width: 5),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: StudyUi.title(isDarkMode),
                        fontSize: 14,
                        fontWeight: AppTypography.hero,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: StudyUi.body(isDarkMode),
                    fontSize: 11,
                    fontWeight: AppTypography.title,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskActionButton extends StatelessWidget {
  const _TaskActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.accent,
    required this.isDarkMode,
    required this.onPressed,
    this.filled = false,
    this.expand = false,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final bool isDarkMode;
  final VoidCallback? onPressed;
  final bool filled;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foreground = filled ? Colors.white : accent;
    final background =
        filled ? accent : StudyUi.chipBackground(accent, isDarkMode);
    final disabledForeground =
        StudyUi.muted(isDarkMode).withValues(alpha: 0.62);
    final content = Container(
      width: expand ? double.infinity : null,
      padding: EdgeInsets.symmetric(
        horizontal: expand ? 12 : 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: enabled
            ? background
            : StudyUi.surfaceAlt(isDarkMode).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: enabled
              ? accent.withValues(alpha: filled ? 0.18 : 0.28)
              : StudyUi.border(isDarkMode),
        ),
        boxShadow: [
          if (enabled && filled && !isDarkMode)
            BoxShadow(
              color: accent.withValues(alpha: 0.20),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 16,
            color: enabled ? foreground : disabledForeground,
          ),
          const SizedBox(width: 7),
          if (expand)
            Flexible(child: _label(enabled, foreground, disabledForeground))
          else
            _label(enabled, foreground, disabledForeground),
        ],
      ),
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: content,
      ),
    );
  }

  Widget _label(bool enabled, Color foreground, Color disabledForeground) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: enabled ? foreground : disabledForeground,
        fontSize: 13,
        fontWeight: AppTypography.title,
      ),
    );
  }
}

class _TaskRouteDetailPage extends StatefulWidget {
  const _TaskRouteDetailPage({
    required this.taskId,
    required this.controller,
    required this.isDarkMode,
  });

  final String taskId;
  final AppDataController controller;
  final bool isDarkMode;

  @override
  State<_TaskRouteDetailPage> createState() => _TaskRouteDetailPageState();
}

class _TaskRouteDetailPageState extends State<_TaskRouteDetailPage> {
  final _stepsKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final task = _findTask();
        if (task == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: StudyEmptyState.tasks(
                title: '任务已经不在列表里',
                message: '可能刚刚被删除了，返回任务页再看看其他安排。',
                compact: true,
              ),
            ),
          );
        }

        final progress = task.progress.clamp(0.0, 1.0);
        final accent = _taskAccent(task);
        return ListView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 110),
          children: [
            StudyPathHero(
              isDarkMode: widget.isDarkMode,
              accent: accent,
              badge: '完成路径',
              title: task.title,
              subtitle: '按任务内容、备注和小步骤整理成完成顺序，先看下一步，再一项项推进。',
              icon: Icons.route_rounded,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: StudyPathMetricPill(
                          label: '进度',
                          value: '${(progress * 100).round()}%',
                          icon: Icons.trending_up_rounded,
                          color: accent,
                          isDarkMode: widget.isDarkMode,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StudyPathMetricPill(
                          label: '截止',
                          value: _shortTaskDate(task.deadline),
                          icon: Icons.schedule_rounded,
                          color: StudyUi.pathWarm,
                          isDarkMode: widget.isDarkMode,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: widget.isDarkMode
                          ? Colors.white.withValues(alpha: 0.10)
                          : const Color(0xFFE7ECFF),
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _TaskActionButton(
                          icon: Icons.play_arrow_rounded,
                          label: '开始处理',
                          accent: accent,
                          isDarkMode: widget.isDarkMode,
                          expand: true,
                          onPressed:
                              task.effectiveStatus == StudyTaskStatus.completed
                                  ? null
                                  : () => _startTask(task),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TaskActionButton(
                          icon: Icons.check_rounded,
                          label: '全部完成',
                          accent: StudyUi.pathMint,
                          isDarkMode: widget.isDarkMode,
                          filled: true,
                          expand: true,
                          onPressed:
                              task.effectiveStatus == StudyTaskStatus.completed
                                  ? null
                                  : () => _markTaskCompleted(task),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _TaskRouteSummaryCard(
              task: task,
              isDarkMode: widget.isDarkMode,
              accent: accent,
            ),
            const SizedBox(height: 16),
            KeyedSubtree(
              key: _stepsKey,
              child: _TaskRouteSectionHeader(
                title: '下一步怎么做',
                subtitle: task.subTasks.isEmpty
                    ? '这个任务还没拆小，我先按内容整理成三步。'
                    : '这些小步骤来自原任务，可以在这里逐项完成。',
                isDarkMode: widget.isDarkMode,
                accent: accent,
              ),
            ),
            const SizedBox(height: 10),
            if (task.subTasks.isEmpty)
              ..._buildGeneratedRoute(task, accent)
            else
              for (var i = 0; i < task.subTasks.length; i++) ...[
                _TaskRouteStepTile(
                  index: i + 1,
                  title: task.subTasks[i].title,
                  subtitle: task.subTasks[i].note.isEmpty
                      ? '截止 ${_shortTaskDate(task.subTasks[i].deadline)}'
                      : '${task.subTasks[i].note} · 截止 ${_shortTaskDate(task.subTasks[i].deadline)}',
                  statusLabel: task.subTasks[i].status.label,
                  color: _subTaskAccent(task.subTasks[i]),
                  completed: task.subTasks[i].status == SubTaskStatus.completed,
                  isDarkMode: widget.isDarkMode,
                  onTap: () => _toggleSubTask(task, i),
                ),
                if (i != task.subTasks.length - 1) const SizedBox(height: 10),
              ],
          ],
        );
      },
    );
  }

  StudyTaskItem? _findTask() {
    for (final task in widget.controller.studyTasks) {
      if (task.id == widget.taskId) return task;
    }
    return null;
  }

  List<Widget> _buildGeneratedRoute(StudyTaskItem task, Color accent) {
    final course = task.courseName.isEmpty ? task.type.label : task.courseName;
    final note =
        task.note.trim().isEmpty ? '先确认要做什么、最后要交什么，以及容易漏掉的细节。' : task.note.trim();
    return [
      _TaskRouteStepTile(
        index: 1,
        title: '看清要做什么',
        subtitle: '$course · $note',
        statusLabel: '先看',
        color: StudyUi.pathBlue,
        completed: false,
        isDarkMode: widget.isDarkMode,
      ),
      const SizedBox(height: 10),
      _TaskRouteStepTile(
        index: 2,
        title: '推进主要内容',
        subtitle: task.title,
        statusLabel: task.effectiveStatus.label,
        color: accent,
        completed: task.effectiveStatus == StudyTaskStatus.completed,
        isDarkMode: widget.isDarkMode,
        onTap: () => _markTaskInProgress(task),
      ),
      const SizedBox(height: 10),
      _TaskRouteStepTile(
        index: 3,
        title: '完成前确认',
        subtitle: '要在 ${_fmtDate(task.deadline)} 前完成，最后确认命名、格式和遗漏项。',
        statusLabel: '收尾',
        color: StudyUi.pathWarm,
        completed: false,
        isDarkMode: widget.isDarkMode,
      ),
    ];
  }

  void _startTask(StudyTaskItem task) {
    _markTaskInProgress(task);
    _scrollToSteps();
  }

  void _scrollToSteps() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _stepsKey.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.08,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _markTaskInProgress(StudyTaskItem task) {
    if (task.subTasks.isEmpty) {
      widget.controller
          .updateStudyTaskStatus(task.id, StudyTaskStatus.inProgress);
      return;
    }
    final updated = task.subTasks.toList();
    final index =
        updated.indexWhere((item) => item.status == SubTaskStatus.notStarted);
    if (index >= 0) {
      updated[index] =
          updated[index].copyWith(status: SubTaskStatus.inProgress);
      _updateSubTasks(task, updated);
    }
  }

  void _markTaskCompleted(StudyTaskItem task) {
    if (task.subTasks.isEmpty) {
      widget.controller.updateStudyTaskStatus(task.id, StudyTaskStatus.completed);
      return;
    }
    final updated = task.subTasks
        .map((item) => item.copyWith(status: SubTaskStatus.completed))
        .toList();
    _updateSubTasks(task, updated, status: StudyTaskStatus.completed);
  }

  void _toggleSubTask(StudyTaskItem task, int index) {
    final updated = task.subTasks.toList();
    final current = updated[index];
    final nextStatus = current.status == SubTaskStatus.completed
        ? SubTaskStatus.notStarted
        : SubTaskStatus.completed;
    updated[index] = current.copyWith(status: nextStatus);
    _updateSubTasks(task, updated);
  }

  void _updateSubTasks(
    StudyTaskItem task,
    List<StudySubTaskItem> subTasks, {
    StudyTaskStatus? status,
  }) {
    widget.controller.updateStudyTask(
      task.id,
      title: task.title,
      type: task.type,
      courseName: task.courseName,
      deadline: task.deadline,
      status: status ?? task.status,
      note: task.note,
      reminderTime: task.reminderTime,
      subTasks: subTasks,
    );
  }

  Color _taskAccent(StudyTaskItem task) {
    if (task.effectiveStatus == StudyTaskStatus.completed) {
      return StudyUi.pathMint;
    }
    if (task.deadline.isBefore(DateTime.now())) return StudyUi.pathWarm;
    return StudyUi.pathViolet;
  }

  Color _subTaskAccent(StudySubTaskItem subTask) {
    return switch (subTask.status) {
      SubTaskStatus.completed => StudyUi.pathMint,
      SubTaskStatus.inProgress => StudyUi.pathWarm,
      SubTaskStatus.notStarted => StudyUi.pathViolet,
    };
  }
}

class _TaskRouteSummaryCard extends StatelessWidget {
  const _TaskRouteSummaryCard({
    required this.task,
    required this.isDarkMode,
    required this.accent,
  });

  final StudyTaskItem task;
  final bool isDarkMode;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final course = task.courseName.isEmpty ? task.type.label : task.courseName;
    return StudyCard(
      borderColor: accent.withValues(alpha: isDarkMode ? 0.22 : 0.14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StudyGlassIconNode(
                icon: task.type.icon,
                accent: accent,
                size: 40,
                iconSize: 18,
                isDarkMode: isDarkMode,
              ),
              const SizedBox(width: 12),
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
                        fontSize: 15,
                        fontWeight: AppTypography.hero,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${task.type.label} · ${task.effectiveStatus.label}',
                      style: TextStyle(
                        color: StudyUi.body(isDarkMode),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              BadgePill(
                label: '${task.completedCount}/${task.totalCount}',
                background: accent.withValues(alpha: 0.12),
                foreground: accent,
              ),
            ],
          ),
          if (task.note.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              task.note.trim(),
              style: TextStyle(
                color: StudyUi.body(isDarkMode),
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TaskRouteSectionHeader extends StatelessWidget {
  const _TaskRouteSectionHeader({
    required this.title,
    required this.subtitle,
    required this.isDarkMode,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final bool isDarkMode;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        StudyGlassIconNode(
          icon: Icons.route_rounded,
          accent: accent,
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
                  fontWeight: AppTypography.hero,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: StudyUi.body(isDarkMode),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TaskRouteStepTile extends StatelessWidget {
  const _TaskRouteStepTile({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.color,
    required this.completed,
    required this.isDarkMode,
    this.onTap,
  });

  final int index;
  final String title;
  final String subtitle;
  final String statusLabel;
  final Color color;
  final bool completed;
  final bool isDarkMode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      borderColor: color.withValues(alpha: isDarkMode ? 0.22 : 0.14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StudyGlassIconNode(
            icon: completed ? Icons.check_rounded : Icons.flag_rounded,
            accent: color,
            size: 42,
            iconSize: 18,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    BadgePill(
                      label: '第 $index 步',
                      background: color.withValues(alpha: 0.12),
                      foreground: color,
                    ),
                    const SizedBox(width: 8),
                    BadgePill(
                      label: statusLabel,
                      background: StudyUi.surfaceAlt(isDarkMode),
                      foreground: color,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: StudyUi.title(isDarkMode),
                    fontSize: 15,
                    fontWeight: AppTypography.hero,
                    decoration: completed ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: StudyUi.body(isDarkMode),
                    fontSize: 12,
                    height: 1.42,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            Icon(
              completed
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 22,
              color: color,
            ),
          ],
        ],
      ),
    );
  }
}

class _TaskIconButton extends StatelessWidget {
  const _TaskIconButton({
    required this.icon,
    required this.accent,
    required this.isDarkMode,
    required this.onPressed,
    this.size = 40,
  });

  final IconData icon;
  final Color accent;
  final bool isDarkMode;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.46,
          duration: const Duration(milliseconds: 160),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: StudyUi.chipBackground(accent, isDarkMode),
              border: Border.all(
                color: accent.withValues(alpha: isDarkMode ? 0.22 : 0.24),
              ),
            ),
            child: Icon(icon, color: accent, size: size * 0.50),
          ),
        ),
      ),
    );
  }
}

class _TaskSheetSurface extends StatelessWidget {
  const _TaskSheetSurface({
    required this.isDarkMode,
    required this.child,
    this.heightFactor = 0.88,
  });

  final bool isDarkMode;
  final Widget child;
  final double heightFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: heightFactor,
      alignment: Alignment.bottomCenter,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDarkMode
                    ? const [
                        Color(0xF017222C),
                        Color(0xF01D2A35),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.95),
                        const Color(0xFFF4FAFF).withValues(alpha: 0.92),
                      ],
              ),
              border: Border(
                top: BorderSide(
                  color:
                      Colors.white.withValues(alpha: isDarkMode ? 0.12 : 0.86),
                ),
              ),
            ),
            child: StudyFontScope(child: child),
          ),
        ),
      ),
    );
  }
}

class _TaskDialogSurface extends StatelessWidget {
  const _TaskDialogSurface({
    required this.isDarkMode,
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final bool isDarkMode;
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: StudyFontScope(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 390),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDarkMode
                      ? const [
                          Color(0xEE17222C),
                          Color(0xEE1D2A35),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.94),
                          const Color(0xFFF5F8FF).withValues(alpha: 0.90),
                        ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color:
                      Colors.white.withValues(alpha: isDarkMode ? 0.12 : 0.84),
                ),
                boxShadow: [
                  if (!isDarkMode)
                    BoxShadow(
                      color: accent.withValues(alpha: 0.15),
                      blurRadius: 32,
                      offset: const Offset(0, 18),
                    ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TaskSheetTitle(
                    isDarkMode: isDarkMode,
                    icon: icon,
                    accent: accent,
                    title: title,
                    subtitle: subtitle,
                  ),
                  const SizedBox(height: 18),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskSheetTitle extends StatelessWidget {
  const _TaskSheetTitle({
    required this.isDarkMode,
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
  });

  final bool isDarkMode;
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        StudyGlassIconNode(
          icon: icon,
          accent: accent,
          isDarkMode: isDarkMode,
          size: 46,
          iconSize: 21,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: StudyUi.title(isDarkMode),
                  fontSize: 21,
                  fontWeight: AppTypography.hero,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: StudyUi.body(isDarkMode),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TaskTypeSelector extends StatelessWidget {
  const _TaskTypeSelector({
    required this.selectedType,
    required this.isDarkMode,
    required this.accent,
    required this.onChanged,
  });

  final StudyTaskType selectedType;
  final bool isDarkMode;
  final Color accent;
  final ValueChanged<StudyTaskType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: StudyTaskType.values.map((type) {
        final selected = type == selectedType;
        return _TaskActionButton(
          icon: type.icon,
          label: type.label,
          accent: accent,
          isDarkMode: isDarkMode,
          filled: selected,
          onPressed: () => onChanged(type),
        );
      }).toList(growable: false),
    );
  }
}

class _TaskStatusSelector extends StatelessWidget {
  const _TaskStatusSelector({
    required this.selectedStatus,
    required this.isDarkMode,
    required this.accent,
    required this.onChanged,
  });

  final StudyTaskStatus selectedStatus;
  final bool isDarkMode;
  final Color accent;
  final ValueChanged<StudyTaskStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: StudyTaskStatus.values.map((status) {
        final selected = status == selectedStatus;
        final color = switch (status) {
          StudyTaskStatus.completed => StudyUi.success,
          StudyTaskStatus.inProgress => StudyUi.warning,
          StudyTaskStatus.notStarted => accent,
        };
        return _TaskActionButton(
          icon: _statusIcon(status),
          label: status.label,
          accent: color,
          isDarkMode: isDarkMode,
          filled: selected,
          onPressed: () => onChanged(status),
        );
      }).toList(growable: false),
    );
  }

  IconData _statusIcon(StudyTaskStatus status) => switch (status) {
        StudyTaskStatus.completed => Icons.check_rounded,
        StudyTaskStatus.inProgress => Icons.play_arrow_rounded,
        StudyTaskStatus.notStarted => Icons.radio_button_unchecked_rounded,
      };
}

class _TaskDateTimeButton extends StatelessWidget {
  const _TaskDateTimeButton({
    required this.icon,
    required this.label,
    required this.accent,
    required this.isDarkMode,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final bool isDarkMode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _TaskActionButton(
      icon: icon,
      label: label,
      accent: accent,
      isDarkMode: isDarkMode,
      onPressed: onPressed,
      expand: true,
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({required this.label, required this.child});
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

class _CourseSelector extends StatefulWidget {
  final bool isDarkMode;
  final TextEditingController controller;
  final List<String> allCourses;
  final ValueChanged<String> onSelectionChanged;
  final Color accentColor;

  const _CourseSelector({
    required this.isDarkMode,
    required this.controller,
    required this.allCourses,
    required this.onSelectionChanged,
    required this.accentColor,
  });

  @override
  State<_CourseSelector> createState() => _CourseSelectorState();
}

class _CourseSelectorState extends State<_CourseSelector> {
  bool _showDropdown = false;
  List<String> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateSuggestions);
    _updateSuggestions();
  }

  @override
  void didUpdateWidget(_CourseSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_updateSuggestions);
      widget.controller.addListener(_updateSuggestions);
      _updateSuggestions();
    } else if (oldWidget.allCourses != widget.allCourses) {
      _updateSuggestions();
    }
  }

  void _updateSuggestions() {
    final query = widget.controller.text.toLowerCase();
    final newList = widget.allCourses
        .where(
          (c) => c.toLowerCase().contains(query) && c.toLowerCase() != query,
        )
        .toList();
    if (!_listEquals(_suggestions, newList)) {
      _suggestions = newList;
      setState(() {});
    }
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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
              color: StudyUi.muted(widget.isDarkMode),
            ),
            filled: true,
            fillColor:
                StudyUi.surfaceAlt(widget.isDarkMode).withValues(alpha: 0.86),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: StudyUi.border(widget.isDarkMode)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: widget.accentColor.withValues(alpha: 0.62),
                width: 1.3,
              ),
            ),
            suffixIcon: widget.controller.text.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _TaskIconButton(
                      icon: Icons.close_rounded,
                      accent: StudyUi.muted(widget.isDarkMode),
                      isDarkMode: widget.isDarkMode,
                      size: 34,
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
              color: StudyUi.surface(widget.isDarkMode),
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

class _TaskCard extends StatefulWidget {
  const _TaskCard({
    super.key,
    required this.task,
    required this.isDarkMode,
    required this.isOverdue,
    required this.onStatusChanged,
    required this.onOpenDetail,
    required this.onEdit,
    required this.onRescheduleOverdue,
    required this.onDismissOverdueWarning,
    required this.onDelete,
    this.onSubTaskToggled,
  });

  final StudyTaskItem task;
  final bool isDarkMode;
  final bool isOverdue;
  final ValueChanged<StudyTaskStatus> onStatusChanged;
  final VoidCallback onOpenDetail;
  final VoidCallback onEdit;
  final VoidCallback? onRescheduleOverdue;
  final VoidCallback? onDismissOverdueWarning;
  final VoidCallback onDelete;
  final void Function(int subTaskIndex, SubTaskStatus newStatus)?
      onSubTaskToggled;

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  bool _expanded = false;
  late StudyTaskItem _task;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
  }

  @override
  void didUpdateWidget(covariant _TaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task != widget.task) _task = widget.task;
  }

  void _handleMenu(String action) {
    switch (action) {
      case 'edit':
        widget.onEdit();
        return;
      case 'reschedule_overdue':
        widget.onRescheduleOverdue?.call();
        return;
      case 'dismiss_overdue':
        widget.onDismissOverdueWarning?.call();
        return;
      case 'delete':
        widget.onDelete();
        return;
      case 'status_completed':
        widget.onStatusChanged(StudyTaskStatus.completed);
        return;
      case 'status_inProgress':
        widget.onStatusChanged(StudyTaskStatus.inProgress);
        return;
      case 'status_notStarted':
        widget.onStatusChanged(StudyTaskStatus.notStarted);
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final task = _task;
    final titleColor = StudyUi.title(isDark);
    final bodyColor = StudyUi.body(isDark);
    final effStatus = task.effectiveStatus;

    final statusColor = switch (effStatus) {
      StudyTaskStatus.completed => StudyUi.success,
      StudyTaskStatus.inProgress => StudyUi.warning,
      StudyTaskStatus.notStarted => StudyUi.secondary,
    };

    return StudyCard(
      onTap: widget.onOpenDetail,
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6)),
                          child: Text(effStatus.label,
                              style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 8),
                        BadgePill(
                            label: task.type.label,
                            background: StudyUi.chipBackground(
                                StudyUi.secondary, isDark),
                            foreground: StudyUi.secondary),
                        if (task.isTaskSet) ...[
                          const SizedBox(width: 8),
                          Text('${task.completedCount}/${task.totalCount}',
                              style: TextStyle(
                                  color: bodyColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(task.title,
                        style: TextStyle(
                            color: titleColor,
                            fontSize: 16,
                            fontWeight: AppTypography.title)),
                    if (task.courseName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('课程：${task.courseName}',
                          style: TextStyle(color: bodyColor, fontSize: 13)),
                    ],
                    const SizedBox(height: 4),
                    Text('要在 ${_fmtDate(task.deadline)} 前完成',
                        style: TextStyle(
                            color: StudyUi.muted(isDark),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    if (task.note.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(task.note,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: bodyColor, fontSize: 13, height: 1.45)),
                    ],
                    if (widget.isOverdue) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: StudyUi.danger.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: StudyUi.danger.withValues(alpha: 0.16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: StudyUi.danger,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '这项安排已过期，可以重排时间、完成或删除',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: StudyUi.danger,
                                      fontSize: 12,
                                      fontWeight: AppTypography.title,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _TaskActionButton(
                                    icon: Icons.edit_calendar_rounded,
                                    label: '重排时间',
                                    accent: StudyUi.pathWarm,
                                    isDarkMode: isDark,
                                    expand: true,
                                    onPressed: widget.onRescheduleOverdue,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _TaskActionButton(
                                    icon: Icons.notifications_off_rounded,
                                    label: '收起提醒',
                                    accent: StudyUi.danger,
                                    isDarkMode: isDark,
                                    expand: true,
                                    onPressed:
                                        widget.onDismissOverdueWarning,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              StudyPopupMenuButton<String>(
                icon:
                    Icon(Icons.more_vert_rounded, color: StudyUi.muted(isDark)),
                onSelected: _handleMenu,
                itemBuilder: (_) => [
                  PopupMenuItem(
                      value: 'status_completed',
                      child: Text('标记完成',
                          style: TextStyle(
                              color: isDark ? Colors.white : AppColors.ink))),
                  PopupMenuItem(
                      value: 'status_inProgress',
                      child: Text('标记进行中',
                          style: TextStyle(
                              color: isDark ? Colors.white : AppColors.ink))),
                  PopupMenuItem(
                      value: 'status_notStarted',
                      child: Text('标记未开始',
                          style: TextStyle(
                              color: isDark ? Colors.white : AppColors.ink))),
                  if (widget.isOverdue) ...[
                    const PopupMenuDivider(),
                    PopupMenuItem(
                        value: 'reschedule_overdue',
                        child: const Text('重排时间',
                            style: TextStyle(color: StudyUi.pathWarm))),
                    PopupMenuItem(
                        value: 'dismiss_overdue',
                        child: const Text('收起过期提醒',
                            style: TextStyle(color: StudyUi.danger))),
                  ],
                  const PopupMenuDivider(),
                  PopupMenuItem(
                      value: 'edit',
                      child: const Text('编辑任务',
                          style: TextStyle(color: Color(0xFF7394F9)))),
                  PopupMenuItem(
                      value: 'delete',
                      child: const Text('删除任务',
                          style: TextStyle(color: Color(0xFFEF6850)))),
                ],
              ),
            ],
          ),
          // Expandable sub-tasks
          if (task.subTasks.isNotEmpty) ...[
            const SizedBox(height: 4),
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18, color: bodyColor),
                  Text(
                      '${_expanded ? '收起' : '展开'}子任务 (${task.completedCount}/${task.totalCount})',
                      style: TextStyle(color: bodyColor, fontSize: 12)),
                ],
              ),
            ),
            if (_expanded) ...[
              const SizedBox(height: 6),
              ...task.subTasks.map((st) => Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            final newStatus =
                                st.status == SubTaskStatus.completed
                                    ? SubTaskStatus.notStarted
                                    : SubTaskStatus.completed;
                            widget.onSubTaskToggled
                                ?.call(task.subTasks.indexOf(st), newStatus);
                          },
                          child: Icon(
                            st.status == SubTaskStatus.completed
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            size: 16,
                            color: st.status == SubTaskStatus.completed
                                ? const Color(0xFF4BC4A1)
                                : bodyColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(st.title,
                                style: TextStyle(
                                    color: titleColor,
                                    fontSize: 13,
                                    decoration:
                                        st.status == SubTaskStatus.completed
                                            ? TextDecoration.lineThrough
                                            : null))),
                        Text(_fmtDate(st.deadline),
                            style: TextStyle(color: bodyColor, fontSize: 10)),
                      ],
                    ),
                  )),
            ],
          ],
        ],
      ),
    );
  }
}

String _fmtDate(DateTime date) {
  final h = date.hour.toString().padLeft(2, '0');
  final m = date.minute.toString().padLeft(2, '0');
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} $h:$m';
}
