import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../controllers/app_data_controller.dart';
import '../../models/ai_chat_message.dart';
import '../../models/note_block.dart';
import '../../models/study_sub_task_item.dart';
import '../../services/ai_study_service.dart';
import '../../services/local_storage_service.dart';
import '../../theme/app_theme.dart';
import 'flash_card_page.dart';
import 'timer_page.dart';

enum _ChatRole { user, assistant }

class AiChatPage extends StatefulWidget {
  const AiChatPage({
    super.key,
    required this.isDarkMode,
    required this.controller,
  });

  final bool isDarkMode;
  final AppDataController controller;

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final _aiService = AiStudyService();
  final _imagePicker = ImagePicker();
  final _speech = stt.SpeechToText();
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _storage = LocalStorageService();

  final List<_ChatEntry> _entries = [];
  bool _isSending = false;
  bool _isListening = false;
  StreamSubscription<String>? _streamSub;
  TextEditingController? _speechTarget;
  String? _pendingImageBase64;
  late String _sessionId;
  String _sessionTitle = '新对话';
  bool _thinkingEnabled = false;

  @override
  void initState() {
    super.initState();
    _sessionId = 'chat_${DateTime.now().millisecondsSinceEpoch}';
    _loadLatestSession();
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
        if (s.title.isEmpty || s.title == 'AI 对话') {
          needSave = true;
          final firstUser = s.messages.where((m) => m.role == ChatMessageRole.user).firstOrNull;
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
        _storage.setString('chat_sessions', jsonEncode(fixed.map((s) => s.toJson()).toList()));
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
          role: m.role == ChatMessageRole.user ? _ChatRole.user : _ChatRole.assistant,
          text: m.content,
        ));
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('加载最近会话失败: $e');
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _streamSub?.cancel();
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
    final titleColor = widget.isDarkMode ? Colors.white : Colors.black;
    final bodyColor =
        widget.isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;
    final accent = widget.controller.primaryColor;

