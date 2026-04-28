import 'package:flutter/material.dart';

import '../../controllers/app_data_controller.dart';
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
    var result = tasks;
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
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
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
                              style: const TextStyle(fontSize: 12)),
                          selected: _statusFilter == s,
                          selectedColor: const Color(0xFF7040F2).withValues(alpha: 0.22),
                          checkmarkColor: const Color(0xFF7040F2),
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
                              style: const TextStyle(fontSize: 12)),
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
                  backgroundColor: const Color(0xFF7040F2),
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
                ),
                if (task != tasks.last) const SizedBox(height: 12),
              ],
          ],
        );
      },
    );
  }

  void _showTaskForm(BuildContext context, [StudyTaskItem? existing]) {
    final isEditing = existing != null;
    final titleController = TextEditingController(text: existing?.title ?? '');
    final courseController = TextEditingController(text: existing?.courseName ?? '');
    final noteController = TextEditingController(text: existing?.note ?? '');
    var selectedType = existing?.type ?? StudyTaskType.other;
    var selectedStatus = existing?.status ?? StudyTaskStatus.notStarted;
    var deadline = existing?.deadline ?? DateTime.now().add(const Duration(days: 7));

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
                      color: widget.isDarkMode
                          ? Colors.white24
                          : Colors.black26,
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
                  child: TextField(
                    controller: courseController,
                    style: TextStyle(
                      color: widget.isDarkMode ? Colors.white : AppColors.ink,
                    ),
                    decoration: _inputDeco('例如：高等数学', widget.isDarkMode),
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
                      backgroundColor:
                          widget.isDarkMode ? const Color(0xFF2A3040) : const Color(0xFFEEF1FA),
                      selectedBackgroundColor: const Color(0xFF7040F2),
                      foregroundColor: widget.isDarkMode ? Colors.white70 : AppColors.body,
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
                        initialDate: deadline,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setSheetState(() => deadline = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today_rounded, size: 18),
                    label: Text(
                      '${deadline.year}-${deadline.month.toString().padLeft(2, '0')}-${deadline.day.toString().padLeft(2, '0')}',
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
                      final title = titleController.text.trim();
                      if (title.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('请输入任务标题')),
                        );
                        return;
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
                        );
                      } else {
                        await widget.controller.addStudyTask(
                          title: title,
                          type: selectedType,
                          courseName: courseController.text.trim(),
                          deadline: deadline,
                          status: selectedStatus,
                          note: noteController.text.trim(),
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
    );
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

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    super.key,
    required this.task,
    required this.isDarkMode,
    required this.onStatusChanged,
    required this.onEdit,
    required this.onDelete,
  });

  final StudyTaskItem task;
  final bool isDarkMode;
  final ValueChanged<StudyTaskStatus> onStatusChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final titleColor = isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor = isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;

    final statusColor = switch (task.status) {
      StudyTaskStatus.completed => const Color(0xFF4BC4A1),
      StudyTaskStatus.inProgress => const Color(0xFFF8AA5B),
      StudyTaskStatus.notStarted =>
          isDarkMode ? const Color(0xFFB0B8CC) : const Color(0xFF8B93A7),
    };

    return GlassCard(
      color: isDarkMode
          ? const Color(0xFF242B37).withValues(alpha: 0.9)
          : null,
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      child: Row(
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
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        task.status.label,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    BadgePill(
                      label: task.type.label,
                      background: const Color(0x197394F9),
                      foreground: const Color(0xFF7394F9),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  task.title,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (task.courseName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '📖 ${task.courseName}',
                    style: TextStyle(color: bodyColor, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '截止：${_fmtDate(task.deadline)}',
                  style: TextStyle(
                    color:
                        isDarkMode ? Colors.white54 : AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (task.subtasks.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...task.subtasks.map((st) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('· ',
                                style: TextStyle(
                                    color: bodyColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                            Expanded(
                              child: Text(st,
                                  style: TextStyle(
                                      color: bodyColor, fontSize: 12)),
                            ),
                          ],
                        ),
                      )),
                ],
                if (task.note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    task.note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: bodyColor, fontSize: 13, height: 1.45),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<StudyTaskStatus>(
            icon: Icon(
              Icons.more_vert_rounded,
              color: isDarkMode ? Colors.white54 : AppColors.muted,
            ),
            color:
                isDarkMode ? const Color(0xFF242B37) : Colors.white,
            onSelected: onStatusChanged,
            itemBuilder: (_) => StudyTaskStatus.values
                .map((s) => PopupMenuItem(
                      value: s,
                      child: Text(
                        '切换为「${s.label}」',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : AppColors.ink,
                        ),
                      ),
                    ))
                .toList()
              ..add(
                const PopupMenuItem(
                  value: null,
                  enabled: false,
                  child: Divider(height: 1),
                ),
              )
              ..add(
                PopupMenuItem(
                  value: null,
                  enabled: false,
                  child: InkWell(
                    onTap: onEdit,
                    child: const Text(
                      '编辑任务',
                      style: TextStyle(color: Color(0xFF7394F9)),
                    ),
                  ),
                ),
              )
              ..add(
                PopupMenuItem(
                  value: null,
                  enabled: false,
                  child: InkWell(
                    onTap: onDelete,
                    child: const Text(
                      '删除任务',
                      style: TextStyle(color: Color(0xFFEF6850)),
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

String _fmtDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
