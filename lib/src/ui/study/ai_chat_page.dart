import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/ai_app_action.dart';
import '../../models/ai_chat_message.dart';
import '../../models/note_block.dart';
import '../../models/study_sub_task_item.dart';
import '../../models/study_task_item.dart';
import '../../services/ai_app_context_builder.dart';
import '../../services/ai_semantic_search_service.dart';
import '../../services/ai_study_service.dart';
import '../../services/ai_tool_registry.dart';
import '../../services/local_storage_service.dart';
import '../../services/platform_file_saver.dart';
import '../../services/tts_service.dart';
import '../../theme/app_theme.dart';
import '../shared/common_widgets.dart';
import '../shared/markdown_styles.dart';
import 'flash_card_page.dart';
import 'timer_page.dart';

enum _ChatRole { user, assistant, confirmCard }

class AiChatPage extends StatefulWidget {
  const AiChatPage({
    super.key,
    required this.isDarkMode,
    required this.controller,
    this.onExecuteActions,
    this.currentLocation,
  });

  final bool isDarkMode;
  final AppDataController controller;
  final AiActionHandler? onExecuteActions;
  final String? currentLocation;

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  late final AiStudyService _aiService;
  final _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _storage = LocalStorageService();

  final List<_ChatEntry> _entries = [];
  bool _isSending = false;
  bool _isListening = false;
  StreamSubscription<String>? _streamSub;
  // 最近一次用户输入，供"重试"按钮使用
  String? _lastUserInput;
  String? _lastUserImageBase64;
  TextEditingController? _speechTarget;
  String? _voiceRecordingPath;
  // 语音半双工
  final TtsService _tts = TtsService();
  bool _voiceCallActive = false;
  String? _pendingImageBase64;
  late String _sessionId;
  String _sessionTitle = '新对话';
  bool _thinkingEnabled = false;
  int _requestSerial = 0;
  List<AiAppAction>? _pendingDangerousActions;
  String? _pendingDangerousReply;
  String? _pendingDangerousInput;
  List<String> _lastMemorySources = const [];
  bool _selectionMode = false;
  final Set<String> _selectedEntryIds = <String>{};

  @override
  void initState() {
    super.initState();
    _aiService = widget.controller.aiStudyService;
    _sessionId = 'chat_${DateTime.now().millisecondsSinceEpoch}';
    _loadLatestSession();
  }

  bool _isDefaultSessionTitle(String title) {
    final normalized = title.trim();
    return normalized.isEmpty ||
        normalized == '新对话' ||
        normalized == '学习对话' ||
        normalized == 'AI 对话';
  }

  Future<void> _loadLatestSession() async {
    try {
      final raw = await _storage.getString('chat_sessions');
      if (raw == null || raw.isEmpty) return;
      final sessions = (jsonDecode(raw) as List<dynamic>)
          .map((j) => AiChatSession.fromJson(j as Map<String, dynamic>))
          .toList();
      if (sessions.isEmpty) return;
      // 修复旧数据中的空标题/默认标题
      var needSave = false;
      final fixed = <AiChatSession>[];
      for (final s in sessions) {
        if (_isDefaultSessionTitle(s.title)) {
          needSave = true;
          AiChatMessage? firstUser;
          for (final message in s.messages) {
            if (message.role == ChatMessageRole.user) {
              firstUser = message;
              break;
            }
          }
          final newTitle = firstUser != null
              ? (firstUser.content.length > 30
                  ? '${firstUser.content.substring(0, 30)}...'
                  : firstUser.content)
              : '新对话';
          fixed.add(AiChatSession(
              id: s.id, title: newTitle, createdAt: s.createdAt,
              updatedAt: s.updatedAt, messages: s.messages));
        } else {
          fixed.add(s);
        }
      }
      if (needSave) {
        await _storage.setString(
          'chat_sessions',
          jsonEncode(fixed.map((s) => s.toJson()).toList()),
        );
      }
      sessions.clear();
      sessions.addAll(fixed);
      sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final latest = sessions.first;
      _sessionId = latest.id;
      _sessionTitle = latest.title.isNotEmpty ? latest.title : '新对话';
      _entries.clear();
      for (final m in latest.messages) {
        _entries.add(_ChatEntry(
          id: m.id,
          role: m.role == ChatMessageRole.user ? _ChatRole.user : _ChatRole.assistant,
          text: m.content,
          attachments: m.attachments,
        ));
      }
      if (mounted) {
        setState(() {});
        _scrollToBottom();
      }
    } catch (error) {
      debugPrint('加载最近会话失败: $error');
      _showSnack('最近会话加载失败：$error');
    }
  }

