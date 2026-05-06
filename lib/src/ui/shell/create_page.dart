import 'package:flutter/material.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/study_sub_task_item.dart';
import '../../models/study_task_item.dart';
import '../../theme/app_theme.dart';
import '../shared/common_widgets.dart';

class StudyTasksPage extends StatefulWidget {
  const StudyTasksPage({
    super.key,
    required this.isDarkMode,
    required this.controller,
  });

  final bool isDarkMode;
  final AppDataController controller;

  @override
  State<StudyTasksPage> createState() => _StudyTasksPageState();
}

class _StudyTasksPageState extends State<StudyTasksPage> {
  String _searchQuery = '';
  StudyTaskStatus? _statusFilter;
  StudyTaskType? _typeFilter;

  List<StudyTaskItem> _filteredTasks(List<StudyTaskItem> tasks) {
    var result = tasks.toList(); // 确保是可修改的列表
    if (_statusFilter != null) {
      result = result.where((t) => t.status == _statusFilter).toList();
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
      final aDeadline =
          _earliestUnfinishedDeadline(a.subTasks, a.deadline);
      final bDeadline =
          _earliestUnfinishedDeadline(b.subTasks, b.deadline);
      return aDeadline.compareTo(bDeadline);
    });
    return result;
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
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final accent = widget.controller.primaryColor;
        final allTasks = widget.controller.studyTasks;
        final tasks = _filteredTasks(allTasks);

