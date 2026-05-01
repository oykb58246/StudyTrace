import 'package:flutter/material.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/note_block.dart';
import '../../models/study_note.dart';
import '../../theme/app_theme.dart';
import '../shared/common_widgets.dart';

// ─── Notion-style Notes List ───

class StudyNotesPage extends StatefulWidget {
  const StudyNotesPage(
      {super.key, required this.isDarkMode, required this.controller});
  final bool isDarkMode;
  final AppDataController controller;
  @override
  State<StudyNotesPage> createState() => _StudyNotesPageState();
}

class _StudyNotesPageState extends State<StudyNotesPage> {
  String? _folderId; // null = root
  String _search = '';
  bool _selectionMode = false;
  final Set<String> _selectedNoteIds = <String>{};

  List<StudyNote> _currentNotes() {
    var notes = widget.controller.notesForFolder(_folderId);
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      notes = notes.where((n) => n.title.toLowerCase().contains(q) || n.content.toLowerCase().contains(q)).toList();
    }
    return notes;
  }

  void _goTo(StudyNote folder) => setState(() => _folderId = folder.id);
  void _goUp() => setState(() {
        _folderId = null;
        _exitSelectionMode();
      });

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) {
        _selectedNoteIds.clear();
      }
    });
  }

  void _exitSelectionMode() {
    _selectionMode = false;
    _selectedNoteIds.clear();
  }

  void _toggleNoteSelection(StudyNote note) {
    setState(() {
      _selectionMode = true;
      if (_selectedNoteIds.contains(note.id)) {
        _selectedNoteIds.remove(note.id);
      } else {
        _selectedNoteIds.add(note.id);
      }
      if (_selectedNoteIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final notes = _currentNotes();
        final textColor = widget.isDarkMode ? Colors.white : AppColors.ink;
        final bodyColor = widget.isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;

        return Scaffold(
          backgroundColor: widget.isDarkMode ? const Color(0xFF141923) : const Color(0xFFF5F7FF),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: textColor,
            title: _selectionMode
                ? Text('已选择 ${_selectedNoteIds.length} 项', style: const TextStyle(fontWeight: FontWeight.w800))
                : _folderId != null
                ? Row(children: [
                    GestureDetector(onTap: _goUp, child: Text('笔记', style: TextStyle(color: bodyColor, fontSize: 18))),
                    const Icon(Icons.chevron_right_rounded, size: 20),
                    Expanded(child: Text(_findFolderName(), style: const TextStyle(fontWeight: FontWeight.w800))),
                  ])
                : const Text('学习笔记', style: TextStyle(fontWeight: FontWeight.w800)),
            actions: [
              if (_selectionMode) ...[
                IconButton(
                  tooltip: '批量删除',
                  icon: const Icon(Icons.delete_sweep_rounded),
                  onPressed: _selectedNoteIds.isEmpty ? null : _deleteSelectedNotes,
                ),
                IconButton(
                  tooltip: '取消多选',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(_exitSelectionMode),
                ),
              ] else if (notes.isNotEmpty)
                IconButton(
                  tooltip: '多选',
                  icon: const Icon(Icons.checklist_rounded),
                  onPressed: _toggleSelectionMode,
                ),
            ],
          ),
          body: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _search = v),
                style: TextStyle(color: textColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '搜索笔记...',
                  hintStyle: TextStyle(color: widget.isDarkMode ? Colors.white.withValues(alpha: 0.35) : AppColors.muted),
                  prefixIcon: Icon(Icons.search_rounded, color: bodyColor, size: 20),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () => setState(() => _search = ''))
                      : null,
                  filled: true,
                  fillColor: widget.isDarkMode ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF2F5FC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
            ),
            // Content
            Expanded(
              child: notes.isEmpty
                  ? _emptyBody(bodyColor)
                  : Scrollbar(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(22, 8, 22, 120),
                        itemCount: notes.length,
                        itemBuilder: (_, i) => _noteTile(notes[i], textColor, bodyColor),
                      ),
                    ),
            ),
          ]),
          floatingActionButton: _buildFab(),
          bottomNavigationBar: const SizedBox(height: 80),
        );
      },
    );
  }

  String _findFolderName() {
    final all = widget.controller.studyNotes;
    final f = all.where((n) => n.id == _folderId).firstOrNull;
    return f?.title ?? '文件夹';
  }

  Widget _noteTile(StudyNote note, Color textColor, Color bodyColor) {
    final accent = widget.controller.primaryColor;
    final isFolder = note.isFolder;
    final hasBlocks = note.blocks.isNotEmpty;
    final isSelected = _selectedNoteIds.contains(note.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _selectionMode
              ? () => _toggleNoteSelection(note)
              : isFolder
                  ? () => _goTo(note)
                  : () => _openEditor(note: note),
          onLongPress: () => _selectionMode ? _toggleNoteSelection(note) : _showNoteMenu(note),
          child: GlassCard(
            color: isSelected
                ? accent.withValues(alpha: widget.isDarkMode ? 0.2 : 0.12)
                : widget.isDarkMode
                    ? const Color(0xFF242B37).withValues(alpha: 0.9)
                    : null,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              if (_selectionMode) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    size: 22,
                    color: isSelected ? accent : bodyColor,
                  ),
                ),
              ],
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: isFolder ? const Color(0xFFF8AA5B).withValues(alpha: 0.15) : accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isFolder ? Icons.folder_rounded : (hasBlocks ? Icons.article_rounded : Icons.notes_rounded),
                  size: 18,
                  color: isFolder ? const Color(0xFFF8AA5B) : accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(note.title, style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    isFolder
                        ? '${widget.controller.notesForFolder(note.id).length} 项'
                        : note.content.isEmpty
                            ? _blockSummary(note)
                            : note.content,
                    style: TextStyle(color: bodyColor, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ]),
              ),
              Text(_fmtNoteDate(note.updatedAt), style: TextStyle(color: widget.isDarkMode ? Colors.white24 : Colors.black26, fontSize: 11)),
            ]),
          ),
        ),
      ),
    );
  }

  String _blockSummary(StudyNote note) {
    if (note.blocks.isEmpty) return '空笔记';
    final first = note.blocks.firstWhere((b) => b.content.isNotEmpty, orElse: () => note.blocks.first);
    return first.content;
  }

  Widget _emptyBody(Color bodyColor) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(shape: BoxShape.circle, color: widget.isDarkMode ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF2F5FC)),
            child: Icon(Icons.auto_awesome_rounded, size: 36, color: widget.isDarkMode ? Colors.white24 : const Color(0xFFC2C8D6)),
          ),
          const SizedBox(height: 16),
          Text('开始搭建你的知识库', style: TextStyle(color: widget.isDarkMode ? Colors.white : AppColors.ink, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('新建文件夹整理笔记，或直接创建文档', style: TextStyle(color: bodyColor, fontSize: 13)),
        ]),
      );

  Widget _buildFab() {
    final accent = widget.controller.primaryColor;
    return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          FloatingActionButton.small(
            heroTag: 'new_folder',
            backgroundColor: const Color(0xFFF8AA5B),
            foregroundColor: Colors.white,
            onPressed: () => _createFolder(),
            child: const Icon(Icons.create_new_folder_rounded),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'new_note',
            backgroundColor: accent,
            foregroundColor: Colors.white,
            onPressed: () => _openEditor(),
            child: const Icon(Icons.add_rounded),
          ),
        ]),
      );
  }

  void _createFolder() {
    final accent = widget.controller.primaryColor;
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('新建文件夹'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '文件夹名称',
            filled: true,
            fillColor: widget.isDarkMode ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF2F5FC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white),
            onPressed: () {
              final title = ctrl.text.trim();
              if (title.isNotEmpty) {
                widget.controller.addStudyNote(title: title, content: '', isFolder: true, parentId: _folderId);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _openEditor({StudyNote? note}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoteBlockEditor(
          isDarkMode: widget.isDarkMode,
          controller: widget.controller,
          existingNote: note,
          parentId: _folderId,
        ),
      ),
    );
  }

  void _showNoteMenu(StudyNote note) {
    final accent = widget.controller.primaryColor;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: widget.isDarkMode ? const Color(0xFF1A1F2E) : const Color(0xFFF5F7FF),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: widget.isDarkMode ? Colors.white24 : Colors.black26, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 18),
          ListTile(
            leading: Icon(Icons.edit_rounded, color: accent),
            title: const Text('打开编辑'),
            onTap: () { Navigator.of(ctx).pop(); _openEditor(note: note); },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF6850)),
            title: const Text('删除'),
            onTap: () {
              Navigator.of(ctx).pop();
              widget.controller.deleteStudyNote(note.id);
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _deleteSelectedNotes() async {
    final selectedCount = _selectedNoteIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('批量删除'),
        content: Text('确定删除已选中的 $selectedCount 项吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF6850), foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ids = _selectedNoteIds.toList(growable: false);
    for (final id in ids) {
      await widget.controller.deleteStudyNote(id);
    }

    if (!mounted) return;
    setState(_exitSelectionMode);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已删除 $selectedCount 项')),
    );
  }

  String _fmtNoteDate(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.month}/${d.day} $h:$m';
  }
}