  @override
  void dispose() {
    unawaited(_audioRecorder.dispose());
    _streamSub?.cancel();
    unawaited(_tts.dispose());
    _voiceCallActive = false;
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 构建标准 messages 数组，用于多轮对话上下文
  List<Map<String, dynamic>> _buildMessages() {
    final msgs = <Map<String, dynamic>>[];
    final recent = _entries.reversed.take(10).toList().reversed;
    for (final entry in recent) {
      msgs.add({
        'role': entry.role == _ChatRole.user ? 'user' : 'assistant',
        'content': entry.text,
      });
    }
    return msgs;
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(widget.isDarkMode);
    final bodyColor = StudyUi.body(widget.isDarkMode);
    const accent = StudyUi.primary;

    return Scaffold(
      backgroundColor: StudyUi.background(widget.isDarkMode),
      appBar: AppBar(
        toolbarHeight: 68,
        backgroundColor: Colors.transparent,
        foregroundColor: titleColor,
        title: Text(
          _sessionTitle,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: titleColor,
          ),
        ),
        actions: [
          if (_selectionMode) ...[
            _buildTopBarAction(
              label: '取消',
              tooltip: '取消选择',
              icon: const Icon(Icons.close_rounded),
              onPressed: _clearSelection,
            ),
          ] else ...[
            _buildTopBarAction(
              label: _thinkingEnabled ? '深度' : '快速',
              tooltip: '选择思考模式',
              icon: Icon(_thinkingEnabled
                  ? Icons.psychology_rounded
                  : Icons.speed_rounded),
              color: _thinkingEnabled ? accent : null,
              onPressed: _isSending ? null : _showThinkingModeSheet,
            ),
            _buildTopBarAction(
              label: '历史',
              tooltip: '历史对话',
              icon: const Icon(Icons.history_rounded),
              onPressed: _showHistorySheet,
            ),
            _buildTopBarAction(
              label: '新建',
              tooltip: '新建对话',
              icon: const Icon(Icons.add_comment_rounded),
              onPressed: _newSession,
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 紧凑状态栏
            _buildStatusBar(titleColor, bodyColor, accent),
            // 消息列表
            Expanded(
              child: _entries.isEmpty
                  ? _emptyBody(bodyColor, accent)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(22, 4, 22, 14),
                      itemCount: _entries.length,
                      itemBuilder: (context, index) {
                        final entry = _entries[index];
                        final isLastAssistant =
                            index == _entries.length - 1 &&
                            entry.role == _ChatRole.assistant &&
                            _isSending;
                        return _ChatBubble(
                          entry: entry,
                          isDarkMode: widget.isDarkMode,
                          accent: accent,
                          isStreaming: isLastAssistant,
                          isThinking: _thinkingEnabled && isLastAssistant,
                          maxWidth: MediaQuery.of(context).size.width * 0.78,
                          selectionMode: _selectionMode,
                          selected: _selectedEntryIds.contains(entry.id),
                          onLongPress: () => _toggleEntrySelection(entry),
                          onTap: _selectionMode
                              ? () => _toggleEntrySelection(entry)
                              : null,
                        );
                      },
                    ),
            ),
            if (_selectionMode) _buildSelectionBar(accent),
            // 输入栏
            _buildInputBar(accent),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBarAction({
    required String label,
    required String tooltip,
    required Widget icon,
    required VoidCallback? onPressed,
    Color? color,
  }) {
    final enabled = onPressed != null;
    final labelColor = color ??
        (enabled
            ? StudyUi.body(widget.isDarkMode)
            : StudyUi.body(widget.isDarkMode).withValues(alpha: 0.45));
    return SizedBox(
      width: 52,
      child: Tooltip(
        message: tooltip,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: tooltip,
              icon: icon,
              color: color,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 36, height: 34),
              onPressed: onPressed,
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: labelColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showThinkingModeSheet() async {
    final titleColor = StudyUi.title(widget.isDarkMode);
    final bodyColor = StudyUi.body(widget.isDarkMode);
    final sheetColor =
        widget.isDarkMode ? const Color(0xFF1A1F2E) : Colors.white;
    final selected = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            decoration: BoxDecoration(
              color: sheetColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: bodyColor.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: const Icon(Icons.speed_rounded),
                  title: Text('快速', style: TextStyle(color: titleColor)),
                  subtitle: Text(
                    '更快回复，适合日常问答',
                    style: TextStyle(color: bodyColor),
                  ),
                  trailing: !_thinkingEnabled
                      ? const Icon(Icons.check_rounded, color: StudyUi.primary)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(false),
                ),
                ListTile(
                  leading: const Icon(Icons.psychology_rounded),
                  title: Text('深度', style: TextStyle(color: titleColor)),
                  subtitle: Text(
                    '开启深度思考，适合复杂规划和分析',
                    style: TextStyle(color: bodyColor),
                  ),
                  trailing: _thinkingEnabled
                      ? const Icon(Icons.check_rounded, color: StudyUi.primary)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(true),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null || selected == _thinkingEnabled || !mounted) return;
    setState(() => _thinkingEnabled = selected);
  }

  Widget _buildStatusBar(Color titleColor, Color bodyColor, Color accent) {
    final isLoggedIn = widget.controller.isLoggedIn;
    final provider = isLoggedIn ? '蓝心模型' : '模型未就绪';
    final color =
        isLoggedIn ? StudyUi.success : StudyUi.danger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            provider,
            style: TextStyle(
              color: titleColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_pendingImageBase64 != null) ...[
            const SizedBox(width: 8),
            Icon(Icons.image_rounded, size: 16, color: accent),
            const SizedBox(width: 2),
            Text('图片已附加',
                style: TextStyle(color: accent, fontSize: 12)),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => setState(() => _pendingImageBase64 = null),
              child:
                  const Icon(Icons.close_rounded, size: 14, color: Colors.red),
            ),
          ],
          const Spacer(),
          if (_isSending)
            const SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _emptyBody(Color bodyColor, Color accent) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.12),
          ),
          child: Icon(Icons.forum_rounded,
              color: accent, size: 30),
        ),
        const SizedBox(height: 16),
        Text('开始学习对话',
            style: TextStyle(
                color: StudyUi.title(widget.isDarkMode),
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _quickPrompt('帮我总结本周学习'),
              _quickPrompt('生成学习计划'),
              _quickPrompt('打开倒计时'),
              _quickPrompt('根据收藏闪卡生成笔记'),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _quickPrompt(String text) {
    return ActionChip(
      backgroundColor: widget.isDarkMode
          ? Colors.white.withValues(alpha: 0.08)
          : const Color(0xFFF2F5FC),
      side: BorderSide.none,
      label: Text(text, style: const TextStyle(fontSize: 13)),
      onPressed: _isSending
          ? null
          : () {
              _inputController.text = text;
              _sendMessage();
            },
    );
  }

  Widget _buildInputBar(Color accent) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? const Color(0xFF141923)
            : const Color(0xFFF5F7FF),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton.filledTonal(
            style: IconButton.styleFrom(
              backgroundColor: widget.isDarkMode
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFF2F5FC),
            ),
            onPressed: _pickAndAnalyzeImage,
            icon: const Icon(Icons.image_rounded, size: 20),
          ),
          const SizedBox(width: 6),
          if (widget.controller.aiConfig.voiceMode)
            IconButton.filledTonal(
              tooltip: _voiceCallActive ? '挂断语音' : '语音连续对话',
              style: IconButton.styleFrom(
                backgroundColor: _voiceCallActive
                    ? const Color(0xFF4BC4A1).withValues(alpha: 0.25)
                    : widget.isDarkMode
                        ? Colors.white.withValues(alpha: 0.06)
                        : const Color(0xFFF2F5FC),
              ),
              onPressed:
                  _voiceCallActive ? _endVoiceCall : _startVoiceCall,
              icon: Icon(
                _voiceCallActive
                    ? Icons.call_end_rounded
                    : Icons.call_rounded,
                size: 20,
                color: _voiceCallActive
                    ? const Color(0xFF4BC4A1)
                    : null,
              ),
            ),
          if (widget.controller.aiConfig.voiceMode)
            const SizedBox(width: 6),
          IconButton.filledTonal(
            style: IconButton.styleFrom(
              backgroundColor: _isListening
                  ? const Color(0xFFF77D8E).withValues(alpha: 0.2)
                  : widget.isDarkMode
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFF2F5FC),
            ),
            onPressed: _toggleSpeech,
            icon: Icon(
              _isListening ? Icons.stop_rounded : Icons.mic_rounded,
              size: 20,
              color: _isListening ? const Color(0xFFF77D8E) : null,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _inputController,
              autofocus: true,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              style: TextStyle(
                color: widget.isDarkMode ? Colors.white : AppColors.ink,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: _pendingImageBase64 != null
                    ? '描述你想了解这张图片的什么内容...'
                    : '输入消息...',
                hintStyle: TextStyle(
                    color: widget.isDarkMode
                        ? Colors.white.withValues(alpha: 0.35)
                        : AppColors.muted,
                    fontSize: 14),
                filled: true,
                fillColor: widget.isDarkMode
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 6),
          if (_lastUserInput != null && _lastUserInput!.isNotEmpty)
            IconButton.filledTonal(
              tooltip: '重发上一条',
              style: IconButton.styleFrom(
                backgroundColor: widget.isDarkMode
                    ? Colors.white.withValues(alpha: 0.06)
                    : const Color(0xFFF2F5FC),
              ),
              onPressed: _isSending ? null : _retryLastMessage,
              icon: const Icon(Icons.refresh_rounded, size: 20),
            ),
          if (_lastUserInput != null && _lastUserInput!.isNotEmpty)
            const SizedBox(width: 6),
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: _isSending
                  ? const Color(0xFFF77D8E)
                  : (_inputController.text.trim().isEmpty
                      ? (widget.isDarkMode
                          ? Colors.white.withValues(alpha: 0.1)
                          : const Color(0xFFE0E4EE))
                      : accent),
              foregroundColor: _isSending
                  ? Colors.white
                  : (_inputController.text.trim().isEmpty
                      ? Colors.grey
                      : Colors.white),
            ),
            onPressed: _isSending ? _stopStreaming : _sendMessage,
            icon: Icon(
              _isSending ? Icons.stop_rounded : Icons.send_rounded,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionBar(Color accent) {
    final count = _selectedEntryIds.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1D2430) : Colors.white,
        border: Border(
          top: BorderSide(
            color: widget.isDarkMode
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE7ECF5),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Text(
              '已选 $count 条',
              style: TextStyle(
                color: StudyUi.title(widget.isDarkMode),
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: '转发',
              onPressed: count == 0 ? null : _forwardSelected,
              icon: const Icon(Icons.ios_share_rounded),
              color: accent,
            ),
            IconButton(
              tooltip: '转成笔记',
              onPressed: count == 0 ? null : _selectedToNote,
              icon: const Icon(Icons.note_add_rounded),
              color: accent,
            ),
            IconButton(
              tooltip: '总结成笔记',
              onPressed: count == 0 ? null : _summarizeSelectedToNote,
              icon: const Icon(Icons.summarize_rounded),
              color: accent,
            ),
            IconButton(
              tooltip: '保存图片',
              onPressed: count == 0 ? null : _saveSelectedAsImage,
              icon: const Icon(Icons.image_rounded),
              color: accent,
            ),
          ],
        ),
      ),
    );
  }

  // ─── 会话管理 ───

  Future<void> _showHistorySheet() async {
    try {
      final raw = await _storage.getString('chat_sessions');
      if (raw == null || raw.isEmpty) {
        if (mounted) {
          StudyToast.show(context, '暂无历史对话');
        }
        return;
      }
      final sessions = (jsonDecode(raw) as List<dynamic>)
          .map((j) => AiChatSession.fromJson(j as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSheetState) => Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.6,
            ),
            decoration: BoxDecoration(
              color: widget.isDarkMode ? const Color(0xFF1A1F2E) : const Color(0xFFF5F7FF),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: widget.isDarkMode ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('历史对话',
                            style: TextStyle(
                                color: widget.isDarkMode
                                    ? Colors.white
                                    : AppColors.ink,
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                      ),
                      TextButton.icon(
                        onPressed: sessions.isEmpty
                            ? null
                            : () async {
                                final confirmed = await showDialog<bool>(
                                  context: ctx,
                                  builder: (dctx) => AlertDialog(
                                    title: const Text('清空所有对话？'),
                                    content: const Text(
                                        '将删除全部历史会话，此操作不可恢复。'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(dctx).pop(false),
                                        child: const Text('取消'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(dctx).pop(true),
                                        style: TextButton.styleFrom(
                                            foregroundColor:
                                                const Color(0xFFEF6850)),
                                        child: const Text('清空'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  await _clearAllSessions();
                                  if (ctx.mounted) Navigator.of(ctx).pop();
                                }
                              },
                        icon: const Icon(Icons.delete_sweep_outlined,
                            size: 18, color: Color(0xFFEF6850)),
                        label: const Text('清空全部',
                            style: TextStyle(color: Color(0xFFEF6850))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
                    itemCount: sessions.length,
                    itemBuilder: (_, i) {
                      final s = sessions[i];
                      final isActive = s.id == _sessionId;
                      return ListTile(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        tileColor: isActive
                            ? widget.controller.primaryColor.withValues(alpha: 0.12)
                            : null,
                        title: Text(
                          s.title,
                          style: TextStyle(
                            color: widget.isDarkMode ? Colors.white : AppColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${s.messages.length} 条消息 · ${_fmtSessionDate(s.updatedAt)}',
                          style: TextStyle(
                              color: widget.isDarkMode ? Colors.white38 : Colors.black38,
                              fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 20, color: Color(0xFFEF6850)),
                          onPressed: () async {
                            final deleted =
                                await _deleteSession(s.id, closeSheet: false);
                            if (!ctx.mounted || !deleted) return;
                            setSheetState(() => sessions.removeWhere(
                                  (session) => session.id == s.id,
                                ));
                            if (sessions.isEmpty) Navigator.of(ctx).pop();
                          },
                        ),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _loadSession(s.id);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      _showSnack('历史对话加载失败：$error');
    }
  }

  // ─── 发送状态集中控制 ───
  // _isSending 被多处切换，这里收口避免漏清导致对话页卡死。

  void _enterSending() {
    if (mounted) setState(() => _isSending = true);
  }

  void _exitSending({bool clearPending = false}) {
    if (!mounted) return;
    setState(() {
      _isSending = false;
      if (clearPending) {
        _pendingDangerousActions = null;
        _pendingDangerousReply = null;
        _pendingDangerousInput = null;
      }
    });
  }

  void _newSession() {
    _streamSub?.cancel();
    _streamSub = null;
    _requestSerial++;
    _sessionId = 'chat_${DateTime.now().millisecondsSinceEpoch}';
    _sessionTitle = '新对话';
    _entries.clear();
    _pendingImageBase64 = null;
    _selectionMode = false;
    _selectedEntryIds.clear();
    _inputController.clear();
    _exitSending(clearPending: true);
    // 首次引导气泡
    _entries.add(_ChatEntry(
      id: _newEntryId('assistant'),
      role: _ChatRole.assistant,
      text: '你好！我是蓝心模型，可以帮你：\n'
          '- 打开任何页面（"打开闪卡""打开数据看板"）\n'
          '- 创建任务和日志（"帮我创建一个复习任务"）\n'
          '- 切换设置（"切换深色模式""开始 25 分钟专注"）\n'
          '- 分析学习数据（"生成周报""根据收藏闪卡生成笔记"）\n\n'
          '直接说你想做什么吧。',
    ));
  }

  Future<void> _loadSession(String id) async {
    try {
      final raw = await _storage.getString('chat_sessions');
      if (raw == null || raw.isEmpty) return;
      final sessions = (jsonDecode(raw) as List<dynamic>)
          .map((j) => AiChatSession.fromJson(j as Map<String, dynamic>))
          .toList();
      final target = sessions.cast<AiChatSession?>().firstWhere(
          (s) => s?.id == id,
          orElse: () => null);
      if (target == null || !mounted) return;
      setState(() {
        _sessionId = target.id;
        _sessionTitle = target.title;
        _selectionMode = false;
        _selectedEntryIds.clear();
        _entries.clear();
        for (final m in target.messages) {
          _entries.add(_ChatEntry(
            id: m.id,
            role: m.role == ChatMessageRole.user
                ? _ChatRole.user
                : _ChatRole.assistant,
            text: m.content,
            attachments: m.attachments,
          ));
        }
      });
      _scrollToBottom();
    } catch (error) {
      _showSnack('历史对话打开失败：$error');
    }
  }

  Future<bool> _deleteSession(String id, {bool closeSheet = false}) async {
    try {
      final raw = await _storage.getString('chat_sessions');
      if (raw == null) return false;
      var sessions = (jsonDecode(raw) as List<dynamic>)
          .map((j) => AiChatSession.fromJson(j as Map<String, dynamic>))
          .toList();
      final before = sessions.length;
      sessions.removeWhere((s) => s.id == id);
      if (sessions.length == before) return false;
      await _storage.setString(
        'chat_sessions',
        jsonEncode(sessions.map((s) => s.toJson()).toList()),
      );
      if (id == _sessionId && sessions.isNotEmpty) {
        sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        await _loadSession(sessions.first.id);
      } else if (id == _sessionId) {
        _newSession();
      }
      if (closeSheet && mounted) Navigator.of(context).pop();
      if (mounted) {
        setState(() {});
        _showSnack('已删除历史对话');
      }
      return true;
    } catch (error) {
      _showSnack('历史对话删除失败：$error');
      return false;
    }
  }

  Future<void> _clearAllSessions() async {
    try {
      await _storage.setString('chat_sessions', '[]');
      _newSession();
      if (mounted) {
        StudyToast.show(context, '已清空所有历史对话');
      }
    } catch (error) {
      _showSnack('历史对话清空失败：$error');
    }
  }

  String _fmtSessionDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${d.month}/${d.day}';
  }

  // ─── 核心发送逻辑（结构化操作） ───

  Future<void> _sendMessage() async {
    final input = _inputController.text.trim();
    if (input.isEmpty || _isSending) return;

    final requestId = ++_requestSerial;
    final imageBase64 = _pendingImageBase64;
    final messages = _buildMessages();
    // 记录本轮用户输入，用于失败后"重试"按钮
    _lastUserInput = input;
    _lastUserImageBase64 = imageBase64;

    setState(() {
      if (imageBase64 != null) {
        _entries.add(_ChatEntry(
          id: _newEntryId('user'),
          role: _ChatRole.user,
          text: input.isNotEmpty ? '[图片] $input' : '[图片]',
        ));
      } else {
        _entries.add(_ChatEntry(
          id: _newEntryId('user'),
          role: _ChatRole.user,
          text: input,
        ));
      }
      _entries.add(_ChatEntry(
        id: _newEntryId('assistant'),
        role: _ChatRole.assistant,
        text: '',
      ));
      _inputController.clear();
      _pendingImageBase64 = null;
    });
    _enterSending();

    await _saveChatMessage(role: ChatMessageRole.user, content: input);

    try {
      final turn = await _aiService.generateAssistantTurn(
        input: input,
        appContext: await _buildAppContextWithMemory(input),
        messages: messages,
        imageBase64: imageBase64,
        thinkingEnabled: _thinkingEnabled,
      );
      if (requestId != _requestSerial) return;

      final visibleReply = _stripActions(turn.reply.trim());
      final replyBase = visibleReply.isEmpty
          ? '我理解了，但这次没有生成可显示回复。'
          : visibleReply;
      final reply = _lastMemorySources.isEmpty
          ? replyBase
          : '$replyBase\n\n**学习来源**\n${_lastMemorySources.map((item) => '- $item').join('\n')}';
      if (mounted) {
        setState(() => _replaceAssistantDraft(reply));
        _scrollToBottom();
      }

      var finalReply = reply;
      if (turn.actions.isNotEmpty) {
        // 分离安全动作和危险动作
        final safeActions = <AiAppAction>[];
        final dangerousActions = <AiAppAction>[];
        for (final action in turn.actions) {
          final toolId = _actionTypeToToolId(action.type);
          final def = toolId != null
              ? AiToolRegistry.instance.lookup(toolId)
              : null;
          final needsConfirmation =
              def?.needsConfirmation ?? _needsConfirmationFallback(action.type);
          if (needsConfirmation) {
            dangerousActions.add(action);
          } else {
            safeActions.add(action);
          }
        }

        // 安全动作直接执行
        if (safeActions.isNotEmpty) {
          final handler = widget.onExecuteActions;
          final results = handler == null
              ? safeActions
                  .map((action) => AiActionResult(
                        action: action,
                        success: false,
                        message: '当前入口还没有接入全局执行器',
                      ))
                  .toList()
              : await handler(
                  actions: safeActions,
                  input: input,
                  assistantReply: reply,
                );
          if (requestId != _requestSerial) return;
          finalReply = _appendActionResults(reply, results);
        }

        // 危险动作渲染确认卡片
        if (dangerousActions.isNotEmpty && mounted) {
          setState(() {
            _replaceAssistantDraft(finalReply);
            _entries.add(_ChatEntry(
              id: _newEntryId('confirm'),
              role: _ChatRole.confirmCard,
              text: '',
              confirmActions: dangerousActions,
            ));
          });
          _scrollToBottom();
          // 不要标记 isSending = false 在 finally 中，而是等确认卡处理完后标记
          _pendingDangerousActions = dangerousActions;
          _pendingDangerousReply = finalReply;
          _pendingDangerousInput = input;
          await _saveChatMessage(
            role: ChatMessageRole.assistant,
            content: finalReply,
            attachments: _attachmentsFromMarkdown(finalReply),
          );
          return; // 提前返回，不清除 isSending
        }

        if (mounted) {
          setState(() => _replaceAssistantDraft(finalReply));
          _scrollToBottom();
        }
      }
      await _saveChatMessage(
        role: ChatMessageRole.assistant,
        content: finalReply,
        attachments: _attachmentsFromMarkdown(finalReply),
      );
    } catch (error) {
      await _handleAssistantTurnError(
        error: error,
        input: input,
        messages: messages,
        requestId: requestId,
      );
    } finally {
      if (requestId == _requestSerial && mounted &&
          _pendingDangerousActions == null) {
        _exitSending();
        _scrollToBottom();
      }
    }
  }

  String? _actionTypeToToolId(AiAppActionType type) {
    return switch (type) {
      AiAppActionType.switchTab => AiToolIds.switchTab,
      AiAppActionType.openTimer => AiToolIds.openTimer,
      AiAppActionType.openFlashcard => AiToolIds.openFlashcard,
      AiAppActionType.openNotes => AiToolIds.openNotes,
      AiAppActionType.openAiSettings => AiToolIds.openAiSettings,
      AiAppActionType.openDashboard => AiToolIds.openDashboard,
      AiAppActionType.openTaskPlanning => AiToolIds.openTaskPlanning,
      AiAppActionType.openAiAssistant => AiToolIds.openAiAssistant,
      AiAppActionType.openUserProfile => AiToolIds.openUserProfile,
      AiAppActionType.openAbout => AiToolIds.openAbout,
      AiAppActionType.openStudyGroup => AiToolIds.openStudyGroup,
      AiAppActionType.openLeaderboard => AiToolIds.openLeaderboard,
      AiAppActionType.openWeeklyReport => AiToolIds.openWeeklyReport,
      AiAppActionType.openSystemSettings => AiToolIds.openSystemSettings,
      AiAppActionType.addTask => AiToolIds.addTask,
      AiAppActionType.createLog => AiToolIds.createLog,
      AiAppActionType.markTaskStatus => AiToolIds.markTaskStatus,
      AiAppActionType.saveNote => AiToolIds.saveNote,
      AiAppActionType.summarizeStarredCards => AiToolIds.summarizeStarredCards,
      AiAppActionType.deleteTask => AiToolIds.deleteTask,
      AiAppActionType.deleteLog => AiToolIds.deleteLog,
      AiAppActionType.deleteNote => AiToolIds.deleteNote,
      AiAppActionType.deleteFlashcard => AiToolIds.deleteFlashcard,
      AiAppActionType.overwriteNote => AiToolIds.overwriteNote,
      AiAppActionType.setDarkMode => AiToolIds.setDarkMode,
      AiAppActionType.setSkin => AiToolIds.setSkin,
      AiAppActionType.setDailyReminder => AiToolIds.setDailyReminder,
      AiAppActionType.setServerUrl => AiToolIds.setServerUrl,
      AiAppActionType.logout => AiToolIds.logout,
      AiAppActionType.addCourse => AiToolIds.addCourse,
      AiAppActionType.renameCourse => AiToolIds.renameCourse,
      AiAppActionType.deleteCourse => AiToolIds.deleteCourse,
      AiAppActionType.toggleFlashcardStar => AiToolIds.toggleFlashcardStar,
      AiAppActionType.addFlashcard => AiToolIds.addFlashcard,
      AiAppActionType.generateTodayFlashcards =>
        AiToolIds.generateTodayFlashcards,
      AiAppActionType.startFocus => AiToolIds.startFocus,
      AiAppActionType.addTaskDirect => AiToolIds.addTaskDirect,
      AiAppActionType.updateSubtask => AiToolIds.updateSubtask,
      AiAppActionType.emptyTrash => AiToolIds.emptyTrash,
      AiAppActionType.generateWeeklyPlan => AiToolIds.generateWeeklyPlan,
      AiAppActionType.noteFromLog => AiToolIds.noteFromLog,
      AiAppActionType.createLoopFromSource => AiToolIds.createLoopFromSource,
      AiAppActionType.generateTodayMission => AiToolIds.generateTodayMission,
      AiAppActionType.searchMemory => AiToolIds.searchMemory,
      AiAppActionType.noteFromOcr => AiToolIds.noteFromOcr,
      AiAppActionType.createFlashcardBatch => AiToolIds.createFlashcardBatch,
      AiAppActionType.startFocusWithTask => AiToolIds.startFocusWithTask,
      AiAppActionType.generateImage => AiToolIds.generateImage,
      AiAppActionType.refreshImage => AiToolIds.refreshImage,
      AiAppActionType.generateVideo => AiToolIds.generateVideo,
      AiAppActionType.refreshVideo => AiToolIds.refreshVideo,
      AiAppActionType.translateText => AiToolIds.translateText,
      AiAppActionType.searchPoi => AiToolIds.searchPoi,
      AiAppActionType.reverseGeocode => AiToolIds.reverseGeocode,
    };
  }

  /// 执行单个危险动作（由确认卡片触发）
  bool _needsConfirmationFallback(AiAppActionType type) {
    return switch (type) {
      AiAppActionType.deleteTask ||
      AiAppActionType.deleteLog ||
      AiAppActionType.deleteNote ||
      AiAppActionType.deleteFlashcard ||
      AiAppActionType.overwriteNote ||
      AiAppActionType.logout ||
      AiAppActionType.deleteCourse ||
      AiAppActionType.emptyTrash =>
        true,
      _ => false,
    };
  }

  Future<void> _executeDangerousAction(AiAppAction action) async {
    final handler = widget.onExecuteActions;
    List<AiActionResult> results;
    if (handler == null) {
      results = [
        AiActionResult(
          action: action,
          success: false,
          message: '当前入口还没有接入全局执行器',
        ),
      ];
    } else {
      try {
        results = await handler(
          actions: [action],
          input: _pendingDangerousInput ?? '',
          assistantReply: _pendingDangerousReply ?? '',
        );
      } catch (error) {
        results = [
          AiActionResult(
            action: action,
            success: false,
            message: '执行失败：$error',
          ),
        ];
      }
    }
    if (mounted) {
      final remaining = _remainingDangerousActions(action);
      setState(() {
        // 最后一条可能是确认卡，真正的助手回复在它之前。
        // 先更新确认卡，再把结果追加到 assistant 气泡上。
        if (_entries.isNotEmpty &&
            _entries.last.role == _ChatRole.confirmCard) {
        if (remaining.isEmpty) {
          _entries.removeLast();
        } else {
          _entries[_entries.length - 1] = _ChatEntry(
            id: _entries.last.id,
            role: _ChatRole.confirmCard,
            text: '',
            confirmActions: remaining,
          );
        }
        }
        for (var i = _entries.length - 1; i >= 0; i--) {
          if (_entries[i].role == _ChatRole.assistant) {
            final updated = _appendActionResults(_entries[i].text, results);
            _entries[i] = _entries[i].copyWith(text: updated);
            break;
          }
        }
        _pendingDangerousActions = remaining.isEmpty ? null : remaining;
      });
      if (remaining.isEmpty) _exitSending(clearPending: true);
    }
  }

  /// 取消单个危险动作
  void _cancelDangerousAction(AiAppAction action) {
    final remaining = _remainingDangerousActions(action);
    setState(() {
      // 取消时也移除确认卡并在气泡里追加"已取消"
      if (_entries.isNotEmpty &&
          _entries.last.role == _ChatRole.confirmCard) {
        if (remaining.isEmpty) {
          _entries.removeLast();
          } else {
            _entries[_entries.length - 1] = _ChatEntry(
              id: _entries.last.id,
              role: _ChatRole.confirmCard,
              text: '',
              confirmActions: remaining,
            );
        }
      }
      for (var i = _entries.length - 1; i >= 0; i--) {
        if (_entries[i].role == _ChatRole.assistant) {
          final base = _entries[i].text.trim();
          final updated = base.isEmpty
              ? '- 未执行：用户已取消'
              : '$base\n\n- 未执行：用户已取消';
          _entries[i] = _entries[i].copyWith(text: updated);
          break;
        }
      }
      _pendingDangerousActions = remaining.isEmpty ? null : remaining;
    });
    if (remaining.isEmpty) _exitSending(clearPending: true);
  }

  List<AiAppAction> _remainingDangerousActions(AiAppAction action) {
    final pending = _pendingDangerousActions ?? const <AiAppAction>[];
    return pending
        .where((item) => !_isSameAction(item, action))
        .toList(growable: false);
  }

  bool _isSameAction(AiAppAction left, AiAppAction right) {
    if (identical(left, right)) return true;
    final leftId = left.actionId;
    final rightId = right.actionId;
    return leftId != null &&
        leftId.isNotEmpty &&
        rightId != null &&
        leftId == rightId;
  }

  List<String> _buildAppContext() {
    return AiAppContextBuilder.build(
      widget.controller,
      currentLocation:
          widget.currentLocation ?? widget.controller.currentPrimaryTab,
    );
  }

  Future<List<String>> _buildAppContextWithMemory(String input) async {
    final context = _buildAppContext();
    final memory = await _semanticMemoryContext(input);
    _lastMemorySources = memory.take(5).toList();
    if (memory.isEmpty) return context;
    return [
      ...context,
      '语义召回的个人学习记忆：',
      ...memory,
    ];
  }

  Future<List<String>> _semanticMemoryContext(String query) async {
    final candidates = _memoryCandidates();
    if (candidates.isEmpty || query.trim().isEmpty) return const [];
    try {
      final service = widget.controller.createSemanticSearchService();
      final hits = await service.search<String>(
        query: query,
        candidates: candidates,
      );
      return hits.take(5).map((hit) => hit.item).toList();
    } catch (_) {
      return _localMemoryMatches(query, candidates).take(5).map((c) => c.item).toList();
    }
  }

  List<SemanticSearchCandidate<String>> _memoryCandidates() {
    final result = <SemanticSearchCandidate<String>>[];
    for (final task in widget.controller.studyTasks) {
      result.add(SemanticSearchCandidate(
        id: task.id,
        item:
            '任务：${task.title}｜课程：${task.courseName}｜状态：${task.effectiveStatus.name}｜截止：${task.deadline.toIso8601String()}｜备注：${task.note}',
        text:
            '${task.title} ${task.courseName} ${task.note} ${task.subTasks.map((s) => s.title).join(' ')}',
      ));
    }
    for (final log in widget.controller.studyLogs) {
      result.add(SemanticSearchCandidate(
        id: log.id,
        item:
            '日志：${log.courseName}｜${log.content}｜问题：${log.problems}｜下一步：${log.nextPlan}',
        text: '${log.courseName} ${log.content} ${log.problems} ${log.thoughts} ${log.nextPlan}',
      ));
    }
    for (final note in widget.controller.studyNotes.where((n) => !n.isFolder)) {
      result.add(SemanticSearchCandidate(
        id: note.id,
        item: '笔记：${note.title}｜${note.courseName}｜${note.content}',
        text:
            '${note.title} ${note.courseName} ${note.content} ${note.blocks.map((b) => b.content).join(' ')}',
      ));
    }
    for (final card in widget.controller.flashCards) {
      result.add(SemanticSearchCandidate(
        id: card.id,
        item: '闪卡：${card.courseName}｜${card.question}｜${card.answer}',
        text: '${card.courseName} ${card.question} ${card.answer} ${card.hint}',
      ));
    }
    return result;
  }

  List<SemanticSearchCandidate<String>> _localMemoryMatches(
    String query,
    List<SemanticSearchCandidate<String>> candidates,
  ) {
    final q = query.toLowerCase();
    final matches = candidates.where((c) => c.text.toLowerCase().contains(q)).toList();
    return matches.isEmpty ? candidates : matches;
  }

  Future<void> _handleAssistantTurnError({
    required Object error,
    required String input,
    required List<Map<String, dynamic>> messages,
    required int requestId,
  }) async {
    try {
      final fallback = await _aiService.generateAssistantReply(
        input: input,
        messages: messages,
        thinkingEnabled: _thinkingEnabled,
      );
      if (requestId != _requestSerial) return;
      final reply = _stripLegacyActions(fallback);
      if (mounted) setState(() => _replaceAssistantDraft(reply));
      await _saveChatMessage(
        role: ChatMessageRole.assistant,
        content: reply,
        attachments: _attachmentsFromMarkdown(reply),
      );
    } catch (_) {
      final friendly = _friendlyErrorMessage(error);
      if (mounted) setState(() => _replaceAssistantDraft(friendly));
      await _saveChatMessage(
        role: ChatMessageRole.assistant,
        content: friendly,
      );
    }
  }

  String _friendlyErrorMessage(Object error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('failed to fetch') ||
        msg.contains('socketexception') ||
        msg.contains('connection refused') ||
        msg.contains('timeout')) {
      return '蓝心模型暂时不可用，请检查网络连接后重试。';
    }
    if (msg.contains('401') || msg.contains('unauthorized') ||
        msg.contains('appkey')) {
      return '蓝心模型认证失败，请重新登录或检查云端服务。';
    }
    if (msg.contains('429') || msg.contains('rate') ||
        msg.contains('too many')) {
      return '请求过于频繁，请稍后再试。';
    }
    if (msg.contains('quota') || msg.contains('额度') ||
        msg.contains('limit')) {
      return '今日蓝心模型使用次数已达上限，明天再来吧。';
    }
    if (msg.contains('503') || msg.contains('unavailable')) {
      return '蓝心模型暂时不可用，请稍后重试。';
    }
    return '回复失败，请稍后重试。';
  }

  void _replaceAssistantDraft(String text) {
    for (var i = _entries.length - 1; i >= 0; i--) {
      if (_entries[i].role == _ChatRole.assistant) {
        _entries[i] = _entries[i].copyWith(
          text: text,
          attachments: _attachmentsFromMarkdown(text),
        );
        return;
      }
    }
    _entries.add(_ChatEntry(
      id: _newEntryId('assistant'),
      role: _ChatRole.assistant,
      text: text,
      attachments: _attachmentsFromMarkdown(text),
    ));
  }

  String _appendActionResults(String reply, List<AiActionResult> results) {
    if (results.isEmpty) return reply;
    final lines = results.map((result) {
      final prefix = result.success ? '已执行' : '未执行';
      return '- $prefix：${result.message}';
    }).join('\n');
    return '$reply\n\n$lines'.trim();
  }

  String _stripLegacyActions(String text) {
    return text
        .replaceAll(RegExp(r'【ACTION:[A-Z_]+】|\[ACTION:[A-Z_]+\]'), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  /// 去掉给 TTS 朗读时会被念成干扰字符的 Markdown 符号
  String _stripMarkdownForSpeech(String text) {
    return text
        .replaceAll(RegExp(r'[#>`*_~-]{2,}'), ' ')
        .replaceAll(RegExp(r'^[#>\-*]\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1')
        .replaceAll(RegExp(r'`([^`]+)`'), r'$1')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1')
        .replaceAll(RegExp(r'\n{2,}'), '。')
        .trim();
  }

  void _stopStreaming() {
    _streamSub?.cancel();
    _streamSub = null;
    _requestSerial++;
    if (!mounted) return;
    setState(() => _replaceAssistantDraft('已停止生成。'));
    _exitSending(clearPending: true);
  }

  void _toggleEntrySelection(_ChatEntry entry) {
    if (entry.role == _ChatRole.confirmCard) return;
    setState(() {
      _selectionMode = true;
      if (_selectedEntryIds.contains(entry.id)) {
        _selectedEntryIds.remove(entry.id);
      } else {
        _selectedEntryIds.add(entry.id);
      }
      if (_selectedEntryIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  void _clearSelection() {
    if (!mounted) return;
    setState(() {
      _selectionMode = false;
      _selectedEntryIds.clear();
    });
  }

  List<_ChatEntry> get _selectedEntries => _entries
      .where((entry) => _selectedEntryIds.contains(entry.id))
      .toList(growable: false);

  String _selectedMarkdown() {
    return _selectedEntries
        .map((entry) {
          final speaker = entry.role == _ChatRole.user ? '我' : 'AI';
          final attachmentLines = entry.attachments
              .map((item) => item.url == null
                  ? ''
                  : item.type == AiChatAttachmentType.image
                      ? '![${item.title ?? '图片'}](${item.url})'
                      : '[${item.title ?? '附件'}](${item.url})')
              .where((line) => line.trim().isNotEmpty)
              .join('\n');
          return [
            '**$speaker**',
            entry.text.trim(),
            if (attachmentLines.isNotEmpty) attachmentLines,
          ].where((part) => part.trim().isNotEmpty).join('\n');
        })
        .where((part) => part.trim().isNotEmpty)
        .join('\n\n---\n\n');
  }

  Future<void> _forwardSelected() async {
    final text = _selectedMarkdown();
    if (text.isEmpty) return;
    try {
      await Clipboard.setData(ClipboardData(text: text));
      await widget.controller.publishLearningMoment(
        content: text.length > 500 ? '${text.substring(0, 500)}...' : text,
        sourceType: 'ai_chat',
        sourceId: _sessionId,
      );
      _showSnack('已复制，可粘贴转发；同时已保存为私密学迹');
      _clearSelection();
    } catch (error) {
      _showSnack('转发准备失败：$error');
    }
  }

  Future<void> _selectedToNote() async {
    final text = _selectedMarkdown();
    if (text.isEmpty) return;
    try {
      await widget.controller.addStudyNote(
        title: 'AI 对话笔记 ${DateTime.now().month}/${DateTime.now().day}',
        content: text,
        blocks: markdownToNoteBlocks(text),
      );
      _showSnack('已转成笔记');
      _clearSelection();
    } catch (error) {
      _showSnack('转成笔记失败：$error');
    }
  }

  Future<void> _summarizeSelectedToNote() async {
    final text = _selectedMarkdown();
    if (text.isEmpty || _isSending) return;
    _enterSending();
    try {
      final summary = await _aiService.generateAssistantReply(
        input: '请把以下 AI 对话整理成一篇结构清晰的学习笔记：\n\n$text',
        purpose: 'note',
        thinkingEnabled: _thinkingEnabled,
      );
      final content = summary.trim().isEmpty ? text : summary.trim();
      await widget.controller.addStudyNote(
        title: 'AI 对话总结 ${DateTime.now().month}/${DateTime.now().day}',
        content: content,
        blocks: markdownToNoteBlocks(content),
      );
      _showSnack('已总结成笔记');
      _clearSelection();
    } catch (error) {
      _showSnack('总结成笔记失败：$error');
    } finally {
      _exitSending();
    }
  }

  Future<void> _saveSelectedAsImage() async {
    final imageUrls = _selectedEntries
        .expand((entry) => entry.attachments)
        .where((item) => item.type == AiChatAttachmentType.image)
        .map((item) => item.url ?? '')
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
    try {
      if (imageUrls.isNotEmpty) {
        var saved = 0;
        for (final url in imageUrls.take(6)) {
          final bytes = await _downloadImageBytes(url);
          if (bytes == null) continue;
          await saveExportFile(
            fileName:
                'studytrace_ai_image_${DateTime.now().microsecondsSinceEpoch}.png',
            mimeType: 'image/png',
            bytes: bytes,
          );
          saved++;
        }
        _showSnack(saved > 0 ? '已保存 $saved 张图片' : '图片下载失败');
      } else {
        final bytes = await _renderSelectedMarkdownImage(_selectedMarkdown());
        await saveExportFile(
          fileName:
              'studytrace_chat_${DateTime.now().microsecondsSinceEpoch}.png',
          mimeType: 'image/png',
          bytes: bytes,
        );
        _showSnack('已保存选中对话截图');
      }
      _clearSelection();
    } catch (error) {
      _showSnack('保存图片失败：$error');
    }
  }

  Future<Uint8List?> _downloadImageBytes(String url) async {
    if (url.startsWith('data:image/')) {
      final comma = url.indexOf(',');
      if (comma <= 0) return null;
      final header = url.substring(0, comma).toLowerCase();
      final body = url.substring(comma + 1);
      return header.contains(';base64')
          ? base64Decode(body)
          : Uint8List.fromList(utf8.encode(Uri.decodeComponent(body)));
    }
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    return response.bodyBytes;
  }

  Future<Uint8List> _renderSelectedMarkdownImage(String markdown) async {
    String cleanLine(String value) {
      var text = value;
      text = text.replaceAllMapped(
        RegExp(r'\*\*(.*?)\*\*'),
        (match) => match.group(1) ?? '',
      );
      text = text.replaceAll(RegExp(r'[`>#*_]'), '');
      return text.trimRight();
    }

    final cleaned = markdown
        .replaceAllMapped(
          RegExp(r'!\[[^\]]*\]\(([^)]+)\)'),
          (match) => '[图片] ${match.group(1) ?? ''}',
        )
        .replaceAllMapped(
          RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
          (match) => '${match.group(1) ?? ''}：${match.group(2) ?? ''}',
        )
        .replaceAll(RegExp(r'<video[^>]*></video>', caseSensitive: false), '')
        .trim();
    final text = cleaned.isEmpty ? '选中的 AI 对话' : cleaned;
    const width = 900.0;
    const horizontal = 48.0;
    const vertical = 42.0;
    const lineGap = 12.0;
    final contentWidth = width - horizontal * 2;
    final paragraphs = <TextPainter>[];
    for (final block in text.split('\n')) {
      final display = cleanLine(block);
      final painter = TextPainter(
        text: TextSpan(
          text: display.isEmpty ? ' ' : display,
          style: TextStyle(
            color: widget.isDarkMode ? Colors.white : const Color(0xFF172033),
            fontSize: 28,
            height: 1.45,
            fontWeight:
                block.startsWith('**') ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: contentWidth);
      paragraphs.add(painter);
    }
    final height = (vertical * 2 +
            paragraphs.fold<double>(
              0,
              (sum, painter) => sum + painter.height + lineGap,
            ))
        .clamp(420.0, 6000.0)
        .toDouble();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final bg = Paint()
      ..color = widget.isDarkMode ? const Color(0xFF111722) : Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), bg);
    final accentPaint = Paint()..color = StudyUi.primary;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, width, 18),
        const Radius.circular(0),
      ),
      accentPaint,
    );
    var y = vertical;
    for (final painter in paragraphs) {
      if (y + painter.height > height - vertical) break;
      painter.paint(canvas, Offset(horizontal, y));
      y += painter.height + lineGap;
    }
    final image = await recorder.endRecording().toImage(
          width.toInt(),
          height.toInt(),
        );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('截图生成失败');
    return data.buffer.asUint8List();
  }

  Future<void> _retryLastMessage() async {
    final input = _lastUserInput;
    if (input == null || input.isEmpty || _isSending) return;
    _inputController.text = input;
    _pendingImageBase64 = _lastUserImageBase64;
    await _sendMessage();
  }

  // ─── 图片分析（Vision） ───

  Future<void> _pickAndAnalyzeImage() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: widget.isDarkMode ? const Color(0xFF1A1F2E) : const Color(0xFFF5F7FF),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: widget.isDarkMode ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 18),
          ListTile(
            leading: Icon(Icons.photo_library_rounded, color: widget.controller.primaryColor),
            title: const Text('从相册选择'),
            onTap: () => Navigator.of(ctx).pop('gallery'),
          ),
          ListTile(
            leading: Icon(Icons.camera_alt_rounded, color: widget.controller.primaryColor),
            title: const Text('拍照'),
            onTap: () => Navigator.of(ctx).pop('camera'),
          ),
        ]),
      ),
    );
    if (result == null) return;

    final source = result == 'camera' ? ImageSource.camera : ImageSource.gallery;
    try {
      final picked = await _imagePicker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _pendingImageBase64 = base64Encode(bytes);
        _inputController.text = '请分析这张图片的内容';
      });
    } catch (e) {
      if (!mounted) return;
      await StudyToast.dialog(
        context,
        title: '读取图片失败',
        message: '$e',
      );
    }
  }

  // ─── 辅助方法 ───

  // ignore: unused_element
  List<String> _extractActions(String text) {
    final matches =
        RegExp(r'【ACTION:([A-Z_]+)】|\[ACTION:([A-Z_]+)\]').allMatches(text);
    return matches
        .map((match) => match.group(1) ?? match.group(2) ?? '')
        .where((action) => action.isNotEmpty)
        .toList(growable: false);
  }

  String _stripActions(String text) {
    var cleaned = text
        .replaceAll(RegExp(r'【ACTION:[A-Z_]+】|\[ACTION:[A-Z_]+\]'), '')
        .trim();
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return cleaned.trim();
  }

  String _newEntryId(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}';

  List<AiChatAttachment> _attachmentsFromMarkdown(String markdown) {
    final attachments = <AiChatAttachment>[];
    var index = 0;
    for (final match in RegExp(r'!\[[^\]]*\]\(([^)]+)\)')
        .allMatches(markdown)) {
      final url = (match.group(1) ?? '').trim();
      if (url.isEmpty) continue;
      attachments.add(AiChatAttachment(
        id: 'att_${DateTime.now().microsecondsSinceEpoch}_${index++}',
        type: AiChatAttachmentType.image,
        url: url,
        title: 'AI 图片',
      ));
    }
    final videoPattern = RegExp(
      """<video[^>]+src=["']([^"']+)["'][^>]*>|https?://\\S+\\.(?:mp4|mov|webm|m3u8)(?:\\?\\S*)?""",
      caseSensitive: false,
    );
    for (final match in videoPattern.allMatches(markdown)) {
      final url = (match.group(1) ?? match.group(0) ?? '')
          .replaceAll(RegExp(r'[)\]>]+$'), '')
          .trim();
      if (url.isEmpty || attachments.any((item) => item.url == url)) continue;
      attachments.add(AiChatAttachment(
        id: 'att_${DateTime.now().microsecondsSinceEpoch}_${index++}',
        type: AiChatAttachmentType.video,
        url: url,
        title: '生成视频',
      ));
    }
    return attachments;
  }

  Future<void> _saveChatMessage({
    required ChatMessageRole role,
    required String content,
    List<AiChatAttachment> attachments = const [],
  }) async {
    try {
      final message = AiChatMessage(
        id: '${_sessionId}_${DateTime.now().millisecondsSinceEpoch}',
        role: role,
        content: content,
        timestamp: DateTime.now(),
        attachments: attachments.isEmpty
            ? _attachmentsFromMarkdown(content)
            : attachments,
      );
      final chatHistoryJson =
          await _storage.getString('chat_sessions') ?? '[]';
      final sessions = (jsonDecode(chatHistoryJson) as List<dynamic>)
          .map((j) => AiChatSession.fromJson(j as Map<String, dynamic>))
          .toList();
      var sessionIndex = sessions.indexWhere((s) => s.id == _sessionId);
      if (sessionIndex < 0) {
        sessions.add(AiChatSession(
          id: _sessionId,
          title: '新对话',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          messages: [],
        ));
        sessionIndex = sessions.length - 1;
      }
      final session = sessions[sessionIndex];
      session.messages.add(message);
      // 自动标题：第一条 user 消息的第一句（或前30字）
      String title = session.title;
      if (_isDefaultSessionTitle(title)) {
        final firstUser = session.messages
            .firstWhere((m) => m.role == ChatMessageRole.user,
                orElse: () => message);
        final content = firstUser.content;
        // 取第一句（按。！？. ! ? 分割）
        final sentenceEnd = content.indexOf(RegExp(r'[。！？.!?]'));
        final firstSentence = sentenceEnd > 0
            ? content.substring(0, sentenceEnd + 1)
            : (content.length > 30
                ? '${content.substring(0, 30)}...'
                : content);
        title = firstSentence.isNotEmpty ? firstSentence : '新对话';
      }
      _sessionTitle = title;
      if (mounted) setState(() {});
      sessions[sessionIndex] = AiChatSession(
        id: session.id,
        title: title,
        createdAt: session.createdAt,
        updatedAt: DateTime.now(),
        messages: session.messages,
      );
      await _storage.setString(
        'chat_sessions',
        jsonEncode(sessions.map((s) => s.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('保存聊天消息失败: $e');
    }
  }

  // ignore: unused_element
  Future<void> _runActions(List<String> actions, String input) async {
    for (final action in actions) {
      switch (action) {
        case 'OPEN_TIMER':
          if (!mounted) return;
          try {
            await Navigator.of(context).push(MaterialPageRoute(
              builder: (ctx) => TimerPage(
                  isDarkMode: widget.isDarkMode,
                  controller: widget.controller),
            ));
          } catch (e) {
            if (!mounted) return;
            _showSnack('无法打开计时器：$e');
          }
          break;
        case 'OPEN_FLASHCARD':
          if (!mounted) return;
          try {
            await Navigator.of(context).push(MaterialPageRoute(
              builder: (ctx) => FlashCardPage(
                  isDarkMode: widget.isDarkMode,
                  controller: widget.controller),
            ));
          } catch (e) {
            if (!mounted) return;
            _showSnack('无法打开闪卡：$e');
          }
          break;
        case 'ADD_TASK':
          try {
            final plan = await _aiService.generateTaskPlan(input);
            final now = DateTime.now();
            final subTasks = plan.plannedSubTasks.isNotEmpty
                ? plan.plannedSubTasks
                    .map((p) => StudySubTaskItem(
                          id: 'sub_${now.microsecondsSinceEpoch}_${plan.plannedSubTasks.indexOf(p)}',
                          title: p.title,
                          startAt: p.startAt,
                          deadline: p.deadline,
                          note: p.note,
                          createdAt: now,
                          updatedAt: now,
                        ))
                    .toList()
                : plan.subTasks
                    .map((title) => StudySubTaskItem(
                          id: 'sub_${now.microsecondsSinceEpoch}_${plan.subTasks.indexOf(title)}',
                          title: title,
                          deadline: plan.deadline,
                          createdAt: now,
                          updatedAt: now,
                        ))
                    .toList();
            final note = [
              if (plan.difficulty.isNotEmpty) '难度：${plan.difficulty}',
              if (plan.schedule.isNotEmpty) '推荐安排：\n${plan.schedule}',
            ].join('\n');
            await widget.controller.addStudyTask(
              title: plan.mainTitle,
              type: plan.taskType,
              courseName: plan.courseName,
              deadline: plan.deadline,
              note: note,
              subTasks: subTasks,
            );
            if (mounted) {
              _showSnack('任务 "${plan.mainTitle}" 已添加');
            }
          } catch (e) {
            if (!mounted) return;
            _showSnack('创建任务失败：$e');
          }
          break;
        case 'SUMMARY_NOTE':
          await _generateNoteFromStarredCards();
          break;

        // ─── 新增 ACTION ───

        case 'CREATE_LOG':
          // 从对话内容提取学习日志
          try {
            final log = await _aiService.generateStudyLog(input);
            await widget.controller.addStudyLog(
              date: DateTime.now(),
              courseName: log.courseName,
              content: log.content,
              problems: log.problems,
              thoughts: log.thoughts,
              nextPlan: log.nextPlan,
            );
            if (mounted) {
              _showSnack('学习日志已保存：${log.courseName}');
            }
          } catch (e) {
            if (!mounted) return;
            _showSnack('保存日志失败：$e');
          }
          break;

        case 'MARK_COMPLETED':
        case 'MARK_IN_PROGRESS':
          // 匹配用户输入中的任务标题
          try {
            final targetStatus = action == 'MARK_COMPLETED'
                ? StudyTaskStatus.completed
                : StudyTaskStatus.inProgress;
            final tasks = widget.controller.studyTasks;
            var matched = _findBestTask(tasks, input);
            if (matched != null) {
              await widget.controller.updateStudyTaskStatus(
                  matched.id, targetStatus);
              final label =
                  targetStatus == StudyTaskStatus.completed ? '已完成' : '进行中';
              if (mounted) {
                _showSnack('任务 "${matched.title}" 已标记为$label');
              }
            } else {
              // 列出所有未完成任务供用户选择
              final pending = tasks.where(
                  (t) => t.status != StudyTaskStatus.completed).toList();
              if (pending.isEmpty) {
                _showSnack('没有找到可操作的任务');
              } else {
                final names =
                    pending.take(5).map((t) => t.title).join('、');
                _showSnack('请指定任务，当前未完成任务：$names');
              }
            }
          } catch (e) {
            if (!mounted) return;
            _showSnack('更新任务状态失败：$e');
          }
          break;

        case 'SAVE_NOTE':
          // 将对话内容保存为笔记
          try {
            final title =
                '对话笔记 ${DateTime.now().month}/${DateTime.now().day}';
            final blocksData = parseMarkdownToBlocks(input);
            final blocks = blocksData
                .map((b) => NoteBlock(
                      id: b['id'] as String,
                      type: _parseBlockType(b['type'] as String),
                      content: (b['content'] as String?) ?? '',
                      checked: (b['checked'] as bool?) ?? false,
                    ))
                .toList();
            await widget.controller.addStudyNote(
              title: title,
              content: input,
              blocks: blocks,
            );
            if (mounted) {
              _showSnack('笔记已保存');
            }
          } catch (e) {
            if (!mounted) return;
            _showSnack('保存笔记失败：$e');
          }
          break;

        case 'SWITCH_CALENDAR':
          _navigateToTab('calendar');
          break;
        case 'SWITCH_TASKS':
          _navigateToTab('create');
          break;
        case 'SWITCH_LOGS':
          _navigateToTab('scenarios');
          break;
        case 'SWITCH_ARCHIVE':
          _navigateToTab('profile');
          break;
        case 'BACK_HOME':
          _navigateToTab('assistant');
          break;
      }
    }
  }

  /// 模糊匹配任务标题 — 优先完全匹配，再部分匹配
  StudyTaskItem? _findBestTask(List<StudyTaskItem> tasks, String query) {
    if (tasks.isEmpty) return null;
    final trimmed = query.trim().toLowerCase();
    // 精确匹配
    final exact = tasks.cast<StudyTaskItem?>().firstWhere(
          (t) => t!.title.toLowerCase() == trimmed,
          orElse: () => null);
    if (exact != null) return exact;
    // 包含匹配：query 包含在标题中
    for (final t in tasks) {
      if (t.title.toLowerCase().contains(trimmed) && trimmed.length > 1) {
        return t;
      }
    }
    // 包含匹配：标题部分包含在 query 中
    for (final t in tasks) {
      if (trimmed.contains(t.title.toLowerCase()) && t.title.length > 1) {
        return t;
      }
    }
    return null;
  }

  /// 通过 navigatorKey 切换底部 Tab
  void _navigateToTab(String tabName) {
    final navigator = widget.controller.navigatorKey?.currentState;
    if (navigator == null) {
      _showSnack('无法切换页面');
      return;
    }
    // pop 所有 push 的页面，回到 AppShell
    navigator.popUntil((route) => route.isFirst);
    // 通过 controller 的 tab 通知 shell 切换
    widget.controller.setCurrentPrimaryTab(tabName);
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    widget.controller.notifyListeners();
    _showSnack('已切换到${_tabLabel(tabName)}');
  }

  String _tabLabel(String name) => switch (name) {
    'assistant' => '首页',
    'scenarios' => '记录',
    'calendar' => '日历',
    'create' => '任务',
    'profile' => '归档',
    _ => name,
  };

  void _showSnack(String msg) {
    if (!mounted) return;
    StudyToast.show(context, msg);
  }

  Future<void> _generateNoteFromStarredCards() async {
    final starred =
        widget.controller.flashCards.where((c) => c.isStarred).toList();
    if (starred.isEmpty) {
      StudyToast.show(context, '先收藏几张闪卡，再整理成笔记');
      return;
    }
    final flashcardContext = starred
        .take(12)
        .map((card) =>
            '【${card.courseName.isEmpty ? '未归类' : card.courseName}】${card.question} / ${card.answer}')
        .toList(growable: false);
    setState(() {});
    _enterSending();
    try {
      final note = await _aiService.generateAssistantReply(
        input: '请根据以下收藏闪卡整理为一篇可直接保存的学习笔记：',
        context: flashcardContext,
        purpose: 'note',
        thinkingEnabled: _thinkingEnabled,
      );
      // Markdown → Notion blocks 转换
      final blocks = markdownToNoteBlocks(note);
      await widget.controller.addStudyNote(
        title: '学习笔记 ${DateTime.now().month}/${DateTime.now().day}',
        content: note,
        blocks: blocks,
      );
      if (mounted) {
        StudyToast.show(context, '学习笔记已保存');
      }
    } catch (error) {
      if (mounted) {
        await StudyToast.dialog(
          context,
          title: '生成笔记失败',
          message: '$error',
        );
      }
    } finally {
      _exitSending();
    }
  }

  // ─── 语音 ───

  Future<void> _toggleSpeech() async {
    if (_voiceCallActive) {
      StudyToast.show(context, '连续语音中，可点击电话按钮结束');
      return;
    }
    if (_isListening && identical(_speechTarget, _inputController)) {
      await _finishCloudSpeechInput();
      return;
    }
    await _startCloudSpeechInput(
      startTip: '正在录音，再次点击麦克风结束并识别',
    );
  }

  // ─── 语音半双工连续对话 ───

  Future<void> _startVoiceCall() async {
    if (_voiceCallActive) return;
    if (!widget.controller.isLoggedIn) {
      StudyToast.show(context, '请先登录后使用蓝心语音识别，可手动输入');
      return;
    }
    try {
      setState(() => _voiceCallActive = true);
      if (mounted) {
        StudyToast.show(context, '语音连续对话已开启，每轮录音后自动发送');
      }
      final cfg = widget.controller.aiConfig;
      await _tts.speak(
        '蓝心语音连续对话已开启，请说话吧。',
        language: cfg.voiceLanguage,
        rate: cfg.voiceRate,
      );
      if (!_voiceCallActive || !mounted) return;
      await _listenTurnAndSend();
    } catch (error) {
      await _endVoiceCall();
      _showSnack('语音连续对话启动失败：$error');
    }
  }

  Future<void> _endVoiceCall() async {
    if (!_voiceCallActive) return;
    setState(() => _voiceCallActive = false);
    try {
      if (_isListening) {
        await _audioRecorder.stop();
      }
    } catch (_) {}
    try {
      await _tts.stop();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isListening = false;
        _speechTarget = null;
        _voiceRecordingPath = null;
      });
    }
  }

  /// 一轮：听用户说 → 自动发送 → 助手回复 → TTS 朗读 → 再次进入听状态
  Future<void> _listenTurnAndSend() async {
    if (!_voiceCallActive || !mounted) return;
    if (_isSending) return;
    try {
      final started = await _startCloudSpeechInput(
        startTip: '请开始说话，本轮录音稍后自动发送',
        showStartTip: false,
      );
      if (!started) {
        await _endVoiceCall();
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 7));
      if (!mounted || !_voiceCallActive) return;
      final finalText = await _stopAndTranscribeCloudSpeech(longForm: false);
      if (!mounted || !_voiceCallActive) return;
      final trimmed = finalText.trim();
      if (trimmed.isEmpty) {
        StudyToast.show(context, '没有识别到语音内容，继续下一轮');
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (_voiceCallActive) unawaited(_listenTurnAndSend());
        return;
      }
      _inputController.text = trimmed;
      _inputController.selection =
          TextSelection.collapsed(offset: _inputController.text.length);
      await _sendMessage();
    } catch (error) {
      await _endVoiceCall();
      _showSnack('语音识别失败：$error');
      return;
    }
    if (!mounted || !_voiceCallActive) return;
    // 找到最新的 assistant 回复朗读出来
    final lastReply = _entries.lastWhere(
      (e) => e.role == _ChatRole.assistant,
      orElse: () => _ChatEntry(
        id: _newEntryId('assistant'),
        role: _ChatRole.assistant,
        text: '',
      ),
    );
    final visible = _stripActions(lastReply.text).trim();
    if (visible.isNotEmpty) {
      final cfg = widget.controller.aiConfig;
      try {
        await _tts.speak(
          _stripMarkdownForSpeech(visible),
          language: cfg.voiceLanguage,
          rate: cfg.voiceRate,
        );
      } catch (error) {
        if (!mounted) return;
        _showSnack('语音朗读失败：$error');
      } finally {
      }
    }
    if (!_voiceCallActive || !mounted) return;
    // 朗读完再进入下一轮
    unawaited(_listenTurnAndSend());
  }

  Future<bool> _startCloudSpeechInput({
    required String startTip,
    bool showStartTip = true,
  }) async {
    if (!widget.controller.isLoggedIn) {
      StudyToast.show(context, '请先登录后使用蓝心语音识别，可手动输入');
      return false;
    }
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        StudyToast.show(context, '未获得麦克风权限，可手动输入');
        return false;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/studytrace_chat_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      if (!mounted) {
        await _audioRecorder.stop();
        return false;
      }
      setState(() {
        _isListening = true;
        _speechTarget = _inputController;
        _voiceRecordingPath = path;
      });
      if (showStartTip) StudyToast.show(context, startTip);
      return true;
    } catch (error) {
      if (mounted) {
        setState(() {
          _isListening = false;
          _speechTarget = null;
          _voiceRecordingPath = null;
        });
        StudyToast.show(context, '语音录制不可用，可手动输入：$error');
      }
      return false;
    }
  }

  Future<void> _finishCloudSpeechInput() async {
    try {
      final text = await _stopAndTranscribeCloudSpeech(longForm: false);
      if (!mounted) return;
      final trimmed = text.trim();
      if (trimmed.isEmpty) {
        StudyToast.show(context, '没有识别到语音内容，可手动输入');
        return;
      }
      _inputController.text = trimmed;
      _inputController.selection =
          TextSelection.collapsed(offset: _inputController.text.length);
      StudyToast.show(context, '语音已识别，可继续编辑或发送');
    } catch (error) {
      if (!mounted) return;
      StudyToast.show(context, '蓝心语音识别失败，可手动输入：$error');
    }
  }

  Future<String> _stopAndTranscribeCloudSpeech({required bool longForm}) async {
    final fallbackPath = _voiceRecordingPath;
    String? recordedPath;
    try {
      recordedPath = await _audioRecorder.stop();
    } finally {
      if (mounted) {
        setState(() {
          _isListening = false;
          _speechTarget = null;
          _voiceRecordingPath = null;
        });
      }
    }
    final path = recordedPath ?? fallbackPath;
    if (path == null || path.isEmpty) return '';
    if (mounted) {
      StudyToast.show(context, '正在调用蓝心语音识别...');
    }
    return widget.controller.cloudSpeechService.transcribeBytes(
      await XFile(path).readAsBytes(),
      mimeType: 'audio/m4a',
      longForm: longForm,
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
      );
    });
  }
}

// ─── 聊天气泡组件 ───

class _ChatBubble extends StatelessWidget {
  final _ChatEntry entry;
  final bool isDarkMode;
  final Color accent;
  final bool isStreaming;
  final bool isThinking;
  final double maxWidth;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;

  const _ChatBubble({
    required this.entry,
    required this.isDarkMode,
    required this.accent,
    this.isStreaming = false,
    this.isThinking = false,
    required this.maxWidth,
    this.selectionMode = false,
    this.selected = false,
    this.onLongPress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = entry.role == _ChatRole.user;
    if (entry.role == _ChatRole.confirmCard) {
      return _buildConfirmCards();
    }
    final bubbleColor = isUser ? StudyUi.secondary : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onLongPress: onLongPress,
        onTap: onTap,
        child: Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isUser ? 18 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 18),
                  ),
                  border: selected
                      ? Border.all(color: accent, width: 2)
                      : selectionMode
                          ? Border.all(
                              color: accent.withValues(alpha: 0.25),
                            )
                          : isUser
                              ? null
                              : Border.all(
                                  color: isDarkMode
                                      ? Colors.transparent
                                      : const Color(0xFFE6EAF2),
                                ),
                ),
                child: isStreaming && entry.text.isEmpty
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isThinking)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                '思考中...',
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white38
                                      : Colors.black38,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          _typingDots(accent),
                        ],
                      )
                    : _buildMessageContent(isUser),
              ),
              if (selected)
                Positioned(
                  top: -6,
                  right: isUser ? -6 : null,
                  left: isUser ? null : -6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageContent(bool isUser) {
    final videos = entry.attachments
        .where((item) => item.type == AiChatAttachmentType.video);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        MarkdownBody(
          data: _stripVideoTags(entry.text),
          styleSheet: _chatMarkdownStyle(isUser),
          sizedImageBuilder: (config) => buildStudyMarkdownImage(
            config.uri,
            config.title,
            config.alt,
            isDarkMode: false,
          ),
        ),
        for (final video in videos) _VideoAttachmentCard(video: video),
      ],
    );
  }

  MarkdownStyleSheet _chatMarkdownStyle(bool isUser) {
    final textColor = isUser ? Colors.white : const Color(0xFF111827);
    final mutedColor = isUser
        ? Colors.white.withValues(alpha: 0.82)
        : const Color(0xFF374151);
    return buildStudyMarkdownStyleSheet(isDarkMode: false, bodyHeight: 1.55)
        .copyWith(
      p: TextStyle(color: textColor, fontSize: 14, height: 1.55),
      strong: TextStyle(color: textColor, fontWeight: FontWeight.w800),
      em: TextStyle(color: mutedColor, fontStyle: FontStyle.italic),
      listBullet: TextStyle(color: textColor),
      h1: TextStyle(
        color: textColor,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        height: 1.35,
      ),
      h2: TextStyle(
        color: textColor,
        fontSize: 17,
        fontWeight: FontWeight.w800,
        height: 1.4,
      ),
      h3: TextStyle(
        color: textColor,
        fontSize: 15,
        fontWeight: FontWeight.w800,
        height: 1.45,
      ),
      blockquote: TextStyle(color: mutedColor, fontSize: 14, height: 1.55),
      code: appCodeTextStyle(
        color: isUser ? Colors.white : StudyUi.secondary,
        backgroundColor: isUser
            ? Colors.white.withValues(alpha: 0.14)
            : const Color(0xFFF0F2F5),
        fontSize: 13,
        height: 1.45,
      ),
    );
  }

  String _stripVideoTags(String text) {
    return text
        .replaceAll(RegExp(r'<video[^>]*></video>', caseSensitive: false), '')
        .trim();
  }

  Widget _typingDots(Color accent) {
    return SizedBox(
      width: 40, height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Dot(delay: 0, color: accent),
          _Dot(delay: 300, color: accent),
          _Dot(delay: 600, color: accent),
        ],
      ),
    );
  }

  Widget _buildConfirmCards() {
    final actions = entry.confirmActions;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDarkMode
                ? const Color(0xFF2A3040)
                : const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDarkMode
                  ? const Color(0xFFF8AA5B).withValues(alpha: 0.3)
                  : const Color(0xFFF8AA5B).withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Icon(Icons.warning_amber_rounded,
                    size: 18, color: const Color(0xFFF8AA5B)),
                const SizedBox(width: 6),
                Text('建议执行以下操作',
                    style: TextStyle(
                      color: const Color(0xFFF8AA5B),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    )),
              ]),
              const SizedBox(height: 10),
              ...actions.map((action) => _ConfirmActionCard(
                    key: ValueKey(action.actionId ??
                        '${action.type.name}_${action.targetId}_${action.targetTitle}_${action.title}'),
                    action: action,
                    isDarkMode: isDarkMode,
                    accent: accent,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmActionCard extends StatefulWidget {
  const _ConfirmActionCard({
    super.key,
    required this.action,
    required this.isDarkMode,
    required this.accent,
  });

  final AiAppAction action;
  final bool isDarkMode;
  final Color accent;

  @override
  State<_ConfirmActionCard> createState() => _ConfirmActionCardState();
}

class _ConfirmActionCardState extends State<_ConfirmActionCard> {
  bool _executed = false;
  bool _cancelled = false;

  String get _description {
    final type = widget.action.type;
    return switch (type) {
      _ when type.name.startsWith('open') => '打开 $_targetLabel',
      _ when type.name == 'addTask' => '创建任务：${widget.action.sourceText ?? ""}',
      _ when type.name == 'createLog' => '记录学习：${widget.action.sourceText ?? ""}',
      _ when type.name == 'markTaskStatus' =>
        '标记任务「${widget.action.targetTitle ?? widget.action.targetId ?? ""}」为 ${widget.action.status ?? ""}',
      _ when type.name == 'saveNote' => '保存笔记：${widget.action.title ?? ""}',
      _ => '执行 ${type.name}',
    };
  }

  String get _targetLabel {
    return widget.action.targetTitle ??
        widget.action.targetId ??
        widget.action.title ??
        '';
  }

  Future<void> _execute() async {
    final pageState = context.findAncestorStateOfType<_AiChatPageState>();
    if (pageState != null) {
      await pageState._executeDangerousAction(widget.action);
    }
    if (mounted) setState(() => _executed = true);
  }

  void _cancel() {
    setState(() => _cancelled = true);
    final pageState = context.findAncestorStateOfType<_AiChatPageState>();
    if (pageState != null) {
      pageState._cancelDangerousAction(widget.action);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_executed) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          const Icon(Icons.check_circle, size: 16, color: Color(0xFF4BC4A1)),
          const SizedBox(width: 6),
          Text('已执行',
              style: TextStyle(
                  color: const Color(0xFF4BC4A1),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
      );
    }
    if (_cancelled) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          const Icon(Icons.cancel, size: 16, color: Color(0xFFEF6850)),
          const SizedBox(width: 6),
          Text('已取消',
              style: TextStyle(
                  color: const Color(0xFFEF6850),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: widget.isDarkMode
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Expanded(
            child: Text(
              _description,
              style: TextStyle(
                color: widget.isDarkMode ? Colors.white : AppColors.ink,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _cancel,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFB0B8CC),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('取消', style: TextStyle(fontSize: 12)),
          ),
          ElevatedButton(
            onPressed: _execute,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              elevation: 0,
            ),
            child: const Text('执行', style: TextStyle(fontSize: 12)),
          ),
        ]),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  final Color color;
  const _Dot({required this.delay, required this.color});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _VideoAttachmentCard extends StatelessWidget {
  const _VideoAttachmentCard({required this.video});

  final AiChatAttachment video;

  @override
  Widget build(BuildContext context) {
    final url = video.url ?? '';
    if (url.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Clipboard.setData(ClipboardData(text: url));
          StudyToast.show(context, '视频链接已复制');
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.play_circle_fill_rounded, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title ?? '生成视频',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.copy_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

NoteBlockType _parseBlockType(String type) {
  return switch (type) {
    'heading' => NoteBlockType.heading,
    'bullet' => NoteBlockType.bullet,
    'todo' => NoteBlockType.todo,
    'code' => NoteBlockType.code,
    'divider' => NoteBlockType.divider,
    'markdown' => NoteBlockType.markdown,
    'image' => NoteBlockType.image,
    _ => NoteBlockType.text,
  };
}

List<NoteBlock> markdownToNoteBlocks(String markdown) {
  return parseMarkdownToBlocks(markdown)
      .map((b) => NoteBlock(
            id: b['id'] as String,
            type: _parseBlockType(b['type'] as String),
            content: (b['content'] as String?) ?? '',
            checked: (b['checked'] as bool?) ?? false,
          ))
      .toList();
}

class _ChatEntry {
  const _ChatEntry({
    required this.id,
    required this.role,
    required this.text,
    this.attachments = const [],
    this.confirmActions = const [],
  });
  final String id;
  final _ChatRole role;
  final String text;
  final List<AiChatAttachment> attachments;
  final List<AiAppAction> confirmActions; // 待确认的危险动作

  _ChatEntry copyWith({
    String? text,
    List<AiChatAttachment>? attachments,
    List<AiAppAction>? confirmActions,
  }) {
    return _ChatEntry(
      id: id,
      role: role,
      text: text ?? this.text,
      attachments: attachments ?? this.attachments,
      confirmActions: confirmActions ?? this.confirmActions,
    );
  }
}

/// 将 Markdown 文本解析为 NoteBlock 列表
List<Map<String, dynamic>> parseMarkdownToBlocks(String md) {
  final blocks = <Map<String, dynamic>>[];
  final lines = md.split('\n');
  var inCode = false;
  var codeBuf = '';
  var idCounter = DateTime.now().microsecondsSinceEpoch;

  String bid() => '${idCounter++}';

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final trimmed = line.trim();

    // 代码块起止
    if (trimmed.startsWith('```')) {
      if (inCode) {
        if (codeBuf.trim().isNotEmpty) {
          blocks.add({
            'id': bid(),
            'type': 'code',
            'content': codeBuf.trim(),
          });
        }
        codeBuf = '';
        inCode = false;
      } else {
        inCode = true;
      }
      continue;
    }
    if (inCode) {
      codeBuf += (codeBuf.isEmpty ? '' : '\n') + line;
      continue;
    }

    if (trimmed.isEmpty) continue;

    final imageMatch = RegExp(r'^!\[[^\]]*\]\(([^)]+)\)$').firstMatch(trimmed);
    if (imageMatch != null) {
      blocks.add({
        'id': bid(),
        'type': 'image',
        'content': imageMatch.group(1)!.trim(),
      });
      continue;
    }

    // 标题
    if (trimmed.startsWith('### ')) {
      blocks.add({
        'id': bid(),
        'type': 'heading',
        'content': trimmed.substring(4).trim(),
      });
      continue;
    }
    if (trimmed.startsWith('## ')) {
      blocks.add({
        'id': bid(),
        'type': 'heading',
        'content': trimmed.substring(3).trim(),
      });
      continue;
    }
    if (trimmed.startsWith('# ')) {
      blocks.add({
        'id': bid(),
        'type': 'heading',
        'content': trimmed.substring(2).trim(),
      });
      continue;
    }

    // 分割线
    if (trimmed == '---' || trimmed == '***' || trimmed == '___') {
      blocks.add({'id': bid(), 'type': 'divider'});
      continue;
    }

    // 待办
    if (trimmed.startsWith('- [ ] ') || trimmed.startsWith('- [x] ') ||
        trimmed.startsWith('* [ ] ') || trimmed.startsWith('* [x] ')) {
      blocks.add({
        'id': bid(),
        'type': 'todo',
        'content': trimmed.substring(6).trim(),
        'checked': trimmed[3] == 'x' || trimmed[3] == 'X',
      });
      continue;
    }

    // 列表
    if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
      blocks.add({
        'id': bid(),
        'type': 'bullet',
        'content': trimmed.substring(2).trim(),
      });
      continue;
    }
    if (RegExp(r'^\d+\.\s').hasMatch(trimmed)) {
      blocks.add({
        'id': bid(),
        'type': 'bullet',
        'content': trimmed.replaceFirst(RegExp(r'^\d+\.\s'), '').trim(),
      });
      continue;
    }

    // 加粗标题行
    if (trimmed.startsWith('**') && trimmed.endsWith('**') && trimmed.length > 4) {
      blocks.add({
        'id': bid(),
        'type': 'heading',
        'content': trimmed.substring(2, trimmed.length - 2).trim(),
      });
      continue;
    }

    // 普通文本
    blocks.add({
      'id': bid(),
      'type': 'text',
      'content': trimmed,
    });
  }

  return blocks;
}