        return ListView(
          key: const Key('page_study_tasks'),
          padding: const EdgeInsets.fromLTRB(22, 94, 22, 124),
          children: [
            Text(
              '学习任务',
              style: TextStyle(
                color: widget.isDarkMode ? Colors.white : Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            // Search bar
            TextField(
              key: const Key('task_search_field'),
              onChanged: (v) => setState(() => _searchQuery = v),
              style: TextStyle(
                color: widget.isDarkMode ? Colors.white : AppColors.ink,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: '搜索任务标题或课程...',
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
            const SizedBox(height: 10),
            // Filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Status filter chips
                  ...StudyTaskStatus.values.map((s) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(s.label,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: widget.isDarkMode
                                      ? Colors.white
                                      : AppColors.ink)),
                          selected: _statusFilter == s,
                          selectedColor:
                              accent.withValues(alpha: 0.2),
                          checkmarkColor: accent,
                          backgroundColor: widget.isDarkMode
                              ? const Color(0xFF2A3040)
                              : const Color(0xFFEEF1FA),
                          side: BorderSide.none,
                          onSelected: (sel) {
                            setState(() => _statusFilter = sel ? s : null);
                          },
                        ),
                      )),
                  const SizedBox(width: 4),
                  // Type filter chips
                  ...StudyTaskType.values.map((t) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(t.label,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: widget.isDarkMode
                                      ? Colors.white
                                      : AppColors.ink)),
                          selected: _typeFilter == t,
                          selectedColor:
                              const Color(0xFF7394F9).withValues(alpha: 0.22),
                          checkmarkColor: const Color(0xFF7394F9),
                          backgroundColor: widget.isDarkMode
                              ? const Color(0xFF2A3040)
                              : const Color(0xFFEEF1FA),
                          side: BorderSide.none,
                          onSelected: (sel) {
                            setState(() => _typeFilter = sel ? t : null);
                          },
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                key: const Key('add_task_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 0,
                ),
                onPressed: () => _showTaskForm(context),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(
                  '添加学习任务',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (allTasks.isEmpty)
              GlassCard(
                key: const Key('tasks_empty_state'),
                color: widget.isDarkMode
                    ? const Color(0xFF242B37).withValues(alpha: 0.9)
                    : null,
                child: Text(
                  '还没有学习任务。点击上方按钮添加你的第一个任务。',
                  style: TextStyle(
                    color: widget.isDarkMode
                        ? const Color(0xFFC2C8D6)
                        : AppColors.body,
                    height: 1.55,
                  ),
                ),
              )
            else if (tasks.isEmpty)
              GlassCard(
                key: const Key('tasks_filter_empty_state'),
                color: widget.isDarkMode
                    ? const Color(0xFF242B37).withValues(alpha: 0.9)
                    : null,
                child: Text(
                  '没有匹配的任务。尝试调整筛选条件或搜索关键词。',
                  style: TextStyle(
                    color: widget.isDarkMode
                        ? const Color(0xFFC2C8D6)
                        : AppColors.body,
                    height: 1.55,
                  ),
                ),
              )
            else
              for (final task in tasks) ...[
                _TaskCard(
                  key: Key('task_item_${task.id}'),
                  task: task,
                  isDarkMode: widget.isDarkMode,
                  onStatusChanged: (status) =>
                      widget.controller.updateStudyTaskStatus(task.id, status),
                  onEdit: () => _showEditForm(context, task),
                  onDelete: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('删除任务'),
                        content: Text('确定要删除「${task.title}」吗？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () {
                              widget.controller.deleteStudyTask(task.id);
                              Navigator.of(ctx).pop();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFEF6850),
                            ),
                            child: const Text('删除'),
                          ),
                        ],
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
    );
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
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.88,
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
                  isEditing ? '编辑学习任务' : '添加学习任务',
                  style: TextStyle(
                    color: widget.isDarkMode ? Colors.white : AppColors.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
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
                  child: DropdownButtonFormField<StudyTaskType>(
                    initialValue: selectedType,
                    dropdownColor: widget.isDarkMode
                        ? const Color(0xFF242B37)
                        : Colors.white,
                    style: TextStyle(
                      color: widget.isDarkMode ? Colors.white : AppColors.ink,
                    ),
                    decoration: _inputDeco(null, widget.isDarkMode),
                    items: StudyTaskType.values
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(t.label),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setSheetState(() => selectedType = v);
                    },
                  ),
                ),
                const SizedBox(height: 14),
                _FormField(
                  label: '状态',
                  child: SegmentedButton<StudyTaskStatus>(
                    style: SegmentedButton.styleFrom(
                      backgroundColor: widget.isDarkMode
                          ? const Color(0xFF2A3040)
                          : const Color(0xFFEEF1FA),
                      selectedBackgroundColor: accent,
                      foregroundColor:
                          widget.isDarkMode ? Colors.white70 : AppColors.body,
                      selectedForegroundColor: Colors.white,
                    ),
                    segments: StudyTaskStatus.values
                        .map((s) => ButtonSegment(
                              value: s,
                              label: Text(
                                s.label,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ))
                        .toList(),
                    selected: {selectedStatus},
                    onSelectionChanged: (v) {
                      setSheetState(() => selectedStatus = v.first);
                    },
                  ),
                ),
                const SizedBox(height: 14),
                _FormField(
                  label: '截止时间',
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
                    icon: const Icon(Icons.calendar_today_rounded, size: 18),
                    label: Text(
                      '${deadline.year}-${deadline.month.toString().padLeft(2, '0')}-${deadline.day.toString().padLeft(2, '0')} '
                      '${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _FormField(
                  label: '提醒时间（可选）',
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: widget.isDarkMode
                          ? Colors.white
                          : const Color(0xFF4BC4A1),
                      side: BorderSide(
                        color: widget.isDarkMode
                            ? Colors.white24
                            : const Color(0x334BC4A1),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
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
                    icon: const Icon(Icons.notifications_active_rounded,
                        size: 18),
                    label: Text(
                      reminderTime != null
                          ? '${reminderTime!.year}-${reminderTime!.month.toString().padLeft(2, '0')}-${reminderTime!.day.toString().padLeft(2, '0')} ${reminderTime!.hour.toString().padLeft(2, '0')}:${reminderTime!.minute.toString().padLeft(2, '0')}'
                          : '不设置提醒',
                      style: const TextStyle(fontSize: 13),
                    ),
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
                        color: widget.isDarkMode
                            ? Colors.white
                            : AppColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        setSheetState(() {
                          subTaskControllers.add(TextEditingController());
                          subTaskDeadlines.add(deadline);
                        });
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('添加'),
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
                              color: widget.isDarkMode
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : const Color(0xFFF2F5FC),
                            ),
                            child: Icon(Icons.calendar_today_rounded,
                                size: 18,
                                color: widget.isDarkMode
                                    ? Colors.white54
                                    : Colors.black38),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            late final TextEditingController removedController;
                            setSheetState(() {
                              removedController = subTaskControllers.removeAt(i);
                              subTaskDeadlines.removeAt(i);
                            });
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              removedController.dispose();
                            });
                          },
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Text(
                        '截止：${subTaskDeadlines[i].year}-'
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
                      final title = titleController.text.trim();
                      if (title.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('请输入任务标题')),
                        );
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
                    child: Text(
                      isEditing ? '更新任务' : '保存任务',
                      style: const TextStyle(
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
    ).whenComplete(disposeControllers);
  }

  void _showEditForm(BuildContext context, StudyTaskItem task) {
    _showTaskForm(context, task);
  }

  InputDecoration _inputDeco(String? hint, bool isDark) {
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

class _TaskCard extends StatefulWidget {
  const _TaskCard({
    super.key,
    required this.task,
    required this.isDarkMode,
    required this.onStatusChanged,
    required this.onEdit,
    required this.onDelete,
    this.onSubTaskToggled,
  });

  final StudyTaskItem task;
  final bool isDarkMode;
  final ValueChanged<StudyTaskStatus> onStatusChanged;
  final VoidCallback onEdit;
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
      case 'delete':
        widget.onDelete();
      case 'status_completed':
        widget.onStatusChanged(StudyTaskStatus.completed);
      case 'status_inProgress':
        widget.onStatusChanged(StudyTaskStatus.inProgress);
      case 'status_notStarted':
        widget.onStatusChanged(StudyTaskStatus.notStarted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final task = _task;
    final titleColor = isDark ? Colors.white : AppColors.ink;
    final bodyColor = isDark ? const Color(0xFFC2C8D6) : AppColors.body;
    final effStatus = task.effectiveStatus;

    final statusColor = switch (effStatus) {
      StudyTaskStatus.completed => const Color(0xFF4BC4A1),
      StudyTaskStatus.inProgress => const Color(0xFFF8AA5B),
      StudyTaskStatus.notStarted =>
        isDark ? const Color(0xFFB0B8CC) : const Color(0xFF8B93A7),
    };

    return GlassCard(
      color: isDark ? const Color(0xFF242B37).withValues(alpha: 0.9) : null,
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
                            background: const Color(0x197394F9),
                            foreground: const Color(0xFF7394F9)),
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
                            fontWeight: FontWeight.w800)),
                    if (task.courseName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('📖 ${task.courseName}',
                          style: TextStyle(color: bodyColor, fontSize: 13)),
                    ],
                    const SizedBox(height: 4),
                    Text('截止：${_fmtDate(task.deadline)}',
                        style: TextStyle(
                            color: isDark ? Colors.white54 : AppColors.muted,
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
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded,
                    color: isDark ? Colors.white54 : AppColors.muted),
                color: isDark ? const Color(0xFF242B37) : Colors.white,
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
