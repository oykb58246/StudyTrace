import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/note_block.dart';
import '../../models/study_note.dart';
import '../../services/ai_semantic_search_service.dart';
import '../../services/ai_exceptions.dart';
import '../../services/ai_study_service.dart';
import '../../services/picked_image_store.dart';
import '../../theme/app_theme.dart';
import '../shared/common_widgets.dart';
import '../shared/local_image.dart';
import '../shared/markdown_styles.dart';

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
  final _searchController = TextEditingController();
  String? _folderId; // null = root
  String _search = '';
  String _semanticQuery = '';
  int _searchVersion = 0;
  bool _isSemanticSearching = false;
  List<StudyNote>? _semanticNotes;
  bool _selectionMode = false;
  final Set<String> _selectedNoteIds = <String>{};

  List<StudyNote> _currentNotes() {
    var notes = widget.controller.notesForFolder(_folderId);
    if (_search.isNotEmpty) {
      if (_semanticQuery == _search && _semanticNotes != null) {
        return _semanticNotes!;
      }
      final q = _search.toLowerCase();
      notes = notes.where((n) => _noteSearchText(n).toLowerCase().contains(q)).toList();
    }
    return notes;
  }

  void _goTo(StudyNote folder) => setState(() {
        _folderId = folder.id;
        _semanticQuery = '';
        _semanticNotes = null;
      });
  void _goUp() => setState(() {
        _folderId = null;
        _semanticQuery = '';
        _semanticNotes = null;
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    final version = ++_searchVersion;
    setState(() {
      _search = value.trim();
      _semanticQuery = '';
      _semanticNotes = null;
      _isSemanticSearching = _search.isNotEmpty;
    });
    if (_search.isEmpty) {
      setState(() => _isSemanticSearching = false);
      return;
    }
    _runSemanticSearch(_search, version);
  }

  Future<void> _runSemanticSearch(String query, int version) async {
    final notes = widget.controller.notesForFolder(_folderId);
    final candidates = notes
        .map((note) => SemanticSearchCandidate<StudyNote>(
              id: note.id,
              item: note,
              text: _noteSearchText(note),
            ))
        .toList();
    final service = widget.controller.createSemanticSearchService();
    final hits = await service.search(query: query, candidates: candidates);
    if (!mounted || version != _searchVersion) return;
    setState(() {
      _semanticQuery = query;
      _semanticNotes = hits.map((hit) => hit.item).toList();
      _isSemanticSearching = false;
    });
  }

  String _noteSearchText(StudyNote note) {
    final blockText = note.blocks.map((b) => b.content).join('\n');
    return [
      note.title,
      note.courseName,
      note.content,
      blockText,
    ].where((part) => part.trim().isNotEmpty).join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final notes = _currentNotes();
        final textColor = StudyUi.title(widget.isDarkMode);
        final bodyColor = StudyUi.body(widget.isDarkMode);

        return Scaffold(
          backgroundColor: StudyUi.background(widget.isDarkMode),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: textColor,
            title: _selectionMode
                ? Text('已选择 ${_selectedNoteIds.length} 项', style: const TextStyle(fontWeight: FontWeight.w800))
                : _folderId != null
                ? Row(children: [
                    GestureDetector(onTap: _goUp, child: Text('笔记', style: TextStyle(color: bodyColor, fontSize: 18))),
                    const Icon(Icons.chevron_right_rounded, size: 20),
                    Expanded(
                      child: Text(
                        _findFolderName(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ])
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: StudyUi.chipBackground(
                            StudyUi.primary,
                            widget.isDarkMode,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.menu_book_rounded,
                          color: StudyUi.primary,
                          size: 17,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Flexible(
                        child: Text(
                          '学习笔记',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
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
                controller: _searchController,
                autofocus: false,
                onChanged: _onSearchChanged,
                style: TextStyle(color: textColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '搜索笔记...',
                  hintStyle: TextStyle(color: StudyUi.muted(widget.isDarkMode)),
                  prefixIcon: Icon(Icons.search_rounded, color: bodyColor, size: 20),
                  suffixIcon: _isSemanticSearching
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: StudyUi.primary,
                            ),
                          ),
                        )
                      : _search.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                  filled: true,
                  fillColor: StudyUi.surfaceAlt(widget.isDarkMode),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                    borderSide: const BorderSide(color: StudyUi.primary),
                  ),
                ),
              ),
            ),
            // Content
            Expanded(
              child: notes.isEmpty
                  ? _emptyBody()
                  : RefreshIndicator(
                      onRefresh: () async => widget.controller.notifyListeners(),
                      child: Scrollbar(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(22, 8, 22, 120),
                        itemCount: notes.length,
                        itemBuilder: (_, i) => _noteTile(notes[i], textColor, bodyColor),
                      ),
                      ), // RefreshIndicator
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
    for (final note in all) {
      if (note.id == _folderId) return note.title;
    }
    return '文件夹';
  }

  Widget _noteTile(StudyNote note, Color textColor, Color bodyColor) {
    const accent = StudyUi.primary;
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
          child: StudyCard(
            color: isSelected
                ? accent.withValues(alpha: widget.isDarkMode ? 0.2 : 0.12)
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
                  color: isFolder
                      ? StudyUi.chipBackground(StudyUi.warning, widget.isDarkMode)
                      : StudyUi.chipBackground(accent, widget.isDarkMode),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isFolder ? Icons.folder_rounded : (hasBlocks ? Icons.article_rounded : Icons.notes_rounded),
                  size: 18,
                  color: isFolder ? StudyUi.warning : accent,
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
              Text(_fmtNoteDate(note.updatedAt), style: TextStyle(color: StudyUi.muted(widget.isDarkMode), fontSize: 11)),
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

  Widget _emptyBody() => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: StudyEmptyState.notes(
            title: '开始搭建你的课程笔记',
            message: '新建文件夹整理资料，或直接创建文档记录课堂要点。',
            actionLabel: '新建笔记',
            onAction: _showCreateMenu,
          ),
        ),
      );

  Widget _buildFab() {
    const accent = StudyUi.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: FloatingActionButton(
        heroTag: 'new_note_menu',
        backgroundColor: accent,
        foregroundColor: Colors.white,
        onPressed: _showCreateMenu,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _showCreateMenu() {
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
            leading: Icon(Icons.note_add_rounded, color: accent),
            title: const Text('新建笔记'),
            onTap: () {
              Navigator.of(ctx).pop();
              _openEditor();
            },
          ),
          ListTile(
            leading: const Icon(Icons.create_new_folder_rounded, color: Color(0xFFF8AA5B)),
            title: const Text('新建文件夹'),
            onTap: () {
              Navigator.of(ctx).pop();
              _createFolder();
            },
          ),
          ListTile(
            leading: Icon(Icons.document_scanner_rounded, color: accent),
            title: const Text('拍照成笔记'),
            onTap: () {
              Navigator.of(ctx).pop();
              _createNoteFromPhoto();
            },
          ),
        ]),
      ),
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

  Future<void> _createNoteFromPhoto() async {
    final ocr = widget.controller.createOcrService();
    try {
      StudyToast.show(context, '正在识别图片文字...');
      final text = (await ocr.captureAndRecognize(
            onStatus: (status) {
              if (mounted) StudyToast.show(context, status);
            },
          ))
              ?.trim() ??
          '';
      if (!mounted) return;
      if (text.isEmpty) {
        StudyToast.show(context, '未识别到文字，可重新拍照或手动新建笔记');
        return;
      }
      final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
      final title = compact.isEmpty
          ? '拍照笔记'
          : compact.substring(0, compact.length > 20 ? 20 : compact.length);
      final note = await widget.controller.addStudyNote(
        title: title,
        content: text,
        parentId: _folderId,
        blocks: [
          NoteBlock(id: 'block_${DateTime.now().microsecondsSinceEpoch}', content: text),
        ],
      );
      if (!mounted) return;
      StudyToast.show(context, '拍照笔记已创建');
      _openEditor(note: note);
    } catch (error) {
      if (mounted) {
        await StudyToast.dialog(
          context,
          title: '拍照笔记创建失败',
          message: '$error',
        );
      }
    } finally {
      ocr.dispose();
    }
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
    StudyToast.show(context, '已删除 $selectedCount 项');
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
  bool _isAiRunning = false;
  bool _isGeneratingImage = false;
  final _imagePicker = ImagePicker();
  final _scrollCtrl = ScrollController();

  static const _blockTypes = [
    NoteBlockType.heading,
    NoteBlockType.text,
    NoteBlockType.markdown,
    NoteBlockType.bullet,
    NoteBlockType.todo,
    NoteBlockType.image,
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
    _previewMode = n != null;
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
      StudyToast.show(context, '请输入标题');
      return;
    }
    final nonEmpty = _blocks
        .where((b) => b.type == NoteBlockType.divider || b.content.isNotEmpty)
        .toList();
    final plainText = nonEmpty.map(_blockToPlainText).join('\n');
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
      StudyToast.show(context, existing != null ? '已更新' : '已保存');
      Navigator.of(context).pop();
    }
  }

  void _addBlock(NoteBlockType type) {
    if (type == NoteBlockType.image) {
      _showInsertImageSheet();
      return;
    }
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

  String _blockToPlainText(NoteBlock block) {
    return switch (block.type) {
      NoteBlockType.divider => '---',
      NoteBlockType.image => block.content.isEmpty ? '' : '![图片](${block.content})',
      NoteBlockType.markdown => block.content,
      _ => block.content,
    };
  }

  Future<void> _showInsertImageSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
        decoration: BoxDecoration(
          color: widget.isDarkMode
              ? const Color(0xFF1A1F2E)
              : const Color(0xFFF5F7FF),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('从相册选择'),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded),
                title: const Text('拍照插入'),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;
    await _pickImageBlock(source);
  }

  Future<void> _pickImageBlock(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 88,
      );
      if (picked == null) return;
      final path = await persistPickedImage(picked, prefix: 'note_image');
      if (!mounted) return;
      setState(() {
        _blocks.add(NoteBlock(id: _bid(), type: NoteBlockType.image, content: path));
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      await StudyToast.dialog(
        context,
        title: '插入图片失败',
        message: '$error',
      );
    }
  }

  Future<void> _showAiImageSheet() async {
    final promptController = TextEditingController();
    final prompt = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            decoration: BoxDecoration(
              color: widget.isDarkMode
                  ? const Color(0xFF1A1F2E)
                  : const Color(0xFFF5F7FF),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '生成笔记配图',
                    style: TextStyle(
                      color: AppColors.inkColor(widget.isDarkMode),
                      fontWeight: AppTypography.title,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: promptController,
                    autofocus: true,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: '描述你想插入的学习图片...',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('取消'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () =>
                            Navigator.of(ctx).pop(promptController.text.trim()),
                        icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                        label: const Text('生成'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    promptController.dispose();
    if (prompt == null || prompt.isEmpty || !mounted) return;
    await _generateAiImageBlock(prompt);
  }

  Future<void> _generateAiImageBlock(String prompt) async {
    setState(() => _isGeneratingImage = true);
    try {
      final task = await widget.controller.vivoCapabilityService.createCover(
        prompt: '为学习笔记生成清晰、适合插入正文的配图：$prompt',
        purpose: 'note_image',
      );
      final imageRef = task.imagesUrl.isNotEmpty
          ? task.imagesUrl.first
          : 'vivo-task:${task.taskId}';
      if (!mounted) return;
      setState(() {
        _blocks.add(NoteBlock(
          id: _bid(),
          type: NoteBlockType.image,
          content: imageRef,
        ));
      });
      _scrollToBottom();
      StudyToast.show(
        context,
        task.imagesUrl.isNotEmpty ? '图片已插入' : '图片生成中，稍后可刷新',
      );
    } catch (error) {
      if (!mounted) return;
      await StudyToast.dialog(
        context,
        title: '生成图片失败',
        message: '$error',
      );
    } finally {
      if (mounted) setState(() => _isGeneratingImage = false);
    }
  }

  Future<void> _refreshImageBlock(int index, NoteBlock block) async {
    if (!block.content.startsWith('vivo-task:')) return;
    setState(() => _isGeneratingImage = true);
    try {
      final taskId = block.content.replaceFirst('vivo-task:', '');
      final task = await widget.controller.vivoCapabilityService.refreshImageTask(taskId);
      if (!mounted) return;
      if (task.imagesUrl.isEmpty) {
        StudyToast.show(context, '图片仍在生成中，稍后再试');
        return;
      }
      setState(() {
        _blocks[index] = block.copyWith(content: task.imagesUrl.first);
      });
      StudyToast.show(context, '图片已更新');
    } catch (error) {
      if (!mounted) return;
      await StudyToast.dialog(
        context,
        title: '刷新图片失败',
        message: '$error',
      );
    } finally {
      if (mounted) setState(() => _isGeneratingImage = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  /// 弹出 整理 命令面板（Phase 2.2）
  Future<void> _showAiCommandSheet() async {
    // 找到一个"有内容的"最后一个文本类块作为整理来源
    int srcIndex = -1;
    for (var i = _blocks.length - 1; i >= 0; i--) {
      final b = _blocks[i];
      if (b.type == NoteBlockType.divider) continue;
      if (b.content.trim().isEmpty) continue;
      srcIndex = i;
      break;
    }
    if (srcIndex < 0) {
      StudyToast.show(context, '当前没有可供整理的内容，先写点东西吧');
      return;
    }
    final items = <(String, String, IconData)>[
      ('continue', '续写段落', Icons.short_text_rounded),
      ('expand', '扩写展开', Icons.unfold_more_rounded),
      ('rewrite_formal', '改写为正式', Icons.school_rounded),
      ('rewrite_casual', '改写为口语', Icons.chat_bubble_outline_rounded),
      ('rewrite_concise', '改写为简洁', Icons.filter_alt_rounded),
      ('outline', '总结成要点', Icons.format_list_bulleted_rounded),
    ];
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: widget.isDarkMode
              ? const Color(0xFF1A1F2E)
              : const Color(0xFFF5F7FF),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(left: 140),
                decoration: BoxDecoration(
                  color: widget.isDarkMode ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    const Icon(Icons.tips_and_updates_rounded,
                        color: Color(0xFF4470E8), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '整理当前段落',
                      style: TextStyle(
                          color: widget.isDarkMode
                              ? Colors.white
                              : AppColors.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              ...items.map((t) => ListTile(
                    leading: Icon(t.$3),
                    title: Text(t.$2),
                    onTap: () => Navigator.of(ctx).pop(t.$1),
                  )),
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;
    await _runAiTransform(srcIndex, action);
  }

  Future<void> _runAiTransform(int index, String intent) async {
    final src = _blocks[index].content.trim();
    if (src.isEmpty) return;
    setState(() => _isAiRunning = true);
    try {
      final aiService = widget.controller.aiStudyService;
      final result = await aiService.rewriteOrExpand(
        text: src,
        intent: intent,
      );
      if (result.trim().isEmpty) {
        if (mounted) {
          StudyToast.show(context, '暂时没有返回内容');
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        // 整理 结果以多段的方式插入：按换行拆分成 text 块；bullet 列表识别
        final lines = result.split(RegExp(r'\n+'));
        final insertBlocks = <NoteBlock>[];
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
            insertBlocks.add(NoteBlock(
              id: _bid(),
              type: NoteBlockType.bullet,
              content: trimmed.substring(2).trim(),
            ));
          } else if (trimmed.startsWith('#')) {
            insertBlocks.add(NoteBlock(
              id: _bid(),
              type: NoteBlockType.heading,
              content: trimmed.replaceFirst(RegExp(r'^#+\s*'), ''),
            ));
          } else {
            insertBlocks.add(NoteBlock(
              id: _bid(),
              type: NoteBlockType.text,
              content: trimmed,
            ));
          }
        }
        _blocks.insertAll(index + 1, insertBlocks);
      });
    } on AiServiceException catch (e) {
      if (mounted) {
        await StudyToast.dialog(
          context,
          title: '生成失败',
          message: e.message,
        );
      }
    } catch (e) {
      if (mounted) {
        await StudyToast.dialog(
          context,
          title: '生成失败',
          message: '$e',
        );
      }
    } finally {
      if (mounted) setState(() => _isAiRunning = false);
    }
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
          style: TextStyle(color: textColor, fontSize: 18, fontWeight: AppTypography.title, height: 1.45),
          decoration: InputDecoration(
            hintText: '段落标题',
            filled: false,
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
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
      case NoteBlockType.markdown:
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.isDarkMode
                ? Colors.black.withValues(alpha: 0.18)
                : const Color(0xFFF6F8FA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: StudyUi.border(widget.isDarkMode)),
          ),
          child: TextField(
            key: ValueKey(block.id),
            controller: TextEditingController(text: block.content),
            onChanged: (v) => _blocks[index] = block.copyWith(content: v),
            style: TextStyle(color: textColor, fontSize: 15, height: 1.6),
            decoration: const InputDecoration(
              hintText: '支持 Markdown：标题、列表、加粗、图片链接...',
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            maxLines: null,
          ),
        );
      case NoteBlockType.image:
        return _imageBlockEditor(index, block);
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
            style: appCodeTextStyle(color: textColor),
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
    final content = block.content.trim();
    if (content.isEmpty && block.type != NoteBlockType.divider) {
      return const SizedBox.shrink();
    }

    switch (block.type) {
      case NoteBlockType.heading:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(content, style: TextStyle(color: textColor, fontSize: 18, fontWeight: AppTypography.title, height: 1.45)),
        );
      case NoteBlockType.bullet:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 4, right: 8), child: Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: bodyColor))),
            Expanded(child: _markdownPreview(content, fontSize: 15)),
          ]),
        );
      case NoteBlockType.markdown:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: MarkdownBody(
            data: content,
            selectable: true,
            styleSheet: buildStudyMarkdownStyleSheet(
              isDarkMode: widget.isDarkMode,
              bodyFontSize: 15,
            ),
            imageBuilder: (uri, title, alt) => buildStudyMarkdownImage(
              uri,
              title,
              alt,
              isDarkMode: widget.isDarkMode,
            ),
          ),
        );
      case NoteBlockType.image:
        return _imageBlockPreview(block);
      case NoteBlockType.todo:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 1, right: 10),
              child: Icon(block.checked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 18, color: block.checked ? const Color(0xFF4BC4A1) : bodyColor),
            ),
            Expanded(
              child: block.checked
                  ? Text(
                      content,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        height: 1.6,
                        decoration: TextDecoration.lineThrough,
                      ),
                    )
                  : _markdownPreview(content, fontSize: 15),
            ),
          ]),
        );
      case NoteBlockType.code:
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: widget.isDarkMode ? Colors.black.withValues(alpha: 0.3) : const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(10)),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              content,
              style: appCodeTextStyle(color: bodyColor),
            ),
          ),
        );
      case NoteBlockType.divider:
        return Divider(color: bodyColor.withValues(alpha: 0.15), height: 24);
      default:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _markdownPreview(content, fontSize: 15),
        );
    }
  }

  Widget _markdownPreview(String content, {double fontSize = 15}) {
    return MarkdownBody(
      data: content,
      selectable: true,
      styleSheet: buildStudyMarkdownStyleSheet(
        isDarkMode: widget.isDarkMode,
        bodyFontSize: fontSize,
      ),
      imageBuilder: (uri, title, alt) => buildStudyMarkdownImage(
        uri,
        title,
        alt,
        isDarkMode: widget.isDarkMode,
      ),
    );
  }

  Widget _imageBlockEditor(int index, NoteBlock block) {
    final textColor = widget.isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor = AppColors.bodyColor(widget.isDarkMode);
    final content = block.content.trim();
    final isPending = content.startsWith('vivo-task:');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? Colors.black.withValues(alpha: 0.2)
            : const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: StudyUi.border(widget.isDarkMode)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (content.isNotEmpty) _imageBlockPreview(block),
          if (content.isNotEmpty) const SizedBox(height: 10),
          TextField(
            key: ValueKey('${block.id}_image_path'),
            controller: TextEditingController(text: block.content),
            onChanged: (v) => _blocks[index] = block.copyWith(content: v),
            style: appCodeTextStyle(color: textColor, fontSize: 12),
            decoration: InputDecoration(
              hintText: '图片路径、URL 或 vivo-task:任务ID',
              hintStyle: TextStyle(color: bodyColor),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            maxLines: 2,
          ),
          if (isPending) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _isGeneratingImage
                  ? null
                  : () => _refreshImageBlock(index, block),
              icon: _isGeneratingImage
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('刷新生成结果'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _imageBlockPreview(NoteBlock block) {
    final content = block.content.trim();
    final isPending = content.startsWith('vivo-task:');
    if (content.isEmpty || isPending) {
      return Container(
        height: 150,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.isDarkMode
              ? const Color(0xFF1E2430)
              : const Color(0xFFF2F5FC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: StudyUi.border(widget.isDarkMode)),
        ),
        child: Text(
          isPending ? '图片生成中，点击刷新获取结果' : '未设置图片',
          style: TextStyle(color: AppColors.mutedColor(widget.isDarkMode)),
        ),
      );
    }

    final isRemote = content.startsWith('http://') || content.startsWith('https://');
    final image = isRemote
        ? Image.network(
            content,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _imageErrorBox(),
          )
        : localImageFromPath(
            content,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _imageErrorBox(),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: image,
        ),
      ),
    );
  }

  Widget _imageErrorBox() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? const Color(0xFF1E2430)
            : const Color(0xFFF2F5FC),
      ),
      child: Center(
        child: Icon(
          Icons.broken_image_rounded,
          color: AppColors.mutedColor(widget.isDarkMode),
        ),
      ),
    );
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
          title: Text(_previewMode ? '预览' : widget.existingNote != null ? '编辑' : '新建', style: const TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            IconButton(
              icon: Icon(_previewMode ? Icons.edit_rounded : Icons.visibility_rounded, color: textColor.withValues(alpha: 0.6)),
              tooltip: _previewMode ? '编辑' : '预览',
              onPressed: () => setState(() => _previewMode = !_previewMode),
            ),
            if (!_previewMode)
              TextButton(onPressed: _save, child: Text('保存', style: TextStyle(fontWeight: FontWeight.w800, color: accent))),
          ],
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: _buildBody(textColor),
        ),
        bottomNavigationBar: _previewMode
            ? null
            : _editorToolbar(accent, textColor),
      ),
    );
  }

  Widget _editorToolbar(Color accent, Color textColor) {
    return Container(
      decoration: BoxDecoration(
        color: StudyUi.surface(widget.isDarkMode),
        border: Border(
          top: BorderSide(color: StudyUi.border(widget.isDarkMode)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SafeArea(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _toolbarChip(
                icon: Icons.tips_and_updates_rounded,
                label: _isAiRunning ? '生成中…' : '整理',
                color: accent,
                onTap: _isAiRunning ? null : _showAiCommandSheet,
                busy: _isAiRunning,
              ),
              const SizedBox(width: 8),
              _toolbarChip(
                icon: Icons.image_search_rounded,
                label: _isGeneratingImage ? '生成中…' : 'AI 配图',
                color: StudyUi.secondary,
                onTap: _isGeneratingImage ? null : _showAiImageSheet,
                busy: _isGeneratingImage,
              ),
              const SizedBox(width: 8),
              ..._blockTypes.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _toolbarChip(
                    icon: _blockIcon(t),
                    label: t.label,
                    color: textColor.withValues(alpha: 0.64),
                    onTap: () => _addBlock(t),
                    filled: false,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolbarChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
    bool busy = false,
    bool filled = true,
  }) {
    final enabled = onTap != null;
    final effectiveColor = enabled ? color : StudyUi.muted(widget.isDarkMode);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: filled
              ? color.withValues(alpha: widget.isDarkMode ? 0.16 : 0.1)
              : StudyUi.surfaceAlt(widget.isDarkMode),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: filled
                ? color.withValues(alpha: widget.isDarkMode ? 0.24 : 0.22)
                : StudyUi.border(widget.isDarkMode),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            busy
                ? SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: effectiveColor,
                    ),
                  )
                : Icon(icon, size: 14, color: effectiveColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: effectiveColor,
                fontSize: 12,
                fontWeight: filled ? AppTypography.medium : AppTypography.regular,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewTitle(Color textColor) {
    final title = _titleCtrl.text.trim();
    final mutedColor = StudyUi.muted(widget.isDarkMode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 3,
          decoration: BoxDecoration(
            color: widget.controller.primaryColor,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title.isEmpty ? '无标题' : title,
          style: TextStyle(
            color: textColor,
            fontSize: 24,
            fontWeight: AppTypography.title,
            height: 1.28,
          ),
        ),
        if (widget.existingNote != null) ...[
          const SizedBox(height: 8),
          Text(
            '更新于 ${_formatPreviewDate(widget.existingNote!.updatedAt)}',
            style: TextStyle(
              color: mutedColor,
              fontSize: 12,
              fontWeight: AppTypography.regular,
            ),
          ),
        ],
        const SizedBox(height: 18),
        Divider(
          height: 1,
          color: StudyUi.border(widget.isDarkMode),
        ),
      ],
    );
  }

  Widget _editTitleField(Color textColor, Color accent) {
    final borderColor = StudyUi.border(widget.isDarkMode);
    final mutedColor = StudyUi.muted(widget.isDarkMode);

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleCtrl,
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: AppTypography.title,
              height: 1.35,
            ),
            decoration: InputDecoration(
              hintText: '输入笔记标题',
              filled: false,
              hintStyle: TextStyle(
                color: mutedColor.withValues(alpha: 0.72),
                fontWeight: AppTypography.regular,
              ),
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: accent, width: 1.4),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.fromLTRB(0, 13, 0, 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyPreviewHint() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 18),
      decoration: BoxDecoration(
        color: StudyUi.surfaceAlt(widget.isDarkMode),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: StudyUi.border(widget.isDarkMode)),
      ),
      child: Text(
        '还没有正文内容',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: StudyUi.muted(widget.isDarkMode),
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }

  String _formatPreviewDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  Widget _buildBody(Color textColor) {
    final accent = widget.controller.primaryColor;
    if (_previewMode) {
      final visibleBlocks = _blocks
          .where((b) => b.type == NoteBlockType.divider || b.content.trim().isNotEmpty)
          .toList();
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: () => setState(() => _previewMode = false),
        child: ListView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 140),
          children: [
            _previewTitle(textColor),
            const SizedBox(height: 22),
            if (visibleBlocks.isEmpty)
              _emptyPreviewHint()
            else
              ...visibleBlocks.map((b) => _blockPreview(_blocks.indexOf(b), b)),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 160),
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
      header: _editTitleField(textColor, accent),
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
      NoteBlockType.markdown => Icons.notes_rounded,
      NoteBlockType.image => Icons.image_rounded,
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