    return Scaffold(
      backgroundColor:
          widget.isDarkMode ? const Color(0xFF141923) : const Color(0xFFF5F7FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: titleColor,
        title: Text(
          _sessionTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: _thinkingEnabled ? '关闭深度思考' : '开启深度思考',
            icon: Icon(_thinkingEnabled
                ? Icons.psychology_rounded
                : Icons.psychology_outlined),
            color: _thinkingEnabled ? accent : null,
            onPressed: _isSending
                ? null
                : () => setState(() => _thinkingEnabled = !_thinkingEnabled),
          ),
          IconButton(
            tooltip: '历史对话',
            icon: const Icon(Icons.history_rounded),
            onPressed: _showHistorySheet,
          ),
          IconButton(
            tooltip: '新建对话',
            icon: const Icon(Icons.add_comment_rounded),
            onPressed: _newSession,
          ),
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
                        );
                      },
                    ),
            ),
            // 输入栏
            _buildInputBar(accent),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar(Color titleColor, Color bodyColor, Color accent) {
    final hasBlueHeart = widget.controller.hasBlueHeartAppKey;
    final hasDeepSeek = widget.controller.hasDeepSeekApiKey;
    final provider = hasBlueHeart
        ? '蓝心 · ${widget.controller.aiConfig.blueHeartModel}'
        : hasDeepSeek
            ? 'DeepSeek · ${widget.controller.aiConfig.model}'
            : '未配置 AI';
    final color = hasBlueHeart
        ? const Color(0xFF4470E8)
        : hasDeepSeek
            ? const Color(0xFF4BC4A1)
            : const Color(0xFFF77D8E);

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
          child: Icon(Icons.auto_awesome_rounded,
              color: accent, size: 30),
        ),
        const SizedBox(height: 16),
        Text('开始和 AI 对话',
            style: TextStyle(
                color: widget.isDarkMode ? Colors.white : AppColors.ink,
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

  // ─── 会话管理 ───

  Future<void> _showHistorySheet() async {
    try {
      final raw = await _storage.getString('chat_sessions');
      if (raw == null || raw.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('暂无历史对话')),
          );
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
        builder: (ctx) => Container(
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
              Text('历史对话', style: TextStyle(
                  color: widget.isDarkMode ? Colors.white : AppColors.ink,
                  fontSize: 18, fontWeight: FontWeight.w800)),
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
                        onPressed: () => _deleteSession(s.id, ctx),
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
      );
    } catch (_) {}
  }

  void _newSession() {
    _sessionId = 'chat_${DateTime.now().millisecondsSinceEpoch}';
    _sessionTitle = '新对话';
    _entries.clear();
    if (mounted) setState(() {});
  }

  Future<void> _loadSession(String id) async {
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
      _entries.clear();
      for (final m in target.messages) {
        _entries.add(_ChatEntry(
          role: m.role == ChatMessageRole.user
              ? _ChatRole.user
              : _ChatRole.assistant,
          text: m.content,
        ));
      }
    });
    _scrollToBottom();
  }

  Future<void> _deleteSession(String id, BuildContext ctx) async {
    try {
      final raw = await _storage.getString('chat_sessions');
      if (raw == null) return;
      var sessions = (jsonDecode(raw) as List<dynamic>)
          .map((j) => AiChatSession.fromJson(j as Map<String, dynamic>))
          .toList();
      sessions.removeWhere((s) => s.id == id);
      await _storage.setString(
        'chat_sessions',
        jsonEncode(sessions.map((s) => s.toJson()).toList()),
      );
      if (id == _sessionId && sessions.isNotEmpty) {
        sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        _loadSession(sessions.first.id);
      } else if (id == _sessionId) {
        _newSession();
      }
      if (ctx.mounted) Navigator.of(ctx).pop();
      setState(() {});
    } catch (_) {}
  }

  String _fmtSessionDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${d.month}/${d.day}';
  }

  // ─── 核心发送逻辑（流式） ───

  /// 内置命令映射，直接执行无需 AI
  static const _commands = <String, String>{
    '打开倒计时': 'OPEN_TIMER',
    '计时': 'OPEN_TIMER',
    '专注': 'OPEN_TIMER',
    '开始计时': 'OPEN_TIMER',
    '番茄钟': 'OPEN_TIMER',
    '打开闪卡': 'OPEN_FLASHCARD',
    '闪卡': 'OPEN_FLASHCARD',
    '知识闪卡': 'OPEN_FLASHCARD',
    '生成笔记': 'SUMMARY_NOTE',
    '整理笔记': 'SUMMARY_NOTE',
    '生成学习笔记': 'SUMMARY_NOTE',
    '添加任务': 'ADD_TASK',
    '创建任务': 'ADD_TASK',
    '帮我总结本周': 'SUMMARY_NOTE',
    '总结本周学习': 'SUMMARY_NOTE',
  };

  Future<void> _sendMessage() async {
    final input = _inputController.text.trim();
    if (input.isEmpty || _isSending) return;

    // 内置命令拦截：直接执行，不走 AI
    final cmd = _commands[input];
    if (cmd != null) {
      _inputController.clear();
      await _runActions([cmd], input);
      return;
    }

    final imageBase64 = _pendingImageBase64;
    final messages = _buildMessages();

    setState(() {
      _isSending = true;
      if (imageBase64 != null) {
        _entries.add(_ChatEntry(
          role: _ChatRole.user,
          text: input.isNotEmpty ? '[图片] $input' : '[图片]',
        ));
      } else {
        _entries.add(_ChatEntry(role: _ChatRole.user, text: input));
      }
      _entries.add(_ChatEntry(role: _ChatRole.assistant, text: ''));
      _inputController.clear();
      _pendingImageBase64 = null;
    });

    await _saveChatMessage(role: ChatMessageRole.user, content: input);

    final buffer = StringBuffer();
    final completer = Completer<void>();
    StreamSubscription<String>? sub;
    try {
      final stream = _aiService.generateAssistantReplyStream(
        input: input,
        messages: messages,
        imageBase64: imageBase64,
        thinkingEnabled: _thinkingEnabled,
      );
      sub = stream.listen(
        (token) {
          buffer.write(token);
          if (!mounted) return;
          setState(() {
            final last = _entries.removeLast();
            _entries.add(_ChatEntry(role: last.role, text: buffer.toString()));
          });
          _scrollToBottom();
        },
        onDone: () => completer.complete(),
        onError: (e) => completer.completeError(e),
        cancelOnError: true,
      );
      _streamSub = sub;
      await completer.future;
    } catch (error) {
      final errorMsg = 'AI 回复失败：$error';
      if (!mounted) return;
      setState(() {
        _entries.removeLast();
        _entries.add(_ChatEntry(role: _ChatRole.assistant, text: errorMsg));
      });
      await _saveChatMessage(role: ChatMessageRole.assistant, content: errorMsg);
    } finally {
      _streamSub = null;
      final finalText = buffer.toString();
      if (finalText.isNotEmpty) {
        final actions = _extractActions(finalText);
        final cleaned = _stripActions(finalText);
        if (cleaned != finalText) {
          if (mounted) {
            setState(() {
              _entries.removeLast();
              _entries.add(_ChatEntry(role: _ChatRole.assistant, text: cleaned));
            });
          }
        }
        await _saveChatMessage(
            role: ChatMessageRole.assistant, content: cleaned);
        await _runActions(actions, input);
      } else if (mounted) {
        setState(() {
          _entries.removeLast();
          _entries.add(const _ChatEntry(
              role: _ChatRole.assistant, text: 'AI 暂未返回内容，请重试'));
        });
      }
      if (mounted) setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  void _stopStreaming() {
    _streamSub?.cancel();
    _streamSub = null;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('读取图片失败：$e')),
      );
    }
  }

  // ─── 辅助方法 ───

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

  Future<void> _saveChatMessage({
    required ChatMessageRole role,
    required String content,
  }) async {
    try {
      final message = AiChatMessage(
        id: '${_sessionId}_${DateTime.now().millisecondsSinceEpoch}',
        role: role,
        content: content,
        timestamp: DateTime.now(),
      );
      final chatHistoryJson =
          await _storage.getString('chat_sessions') ?? '[]';
      final sessions = (jsonDecode(chatHistoryJson) as List<dynamic>)
          .map((j) => AiChatSession.fromJson(j as Map<String, dynamic>))
          .toList();
      var session = sessions.firstWhere((s) => s.id == _sessionId, orElse: () {
        final ns = AiChatSession(
          id: _sessionId,
          title: '新对话',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          messages: [],
        );
        sessions.add(ns);
        return ns;
      });
      session.messages.add(message);
      // 自动标题：第一条 user 消息的第一句（或前30字）
      String title = session.title;
      if (title == 'AI 对话' || title == '新对话') {
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
      session = AiChatSession(
        id: session.id,
        title: title,
        createdAt: session.createdAt,
        updatedAt: DateTime.now(),
        messages: session.messages,
      );
      _storage.setString(
        'chat_sessions',
        jsonEncode(sessions.map((s) => s.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('保存聊天消息失败: $e');
    }
  }

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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('无法打开计时器：$e')),
            );
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('无法打开闪卡：$e')),
            );
          }
          break;
        case 'ADD_TASK':
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('任务已添加到列表')),
            );
          }
          break;
        case 'SUMMARY_NOTE':
          await _generateNoteFromStarredCards();
          break;
      }
    }
  }

  Future<void> _generateNoteFromStarredCards() async {
    final starred =
        widget.controller.flashCards.where((c) => c.isStarred).toList();
    if (starred.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先收藏几张闪卡，再让 AI 整理笔记')),
      );
      return;
    }
    final flashcardContext = starred
        .take(12)
        .map((card) =>
            '【${card.courseName.isEmpty ? '未归类' : card.courseName}】${card.question} / ${card.answer}')
        .toList(growable: false);
    setState(() => _isSending = true);
    try {
      final note = await _aiService.generateAssistantReply(
        input: '请根据以下收藏闪卡整理为一篇可直接保存的学习笔记：',
        context: flashcardContext,
        purpose: 'note',
      );
      // Markdown → Notion blocks 转换
      final blocksData = parseMarkdownToBlocks(note);
      final blocks = blocksData
          .map((b) => NoteBlock(
                id: b['id'] as String,
                type: _parseBlockType(b['type'] as String),
                content: (b['content'] as String?) ?? '',
                checked: (b['checked'] as bool?) ?? false,
              ))
          .toList();
      await widget.controller.addStudyNote(
        title: 'AI 学习笔记 ${DateTime.now().month}/${DateTime.now().day}',
        content: note,
        blocks: blocks,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI 学习笔记已保存')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成笔记失败：$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ─── 语音 ───

  Future<void> _toggleSpeech() async {
    if (_isListening && identical(_speechTarget, _inputController)) {
      await _speech.stop();
      if (mounted) {
        setState(() {
          _isListening = false;
          _speechTarget = null;
        });
      }
      return;
    }
    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() {
            _isListening = false;
            _speechTarget = null;
          });
        }
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _isListening = false;
          _speechTarget = null;
        });
      },
    );
    if (!available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('语音识别不可用')),
      );
      return;
    }
    setState(() {
      _isListening = true;
      _speechTarget = _inputController;
    });
    await _speech.listen(
      localeId: 'zh_CN',
      listenFor: const Duration(minutes: 1),
      pauseFor: const Duration(seconds: 4),
      listenOptions: stt.SpeechListenOptions(partialResults: true),
      onResult: (result) {
        _inputController.text = result.recognizedWords;
        _inputController.selection =
            TextSelection.collapsed(offset: _inputController.text.length);
      },
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

  const _ChatBubble({
    required this.entry,
    required this.isDarkMode,
    required this.accent,
    this.isStreaming = false,
    this.isThinking = false,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = entry.role == _ChatRole.user;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isUser
                ? accent
                : isDarkMode
                    ? const Color(0xFF242B37)
                    : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isUser ? 18 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 18),
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
                        child: Text('思考中...',
                            style: TextStyle(
                                color: isDarkMode ? Colors.white38 : Colors.black38,
                                fontSize: 13)),
                      ),
                    _typingDots(accent),
                  ],
                )
              : isUser
                  ? Text(
                      entry.text,
                      style: const TextStyle(
                          color: Colors.white, height: 1.55),
                    )
                  : MarkdownBody(
                      data: entry.text,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                            color: isDarkMode ? Colors.white : AppColors.ink,
                            height: 1.55,
                            fontSize: 14),
                        strong: TextStyle(
                            color: isDarkMode ? Colors.white : AppColors.ink,
                            fontWeight: FontWeight.w800),
                        code: TextStyle(
                            color: const Color(0xFF5A67D8),
                            backgroundColor: isDarkMode
                                ? Colors.black26
                                : const Color(0xFFF0F2F5),
                            fontFamily: 'monospace'),
                        codeblockDecoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.black26
                                : const Color(0xFFF0F2F5),
                            borderRadius: BorderRadius.circular(8)),
                        listBullet:
                            TextStyle(color: isDarkMode ? Colors.white : AppColors.ink),
                      ),
                    ),
        ),
      ),
    );
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

NoteBlockType _parseBlockType(String type) {
  return switch (type) {
    'heading' => NoteBlockType.heading,
    'bullet' => NoteBlockType.bullet,
    'todo' => NoteBlockType.todo,
    'code' => NoteBlockType.code,
    'divider' => NoteBlockType.divider,
    _ => NoteBlockType.text,
  };
}

class _ChatEntry {
  const _ChatEntry({required this.role, required this.text});
  final _ChatRole role;
  final String text;
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
