import 'package:flutter/material.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/study_note.dart';
import '../../theme/app_theme.dart';
import '../shared/common_widgets.dart';

class StudyNotesPage extends StatefulWidget {
  const StudyNotesPage({
    super.key,
    required this.isDarkMode,
    required this.controller,
  });

  final bool isDarkMode;
  final AppDataController controller;

  @override
  State<StudyNotesPage> createState() => _StudyNotesPageState();
}

class _StudyNotesPageState extends State<StudyNotesPage> {
  String _searchQuery = '';

  List<StudyNote> _filteredNotes(List<StudyNote> notes) {
    if (_searchQuery.isEmpty) return notes;
    final q = _searchQuery.toLowerCase();
    return notes
        .where((n) =>
            n.title.toLowerCase().contains(q) ||
            n.content.toLowerCase().contains(q) ||
            n.courseName.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final allNotes = widget.controller.studyNotes;
        final notes = _filteredNotes(allNotes);

        return Scaffold(
          backgroundColor: widget.isDarkMode
              ? const Color(0xFF141923)
              : const Color(0xFFF5F7FF),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor:
                widget.isDarkMode ? Colors.white : AppColors.ink,
            title: const Text('学习笔记',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 100),
            children: [
              // Search bar
              TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.white : AppColors.ink,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: '搜索笔记标题或内容...',
                  hintStyle: TextStyle(
                    color: widget.isDarkMode
                        ? Colors.white.withValues(alpha: 0.4)
                        : AppColors.muted,
                  ),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: widget.isDarkMode ? Colors.white54 : AppColors.muted,
                      size: 22),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded,
                              color: widget.isDarkMode
                                  ? Colors.white54
                                  : AppColors.muted,
                              size: 20),
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
              const SizedBox(height: 18),
              if (allNotes.isEmpty)
                GlassCard(
                  color: widget.isDarkMode
                      ? const Color(0xFF242B37).withValues(alpha: 0.9)
                      : null,
                  child: const Text(
                    '还没有学习笔记。点击右下角按钮开始记录你的学习心得。',
                    style: TextStyle(height: 1.55),
                  ),
                )
              else if (notes.isEmpty)
                GlassCard(
                  color: widget.isDarkMode
                      ? const Color(0xFF242B37).withValues(alpha: 0.9)
                      : null,
                  child: const Text(
                    '没有匹配的笔记。尝试其他关键词。',
                    style: TextStyle(height: 1.55),
                  ),
                )
              else
                for (final note in notes) ...[
                  _NoteCard(
                    note: note,
                    isDarkMode: widget.isDarkMode,
                    onTap: () => _openEditor(note: note),
                    onDelete: () => _deleteNote(note),
                  ),
                  if (note != notes.last) const SizedBox(height: 10),
                ],
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: const Color(0xFF7040F2),
            foregroundColor: Colors.white,
            onPressed: () => _openEditor(),
            child: const Icon(Icons.add_rounded),
          ),
        );
      },
    );
  }

  void _openEditor({StudyNote? note}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _NoteEditPage(
          isDarkMode: widget.isDarkMode,
          controller: widget.controller,
          existingNote: note,
        ),
      ),
    );
  }

  void _deleteNote(StudyNote note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除笔记'),
        content: Text('确定要删除「${note.title}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              widget.controller.deleteStudyNote(note.id);
              Navigator.of(ctx).pop();
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF6850)),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.isDarkMode,
    required this.onTap,
    required this.onDelete,
  });

  final StudyNote note;
  final bool isDarkMode;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: GlassCard(
          color: isDarkMode
              ? const Color(0xFF242B37).withValues(alpha: 0.9)
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0x197394F9),
                    ),
                    child: const Icon(Icons.article_rounded,
                        color: Color(0xFF7394F9), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.title,
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : AppColors.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (note.courseName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            note.courseName,
                            style: TextStyle(
                              color: isDarkMode
                                  ? Colors.white54
                                  : AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline_rounded,
                        color: isDarkMode ? Colors.white54 : AppColors.muted,
                        size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              if (note.content.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  note.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body,
                    height: 1.5,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                _fmtDate(note.updatedAt),
                style: TextStyle(
                  color: isDarkMode ? Colors.white38 : AppColors.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _NoteEditPage extends StatefulWidget {
  const _NoteEditPage({
    required this.isDarkMode,
    required this.controller,
    this.existingNote,
  });

  final bool isDarkMode;
  final AppDataController controller;
  final StudyNote? existingNote;

  @override
  State<_NoteEditPage> createState() => _NoteEditPageState();
}

class _NoteEditPageState extends State<_NoteEditPage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _courseController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.existingNote?.title ?? '');
    _contentController =
        TextEditingController(text: widget.existingNote?.content ?? '');
    _courseController =
        TextEditingController(text: widget.existingNote?.courseName ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _courseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isDarkMode
          ? const Color(0xFF141923)
          : const Color(0xFFF5F7FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: widget.isDarkMode ? Colors.white : AppColors.ink,
        title: Text(
          widget.existingNote != null ? '编辑笔记' : '新建笔记',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: Text(
              _isSaving ? '保存中...' : '保存',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: widget.isDarkMode
                    ? Colors.white
                    : const Color(0xFF7040F2),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 40),
        children: [
          TextField(
            controller: _titleController,
            style: TextStyle(
              color: widget.isDarkMode ? Colors.white : AppColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
            decoration: InputDecoration(
              hintText: '笔记标题',
              hintStyle: TextStyle(
                color: widget.isDarkMode
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.black26,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _courseController,
            style: TextStyle(
              color: widget.isDarkMode ? Colors.white54 : AppColors.muted,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: '关联课程（可选）',
              hintStyle: TextStyle(
                color: widget.isDarkMode
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.black26,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const Divider(height: 28),
          TextField(
            controller: _contentController,
            maxLines: null,
            minLines: 8,
            style: TextStyle(
              color: widget.isDarkMode ? Colors.white : AppColors.ink,
              fontSize: 15,
              height: 1.7,
            ),
            decoration: InputDecoration(
              hintText: '开始记录你的学习笔记...\n\n支持自由书写，记录课堂重点、学习心得、代码片段等。',
              hintStyle: TextStyle(
                color: widget.isDarkMode
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.black26,
                height: 1.7,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入笔记标题')),
      );
      return;
    }
    setState(() => _isSaving = true);
    final existing = widget.existingNote;
    if (existing != null) {
      await widget.controller.updateStudyNote(
        existing.id,
        title: title,
        content: _contentController.text,
        courseName: _courseController.text.trim(),
      );
    } else {
      await widget.controller.addStudyNote(
        title: title,
        content: _contentController.text,
        courseName: _courseController.text.trim(),
      );
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(existing != null ? '笔记已更新' : '笔记已保存')),
      );
      Navigator.of(context).pop();
    }
  }
}