// ─── Block Editor ───

class NoteBlockEditor extends StatefulWidget {
  const NoteBlockEditor(
      {super.key, required this.isDarkMode, required this.controller, this.existingNote, this.parentId});
  final bool isDarkMode;
  final AppDataController controller;
  final StudyNote? existingNote;
  final String? parentId;

  @override
  State<NoteBlockEditor> createState() => _NoteBlockEditorState();
}

class _NoteBlockEditorState extends State<NoteBlockEditor> {
  late TextEditingController _titleCtrl;
  late List<NoteBlock> _blocks;
  late bool _previewMode;
  bool _saved = false;
  final _scrollCtrl = ScrollController();

  static const _blockTypes = [
    NoteBlockType.heading,
    NoteBlockType.text,
    NoteBlockType.bullet,
    NoteBlockType.todo,
    NoteBlockType.code,
    NoteBlockType.divider,
  ];

  @override
  void initState() {
    super.initState();
    final n = widget.existingNote;
    _titleCtrl = TextEditingController(text: n?.title ?? '');
    _blocks = n?.blocks.isNotEmpty == true
        ? n!.blocks.map((b) => b.copyWith()).toList()
        : n?.content.isNotEmpty == true
            ? [NoteBlock(id: _bid(), type: NoteBlockType.text, content: n!.content)]
            : [NoteBlock(id: _bid())];
    _previewMode = false;
    _saved = n != null;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  String _bid() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入标题')));
      return;
    }
    final nonEmpty = _blocks.where((b) => b.type == NoteBlockType.divider || b.content.isNotEmpty).toList();
    final plainText = nonEmpty.map((b) => b.content).join('\n');
    final existing = widget.existingNote;
    if (existing != null) {
      await widget.controller.updateStudyNote(existing.id,
          title: title, content: plainText, blocks: nonEmpty);
    } else {
      await widget.controller.addStudyNote(
          title: title, content: plainText,
          blocks: nonEmpty, parentId: widget.parentId);
    }
    if (mounted) {
      setState(() => _saved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(existing != null ? '已更新' : '已保存'), duration: const Duration(seconds: 1)),
      );
      Navigator.of(context).pop();
    }
  }

  void _addBlock(NoteBlockType type) {
    if (type == NoteBlockType.divider) {
      setState(() => _blocks.add(NoteBlock(id: _bid(), type: NoteBlockType.divider)));
      return;
    }
    setState(() => _blocks.add(NoteBlock(id: _bid(), type: type)));
    // Scroll to bottom after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  void _removeBlock(int index) {
    if (_blocks.length <= 1) return;
    setState(() => _blocks.removeAt(index));
  }

  Widget _blockEditor(int index, NoteBlock block) {
    final textColor = widget.isDarkMode ? Colors.white : AppColors.ink;

    switch (block.type) {
      case NoteBlockType.heading:
        return TextField(
          key: ValueKey(block.id),
          controller: TextEditingController(text: block.content),
          onChanged: (v) => _blocks[index] = block.copyWith(content: v),
          style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.w800, height: 1.4),
          decoration: const InputDecoration(hintText: '大标题', border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
          maxLines: null,
        );
      case NoteBlockType.bullet:
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 9, right: 8),
            child: Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: textColor.withValues(alpha: 0.5))),
          ),
          Expanded(
            child: TextField(
              key: ValueKey(block.id),
              controller: TextEditingController(text: block.content),
              onChanged: (v) => _blocks[index] = block.copyWith(content: v),
              style: TextStyle(color: textColor, fontSize: 15, height: 1.6),
              decoration: const InputDecoration(hintText: '列表项', border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
              maxLines: null,
            ),
          ),
        ]);
      case NoteBlockType.todo:
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            onTap: () => setState(() => _blocks[index] = block.copyWith(checked: !block.checked)),
            child: Padding(
              padding: const EdgeInsets.only(top: 8, right: 10),
              child: Icon(
                block.checked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                size: 20, color: block.checked ? const Color(0xFF4BC4A1) : textColor.withValues(alpha: 0.4),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              key: ValueKey(block.id),
              controller: TextEditingController(text: block.content),
              onChanged: (v) => _blocks[index] = block.copyWith(content: v),
              style: TextStyle(
                  color: textColor, fontSize: 15, height: 1.6,
                  decoration: block.checked ? TextDecoration.lineThrough : null,
                  decorationColor: textColor.withValues(alpha: 0.4)),
              decoration: const InputDecoration(hintText: '待办项', border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
              maxLines: null,
            ),
          ),
        ]);
      case NoteBlockType.code:
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.isDarkMode ? Colors.black.withValues(alpha: 0.3) : const Color(0xFFF0F2F5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            key: ValueKey(block.id),
            controller: TextEditingController(text: block.content),
            onChanged: (v) => _blocks[index] = block.copyWith(content: v),
            style: TextStyle(color: textColor, fontSize: 13, fontFamily: 'monospace', height: 1.5),
            decoration: const InputDecoration(hintText: '代码块...', border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
            maxLines: null,
          ),
        );
      case NoteBlockType.divider:
        return Divider(color: textColor.withValues(alpha: 0.12), height: 32);
      default:
        return TextField(
          key: ValueKey(block.id),
          controller: TextEditingController(text: block.content),
          onChanged: (v) => _blocks[index] = block.copyWith(content: v),
          style: TextStyle(color: textColor, fontSize: 15, height: 1.6),
          decoration: const InputDecoration(hintText: '开始输入...', border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
          maxLines: null,
        );
    }
  }

  Widget _blockPreview(int index, NoteBlock block) {
    final textColor = widget.isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor = widget.isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;
    final content = block.content.isNotEmpty ? block.content : '(空)';

    switch (block.type) {
      case NoteBlockType.heading:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(content, style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.w800)),
        );
      case NoteBlockType.bullet:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 4, right: 8), child: Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: bodyColor))),
            Expanded(child: Text(content, style: TextStyle(color: textColor, fontSize: 15, height: 1.6))),
          ]),
        );
      case NoteBlockType.todo:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 1, right: 10),
              child: Icon(block.checked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 18, color: block.checked ? const Color(0xFF4BC4A1) : bodyColor),
            ),
            Expanded(child: Text(content, style: TextStyle(color: textColor, fontSize: 15, height: 1.6, decoration: block.checked ? TextDecoration.lineThrough : null))),
          ]),
        );
      case NoteBlockType.code:
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: widget.isDarkMode ? Colors.black.withValues(alpha: 0.3) : const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(10)),
          child: Text(content, style: TextStyle(color: bodyColor, fontSize: 13, fontFamily: 'monospace', height: 1.5)),
        );
      case NoteBlockType.divider:
        return Divider(color: bodyColor.withValues(alpha: 0.15), height: 24);
      default:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(content, style: TextStyle(color: textColor, fontSize: 15, height: 1.6)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.controller.primaryColor;
    final textColor = widget.isDarkMode ? Colors.white : AppColors.ink;

    return PopScope(
      canPop: _saved || (_titleCtrl.text.trim().isEmpty && _blocks.every((b) => b.content.isEmpty)),
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('保存更改？'),
              content: const Text('你有未保存的内容。'),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('放弃')),
                ElevatedButton(onPressed: () { Navigator.of(ctx).pop(true); _save(); }, child: const Text('保存')),
              ],
            ),
          );
          if (ok == true && mounted) _save();
        }
      },
      child: Scaffold(
        backgroundColor: widget.isDarkMode ? const Color(0xFF141923) : const Color(0xFFF5F7FF),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: textColor,
          title: Text(widget.existingNote != null ? '编辑' : '新建', style: const TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            IconButton(
              icon: Icon(_previewMode ? Icons.edit_rounded : Icons.visibility_rounded, color: textColor.withValues(alpha: 0.6)),
              tooltip: _previewMode ? '编辑' : '预览',
              onPressed: () => setState(() => _previewMode = !_previewMode),
            ),
            TextButton(onPressed: _save, child: Text('保存', style: TextStyle(fontWeight: FontWeight.w800, color: accent))),
          ],
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: _buildBody(textColor),
        ),
        bottomNavigationBar: _previewMode
            ? null
            : Container(
                color: widget.isDarkMode ? const Color(0xFF1A1F2E) : Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: SafeArea(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _blockTypes.map((t) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => _addBlock(t),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: widget.isDarkMode ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF2F5FC),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(_blockIcon(t), size: 14, color: textColor.withValues(alpha: 0.6)),
                                  const SizedBox(width: 6),
                                  Text(t.label, style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 12)),
                                ]),
                              ),
                            ),
                          ))
                          .toList(),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildBody(Color textColor) {
    final accent = widget.controller.primaryColor;
    if (_previewMode) {
      return ListView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 160),
        children: [
          TextField(
            controller: _titleCtrl,
            style: TextStyle(color: textColor, fontSize: 26, fontWeight: FontWeight.w800, height: 1.3),
            decoration: InputDecoration(
              hintText: '无标题',
              hintStyle: TextStyle(color: widget.isDarkMode ? Colors.white.withValues(alpha: 0.2) : Colors.black26),
              border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 20),
          ..._blocks.map((b) => _blockPreview(_blocks.indexOf(b), b)),
        ],
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 160),
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (_, child) => Material(
            color: Colors.transparent,
            child: Transform.scale(
              scale: 1.02 + 0.02 * animation.value,
              child: child,
            ),
          ),
          child: child,
        );
      },
      header: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: TextField(
          controller: _titleCtrl,
          style: TextStyle(color: textColor, fontSize: 26, fontWeight: FontWeight.w800, height: 1.3),
          decoration: InputDecoration(
            hintText: '无标题',
            hintStyle: TextStyle(color: widget.isDarkMode ? Colors.white.withValues(alpha: 0.2) : Colors.black26),
            border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
      itemCount: _blocks.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          final moved = _blocks.removeAt(oldIndex);
          final insertAt = newIndex > oldIndex ? newIndex - 1 : newIndex;
          _blocks.insert(insertAt, moved);
        });
      },
      itemBuilder: (context, i) {
        final block = _blocks[i];
        return Padding(
          key: ValueKey(block.id),
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ReorderableDragStartListener(
              index: i,
              child: GestureDetector(
                onTap: () => _showBlockTypeMenu(i),
                child: Container(
                  width: 28, height: 28,
                  margin: const EdgeInsets.only(top: 6, right: 6),
                  decoration: BoxDecoration(
                    color: block.type == NoteBlockType.text
                        ? Colors.transparent
                        : accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Opacity(
                    opacity: block.type == NoteBlockType.text ? 0.45 : 0.7,
                    child: Icon(
                      block.type == NoteBlockType.text ? Icons.drag_indicator_rounded : _blockIcon(block.type),
                      size: 14,
                      color: block.type == NoteBlockType.text ? textColor : accent,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: _blockEditor(i, block)),
            if (block.type != NoteBlockType.divider)
              GestureDetector(
                onTap: () => _removeBlock(i),
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Icon(Icons.close_rounded, size: 16, color: textColor.withValues(alpha: 0.2)),
                ),
              ),
          ]),
        );
      },
      );
  }

  IconData _blockIcon(NoteBlockType t) {
    return switch (t) {
      NoteBlockType.heading => Icons.title_rounded,
      NoteBlockType.text => Icons.text_fields_rounded,
      NoteBlockType.bullet => Icons.format_list_bulleted_rounded,
      NoteBlockType.todo => Icons.checklist_rounded,
      NoteBlockType.code => Icons.code_rounded,
      NoteBlockType.divider => Icons.horizontal_rule_rounded,
    };
  }

  void _showBlockTypeMenu(int index) {
    final accent = widget.controller.primaryColor;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: widget.isDarkMode ? const Color(0xFF1A1F2E) : const Color(0xFFF5F7FF), borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: widget.isDarkMode ? Colors.white24 : Colors.black26, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 18),
          ..._blockTypes.map((t) => ListTile(
                leading: Icon(_blockIcon(t), color: accent),
                title: Text(t.label),
                onTap: () {
                  setState(() => _blocks[index] = _blocks[index].copyWith(type: t));
                  Navigator.of(ctx).pop();
                },
              )),
        ]),
      ),
    );
  }
}
