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

import '../../config/ui_review_config.dart';
import '../../controllers/app_data_controller.dart';
import '../../models/ai_app_action.dart';
import '../../models/ai_chat_message.dart';
import '../../models/note_block.dart';
import '../../models/study_log_item.dart';
import '../../models/study_sub_task_item.dart';
import '../../models/study_task_item.dart';
import '../../services/ai_app_context_builder.dart';
import '../../services/ai_chat_action_guard.dart';
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
    this.onOpenTasks,
    this.onOpenLogs,
    this.onOpenNotes,
    this.onOpenFlashCards,
    this.onStartFlashCardReview,
    this.currentLocation,
  });

  final bool isDarkMode;
  final AppDataController controller;
  final AiActionHandler? onExecuteActions;
  final VoidCallback? onOpenTasks;
  final VoidCallback? onOpenLogs;
  final VoidCallback? onOpenNotes;
  final VoidCallback? onOpenFlashCards;
  final ValueChanged<List<String>>? onStartFlashCardReview;
  final String? currentLocation;

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  static const int _agentMaxToolRounds = 3;
  static final RegExp _legacyActionPattern = RegExp(
    r'[【\[]ACTION:([A-Za-z0-9_.-]+)[】\]]',
    caseSensitive: false,
  );

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
  TextEditingController? _speechTarget;
  String? _voiceRecordingPath;
  // 语音半双工
  final TtsService _tts = TtsService();
  bool _voiceCallActive = false;
  String? _pendingImageBase64;
  late String _sessionId;
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
    _thinkingEnabled = widget.controller.aiConfig.thinkingEnabled ||
        widget.controller.aiConfig.thinkingMode;
    if (UiReviewConfig.enabled) {
      _seedReviewSession();
    } else {
      _loadLatestSession();
    }
  }

  void _seedReviewSession() {
    _entries
      ..clear()
      ..addAll(const [
        _ChatEntry(
          id: 'review_user_1',
          role: _ChatRole.user,
          text: '早上好！我今天想复习微分方程，上次卡在一阶线性方程这块，帮我梳理下思路吧～',
        ),
        _ChatEntry(
          id: 'review_ai_1',
          role: _ChatRole.assistant,
          text: '早上好！我们先从一阶线性方程的标准形式入手，一起把解题思路串起来。你可以把之前的题目拍给我，或者直接说你卡在哪里～',
        ),
        _ChatEntry(
          id: 'review_user_2',
          role: _ChatRole.user,
          text: "好的，这是我昨天做的题，积分因子那里总是算错：\n\ny' + P(x)y = Q(x)\nμ = e^(∫P(x)dx)",
        ),
        _ChatEntry(
          id: 'review_ai_2',
          role: _ChatRole.assistant,
          text:
              "**一阶线性方程解题步骤**\n\n1. 先整理成标准形式 `y' + P(x)y = Q(x)`。\n2. 写出积分因子 `μ = e^(∫P(x)dx)`。\n3. 两边同乘积分因子，把左侧合成 `(μy)'`。\n4. 积分后代回初值，最后检查符号和常数项。",
        ),
      ]);
    _scrollToBottom(settle: true);
  }

  bool _isDefaultSessionTitle(String title) {
    final normalized = title.trim();
    return normalized.isEmpty ||
        normalized == '新对话' ||
        normalized == '学习对话' ||
        normalized == '学习对话';
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
              id: s.id,
              title: newTitle,
              createdAt: s.createdAt,
              updatedAt: s.updatedAt,
              messages: s.messages));
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
      _entries.clear();
      for (final m in latest.messages) {
        _entries.add(_ChatEntry(
          id: m.id,
          role: m.role == ChatMessageRole.user
              ? _ChatRole.user
              : _ChatRole.assistant,
          text: m.content,
          attachments: m.attachments,
          resultShortcuts: _resultShortcutsFromAttachments(m.attachments),
          agentSteps: _agentStepsFromAttachments(m.attachments),
        ));
      }
      if (mounted) {
        setState(() {});
        _scrollToBottom(settle: true);
      }
    } catch (error) {
      debugPrint('加载最近会话失败: $error');
      _showSnack('最近会话暂时没打开，请稍后再试');
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
      body: StudyScreenBackground(
        isDarkMode: widget.isDarkMode,
        accent: accent,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
                child: Row(
                  children: [
                    _ChatToolbarAction(
                      tooltip: '返回',
                      icon: Icons.arrow_back_rounded,
                      accent: accent,
                      isDarkMode: widget.isDarkMode,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '学习对话',
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 36),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 2, 18, 8),
                child: _buildChatTools(accent),
              ),
              Expanded(
                child: _entries.isEmpty
                    ? _emptyBody(bodyColor, accent)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
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
                            userAvatarEmoji:
                                widget.controller.userProfile.avatarEmoji,
                            userAvatarImagePath:
                                widget.controller.userProfile.avatarImagePath,
                            isStreaming: isLastAssistant,
                            isThinking: isLastAssistant,
                            maxWidth: MediaQuery.of(context).size.width * 0.78,
                            selectionMode: _selectionMode,
                            selected: _selectedEntryIds.contains(entry.id),
                            onLongPress: () => _toggleEntrySelection(entry),
                            onTap: _selectionMode
                                ? () => _toggleEntrySelection(entry)
                                : null,
                            onTapResultShortcut: _openResultShortcut,
                            onSaveImage: _saveImageFromUrl,
                            onCopyEntry: (entry) =>
                                unawaited(_copyEntryText(entry)),
                            onEditEntry: _editEntryText,
                          );
                        },
                      ),
              ),
              if (_selectionMode) _buildSelectionBar(accent),
              SafeArea(
                top: false,
                child: _buildInputBar(accent),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildStatusBar(Color titleColor, Color bodyColor, Color accent) {
    final isLoggedIn = widget.controller.isLoggedIn;
    final provider = isLoggedIn ? '学习助手' : '登录后可用';
    final color = isLoggedIn ? StudyUi.success : StudyUi.danger;

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
            Text('图片已附加', style: TextStyle(color: accent, fontSize: 12)),
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
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildChatTools(Color accent) {
    final thinkingAccent = _thinkingEnabled ? StudyUi.secondary : accent;
    return Row(
      children: [
        Expanded(
          child: StudyPopupMenuButton<bool>(
            tooltip: '切换回复模式',
            enabled: !_isSending,
            constraints: const BoxConstraints(minWidth: 150, maxWidth: 190),
            onSelected: (value) {
              if (value == _thinkingEnabled) return;
              unawaited(_setThinkingEnabled(value));
            },
            itemBuilder: (context) => [
              _thinkingModeMenuItem(
                value: false,
                label: '快速',
                icon: Icons.flash_on_rounded,
                selected: !_thinkingEnabled,
                accent: accent,
              ),
              _thinkingModeMenuItem(
                value: true,
                label: '深度',
                icon: Icons.psychology_rounded,
                selected: _thinkingEnabled,
                accent: StudyUi.secondary,
              ),
            ],
            child: _ThinkingModeDropdownChip(
              label: _thinkingEnabled ? '深度' : '快速',
              icon: _thinkingEnabled
                  ? Icons.psychology_rounded
                  : Icons.flash_on_rounded,
              accent: thinkingAccent,
              isDarkMode: widget.isDarkMode,
              enabled: !_isSending,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StudyStatusChip(
            label: '历史',
            color: StudyUi.secondary,
            icon: Icons.history_rounded,
            onTap: _showHistorySheet,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StudyStatusChip(
            label: '新建',
            color: StudyUi.pathMint,
            icon: Icons.add_rounded,
            onTap: _confirmNewSession,
          ),
        ),
      ],
    );
  }

  Future<void> _setThinkingEnabled(bool value) async {
    if (!mounted) return;
    setState(() => _thinkingEnabled = value);
    try {
      await widget.controller.saveAiSettings(
        config: widget.controller.aiConfig.copyWith(
          thinkingMode: value,
          thinkingEnabled: value,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _thinkingEnabled = widget.controller.aiConfig.thinkingEnabled ||
            widget.controller.aiConfig.thinkingMode;
      });
      _showSnack('思考深度暂时没有保存成功，请稍后重试');
    }
  }

  PopupMenuItem<bool> _thinkingModeMenuItem({
    required bool value,
    required String label,
    required IconData icon,
    required bool selected,
    required Color accent,
  }) {
    return PopupMenuItem<bool>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 17, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: StudyUi.title(widget.isDarkMode),
                fontWeight: AppTypography.emphasis,
              ),
            ),
          ),
          if (selected) Icon(Icons.check_rounded, size: 18, color: accent),
        ],
      ),
    );
  }

  Widget _emptyBody(Color bodyColor, Color accent) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      children: [
        StudyCard(
          padding: const EdgeInsets.all(18),
          radius: 26,
          borderColor:
              accent.withValues(alpha: widget.isDarkMode ? 0.22 : 0.16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StudyBrandAvatar(
                    size: 54,
                    accent: accent,
                    isDarkMode: widget.isDarkMode,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '学迹助手',
                          style: TextStyle(
                            color: accent,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '今天想整理什么',
                          style: TextStyle(
                            color: StudyUi.title(widget.isDarkMode),
                            fontSize: 20,
                            fontWeight: AppTypography.hero,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '可以把复盘、难点或一张题目发给我，我会帮你整理成下一步。',
                          style: TextStyle(
                            color: bodyColor,
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _emptyBubblePreview(
                isUser: true,
                accent: StudyUi.secondary,
              ),
              const SizedBox(height: 12),
              _emptyBubblePreview(
                isUser: false,
                accent: accent,
              ),
              const SizedBox(height: 16),
              _buildSmartPromptPanel(accent),
            ],
          ),
        ),
      ],
    );
  }

  Widget _emptyBubblePreview({
    required bool isUser,
    required Color accent,
  }) {
    final bubble = Container(
      width: isUser ? 230 : 270,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      decoration: BoxDecoration(
        color: isUser
            ? StudyUi.secondary
                .withValues(alpha: widget.isDarkMode ? 0.18 : 0.12)
            : Colors.white.withValues(alpha: widget.isDarkMode ? 0.08 : 0.62),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(22),
          topRight: const Radius.circular(22),
          bottomLeft: Radius.circular(isUser ? 22 : 8),
          bottomRight: Radius.circular(isUser ? 8 : 22),
        ),
        border: Border.all(
          color: isUser
              ? StudyUi.secondary.withValues(alpha: 0.18)
              : StudyUi.border(widget.isDarkMode),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _skeletonLine(accent, widthFactor: 0.92),
          const SizedBox(height: 8),
          _skeletonLine(accent, widthFactor: isUser ? 0.64 : 0.78),
          if (!isUser) ...[
            const SizedBox(height: 8),
            _skeletonLine(accent, widthFactor: 0.48),
          ],
        ],
      ),
    );

    return Row(
      mainAxisAlignment:
          isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (!isUser) ...[
          StudyBrandAvatar(
            size: 34,
            accent: accent,
            isDarkMode: widget.isDarkMode,
          ),
          const SizedBox(width: 10),
        ],
        Flexible(child: bubble),
        if (isUser) ...[
          const SizedBox(width: 10),
          StudyUserAvatar(
            avatarImagePath: widget.controller.userProfile.avatarImagePath,
            avatarEmoji: widget.controller.userProfile.avatarEmoji,
            size: 34,
            accent: StudyUi.secondary,
            isDarkMode: widget.isDarkMode,
          ),
        ],
      ],
    );
  }

  Widget _skeletonLine(Color accent, {required double widthFactor}) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 11,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: widget.isDarkMode ? 0.18 : 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  List<_SmartQuickPrompt> _smartQuickPrompts({int limit = 4}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    final openTasks = widget.controller.studyTasks
        .where((task) => task.effectiveStatus != StudyTaskStatus.completed)
        .toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));
    final dueTask = openTasks
        .where((task) => task.deadline.isBefore(tomorrow))
        .cast<StudyTaskItem?>()
        .firstWhere((task) => task != null, orElse: () => null);
    final activeTask = openTasks
        .where((task) => task.effectiveStatus == StudyTaskStatus.inProgress)
        .cast<StudyTaskItem?>()
        .firstWhere((task) => task != null, orElse: () => null);
    final todayLogs = widget.controller.studyLogs
        .where((log) => _sameDay(log.date, today))
        .toList();
    final recentLogs = widget.controller.studyLogs
        .where((log) => !log.date.isBefore(weekAgo))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final problemLogs =
        recentLogs.where((log) => log.problems.trim().isNotEmpty).toList();
    final StudyLogItem? problemLog =
        problemLogs.isEmpty ? null : problemLogs.first;
    final dueCards = widget.controller.flashCards
        .where((card) => card.isDueForReview)
        .toList();
    final recentNotes = widget.controller.studyNotes
        .where((note) => !note.isFolder)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final hasConversation =
        _entries.any((entry) => entry.role == _ChatRole.user);

    final candidates = <_SmartQuickPrompt>[];
    void add(_SmartQuickPrompt prompt) {
      if (candidates.any((item) => item.label == prompt.label)) return;
      candidates.add(prompt);
    }

    final focusTask =
        activeTask ?? dueTask ?? (openTasks.isEmpty ? null : openTasks.first);
    if (focusTask != null) {
      add(_SmartQuickPrompt(
        label: activeTask != null ? '继续任务' : '先做任务',
        icon: Icons.play_circle_rounded,
        color: StudyUi.pathWarm,
        score: activeTask != null ? 108 : 104,
        prompt:
            '帮我把「${_shortQuickText(focusTask.title, 20)}」整理成现在能开始的一步，并给我 25 分钟推进顺序。',
      ));
    }

    if (todayLogs.isEmpty) {
      add(const _SmartQuickPrompt(
        label: '写今日复盘',
        icon: Icons.edit_note_rounded,
        color: StudyUi.secondary,
        score: 96,
        prompt: '帮我写一条今天的学习复盘，请先问我学了什么、卡在哪里、下一步做什么。',
      ));
    } else {
      add(const _SmartQuickPrompt(
        label: '今日小结',
        icon: Icons.summarize_rounded,
        color: StudyUi.secondary,
        score: 92,
        prompt: '根据今天的学习记录，帮我整理一段简短复盘和下一步提醒。',
      ));
    }

    if (problemLog != null) {
      final course = problemLog.courseName.trim();
      add(_SmartQuickPrompt(
        label: '拆难点',
        icon: Icons.psychology_alt_rounded,
        color: StudyUi.pathViolet,
        score: 94,
        prompt: course.isEmpty
            ? '根据最近学习记录里的难点，帮我拆出原因、例题和下一步。'
            : '根据我最近在「${_shortQuickText(course, 14)}」里的难点，帮我拆出原因、例题和下一步。',
      ));
    }

    if (dueCards.isNotEmpty) {
      add(_SmartQuickPrompt(
        label: '复习闪卡',
        icon: Icons.style_rounded,
        color: StudyUi.pathCyan,
        score: 90,
        prompt: '帮我安排今天要先复习的 ${dueCards.length} 张闪卡，并挑出最容易忘的知识点。',
      ));
    } else if (recentLogs.isNotEmpty || problemLog != null) {
      add(const _SmartQuickPrompt(
        label: '做复习卡',
        icon: Icons.library_add_check_rounded,
        color: StudyUi.pathCyan,
        score: 86,
        prompt: '把最近的学习难点整理成 3 张复习闪卡，题目短一点，答案说清楚。',
      ));
    }

    if (hasConversation) {
      add(const _SmartQuickPrompt(
        label: '整理对话',
        icon: Icons.notes_rounded,
        color: StudyUi.pathBlue,
        score: 88,
        prompt: '把刚才这段对话整理成一页学习笔记，保留重点、难点和下一步。',
      ));
      add(const _SmartQuickPrompt(
        label: '画成图解',
        icon: Icons.image_rounded,
        color: StudyUi.pathMint,
        score: 84,
        prompt: '把刚才讨论的内容生成一张适合学习笔记的图解，文字少而准。',
      ));
    }

    if (recentNotes.isNotEmpty) {
      add(_SmartQuickPrompt(
        label: '整理笔记',
        icon: Icons.menu_book_rounded,
        color: StudyUi.pathBlue,
        score: 76,
        prompt:
            '根据最近的笔记「${_shortQuickText(recentNotes.first.title, 18)}」，帮我整理重点、易错点和下一步。',
      ));
    }

    if (openTasks.isEmpty) {
      add(const _SmartQuickPrompt(
        label: '补小任务',
        icon: Icons.add_task_rounded,
        color: StudyUi.pathWarm,
        score: 74,
        prompt: '根据最近学习记录，帮我补一个今天能完成的小任务。',
      ));
    }

    add(const _SmartQuickPrompt(
      label: '安排30分钟',
      icon: Icons.timer_rounded,
      color: StudyUi.pathMint,
      score: 70,
      prompt: '根据今天的任务和记录，帮我安排接下来 30 分钟先做什么。',
    ));
    add(const _SmartQuickPrompt(
      label: '出几道题',
      icon: Icons.quiz_rounded,
      color: StudyUi.pathViolet,
      score: 66,
      prompt: '根据我最近学的内容，出 3 道小练习，并附简短答案。',
    ));

    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates.take(limit).toList(growable: false);
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _shortQuickText(String text, int maxLength) {
    final trimmed = text.trim();
    if (trimmed.length <= maxLength) return trimmed;
    return '${trimmed.substring(0, maxLength)}...';
  }

  Widget _buildSmartPromptPanel(Color accent) {
    final prompts = _smartQuickPrompts(limit: 4);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: widget.isDarkMode ? 0.06 : 0.48),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: StudyUi.border(widget.isDarkMode).withValues(alpha: 0.78),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: accent.withValues(alpha: 0.72),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                '现在可以先做',
                style: TextStyle(
                  color: StudyUi.title(widget.isDarkMode),
                  fontWeight: AppTypography.title,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _quickPromptGrid(prompts),
        ],
      ),
    );
  }

  Widget _buildSmartPromptRail(Color accent) {
    final prompts = _smartQuickPrompts(limit: 4);
    if (prompts.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.tips_and_updates_rounded,
              size: 14,
              color: accent.withValues(alpha: 0.66),
            ),
            const SizedBox(width: 5),
            Text(
              '按今天状态推荐',
              style: TextStyle(
                color: StudyUi.muted(widget.isDarkMode),
                fontSize: 11,
                fontWeight: AppTypography.emphasis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        _quickPromptGrid(prompts),
      ],
    );
  }

  Widget _quickPromptGrid(List<_SmartQuickPrompt> prompts) {
    return Row(
      children: [
        for (var i = 0; i < prompts.length; i++) ...[
          Expanded(child: _quickPrompt(prompts[i], dense: true)),
          if (i != prompts.length - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }

  Widget _quickPrompt(_SmartQuickPrompt prompt, {bool dense = false}) {
    return _ChatActionPill(
      icon: prompt.icon,
      label: prompt.label,
      accent: prompt.color,
      isDarkMode: widget.isDarkMode,
      subtle: true,
      dense: dense,
      expand: dense,
      onTap: _isSending
          ? null
          : () {
              _inputController.text = prompt.prompt;
              _sendMessage();
            },
    );
  }

  Widget _buildInputBar(Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSmartPromptRail(accent),
          const SizedBox(height: 10),
          StudyCard(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _ChatToolbarAction(
                  tooltip: '添加图片',
                  icon: Icons.image_rounded,
                  accent: StudyUi.secondary,
                  size: 38,
                  iconSize: 18,
                  isDarkMode: widget.isDarkMode,
                  onPressed: _pickAndAnalyzeImage,
                ),
                const SizedBox(width: 6),
                _ChatToolbarAction(
                  tooltip: widget.controller.aiConfig.voiceMode
                      ? (_voiceCallActive ? '结束语音' : '语音复盘')
                      : '语音复盘',
                  icon: widget.controller.aiConfig.voiceMode
                      ? (_voiceCallActive
                          ? Icons.call_end_rounded
                          : Icons.mic_rounded)
                      : Icons.mic_rounded,
                  accent: StudyUi.pathCyan,
                  size: 38,
                  iconSize: 18,
                  isDarkMode: widget.isDarkMode,
                  onPressed: widget.controller.aiConfig.voiceMode
                      ? (_voiceCallActive ? _endVoiceCall : _startVoiceCall)
                      : _toggleSpeech,
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
                      color: StudyUi.title(widget.isDarkMode),
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: _pendingImageBase64 != null
                          ? '描述你想了解这张图片的什么内容...'
                          : '今天想整理什么...',
                      hintStyle: TextStyle(
                        color: StudyUi.muted(widget.isDarkMode),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _ChatToolbarAction(
                  tooltip: _isSending ? '停止整理' : '发送',
                  icon: _isSending ? Icons.stop_rounded : Icons.send_rounded,
                  accent: _isSending ? StudyUi.danger : accent,
                  size: 42,
                  iconSize: 19,
                  isDarkMode: widget.isDarkMode,
                  filled: true,
                  onPressed: _isSending ? _stopStreaming : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionBar(Color accent) {
    final count = _selectedEntryIds.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: SafeArea(
        top: false,
        child: StudyCard(
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
          radius: 22,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '已选 $count 条消息',
                      style: TextStyle(
                        color: StudyUi.body(widget.isDarkMode),
                        fontSize: 11,
                        fontWeight: AppTypography.emphasis,
                      ),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: _clearSelection,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 17,
                        color: StudyUi.muted(widget.isDarkMode),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: _ChatActionPill(
                      icon: Icons.ios_share_rounded,
                      label: '保存',
                      accent: accent,
                      isDarkMode: widget.isDarkMode,
                      onTap: count == 0 ? null : _forwardSelected,
                      expand: true,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: _ChatActionPill(
                      icon: Icons.note_add_rounded,
                      label: '笔记',
                      accent: StudyUi.secondary,
                      isDarkMode: widget.isDarkMode,
                      onTap: count == 0 ? null : _selectedToNote,
                      expand: true,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: _ChatActionPill(
                      icon: Icons.summarize_rounded,
                      label: '总结',
                      accent: StudyUi.pathCyan,
                      isDarkMode: widget.isDarkMode,
                      onTap: count == 0 ? null : _summarizeSelectedToNote,
                      expand: true,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: _ChatActionPill(
                      icon: Icons.image_rounded,
                      label: '图片',
                      accent: StudyUi.pathMint,
                      isDarkMode: widget.isDarkMode,
                      onTap: count == 0 ? null : _saveSelectedAsImage,
                      expand: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
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
          builder: (ctx, setSheetState) => _ChatSheetSurface(
            isDarkMode: widget.isDarkMode,
            maxHeightFactor: 0.64,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '历史对话',
                        style: TextStyle(
                          color: StudyUi.title(widget.isDarkMode),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _ChatActionPill(
                      icon: Icons.delete_sweep_outlined,
                      label: '清空',
                      accent: StudyUi.danger,
                      isDarkMode: widget.isDarkMode,
                      onTap: sessions.isEmpty
                          ? null
                          : () async {
                              final confirmed = await showDialog<bool>(
                                context: ctx,
                                builder: (dctx) => Dialog(
                                  backgroundColor: Colors.transparent,
                                  surfaceTintColor: Colors.transparent,
                                  insetPadding: const EdgeInsets.symmetric(
                                    horizontal: 22,
                                    vertical: 24,
                                  ),
                                  child: StudyDialogSurface(
                                    isDarkMode: widget.isDarkMode,
                                    accent: StudyUi.danger,
                                    icon: Icons.delete_sweep_outlined,
                                    title: '清空所有对话？',
                                    actions: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: StudyActionPill(
                                              icon: Icons.close_rounded,
                                              label: '取消',
                                              color: StudyUi.muted(
                                                widget.isDarkMode,
                                              ),
                                              isDarkMode: widget.isDarkMode,
                                              filled: false,
                                              expand: true,
                                              onPressed: () =>
                                                  Navigator.of(dctx).pop(false),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: StudyActionPill(
                                              icon: Icons.delete_rounded,
                                              label: '清空',
                                              color: StudyUi.danger,
                                              isDarkMode: widget.isDarkMode,
                                              expand: true,
                                              onPressed: () =>
                                                  Navigator.of(dctx).pop(true),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    child: Text(
                                      '将删除全部历史会话，此操作不可恢复。',
                                      style: TextStyle(
                                        color: StudyUi.body(widget.isDarkMode),
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                              if (confirmed == true) {
                                await _clearAllSessions();
                                if (ctx.mounted) Navigator.of(ctx).pop();
                              }
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: sessions.length,
                    itemBuilder: (_, i) {
                      final s = sessions[i];
                      final isActive = s.id == _sessionId;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: StudyCard(
                          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                          radius: 18,
                          color: isActive
                              ? StudyUi.chipBackground(
                                  StudyUi.secondary,
                                  widget.isDarkMode,
                                )
                              : null,
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _loadSession(s.id);
                          },
                          child: Row(
                            children: [
                              StudyGlassIconNode(
                                icon: Icons.chat_bubble_outline_rounded,
                                accent: isActive
                                    ? StudyUi.secondary
                                    : StudyUi.primary,
                                size: 34,
                                iconSize: 16,
                                isDarkMode: widget.isDarkMode,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.title,
                                      style: TextStyle(
                                        color: StudyUi.title(widget.isDarkMode),
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${s.messages.length} 条消息 · ${_fmtSessionDate(s.updatedAt)}',
                                      style: TextStyle(
                                        color: StudyUi.muted(widget.isDarkMode),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _ChatToolbarAction(
                                tooltip: '删除',
                                icon: Icons.delete_outline_rounded,
                                accent: StudyUi.danger,
                                size: 34,
                                iconSize: 16,
                                isDarkMode: widget.isDarkMode,
                                onPressed: () async {
                                  final deleted = await _deleteSession(
                                    s.id,
                                    closeSheet: false,
                                  );
                                  if (!ctx.mounted || !deleted) return;
                                  setSheetState(
                                    () => sessions.removeWhere(
                                      (session) => session.id == s.id,
                                    ),
                                  );
                                  if (sessions.isEmpty) {
                                    Navigator.of(ctx).pop();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
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
      _showSnack('历史对话暂时没加载出来，请稍后再试');
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
      text: '你好，我可以帮你把今天的学习材料整理清楚。\n\n'
          '你可以直接说：\n'
          '- 这道题卡在哪一步\n'
          '- 帮我把今天内容整理成闪卡\n'
          '- 先做一个复盘，再决定下一步\n\n'
          '把题目拍给我，或者直接说你最想先解决的点。',
    ));
  }

  Future<void> _confirmNewSession() async {
    if (_entries.isEmpty &&
        _inputController.text.trim().isEmpty &&
        _pendingImageBase64 == null) {
      _newSession();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 22,
          vertical: 24,
        ),
        child: StudyDialogSurface(
          isDarkMode: widget.isDarkMode,
          accent: StudyUi.pathMint,
          icon: Icons.add_comment_rounded,
          title: '新建对话？',
          subtitle: '当前内容会保留在历史记录里，新对话会从一条空白学习问题开始。',
          actions: [
            Row(
              children: [
                Expanded(
                  child: StudyActionPill(
                    icon: Icons.close_rounded,
                    label: '取消',
                    color: StudyUi.muted(widget.isDarkMode),
                    isDarkMode: widget.isDarkMode,
                    filled: false,
                    expand: true,
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StudyActionPill(
                    icon: Icons.add_rounded,
                    label: '新建',
                    color: StudyUi.pathMint,
                    isDarkMode: widget.isDarkMode,
                    expand: true,
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                  ),
                ),
              ],
            ),
          ],
          child: Text(
            '如果只是想查看旧内容，可以点上方的“历史”。',
            style: TextStyle(
              color: StudyUi.body(widget.isDarkMode),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ),
      ),
    );
    if (confirmed == true) _newSession();
  }

  Future<void> _loadSession(String id) async {
    try {
      final raw = await _storage.getString('chat_sessions');
      if (raw == null || raw.isEmpty) return;
      final sessions = (jsonDecode(raw) as List<dynamic>)
          .map((j) => AiChatSession.fromJson(j as Map<String, dynamic>))
          .toList();
      final target = sessions
          .cast<AiChatSession?>()
          .firstWhere((s) => s?.id == id, orElse: () => null);
      if (target == null || !mounted) return;
      setState(() {
        _sessionId = target.id;
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
            resultShortcuts: _resultShortcutsFromAttachments(m.attachments),
            agentSteps: _agentStepsFromAttachments(m.attachments),
          ));
        }
      });
      _scrollToBottom(settle: true);
    } catch (error) {
      _showSnack('历史对话暂时没打开，请稍后再试');
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
      _showSnack('历史对话暂时没有删除成功，请稍后再试');
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
      _showSnack('历史对话暂时没有清空成功，请稍后再试');
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
    _scrollToBottom(settle: true);

    await _saveChatMessage(role: ChatMessageRole.user, content: input);

    try {
      final baseContext = await _buildAppContextWithMemory(input);
      final memorySources = <String>[..._lastMemorySources];
      final toolResults = <AiActionResult>[];
      var nextInput = input;
      var nextContext = baseContext;
      var finalReply = '';
      String? agentFooter;

      for (var round = 0; round < _agentMaxToolRounds; round++) {
        late final AiAssistantTurn turn;
        try {
          turn = await _aiService.generateAssistantTurn(
            input: nextInput,
            appContext: nextContext,
            messages: messages,
            imageBase64: round == 0 ? imageBase64 : null,
            thinkingEnabled: _thinkingEnabled,
          );
        } catch (error) {
          if (round == 0) rethrow;
          agentFooter = '前面的改动已完成，最后说明暂时没整理好，可以稍后继续让我补充。';
          break;
        }
        if (requestId != _requestSerial) return;

        final legacyTurn = _parseLegacyActionTurn(turn.reply);
        final reply = legacyTurn.reply;
        if (reply.isNotEmpty) finalReply = reply;
        if (finalReply.isEmpty) {
          finalReply = '我理解了，正在尝试继续帮你整理。';
        }

        if (mounted) {
          setState(
            () => _replaceAssistantDraft(
              _composeAgentReply(finalReply, toolResults),
              memorySources: memorySources,
              agentSteps: _agentStepViews(toolResults),
            ),
          );
          _scrollToBottom();
        }

        final turnActions = _uniqueAgentActions(
          AiChatActionGuard.withFallbackNoteAction(
            input: input,
            assistantReply: finalReply,
            actions: [
              ...turn.actions,
              ...legacyTurn.actions,
            ],
          ),
        );
        final actions = _groupAgentActions(turnActions);
        final safeActions = _newSafeAgentActions(actions.safe, toolResults);
        if (safeActions.isNotEmpty) {
          final runningActions = safeActions.take(1).toList(growable: false);
          final queuedActions = safeActions.skip(1).toList(growable: false);
          if (mounted) {
            setState(
              () => _replaceAssistantDraft(
                _composeAgentReply(
                  finalReply,
                  toolResults,
                  runningText: _runningToolText(safeActions),
                ),
                memorySources: memorySources,
                agentSteps: _agentStepViews(
                  toolResults,
                  runningActions: runningActions,
                  queuedActions: queuedActions,
                ),
              ),
            );
            _scrollToBottom();
          }

          final results = await _executeSafeAgentActions(
            safeActions,
            input: input,
            assistantReply: finalReply,
          );
          if (requestId != _requestSerial) return;
          toolResults.addAll(results);
          _mergeAgentMemorySources(memorySources, results);

          final shouldContinue = round < _agentMaxToolRounds - 1 &&
              actions.dangerous.isEmpty &&
              !_shouldStopAfterSafeActions(results);
          final recoveryFooter = _agentRecoveryFooter(results);
          if (mounted) {
            setState(
              () => _replaceAssistantDraft(
                _composeAgentReply(
                  finalReply,
                  toolResults,
                  runningText: shouldContinue ? '正在接着整理学习内容' : null,
                ),
                memorySources: memorySources,
                agentSteps: _agentStepViews(
                  toolResults,
                  runningText: shouldContinue ? '正在接着整理学习内容' : null,
                  footer: recoveryFooter,
                ),
              ),
            );
            _scrollToBottom();
          }

          if (shouldContinue) {
            nextInput = _agentContinuationInput(input);
            nextContext = _buildAgentContinuationContext(
              baseContext,
              toolResults,
              round: round + 1,
            );
            continue;
          }

          if (round == _agentMaxToolRounds - 1 && actions.dangerous.isEmpty) {
            agentFooter = '这轮能整理的内容先到这里，后续需要的话可以继续让我细化。';
          }
        }

        if (actions.safe.isNotEmpty &&
            safeActions.isEmpty &&
            actions.dangerous.isEmpty) {
          agentFooter = _hasSuccessfulMediaResult(toolResults)
              ? null
              : '已避免重复整理相同内容，当前这一轮先到这里。';
          break;
        }

        if (actions.dangerous.isNotEmpty && mounted) {
          final displayedReply = _composeAgentReply(finalReply, toolResults);
          final waitingSteps = _agentStepViews(
            toolResults,
            waitingActions: actions.dangerous,
          );
          setState(() {
            _replaceAssistantDraft(
              displayedReply,
              memorySources: memorySources,
              agentSteps: waitingSteps,
            );
            _entries.add(_ChatEntry(
              id: _newEntryId('confirm'),
              role: _ChatRole.confirmCard,
              text: '',
              confirmActions: actions.dangerous,
            ));
          });
          _scrollToBottom();
          // 不要标记 isSending = false 在 finally 中，而是等确认卡处理完后标记
          _pendingDangerousActions = actions.dangerous;
          _pendingDangerousReply = displayedReply;
          _pendingDangerousInput = input;
          await _saveChatMessage(
            id: _latestAssistantEntryId(),
            role: ChatMessageRole.assistant,
            content: displayedReply,
            attachments: _buildAssistantAttachments(
              displayedReply,
              resultShortcuts: _buildResultShortcuts(toolResults),
              agentSteps: waitingSteps,
            ),
          );
          return; // 提前返回，不清除 isSending
        }

        break;
      }

      final finalFooter = _joinAgentFooters(
        agentFooter,
        _agentRecoveryFooter(toolResults),
      );
      finalReply = _composeAgentReply(
        finalReply,
        toolResults,
        footer: finalFooter,
      );
      final undoResults = _undoableResults(toolResults);
      final resultShortcuts = _buildResultShortcuts(toolResults);
      final finalAgentSteps = _agentStepViews(
        toolResults,
        footer: finalFooter,
      );
      if (mounted) {
        setState(
          () => _replaceAssistantDraft(
            finalReply,
            memorySources: memorySources,
            agentSteps: finalAgentSteps,
            undoResults: undoResults,
            resultShortcuts: resultShortcuts,
          ),
        );
        _scrollToBottom();
      }
      await _saveChatMessage(
        id: _latestAssistantEntryId(),
        role: ChatMessageRole.assistant,
        content: finalReply,
        attachments: _buildAssistantAttachments(
          finalReply,
          resultShortcuts: resultShortcuts,
          agentSteps: finalAgentSteps,
        ),
      );
    } catch (error) {
      await _handleAssistantTurnError(
        error: error,
        input: input,
        messages: messages,
        requestId: requestId,
      );
    } finally {
      if (requestId == _requestSerial &&
          mounted &&
          _pendingDangerousActions == null) {
        _exitSending();
        _scrollToBottom();
      }
    }
  }

  String _assistantReplyText(String raw) {
    return _stripActions(raw.trim()).trim();
  }

  _LegacyActionTurn _parseLegacyActionTurn(String raw) {
    final parsed = _extractLegacyActionTurn(raw);
    return _LegacyActionTurn(
      reply: _assistantReplyText(parsed.reply),
      actions: parsed.actions,
    );
  }

  List<AiAppAction> _uniqueAgentActions(List<AiAppAction> actions) {
    final unique = <AiAppAction>[];
    for (final action in actions) {
      if (unique.any((item) => _isEquivalentAgentAction(item, action))) {
        continue;
      }
      unique.add(action);
    }
    return unique;
  }

  _AgentActionGroup _groupAgentActions(List<AiAppAction> actions) {
    final safeActions = <AiAppAction>[];
    final dangerousActions = <AiAppAction>[];
    for (final action in actions) {
      final toolId = _actionTypeToToolId(action.type);
      final def =
          toolId != null ? AiToolRegistry.instance.lookup(toolId) : null;
      final needsConfirmation =
          def?.needsConfirmation ?? _needsConfirmationFallback(action.type);
      if (needsConfirmation) {
        dangerousActions.add(action);
      } else {
        safeActions.add(action);
      }
    }
    return _AgentActionGroup(
      safe: safeActions,
      dangerous: dangerousActions,
    );
  }

  List<AiAppAction> _newSafeAgentActions(
    List<AiAppAction> actions,
    List<AiActionResult> previousResults,
  ) {
    return actions
        .where((action) => !_alreadyCompletedAgentAction(
              action,
              previousResults,
            ))
        .toList(growable: false);
  }

  bool _alreadyCompletedAgentAction(
    AiAppAction action,
    List<AiActionResult> previousResults,
  ) {
    return previousResults.any(
      (result) => AiChatActionGuard.isAlreadyHandledAgentAction(
        action,
        [result],
      ),
    );
  }

  bool _isEquivalentAgentAction(AiAppAction left, AiAppAction right) {
    return AiChatActionGuard.areEquivalentAgentActions(left, right);
  }

  bool _shouldStopAfterSafeActions(List<AiActionResult> results) {
    return AiChatActionGuard.shouldStopAfterSafeActions(results);
  }

  Future<List<AiActionResult>> _executeSafeAgentActions(
    List<AiAppAction> actions, {
    required String input,
    required String assistantReply,
  }) async {
    final handler = widget.onExecuteActions;
    if (handler == null) {
      return actions
          .map((action) => AiActionResult(
                action: action,
                success: false,
                message: '当前页面暂时不能直接保存这项更改',
              ))
          .toList(growable: false);
    }
    try {
      return await handler(
        actions: actions,
        input: input,
        assistantReply: assistantReply,
      );
    } catch (error) {
      return actions
          .map((action) => AiActionResult(
                action: action,
                success: false,
                message: '这一步暂时没处理成功，内容没有改动，可以稍后再试。',
              ))
          .toList(growable: false);
    }
  }

  void _mergeAgentMemorySources(
    List<String> memorySources,
    List<AiActionResult> results,
  ) {
    for (final result in results) {
      if (result.action.type != AiAppActionType.searchMemory) continue;
      for (final candidate in result.candidates) {
        final compact = _compactMemorySource(candidate);
        if (compact.isEmpty || memorySources.contains(compact)) continue;
        memorySources.add(compact);
        if (memorySources.length >= 4) return;
      }
    }
  }

  List<AiActionResult> _undoableResults(List<AiActionResult> results) {
    return results
        .where((result) =>
            result.success &&
            (_isUndoableCreation(result) || _isUndoableDeletion(result)) &&
            _undoTargetIds(result).isNotEmpty)
        .toList(growable: false);
  }

  List<String> _undoTargetIds(AiActionResult result) {
    final ids = <String>{
      if (result.createdId != null && result.createdId!.trim().isNotEmpty)
        result.createdId!.trim(),
      ...result.candidates
          .map((item) => item.trim())
          .where((item) => _looksLikeEntityId(item)),
    };
    return ids.toList(growable: false);
  }

  bool _looksLikeEntityId(String value) {
    return value.startsWith('task_') ||
        value.startsWith('log_') ||
        value.startsWith('note_') ||
        value.startsWith('fc_');
  }

  bool _isUndoableCreation(AiActionResult result) {
    return switch (result.action.type) {
      AiAppActionType.addTask ||
      AiAppActionType.addTaskDirect ||
      AiAppActionType.generateWeeklyPlan ||
      AiAppActionType.generateTodayMission ||
      AiAppActionType.createLoopFromSource ||
      AiAppActionType.createLog ||
      AiAppActionType.saveNote ||
      AiAppActionType.summarizeStarredCards ||
      AiAppActionType.noteFromLog ||
      AiAppActionType.noteFromOcr ||
      AiAppActionType.addFlashcard ||
      AiAppActionType.generateTodayFlashcards ||
      AiAppActionType.createFlashcardBatch =>
        true,
      _ => false,
    };
  }

  bool _isUndoableDeletion(AiActionResult result) {
    return switch (result.action.type) {
      AiAppActionType.deleteTask ||
      AiAppActionType.deleteLog ||
      AiAppActionType.deleteNote ||
      AiAppActionType.deleteFlashcard =>
        true,
      _ => false,
    };
  }

  Future<void> _undoAgentActions(_ChatEntry entry) async {
    if (entry.undoResults.isEmpty || entry.undoApplied) return;
    final undoResults = entry.undoResults;
    var undone = 0;
    final failures = <String>[];
    for (final result in undoResults.reversed) {
      try {
        undone += await _undoActionResult(result);
      } catch (error) {
        failures.add(_agentActionLabel(result.action));
      }
    }
    if (!mounted) return;
    final undoneStep = _AgentStepView(
      title: undone == 0 ? '撤销未完成' : '已撤销本轮可撤销操作',
      detail: failures.isEmpty
          ? '共整理 $undone 项，创建内容已移入回收站，删除内容已恢复'
          : '已整理 $undone 项，${failures.join('、')} 需要你再看一下',
      status: undone == 0 ? _AgentStepStatus.failed : _AgentStepStatus.undone,
    );
    setState(() {
      final index = _entries.indexWhere((item) => item.id == entry.id);
      if (index < 0) return;
      _entries[index] = _entries[index].copyWith(
        agentSteps: [..._entries[index].agentSteps, undoneStep],
        undoResults: const [],
        undoApplied: true,
      );
      unawaited(_syncStoredEntry(_entries[index]));
    });
    StudyToast.show(
      context,
      undone == 0 ? '没有找到可撤销的内容' : '已撤销本轮可撤销操作',
    );
  }

  Future<int> _undoActionResult(AiActionResult result) async {
    var count = 0;
    for (final id in _undoTargetIds(result)) {
      if (_isUndoableDeletion(result)) {
        if (await _restoreTrashEntity(id)) count++;
      } else if (_isUndoableCreation(result)) {
        if (await _moveCreatedEntityToTrash(id)) count++;
      }
    }
    return count;
  }

  Future<bool> _moveCreatedEntityToTrash(String entityId) async {
    if (widget.controller.studyTasks.any((item) => item.id == entityId)) {
      await widget.controller.deleteStudyTask(entityId);
      return true;
    }
    if (widget.controller.studyLogs.any((item) => item.id == entityId)) {
      await widget.controller.deleteStudyLog(entityId);
      return true;
    }
    if (widget.controller.studyNotes.any((item) => item.id == entityId)) {
      await widget.controller.deleteStudyNote(entityId);
      return true;
    }
    if (widget.controller.flashCards.any((item) => item.id == entityId)) {
      await widget.controller.deleteFlashCard(entityId);
      return true;
    }
    return false;
  }

  Future<bool> _restoreTrashEntity(String entityId) async {
    final matches = widget.controller.trashItems
        .where((item) => item.entityId == entityId)
        .toList(growable: false);
    if (matches.isEmpty) return false;
    matches.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
    await widget.controller.restoreFromTrash(matches.first.id);
    return true;
  }

  String? _agentRecoveryFooter(List<AiActionResult> results) {
    final visibleResults = _visibleAgentResults(results);
    final failed = visibleResults.where((result) => !result.success).toList();
    if (failed.isEmpty) return null;
    if (failed
        .any((result) => result.action.type == AiAppActionType.searchMemory)) {
      return '没有命中的历史记录时，我会重新判断关键词，必要时会向你追问。';
    }
    if (failed.any((result) => _isMediaAction(result.action.type))) {
      return '图片或短片处理失败时，我会优先建议简化描述或稍后刷新，避免反复整理。';
    }
    return '有内容没有处理完，我会先说明未改动的部分，再判断是否需要补充条件。';
  }

  String? _joinAgentFooters(String? first, String? second) {
    final parts = [
      first?.trim() ?? '',
      second?.trim() ?? '',
    ].where((item) => item.isNotEmpty).toList(growable: false);
    if (parts.isEmpty) return null;
    return parts.join('\n');
  }

  String _composeAgentReply(
    String reply,
    List<AiActionResult> results, {
    String? runningText,
    String? footer,
  }) {
    final parts = <String>[];
    final trimmed = reply.trim();
    if (trimmed.isNotEmpty) parts.add(trimmed);
    if (trimmed.isEmpty && results.isNotEmpty) {
      parts.add('已整理 ${results.length} 个结果。');
    } else if (trimmed.isEmpty &&
        runningText != null &&
        runningText.trim().isNotEmpty) {
      parts.add('正在思考：$runningText');
    }
    final mediaMarkdown = _successfulMediaMarkdown(results, existing: trimmed);
    if (mediaMarkdown.isNotEmpty) parts.add(mediaMarkdown);
    if (footer != null && footer.trim().isNotEmpty) parts.add(footer.trim());
    return parts.join('\n\n').trim();
  }

  String _successfulMediaMarkdown(
    List<AiActionResult> results, {
    String existing = '',
  }) {
    final lines = <String>[];
    final seenUrls = _mediaUrlsFromMarkdown(existing).toSet();
    final existingHasMedia = seenUrls.isNotEmpty;
    for (final result in results) {
      if (!result.success || !_isMediaAction(result.action.type)) continue;
      if (existingHasMedia) continue;
      final message = result.message.trim();
      if (message.isEmpty) continue;
      final messageUrls = _mediaUrlsFromMarkdown(message);
      if (messageUrls.isNotEmpty &&
          messageUrls.every((url) => seenUrls.contains(url))) {
        continue;
      }
      final hasImage = RegExp(r'!\[[^\]]*\]\([^)]+\)').hasMatch(message);
      final hasVideo = RegExp(
        """<video[^>]+src=["'][^"']+["'][^>]*>|https?://\\S+\\.(?:mp4|mov|webm|m3u8)(?:\\?\\S*)?""",
        caseSensitive: false,
      ).hasMatch(message);
      if ((hasImage || hasVideo) && !lines.contains(message)) {
        lines.add(message);
        seenUrls.addAll(messageUrls);
      }
    }
    return lines.join('\n\n');
  }

  List<String> _mediaUrlsFromMarkdown(String markdown) {
    final urls = <String>[];
    void add(String? raw) {
      final url = (raw ?? '').replaceAll(RegExp(r'[)\]>]+$'), '').trim();
      if (url.isNotEmpty && !urls.contains(url)) urls.add(url);
    }

    for (final match
        in RegExp(r'!\[[^\]]*\]\(([^)]+)\)').allMatches(markdown)) {
      add(match.group(1));
    }
    final videoPattern = RegExp(
      """<video[^>]+src=["']([^"']+)["'][^>]*>|https?://\\S+\\.(?:mp4|mov|webm|m3u8)(?:\\?\\S*)?""",
      caseSensitive: false,
    );
    for (final match in videoPattern.allMatches(markdown)) {
      add(match.group(1) ?? match.group(0));
    }
    return urls;
  }

  List<_AgentStepView> _agentStepViews(
    List<AiActionResult> results, {
    List<AiAppAction> queuedActions = const [],
    List<AiAppAction> runningActions = const [],
    List<AiAppAction> waitingActions = const [],
    String? runningText,
    String? footer,
    bool undoApplied = false,
  }) {
    final visibleResults = _visibleAgentResults(results);
    final steps = <_AgentStepView>[
      for (final result in visibleResults)
        _AgentStepView(
          title: _agentActionLabel(result.action),
          detail: _agentStepDetail(result),
          status: result.success
              ? _AgentStepStatus.completed
              : _AgentStepStatus.failed,
        ),
    ];
    for (final action in runningActions) {
      steps.add(_AgentStepView(
        title: _agentActionLabel(action),
        detail: '正在思考',
        status: _AgentStepStatus.running,
      ));
    }
    for (final action in queuedActions) {
      steps.add(_AgentStepView(
        title: _agentActionLabel(action),
        detail: '先等前一项整理完',
        status: _AgentStepStatus.queued,
      ));
    }
    for (final action in waitingActions) {
      steps.add(_AgentStepView(
        title: _agentActionLabel(action),
        detail: _dangerousActionPreview(action),
        status: _AgentStepStatus.waitingConfirmation,
      ));
    }
    if (runningText != null && runningText.trim().isNotEmpty) {
      steps.add(_AgentStepView(
        title: runningText.trim(),
        detail: '整理好后，再继续判断下一步',
        status: _AgentStepStatus.running,
      ));
    }
    if (undoApplied) {
      steps.add(const _AgentStepView(
        title: '已撤销本轮更改',
        detail: '可撤销内容已移入回收站或恢复',
        status: _AgentStepStatus.undone,
      ));
    }
    if (footer != null && footer.trim().isNotEmpty) {
      steps.add(_AgentStepView(
        title: '小提醒',
        detail: footer.trim(),
        status: _AgentStepStatus.info,
      ));
    }
    return steps;
  }

  List<AiActionResult> _visibleAgentResults(List<AiActionResult> results) {
    final hasSuccessfulImage = results.any(
      (result) =>
          result.success &&
          (result.action.type == AiAppActionType.generateImage ||
              result.action.type == AiAppActionType.refreshImage),
    );
    final hasSuccessfulVideo = results.any(
      (result) =>
          result.success &&
          (result.action.type == AiAppActionType.generateVideo ||
              result.action.type == AiAppActionType.refreshVideo),
    );
    if (!hasSuccessfulImage && !hasSuccessfulVideo) return results;
    return results.where((result) {
      if (result.success) return true;
      if (hasSuccessfulImage &&
          (result.action.type == AiAppActionType.generateImage ||
              result.action.type == AiAppActionType.refreshImage)) {
        return false;
      }
      if (hasSuccessfulVideo &&
          (result.action.type == AiAppActionType.generateVideo ||
              result.action.type == AiAppActionType.refreshVideo)) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  String _agentStepDetail(AiActionResult result) {
    if (result.success && _isMediaAction(result.action.type)) {
      return result.action.type == AiAppActionType.generateVideo ||
              result.action.type == AiAppActionType.refreshVideo
          ? '视频已生成，已添加到回复中。'
          : '图片已生成，已添加到回复中。';
    }
    return _friendlyActionResultMessage(result);
  }

  String _runningToolText(List<AiAppAction> actions) {
    final labels = actions.take(2).map(_agentActionLabel).toList();
    final extra = actions.length - labels.length;
    return [
      labels.join('、'),
      if (extra > 0) '等 $extra 项',
    ].where((item) => item.trim().isNotEmpty).join(' ');
  }

  String _agentActionLabel(AiAppAction action) {
    final toolId = _actionTypeToToolId(action.type);
    final base = toolId == null
        ? action.type.name
        : AiToolRegistry.instance.userFacingLabel(toolId);
    final target = action.targetTitle ?? action.title ?? action.sourceText;
    if (target == null || target.trim().isEmpty) return base;
    return '$base（${_shortAgentText(target)}）';
  }

  String _dangerousActionPreview(AiAppAction action) {
    final target = action.targetTitle ?? action.title ?? action.sourceText;
    final suffix = target == null || target.trim().isEmpty
        ? ''
        : '：${_shortAgentText(target)}';
    return switch (action.type) {
      AiAppActionType.deleteTask => '将把任务移入回收站$suffix',
      AiAppActionType.deleteLog => '将把学习记录移入回收站$suffix',
      AiAppActionType.deleteNote => '将把笔记移入回收站$suffix',
      AiAppActionType.deleteFlashcard => '将把闪卡移入回收站$suffix',
      AiAppActionType.overwriteNote => '将覆盖已有笔记内容$suffix',
      AiAppActionType.emptyTrash => '将永久清空回收站，无法恢复',
      AiAppActionType.logout => '将退出当前账号',
      AiAppActionType.deleteCourse => '将删除课程及相关归属$suffix',
      _ => '需要你确认后才会保存$suffix',
    };
  }

  String _shortAgentText(String text) {
    final trimmed = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    return trimmed.length > 28 ? '${trimmed.substring(0, 28)}...' : trimmed;
  }

  List<String> _buildAgentContinuationContext(
    List<String> baseContext,
    List<AiActionResult> results, {
    required int round,
  }) {
    return [
      ...baseContext,
      '连续整理：第 $round 轮处理已经完成。',
      '处理结果：',
      ...results.map(_agentResultContextLine),
      ..._agentRecoveryHints(results),
      '请基于处理结果继续完成用户目标。不要重复执行已经成功的同一处理；如果目标已完成，返回最终 reply 且 actions 为空；如果还需要安全处理，可以继续返回 actions；如果需要删除、覆盖、清空或退出等危险动作，解释原因并返回待确认 action。',
    ];
  }

  List<String> _agentRecoveryHints(List<AiActionResult> results) {
    final hints = <String>[];
    if (results.any(
      (result) =>
          !result.success && result.action.type == AiAppActionType.searchMemory,
    )) {
      hints.add('失败恢复策略：memory.search 无结果时，换更短关键词或向用户追问，不要假装引用学习记录。');
    }
    if (results.any(
        (result) => !result.success && _isMediaAction(result.action.type))) {
      hints.add('失败恢复策略：图片/视频生成失败或超时时，说明原因，建议简化描述或稍后刷新，不要重复创建同一媒体任务。');
    }
    if (results.any((result) =>
        !result.success &&
        result.action.type != AiAppActionType.searchMemory &&
        !_isMediaAction(result.action.type))) {
      hints.add('失败恢复策略：处理失败时，先说明哪些内容未改动，再请求更明确的目标或条件。');
    }
    return hints;
  }

  String _agentResultContextLine(AiActionResult result) {
    return jsonEncode({
      'tool': _agentActionLabel(result.action),
      'type': aiAppActionTypeToWire(result.action.type),
      'success': result.success,
      'message': result.message,
      if (result.createdId != null) 'createdId': result.createdId,
      if (result.candidates.isNotEmpty) 'candidates': result.candidates,
    });
  }

  String _agentContinuationInput(String originalInput) {
    return '继续完成用户最初目标：“$originalInput”。处理结果已经写入上下文，请根据结果继续判断下一步或给出最终答复。';
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
          message: '当前页面暂时不能直接保存这项更改',
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
            message: '这一步暂时没处理成功，内容没有改动，可以稍后再试。',
          ),
        ];
      }
    }
    if (mounted) {
      final remaining = _remainingDangerousActions(action);
      _ChatEntry? updatedAssistantEntry;
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
            final undoResults = _undoableResults(results);
            final mergedShortcuts = _mergeResultShortcuts(
              _entries[i].resultShortcuts,
              _buildResultShortcuts(results),
            );
            final mergedSteps = [
              ..._entries[i].agentSteps,
              ..._agentStepViews(results),
            ];
            _entries[i] = _entries[i].copyWith(
              text: updated,
              attachments: _buildAssistantAttachments(
                updated,
                resultShortcuts: mergedShortcuts,
                agentSteps: mergedSteps,
              ),
              agentSteps: mergedSteps,
              undoResults: [
                ..._entries[i].undoResults,
                ...undoResults,
              ],
              resultShortcuts: mergedShortcuts,
            );
            updatedAssistantEntry = _entries[i];
            break;
          }
        }
        _pendingDangerousActions = remaining.isEmpty ? null : remaining;
      });
      if (updatedAssistantEntry != null) {
        unawaited(_syncStoredEntry(updatedAssistantEntry!));
      }
      if (remaining.isEmpty) _exitSending(clearPending: true);
    }
  }

  /// 取消单个危险动作
  void _cancelDangerousAction(AiAppAction action) {
    final remaining = _remainingDangerousActions(action);
    _ChatEntry? updatedAssistantEntry;
    setState(() {
      // 取消时也移除确认卡并在气泡里追加"已取消"
      if (_entries.isNotEmpty && _entries.last.role == _ChatRole.confirmCard) {
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
          final updated =
              base.isEmpty ? '- 已取消：这次没有保存更改' : '$base\n\n- 已取消：这次没有保存更改';
          _entries[i] = _entries[i].copyWith(
            text: updated,
            attachments: _buildAssistantAttachments(
              updated,
              resultShortcuts: _entries[i].resultShortcuts,
              agentSteps: _entries[i].agentSteps,
            ),
          );
          updatedAssistantEntry = _entries[i];
          break;
        }
      }
      _pendingDangerousActions = remaining.isEmpty ? null : remaining;
    });
    if (updatedAssistantEntry != null) {
      unawaited(_syncStoredEntry(updatedAssistantEntry!));
    }
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

  List<String> _buildAppContext({required bool includeLearningData}) {
    return AiAppContextBuilder.build(
      widget.controller,
      currentLocation:
          widget.currentLocation ?? widget.controller.currentPrimaryTab,
      includeLearningData: includeLearningData,
    );
  }

  Future<List<String>> _buildAppContextWithMemory(String input) async {
    final shouldUseLearningData = _shouldUseLearningData(input);
    final context =
        _buildAppContext(includeLearningData: shouldUseLearningData);
    if (!shouldUseLearningData) {
      _lastMemorySources = const [];
      return context;
    }
    final memory = await _semanticMemoryContext(input);
    _lastMemorySources = memory.take(4).map(_compactMemorySource).toList();
    if (memory.isEmpty) return context;
    return [
      ...context,
      '语义召回的个人历史记录：',
      ...memory,
    ];
  }

  bool _shouldUseLearningData(String input) {
    final text = input.trim().toLowerCase();
    if (text.isEmpty) return false;

    if (_containsAny(text, const [
      '不要参考',
      '不用参考',
      '不参考学习记录',
      '不要用我的',
      '不用我的',
      '别看我的',
    ])) {
      return false;
    }

    if (_containsAny(text, const [
      '学习记录',
      '学习日志',
      '学迹',
      '历史记录',
      '个人记录',
      '历史记录',
      '我的记录',
      '我的笔记',
      '我的任务',
      '我的待办',
      '我的闪卡',
      '收藏闪卡',
      '待办',
      '闪卡',
      '过期任务',
      '最近记录',
      '最近学习',
      '上次',
      '难点',
      '错题',
      '复盘',
    ])) {
      return true;
    }

    final asksPersonalObject = _containsAny(text, const [
      '任务',
      '待办',
      '计划',
      '安排',
      '日历',
      '截止',
      '过期',
      '完成情况',
      '进度',
      '笔记',
    ]);
    if (!asksPersonalObject) return false;

    return _containsAny(text, const [
      '根据',
      '今天',
      '昨天',
      '前天',
      '明天',
      '后天',
      '最近',
      '本周',
      '这周',
      '上周',
      '下周',
      '接下来',
      '当前',
      '现在',
    ]);
  }

  bool _containsAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }

  String _compactMemorySource(String raw) {
    final normalized =
        raw.replaceAll('｜', ' · ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final parts = normalized
        .split(' · ')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return '学习记录';

    final title = parts.first;
    final course = parts.firstWhere(
      (item) => item.startsWith('课程：'),
      orElse: () => '',
    );
    final label = course.isEmpty ? title : '$title · ${course.substring(3)}';
    return label.length > 38 ? '${label.substring(0, 38)}...' : label;
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
      return _localMemoryMatches(query, candidates)
          .take(5)
          .map((c) => c.item)
          .toList();
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
        text:
            '${log.courseName} ${log.content} ${log.problems} ${log.thoughts} ${log.nextPlan}',
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
    final matches =
        candidates.where((c) => c.text.toLowerCase().contains(q)).toList();
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
        id: _latestAssistantEntryId(),
        role: ChatMessageRole.assistant,
        content: reply,
        attachments: _attachmentsFromMarkdown(reply),
      );
    } catch (_) {
      final friendly = _friendlyErrorMessage(error);
      if (mounted) setState(() => _replaceAssistantDraft(friendly));
      await _saveChatMessage(
        id: _latestAssistantEntryId(),
        role: ChatMessageRole.assistant,
        content: friendly,
      );
    }
  }

  String _friendlyErrorMessage(Object error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('整理耗时较长')) {
      return '这次思考时间较长，可以稍等后再试，或切到快速模式。';
    }
    if (msg.contains('登录后可以继续使用')) {
      return '登录后可以继续使用在线学习整理。';
    }
    if (msg.contains('failed to fetch') ||
        msg.contains('socketexception') ||
        msg.contains('connection refused') ||
        msg.contains('timeout')) {
      return '学习助手暂时不可用，请检查网络连接后重试。';
    }
    if (msg.contains('401') ||
        msg.contains('unauthorized') ||
        msg.contains('appkey')) {
      return '请重新登录后继续整理。';
    }
    if (msg.contains('429') ||
        msg.contains('rate') ||
        msg.contains('too many')) {
      return '今天整理得有点频繁，请稍后再试。';
    }
    if (msg.contains('quota') || msg.contains('额度') || msg.contains('limit')) {
      return '今日学习助手使用次数已达上限，明天再来吧。';
    }
    if (msg.contains('503') || msg.contains('unavailable')) {
      return '学习助手暂时不可用，请稍后重试。';
    }
    return '回复失败，请稍后重试。';
  }

  void _replaceAssistantDraft(
    String text, {
    List<String> memorySources = const [],
    List<_AgentStepView>? agentSteps,
    List<AiActionResult>? undoResults,
    List<_ChatResultShortcut>? resultShortcuts,
    bool? undoApplied,
  }) {
    for (var i = _entries.length - 1; i >= 0; i--) {
      if (_entries[i].role == _ChatRole.assistant) {
        final nextAgentSteps = agentSteps ?? _entries[i].agentSteps;
        final nextShortcuts = resultShortcuts ?? _entries[i].resultShortcuts;
        _entries[i] = _entries[i].copyWith(
          text: text,
          attachments: _buildAssistantAttachments(
            text,
            resultShortcuts: nextShortcuts,
            agentSteps: nextAgentSteps,
          ),
          memorySources: memorySources.isEmpty ? null : memorySources,
          agentSteps: agentSteps,
          undoResults: undoResults,
          resultShortcuts: resultShortcuts,
          undoApplied: undoApplied,
        );
        return;
      }
    }
    _entries.add(_ChatEntry(
      id: _newEntryId('assistant'),
      role: _ChatRole.assistant,
      text: text,
      attachments: _buildAssistantAttachments(
        text,
        resultShortcuts: resultShortcuts,
        agentSteps: agentSteps,
      ),
      memorySources: memorySources,
      agentSteps: agentSteps ?? const [],
      undoResults: undoResults ?? const [],
      resultShortcuts: resultShortcuts ?? const [],
      undoApplied: undoApplied ?? false,
    ));
  }

  String _appendActionResults(String reply, List<AiActionResult> results) {
    if (results.isEmpty) return reply;
    final mediaFailures = results
        .where(
            (result) => !result.success && _isMediaAction(result.action.type))
        .toList(growable: false);
    final hasSuccessfulMedia = results
        .any((result) => result.success && _isMediaAction(result.action.type));
    if (mediaFailures.isNotEmpty && !hasSuccessfulMedia) {
      final lines = mediaFailures.map(_formatActionResultLine).join('\n');
      final title = mediaFailures.any(
        (result) =>
            result.action.type == AiAppActionType.generateVideo ||
            result.action.type == AiAppActionType.refreshVideo,
      )
          ? '视频还没生成成功。'
          : '图片还没生成成功。';
      return '$title\n\n$lines\n\n可以把要求改得更具体，例如指定主体、风格、构图和画面细节，再试一次。';
    }

    final lines = results.map(_formatActionResultLine).join('\n');
    return '$reply\n\n$lines'.trim();
  }

  bool _isMediaAction(AiAppActionType type) {
    return switch (type) {
      AiAppActionType.generateImage ||
      AiAppActionType.refreshImage ||
      AiAppActionType.generateVideo ||
      AiAppActionType.refreshVideo =>
        true,
      _ => false,
    };
  }

  bool _hasSuccessfulMediaResult(List<AiActionResult> results) {
    return results.any(
      (result) => result.success && _isMediaAction(result.action.type),
    );
  }

  String _formatActionResultLine(AiActionResult result) {
    final isVideoAction = result.action.type == AiAppActionType.generateVideo ||
        result.action.type == AiAppActionType.refreshVideo;
    final prefix = result.success
        ? '已完成'
        : isVideoAction
            ? '视频未生成'
            : _isMediaAction(result.action.type)
                ? '图片未生成'
                : '暂未完成';
    return '- $prefix：${_friendlyActionResultMessage(result)}';
  }

  String _friendlyActionResultMessage(AiActionResult result) {
    final raw = result.message.trim();
    final lower = raw.toLowerCase();
    if (lower.contains('violates policy') ||
        lower.contains('input content') ||
        lower.contains('policy')) {
      return '这次图片描述不太适合生成，可以换成更中性的图片描述再试。';
    }
    if (lower.contains('503') ||
        lower.contains('unavailable') ||
        lower.contains('service temporarily unavailable')) {
      return '整理暂时不顺利，稍后再试。';
    }
    if (lower.contains('timeout') ||
        raw.contains('超时') ||
        raw.contains('耗时较长')) {
      return '等待时间较长，可以稍后重试或减少上下文。';
    }
    final cleaned = raw
        .replaceFirst('执行失败：', '')
        .replaceFirst('执行失败:', '')
        .replaceFirst('整理失败：', '')
        .replaceFirst('整理失败:', '')
        .trim();
    return cleaned.isEmpty ||
            cleaned.contains('Exception') ||
            cleaned.contains('targetId') ||
            cleaned.contains('status') ||
            cleaned.contains('http') ||
            cleaned.contains('HTTP')
        ? '这一步暂时没处理成功，内容没有改动，可以稍后再试。'
        : cleaned;
  }

  String _stripLegacyActions(String text) {
    return _extractLegacyActionTurn(text).reply;
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
    final existingSteps = _latestAssistantAgentSteps();
    setState(() => _replaceAssistantDraft(
          '已停止整理。',
          agentSteps: [
            ...existingSteps,
            const _AgentStepView(
              title: '用户已停止',
              detail: '本轮整理已中断',
              status: _AgentStepStatus.info,
            ),
          ],
        ));
    _exitSending(clearPending: true);
  }

  List<_AgentStepView> _latestAssistantAgentSteps() {
    for (var i = _entries.length - 1; i >= 0; i--) {
      if (_entries[i].role == _ChatRole.assistant) {
        return _entries[i].agentSteps;
      }
    }
    return const [];
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
          final speaker = entry.role == _ChatRole.user ? '我' : '学习助手';
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
      _showSnack('已复制，同时已保存为私密学迹');
      _clearSelection();
    } catch (error) {
      _showSnack('这次没有保存成学迹，内容还在，可以稍后再试');
    }
  }

  Future<void> _selectedToNote() async {
    final text = _selectedMarkdown();
    if (text.isEmpty) return;
    try {
      await widget.controller.addStudyNote(
        title: '学习对话笔记 ${DateTime.now().month}/${DateTime.now().day}',
        content: text,
        blocks: markdownToNoteBlocks(text),
      );
      _showSnack('已转成笔记');
      _clearSelection();
    } catch (error) {
      _showSnack('这次没有转成笔记，内容还在，可以稍后再试');
    }
  }

  Future<void> _summarizeSelectedToNote() async {
    final text = _selectedMarkdown();
    if (text.isEmpty || _isSending) return;
    _enterSending();
    try {
      final summary = await _aiService.generateAssistantReply(
        input: '请把以下学习对话整理成一篇 Notion 风格块笔记，使用小标题、短段落、列表和待办：\n\n$text',
        purpose: 'note',
        thinkingEnabled: _thinkingEnabled,
      );
      final content = summary.trim().isEmpty ? text : summary.trim();
      await widget.controller.addStudyNote(
        title: '学习对话总结 ${DateTime.now().month}/${DateTime.now().day}',
        content: content,
        blocks: markdownToNoteBlocks(content),
      );
      _showSnack('已总结成笔记');
      _clearSelection();
    } catch (error) {
      _showSnack('这次没有总结成笔记，内容还在，可以稍后再试');
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
      _showSnack('图片暂时没有保存成功，请稍后再试');
    }
  }

  Future<void> _saveImageFromUrl(String url) async {
    final source = url.trim();
    if (source.isEmpty) return;
    try {
      final bytes = await _downloadImageBytes(source);
      if (bytes == null || bytes.isEmpty) {
        _showSnack('图片暂时没有保存成功，请稍后再试');
        return;
      }
      final extension = _imageExtensionForSource(source);
      await saveExportFile(
        fileName:
            'studytrace_image_${DateTime.now().microsecondsSinceEpoch}.$extension',
        mimeType: _imageMimeTypeForExtension(extension),
        bytes: bytes,
      );
      _showSnack('图片已保存');
    } catch (_) {
      _showSnack('图片暂时没有保存成功，请稍后再试');
    }
  }

  Future<void> _copyEntryText(_ChatEntry entry) async {
    final text = entry.text.trim();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    _showSnack('已复制');
  }

  void _editEntryText(_ChatEntry entry) {
    final text = entry.text.trim();
    if (text.isEmpty) return;
    _inputController.text = text;
    _inputController.selection = TextSelection.collapsed(
      offset: _inputController.text.length,
    );
    _showSnack('已放入输入框，可修改后发送');
  }

  String _imageExtensionForSource(String source) {
    final lower = source.toLowerCase();
    if (lower.startsWith('data:image/jpeg') ||
        lower.startsWith('data:image/jpg')) {
      return 'jpg';
    }
    if (lower.startsWith('data:image/webp')) return 'webp';
    if (lower.startsWith('data:image/gif')) return 'gif';
    if (lower.startsWith('data:image/png')) return 'png';

    final path = Uri.tryParse(source)?.path.toLowerCase() ?? lower;
    if (path.endsWith('.jpeg') || path.endsWith('.jpg')) return 'jpg';
    if (path.endsWith('.webp')) return 'webp';
    if (path.endsWith('.gif')) return 'gif';
    return 'png';
  }

  String _imageMimeTypeForExtension(String extension) {
    return switch (extension) {
      'jpg' => 'image/jpeg',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/png',
    };
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
    final text = cleaned.isEmpty ? '选中的学习对话' : cleaned;
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
    if (data == null) throw StateError('截图整理失败');
    return data.buffer.asUint8List();
  }

  // ─── 图片分析（Vision） ───

  Future<void> _pickAndAnalyzeImage() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ChatSheetSurface(
        isDarkMode: widget.isDarkMode,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ChatSheetOption(
              icon: Icons.photo_library_rounded,
              title: '从相册选择',
              subtitle: '导入题目、课堂板书或资料截图',
              accent: StudyUi.secondary,
              isDarkMode: widget.isDarkMode,
              onTap: () => Navigator.of(ctx).pop('gallery'),
            ),
            const SizedBox(height: 10),
            _ChatSheetOption(
              icon: Icons.camera_alt_rounded,
              title: '拍照',
              subtitle: '现场拍题后先把关键信息整理出来',
              accent: StudyUi.pathCyan,
              isDarkMode: widget.isDarkMode,
              onTap: () => Navigator.of(ctx).pop('camera'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;

    final source =
        result == 'camera' ? ImageSource.camera : ImageSource.gallery;
    try {
      final picked =
          await _imagePicker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _pendingImageBase64 = base64Encode(bytes);
        _inputController.text = '请分析这张图片的内容';
      });
    } catch (_) {
      if (!mounted) return;
      await StudyToast.dialog(
        context,
        title: '读取图片失败',
        message: '这张图片暂时没有读取成功，可以换一张或直接输入题目内容。',
      );
    }
  }

  // ─── 辅助方法 ───

  // ignore: unused_element
  List<String> _extractActions(String text) {
    final matches = _legacyActionPattern.allMatches(text);
    return matches
        .map((match) => match.group(1) ?? '')
        .where((action) => action.isNotEmpty)
        .toList(growable: false);
  }

  String _stripActions(String text) {
    return _extractLegacyActionTurn(text).reply;
  }

  _LegacyActionTurn _extractLegacyActionTurn(String text) {
    final actions = <AiAppAction>[];
    final buffer = StringBuffer();
    var cursor = 0;
    for (final match in _legacyActionPattern.allMatches(text)) {
      if (match.start < cursor) continue;
      buffer.write(text.substring(cursor, match.start));
      final actionName = (match.group(1) ?? '').trim();
      final jsonRange = _legacyActionJsonRange(text, match.end);
      Map<String, dynamic> params = const {};
      if (jsonRange != null) {
        params = _decodeLegacyActionJson(
          text.substring(jsonRange.start, jsonRange.end),
        );
        cursor = jsonRange.end;
      } else {
        cursor = match.end;
      }
      final action = AiAppAction.tryParse({
        ...params,
        'type': actionName,
      });
      if (action != null) actions.add(action);
    }
    buffer.write(text.substring(cursor));
    final cleaned = buffer
        .toString()
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    return _LegacyActionTurn(
      reply: cleaned,
      actions: actions,
    );
  }

  _TextRange? _legacyActionJsonRange(String text, int start) {
    var index = start;
    while (index < text.length) {
      final unit = text.codeUnitAt(index);
      if (unit == 0x20 || unit == 0x09 || unit == 0x0A || unit == 0x0D) {
        index++;
        continue;
      }
      break;
    }
    if (index >= text.length || text.codeUnitAt(index) != 0x7B) {
      return null;
    }
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = index; i < text.length; i++) {
      final unit = text.codeUnitAt(i);
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (unit == 0x5C) {
          escaped = true;
        } else if (unit == 0x22) {
          inString = false;
        }
        continue;
      }
      if (unit == 0x22) {
        inString = true;
      } else if (unit == 0x7B) {
        depth++;
      } else if (unit == 0x7D) {
        depth--;
        if (depth == 0) {
          return _TextRange(index, i + 1);
        }
      }
    }
    return null;
  }

  Map<String, dynamic> _decodeLegacyActionJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {
      // Ignore malformed legacy params; the action name may still be usable.
    }
    return const {};
  }

  String _newEntryId(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}';

  List<AiChatAttachment> _attachmentsFromMarkdown(String markdown) {
    final attachments = <AiChatAttachment>[];
    var index = 0;
    for (final match
        in RegExp(r'!\[[^\]]*\]\(([^)]+)\)').allMatches(markdown)) {
      final url = (match.group(1) ?? '').trim();
      if (url.isEmpty) continue;
      attachments.add(AiChatAttachment(
        id: 'att_${DateTime.now().microsecondsSinceEpoch}_${index++}',
        type: AiChatAttachmentType.image,
        url: url,
        title: '生成的图片',
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
        title: '制作视频',
      ));
    }
    return attachments;
  }

  Future<void> _saveChatMessage({
    String? id,
    required ChatMessageRole role,
    required String content,
    List<AiChatAttachment> attachments = const [],
  }) async {
    try {
      final message = AiChatMessage(
        id: id ?? '${_sessionId}_${DateTime.now().millisecondsSinceEpoch}',
        role: role,
        content: content,
        timestamp: DateTime.now(),
        attachments: attachments.isEmpty
            ? _attachmentsFromMarkdown(content)
            : attachments,
      );
      final chatHistoryJson = await _storage.getString('chat_sessions') ?? '[]';
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
        final firstUser = session.messages.firstWhere(
            (m) => m.role == ChatMessageRole.user,
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

  List<AiChatAttachment> _buildAssistantAttachments(
    String content, {
    List<_ChatResultShortcut>? resultShortcuts,
    List<_AgentStepView>? agentSteps,
  }) {
    final attachments =
        _attachmentsFromMarkdown(content).toList(growable: true);
    final shortcuts = resultShortcuts ?? const <_ChatResultShortcut>[];
    if (shortcuts.isNotEmpty) {
      attachments.add(AiChatAttachment(
        id: 'result_shortcuts_${DateTime.now().microsecondsSinceEpoch}',
        type: AiChatAttachmentType.apiResult,
        title: '快捷入口',
        metadata: {
          'kind': 'result_shortcuts',
          'items': shortcuts.map((item) => item.toJson()).toList(),
        },
      ));
    }
    final steps = agentSteps ?? const <_AgentStepView>[];
    if (steps.isNotEmpty) {
      attachments.add(AiChatAttachment(
        id: 'agent_steps_${DateTime.now().microsecondsSinceEpoch}',
        type: AiChatAttachmentType.apiResult,
        title: '工具流',
        metadata: {
          'kind': 'agent_steps',
          'items': steps.map((item) => item.toJson()).toList(),
        },
      ));
    }
    return attachments;
  }

  List<AiChatAttachment> _attachmentsForEntry(_ChatEntry entry) {
    if (entry.role != _ChatRole.assistant) return entry.attachments;
    return _buildAssistantAttachments(
      entry.text,
      resultShortcuts: entry.resultShortcuts,
      agentSteps: entry.agentSteps,
    );
  }

  List<_ChatResultShortcut> _resultShortcutsFromAttachments(
    List<AiChatAttachment> attachments,
  ) {
    for (final attachment in attachments) {
      if (attachment.type != AiChatAttachmentType.apiResult) continue;
      final metadata = attachment.metadata;
      if (metadata['kind'] != 'result_shortcuts') continue;
      final rawItems = metadata['items'];
      if (rawItems is! List) continue;
      return rawItems
          .whereType<Map>()
          .map((item) => _ChatResultShortcut.fromJson(
                item.cast<String, dynamic>(),
              ))
          .toList(growable: false);
    }
    return const [];
  }

  String? _latestAssistantEntryId() {
    for (var i = _entries.length - 1; i >= 0; i--) {
      if (_entries[i].role == _ChatRole.assistant) {
        return _entries[i].id;
      }
    }
    return null;
  }

  List<_AgentStepView> _agentStepsFromAttachments(
    List<AiChatAttachment> attachments,
  ) {
    for (final attachment in attachments) {
      if (attachment.type != AiChatAttachmentType.apiResult) continue;
      final metadata = attachment.metadata;
      if (metadata['kind'] != 'agent_steps') continue;
      final rawItems = metadata['items'];
      if (rawItems is! List) continue;
      return rawItems
          .whereType<Map>()
          .map((item) => _AgentStepView.fromJson(
                item.cast<String, dynamic>(),
              ))
          .toList(growable: false);
    }
    return const [];
  }

  List<_ChatResultShortcut> _buildResultShortcuts(
      List<AiActionResult> results) {
    final shortcuts = <_ChatResultShortcut>[];
    for (final result in results) {
      if (!result.success) continue;
      final shortcut = _shortcutFromActionResult(result);
      if (shortcut == null) continue;
      final index = shortcuts.indexWhere((item) => item.sameTarget(shortcut));
      if (index < 0) {
        shortcuts.add(shortcut);
      } else {
        final ids = <String>{...shortcuts[index].ids, ...shortcut.ids}
            .toList(growable: false);
        shortcuts[index] = shortcuts[index].copyWith(ids: ids);
      }
    }
    return shortcuts;
  }

  _ChatResultShortcut? _shortcutFromActionResult(AiActionResult result) {
    final ids = _resultEntityIds(result);
    switch (result.action.type) {
      case AiAppActionType.addTask:
      case AiAppActionType.addTaskDirect:
      case AiAppActionType.generateWeeklyPlan:
      case AiAppActionType.generateTodayMission:
      case AiAppActionType.createLoopFromSource:
        return _ChatResultShortcut(
          kind: _ChatResultShortcutKind.tasks,
          label: '查看任务',
          iconCodePoint: Icons.checklist_rounded.codePoint,
          colorValue: StudyUi.primary.toARGB32(),
          ids: ids
              .where((item) => item.startsWith('task_'))
              .toList(growable: false),
        );
      case AiAppActionType.saveNote:
      case AiAppActionType.summarizeStarredCards:
      case AiAppActionType.noteFromLog:
      case AiAppActionType.noteFromOcr:
        return _ChatResultShortcut(
          kind: _ChatResultShortcutKind.notes,
          label: '查看笔记',
          iconCodePoint: Icons.note_alt_rounded.codePoint,
          colorValue: StudyUi.pathViolet.toARGB32(),
          ids: ids
              .where((item) => item.startsWith('note_'))
              .toList(growable: false),
        );
      case AiAppActionType.addFlashcard:
      case AiAppActionType.generateTodayFlashcards:
      case AiAppActionType.createFlashcardBatch:
        final cardIds =
            ids.where((item) => item.startsWith('fc_')).toList(growable: false);
        return _ChatResultShortcut(
          kind: _ChatResultShortcutKind.flashcards,
          label: cardIds.isNotEmpty ? '去复习' : '查看闪卡',
          iconCodePoint: Icons.style_rounded.codePoint,
          colorValue: StudyUi.pathMint.toARGB32(),
          ids: cardIds,
        );
      default:
        return null;
    }
  }

  List<String> _resultEntityIds(AiActionResult result) {
    final ids = <String>{
      if (result.createdId != null && result.createdId!.trim().isNotEmpty)
        result.createdId!.trim(),
      ...result.candidates
          .map((item) => item.trim())
          .where((item) => _looksLikeEntityId(item)),
    };
    return ids.toList(growable: false);
  }

  List<_ChatResultShortcut> _mergeResultShortcuts(
    List<_ChatResultShortcut> current,
    List<_ChatResultShortcut> incoming,
  ) {
    if (current.isEmpty) return incoming;
    if (incoming.isEmpty) return current;
    final merged = <_ChatResultShortcut>[...current];
    for (final item in incoming) {
      final index = merged.indexWhere((existing) => existing.sameTarget(item));
      if (index < 0) {
        merged.add(item);
      } else {
        final ids =
            <String>{...merged[index].ids, ...item.ids}.toList(growable: false);
        merged[index] = merged[index].copyWith(ids: ids);
      }
    }
    return merged;
  }

  void _openResultShortcut(_ChatResultShortcut shortcut) {
    switch (shortcut.kind) {
      case _ChatResultShortcutKind.tasks:
        _openShellPage(
          widget.onOpenTasks,
          fallbackTabName: 'scenarios',
          label: '任务清单',
        );
        return;
      case _ChatResultShortcutKind.notes:
        _openShellPage(
          widget.onOpenNotes,
          fallbackTabName: 'scenarios',
          label: '学习笔记',
        );
        return;
      case _ChatResultShortcutKind.flashcards:
        final cardIds = shortcut.ids
            .where((item) => item.startsWith('fc_'))
            .toList(growable: false);
        if (cardIds.isNotEmpty && widget.onStartFlashCardReview != null) {
          _showSnack('已打开闪卡复习');
          Navigator.of(context).popUntil((route) => route.isFirst);
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => widget.onStartFlashCardReview!(cardIds),
          );
          return;
        }
        _openShellPage(
          widget.onOpenFlashCards,
          fallbackTabName: 'create',
          label: '闪卡库',
        );
        return;
    }
  }

  Future<void> _syncStoredEntry(_ChatEntry entry) async {
    if (entry.role == _ChatRole.confirmCard) return;
    try {
      final chatHistoryJson = await _storage.getString('chat_sessions');
      if (chatHistoryJson == null || chatHistoryJson.isEmpty) return;
      final sessions = (jsonDecode(chatHistoryJson) as List<dynamic>)
          .map((j) => AiChatSession.fromJson(j as Map<String, dynamic>))
          .toList();
      final sessionIndex = sessions.indexWhere((s) => s.id == _sessionId);
      if (sessionIndex < 0) return;
      final session = sessions[sessionIndex];
      final messageIndex = session.messages.indexWhere((m) => m.id == entry.id);
      if (messageIndex < 0) return;
      final current = session.messages[messageIndex];
      session.messages[messageIndex] = AiChatMessage(
        id: current.id,
        role: current.role,
        content: entry.text,
        timestamp: current.timestamp,
        attachments: _attachmentsForEntry(entry),
      );
      sessions[sessionIndex] = AiChatSession(
        id: session.id,
        title: session.title,
        createdAt: session.createdAt,
        updatedAt: DateTime.now(),
        messages: session.messages,
      );
      await _storage.setString(
        'chat_sessions',
        jsonEncode(sessions.map((s) => s.toJson()).toList()),
      );
    } catch (error) {
      debugPrint('同步聊天消息失败: $error');
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
                  isDarkMode: widget.isDarkMode, controller: widget.controller),
            ));
          } catch (_) {
            if (!mounted) return;
            _showSnack('计时器暂时没打开，请稍后再试');
          }
          break;
        case 'OPEN_FLASHCARD':
          if (!mounted) return;
          try {
            await Navigator.of(context).push(MaterialPageRoute(
              builder: (ctx) => FlashCardPage(
                isDarkMode: widget.isDarkMode,
                controller: widget.controller,
                onOpenNotes: widget.onOpenNotes,
              ),
            ));
          } catch (_) {
            if (!mounted) return;
            _showSnack('闪卡暂时没打开，请稍后再试');
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
          } catch (_) {
            if (!mounted) return;
            _showSnack('这次没有创建成任务，内容还在，可以稍后再试');
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
          } catch (_) {
            if (!mounted) return;
            _showSnack('这次没有保存成学习记录，请稍后再试');
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
              await widget.controller
                  .updateStudyTaskStatus(matched.id, targetStatus);
              final label =
                  targetStatus == StudyTaskStatus.completed ? '已完成' : '进行中';
              if (mounted) {
                _showSnack('任务 "${matched.title}" 已标记为$label');
              }
            } else {
              // 列出所有未完成任务供用户选择
              final pending = tasks
                  .where((t) => t.status != StudyTaskStatus.completed)
                  .toList();
              if (pending.isEmpty) {
                _showSnack('没有找到可操作的任务');
              } else {
                final names = pending.take(5).map((t) => t.title).join('、');
                _showSnack('请指定任务，当前未完成任务：$names');
              }
            }
          } catch (_) {
            if (!mounted) return;
            _showSnack('任务状态暂时没有更新成功，请稍后再试');
          }
          break;

        case 'SAVE_NOTE':
          // 将对话内容保存为笔记
          try {
            final title = '对话笔记 ${DateTime.now().month}/${DateTime.now().day}';
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
          } catch (_) {
            if (!mounted) return;
            _showSnack('这次没有保存成笔记，请稍后再试');
          }
          break;

        case 'SWITCH_CALENDAR':
          _navigateToTab('scenarios');
          break;
        case 'SWITCH_TASKS':
          _openShellPage(
            widget.onOpenTasks,
            fallbackTabName: 'scenarios',
            label: '今日安排',
          );
          break;
        case 'SWITCH_LOGS':
          _openShellPage(
            widget.onOpenLogs,
            fallbackTabName: 'scenarios',
            label: '学习记录',
          );
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

  /// 切换底部 Tab
  void _navigateToTab(String tabName) {
    _showSnack('已切换到${_tabLabel(tabName)}');
    widget.controller.setCurrentPrimaryTab(tabName);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _openShellPage(
    VoidCallback? openPage, {
    required String fallbackTabName,
    required String label,
  }) {
    if (openPage == null) {
      _navigateToTab(fallbackTabName);
      return;
    }
    _showSnack('已打开$label');
    Navigator.of(context).popUntil((route) => route.isFirst);
    WidgetsBinding.instance.addPostFrameCallback((_) => openPage());
  }

  String _tabLabel(String name) => switch (name) {
        'assistant' => '首页',
        'scenarios' => '计划',
        'calendar' => '专注',
        'create' => '复习',
        'profile' => '我的',
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
        input: '请根据以下收藏闪卡整理为一篇可直接保存的 Notion 风格块笔记：',
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
          title: '整理笔记失败',
          message: '这次没有整理成笔记，内容还在，可以稍后再试。',
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
      StudyToast.show(context, '登录后可使用语音识别，也可以先手动输入');
      return;
    }
    try {
      setState(() => _voiceCallActive = true);
      if (mounted) {
        StudyToast.show(context, '语音连续对话已开启，每轮录音后自动发送');
      }
      final cfg = widget.controller.aiConfig;
      await _tts.speak(
        '语音连续对话已开启，请说话吧。',
        language: cfg.voiceLanguage,
        rate: cfg.voiceRate,
      );
      if (!_voiceCallActive || !mounted) return;
      await _listenTurnAndSend();
    } catch (error) {
      await _endVoiceCall();
      _showSnack('语音对话暂时没启动，可先手动输入');
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
      _showSnack('这次没有听清，可手动输入');
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
        _showSnack('语音朗读暂时不可用，可以继续看文字回复');
      } finally {}
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
      StudyToast.show(context, '登录后可使用语音识别，也可以先手动输入');
      return false;
    }
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) return false;
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
        StudyToast.show(context, '语音录制暂时不可用，可手动输入');
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
      StudyToast.show(context, '这次没有听清，可手动输入');
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
      StudyToast.show(context, '正在识别语音...');
    }
    return widget.controller.cloudSpeechService.transcribeBytes(
      await XFile(path).readAsBytes(),
      mimeType: 'audio/m4a',
      longForm: longForm,
    );
  }

  void _scrollToBottom({bool settle = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      void scroll() {
        if (!mounted || !_scrollController.hasClients) return;
        final position = _scrollController.position;
        _scrollController
            .animateTo(
              position.maxScrollExtent,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
            )
            .ignore();
      }

      scroll();
      if (settle) {
        Future<void>.delayed(const Duration(milliseconds: 90), scroll);
        Future<void>.delayed(const Duration(milliseconds: 220), scroll);
        Future<void>.delayed(const Duration(milliseconds: 420), scroll);
      }
    });
  }
}

class _ChatToolbarAction extends StatelessWidget {
  const _ChatToolbarAction({
    required this.tooltip,
    required this.icon,
    required this.accent,
    required this.isDarkMode,
    required this.onPressed,
    this.size = 36,
    this.iconSize = 18,
    this.filled = false,
  });

  final String tooltip;
  final IconData icon;
  final Color accent;
  final bool isDarkMode;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final node = filled
        ? Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: enabled ? 0.92 : 0.26),
                  (accent == StudyUi.danger
                          ? StudyUi.pathWarm
                          : StudyUi.pathCyan)
                      .withValues(alpha: enabled ? 0.82 : 0.18),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDarkMode ? 0.12 : 0.58),
              ),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color:
                            accent.withValues(alpha: isDarkMode ? 0.20 : 0.26),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: Icon(icon, color: Colors.white, size: iconSize),
          )
        : StudyGlassIconNode(
            icon: icon,
            accent: accent,
            size: size,
            iconSize: iconSize,
            isDarkMode: isDarkMode,
          );

    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: enabled ? 1 : 0.42,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onPressed,
          child: node,
        ),
      ),
    );
  }
}

class _SmartQuickPrompt {
  const _SmartQuickPrompt({
    required this.label,
    required this.icon,
    required this.color,
    required this.prompt,
    required this.score,
  });

  final String label;
  final IconData icon;
  final Color color;
  final String prompt;
  final int score;
}

enum _ChatResultShortcutKind { tasks, notes, flashcards }

class _ChatResultShortcut {
  const _ChatResultShortcut({
    required this.kind,
    required this.label,
    required this.iconCodePoint,
    required this.colorValue,
    this.ids = const [],
  });

  final _ChatResultShortcutKind kind;
  final String label;
  final int iconCodePoint;
  final int colorValue;
  final List<String> ids;

  IconData get icon => switch (kind) {
        _ChatResultShortcutKind.tasks => Icons.checklist_rounded,
        _ChatResultShortcutKind.notes => Icons.note_alt_rounded,
        _ChatResultShortcutKind.flashcards => Icons.style_rounded,
      };

  Color get color => Color(colorValue);

  _ChatResultShortcut copyWith({
    String? label,
    int? iconCodePoint,
    int? colorValue,
    List<String>? ids,
  }) {
    return _ChatResultShortcut(
      kind: kind,
      label: label ?? this.label,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      ids: ids ?? this.ids,
    );
  }

  bool sameTarget(_ChatResultShortcut other) {
    return kind == other.kind;
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'label': label,
        'iconCodePoint': iconCodePoint,
        'colorValue': colorValue,
        if (ids.isNotEmpty) 'ids': ids,
      };

  factory _ChatResultShortcut.fromJson(Map<String, dynamic> json) {
    final rawKind = json['kind']?.toString();
    final kind = _ChatResultShortcutKind.values.firstWhere(
      (item) => item.name == rawKind,
      orElse: () => _ChatResultShortcutKind.tasks,
    );
    final rawIds = json['ids'];
    return _ChatResultShortcut(
      kind: kind,
      label: json['label']?.toString() ?? '查看结果',
      iconCodePoint: (json['iconCodePoint'] as num?)?.toInt() ??
          Icons.arrow_forward_rounded.codePoint,
      colorValue:
          (json['colorValue'] as num?)?.toInt() ?? StudyUi.primary.toARGB32(),
      ids: rawIds is List
          ? rawIds.map((item) => item.toString()).toList(growable: false)
          : const [],
    );
  }
}

class _ChatActionPill extends StatelessWidget {
  const _ChatActionPill({
    required this.icon,
    required this.label,
    required this.accent,
    required this.isDarkMode,
    required this.onTap,
    this.filled = false,
    this.expand = false,
    this.subtle = false,
    this.dense = false,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final bool isDarkMode;
  final VoidCallback? onTap;
  final bool filled;
  final bool expand;
  final bool subtle;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final foreground = filled ? Colors.white : accent;
    final background = filled
        ? accent
        : subtle
            ? Colors.white.withValues(alpha: isDarkMode ? 0.06 : 0.54)
            : StudyUi.chipBackground(accent, isDarkMode);
    final borderColor = filled
        ? Colors.white.withValues(alpha: isDarkMode ? 0.12 : 0.40)
        : subtle
            ? accent.withValues(alpha: isDarkMode ? 0.18 : 0.14)
            : accent.withValues(alpha: isDarkMode ? 0.24 : 0.18);
    return Opacity(
      opacity: enabled ? 1 : 0.46,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: expand ? double.infinity : null,
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 6 : 13,
            vertical: dense ? 8 : 9,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
            boxShadow: filled && enabled
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: isDarkMode ? 0.16 : 0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 9),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment:
                expand ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(icon, color: foreground, size: dense ? 14 : 16),
              SizedBox(width: dense ? 4 : 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: filled ? Colors.white : StudyUi.title(isDarkMode),
                    fontSize: dense ? 11 : 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatMarkdownImage extends StatefulWidget {
  const _ChatMarkdownImage({
    required this.uri,
    required this.title,
    required this.alt,
    required this.isDarkMode,
    required this.accent,
    this.onSaveImage,
  });

  final Uri uri;
  final String? title;
  final String? alt;
  final bool isDarkMode;
  final Color accent;
  final Future<void> Function(String url)? onSaveImage;

  @override
  State<_ChatMarkdownImage> createState() => _ChatMarkdownImageState();
}

class _ChatMarkdownImageState extends State<_ChatMarkdownImage> {
  bool _saving = false;

  String get _source {
    if (widget.uri.scheme == 'file') {
      return widget.uri.toFilePath(windows: true);
    }
    return Uri.decodeFull(widget.uri.toString());
  }

  bool get _canSave {
    final source = _source;
    return widget.onSaveImage != null &&
        (source.startsWith('http://') ||
            source.startsWith('https://') ||
            source.startsWith('data:image/'));
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSaveImage!(_source);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildStudyMarkdownImage(
          widget.uri,
          widget.title,
          widget.alt,
          isDarkMode: widget.isDarkMode,
        ),
        if (_canSave)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 6),
            child: _ChatActionPill(
              icon:
                  _saving ? Icons.downloading_rounded : Icons.download_rounded,
              label: _saving ? '保存中' : '保存图片',
              accent: widget.accent,
              isDarkMode: widget.isDarkMode,
              dense: true,
              subtle: true,
              onTap: _saving ? null : _save,
            ),
          ),
      ],
    );
  }
}

class _ThinkingModeDropdownChip extends StatelessWidget {
  const _ThinkingModeDropdownChip({
    required this.label,
    required this.icon,
    required this.accent,
    required this.isDarkMode,
    required this.enabled,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final bool isDarkMode;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final foreground =
        enabled ? accent : StudyUi.muted(isDarkMode).withValues(alpha: 0.62);
    final background = enabled
        ? StudyUi.chipBackground(accent, isDarkMode)
        : StudyUi.surfaceAlt(isDarkMode);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: enabled
              ? accent.withValues(alpha: 0.30)
              : StudyUi.border(isDarkMode),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 12,
                fontWeight: AppTypography.emphasis,
              ),
            ),
          ),
          const SizedBox(width: 3),
          Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: foreground),
        ],
      ),
    );
  }
}

class _ChatSheetSurface extends StatelessWidget {
  const _ChatSheetSurface({
    required this.child,
    required this.isDarkMode,
    this.maxHeightFactor,
  });

  final Widget child;
  final bool isDarkMode;
  final double? maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final constraints = maxHeightFactor == null
        ? const BoxConstraints()
        : BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * maxHeightFactor!,
          );
    final content = maxHeightFactor == null
        ? child
        : Flexible(
            fit: FlexFit.loose,
            child: child,
          );

    return SafeArea(
      child: Container(
        constraints: constraints,
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        decoration: BoxDecoration(
          color: StudyUi.surface(isDarkMode),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border.all(color: StudyUi.border(isDarkMode)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkMode ? 0.24 : 0.08),
              blurRadius: 26,
              offset: const Offset(0, -12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: StudyUi.muted(isDarkMode).withValues(alpha: 0.30),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            content,
          ],
        ),
      ),
    );
  }
}

class _ChatSheetOption extends StatelessWidget {
  const _ChatSheetOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.isDarkMode,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final bool isDarkMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      radius: 18,
      onTap: onTap,
      child: Row(
        children: [
          StudyGlassIconNode(
            icon: icon,
            accent: accent,
            size: 38,
            iconSize: 18,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: StudyUi.title(isDarkMode),
                    fontWeight: FontWeight.w700,
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
      ),
    );
  }
}

// ─── 聊天气泡组件 ───

class _ChatBubble extends StatelessWidget {
  final _ChatEntry entry;
  final bool isDarkMode;
  final Color accent;
  final String userAvatarEmoji;
  final String? userAvatarImagePath;
  final bool isStreaming;
  final bool isThinking;
  final double maxWidth;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  final ValueChanged<_ChatResultShortcut>? onTapResultShortcut;
  final Future<void> Function(String url)? onSaveImage;
  final ValueChanged<_ChatEntry>? onCopyEntry;
  final ValueChanged<_ChatEntry>? onEditEntry;

  const _ChatBubble({
    required this.entry,
    required this.isDarkMode,
    required this.accent,
    required this.userAvatarEmoji,
    required this.userAvatarImagePath,
    this.isStreaming = false,
    this.isThinking = false,
    required this.maxWidth,
    this.selectionMode = false,
    this.selected = false,
    this.onLongPress,
    this.onTap,
    this.onTapResultShortcut,
    this.onSaveImage,
    this.onCopyEntry,
    this.onEditEntry,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = entry.role == _ChatRole.user;
    if (entry.role == _ChatRole.confirmCard) {
      return _buildConfirmCards();
    }
    final hasQuickActions = !selectionMode &&
        !isStreaming &&
        (onCopyEntry != null || onEditEntry != null);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onLongPress: onLongPress,
        onTap: onTap,
        child: Row(
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              _buildAvatar(isUser, accent),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: isUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            gradient: isUser
                                ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      StudyUi.secondary.withValues(alpha: 0.22),
                                      StudyUi.pathViolet
                                          .withValues(alpha: 0.22),
                                    ],
                                  )
                                : LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: isDarkMode
                                        ? [
                                            const Color(0xFF1C2431),
                                            const Color(0xFF222C3B),
                                          ]
                                        : [
                                            Colors.white
                                                .withValues(alpha: 0.96),
                                            const Color(0xFFF7F9FF),
                                          ],
                                  ),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(22),
                              topRight: const Radius.circular(22),
                              bottomLeft: Radius.circular(isUser ? 22 : 8),
                              bottomRight: Radius.circular(isUser ? 8 : 22),
                            ),
                            border: selected
                                ? Border.all(color: accent, width: 1.5)
                                : Border.all(
                                    color: isUser
                                        ? Colors.white.withValues(alpha: 0.12)
                                        : StudyUi.border(isDarkMode),
                                  ),
                            boxShadow: [
                              BoxShadow(
                                color: isUser
                                    ? StudyUi.secondary.withValues(alpha: 0.16)
                                    : Colors.black.withValues(
                                        alpha: isDarkMode ? 0.12 : 0.04),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: isStreaming
                              ? _buildStreamingMessageContent(isUser)
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
                    if (hasQuickActions)
                      Padding(
                        padding: EdgeInsets.only(
                          top: 3,
                          left: isUser ? 0 : 10,
                          right: isUser ? 10 : 0,
                        ),
                        child: _ChatBubbleQuickActions(
                          isDarkMode: isDarkMode,
                          mutedColor: isUser
                              ? (isDarkMode
                                  ? Colors.white.withValues(alpha: 0.72)
                                  : StudyUi.pathViolet.withValues(alpha: 0.78))
                              : StudyUi.muted(isDarkMode),
                          onCopy: onCopyEntry == null
                              ? null
                              : () => onCopyEntry!(entry),
                          onEdit: onEditEntry == null
                              ? null
                              : () => onEditEntry!(entry),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (isUser) ...[
              const SizedBox(width: 8),
              _buildAvatar(isUser, accent),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(bool isUser, Color accent) {
    if (isUser) {
      return StudyUserAvatar(
        avatarImagePath: userAvatarImagePath,
        avatarEmoji: userAvatarEmoji,
        size: 32,
        accent: StudyUi.secondary,
        isDarkMode: isDarkMode,
      );
    }
    return StudyBrandAvatar(
      size: 36,
      accent: accent,
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildMessageContent(bool isUser) {
    final videos = entry.attachments
        .where((item) => item.type == AiChatAttachmentType.video);
    final messageText = _stripInlineMemorySources(_stripVideoTags(entry.text));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        MarkdownBody(
          data: messageText,
          styleSheet: _chatMarkdownStyle(isUser),
          extensionSet: studyMarkdownExtensionSet,
          builders: buildStudyMarkdownBuilders(
            isDarkMode: isDarkMode,
            bodyFontSize: 14,
            textColor: isUser ? Colors.white : StudyUi.title(isDarkMode),
          ),
          sizedImageBuilder: (config) => _ChatMarkdownImage(
            uri: config.uri,
            title: config.title,
            alt: config.alt,
            isDarkMode: isDarkMode,
            accent: accent,
            onSaveImage: onSaveImage,
          ),
        ),
        if (!isUser && entry.agentSteps.isNotEmpty) ...[
          const SizedBox(height: 10),
          _AgentProgressPanel(
            steps: entry.agentSteps,
            isDarkMode: isDarkMode,
            accent: accent,
          ),
        ],
        if (!isUser &&
            entry.undoResults.isNotEmpty &&
            entry.agentSteps.isNotEmpty) ...[
          const SizedBox(height: 8),
          _UndoAgentActionsBar(
            entry: entry,
            isDarkMode: isDarkMode,
            accent: accent,
          ),
        ],
        if (!isUser && entry.resultShortcuts.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: entry.resultShortcuts
                .map(
                  (shortcut) => _ChatActionPill(
                    icon: shortcut.icon,
                    label: shortcut.label,
                    accent: shortcut.color,
                    isDarkMode: isDarkMode,
                    subtle: true,
                    dense: true,
                    onTap: onTapResultShortcut == null
                        ? null
                        : () => onTapResultShortcut!(shortcut),
                  ),
                )
                .toList(growable: false),
          ),
        ],
        if (!isUser && entry.memorySources.isNotEmpty) ...[
          const SizedBox(height: 10),
          _ChatMemorySources(
            sources: entry.memorySources,
            isDarkMode: isDarkMode,
            accent: accent,
          ),
        ],
        for (final video in videos) _VideoAttachmentCard(video: video),
      ],
    );
  }

  Widget _buildStreamingMessageContent(bool isUser) {
    final statusColor = isUser
        ? Colors.white.withValues(alpha: 0.78)
        : StudyUi.body(isDarkMode);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isThinking)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '正在思考...',
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: AppTypography.emphasis,
              ),
            ),
          ),
        if (entry.text.trim().isEmpty)
          _typingDots(isUser ? Colors.white : accent)
        else
          _buildMessageContent(isUser),
      ],
    );
  }

  MarkdownStyleSheet _chatMarkdownStyle(bool isUser) {
    final textColor = isUser ? Colors.white : StudyUi.title(isDarkMode);
    final mutedColor = isUser
        ? Colors.white.withValues(alpha: 0.82)
        : StudyUi.body(isDarkMode);
    return buildStudyMarkdownStyleSheet(
      isDarkMode: isDarkMode,
      bodyHeight: 1.55,
    ).copyWith(
      p: TextStyle(color: textColor, fontSize: 14, height: 1.55),
      strong: TextStyle(color: textColor, fontWeight: FontWeight.w700),
      em: TextStyle(color: mutedColor, fontStyle: FontStyle.italic),
      listBullet: TextStyle(color: textColor),
      h1: TextStyle(
        color: textColor,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
      h2: TextStyle(
        color: textColor,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        height: 1.4,
      ),
      h3: TextStyle(
        color: textColor,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        height: 1.45,
      ),
      blockquote: TextStyle(color: mutedColor, fontSize: 14, height: 1.55),
      code: appCodeTextStyle(
        color: isUser ? Colors.white : StudyUi.secondary,
        backgroundColor: isUser
            ? Colors.white.withValues(alpha: 0.14)
            : StudyUi.surfaceAlt(isDarkMode),
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

  String _stripInlineMemorySources(String text) {
    return text
        .replaceFirst(
          RegExp(
            r'\n{2,}\*\*学习来源\*\*\n(?:- .+(?:\n|$))+',
            multiLine: true,
          ),
          '',
        )
        .trim();
  }

  Widget _typingDots(Color accent) {
    return SizedBox(
      width: 40,
      height: 20,
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
            color: StudyUi.chipBackground(StudyUi.warning, isDarkMode),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  StudyUi.warning.withValues(alpha: isDarkMode ? 0.28 : 0.24),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Icon(Icons.warning_amber_rounded,
                    size: 18, color: StudyUi.warning),
                const SizedBox(width: 6),
                Text('需要你确认这些更改',
                    style: TextStyle(
                      color: StudyUi.warning,
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

class _AgentProgressPanel extends StatelessWidget {
  const _AgentProgressPanel({
    required this.steps,
    required this.isDarkMode,
    required this.accent,
  });

  final List<_AgentStepView> steps;
  final bool isDarkMode;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: StudyUi.chipBackground(accent, isDarkMode),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent.withValues(alpha: isDarkMode ? 0.22 : 0.16),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.route_rounded, size: 14, color: accent),
              const SizedBox(width: 6),
              Text(
                '整理进度',
                style: TextStyle(
                  color: StudyUi.body(isDarkMode),
                  fontSize: 11,
                  fontWeight: AppTypography.emphasis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < steps.length; i++) ...[
            _AgentProgressRow(
              step: steps[i],
              isDarkMode: isDarkMode,
              accent: accent,
            ),
            if (i != steps.length - 1) const SizedBox(height: 7),
          ],
        ],
      ),
    );
  }
}

class _AgentProgressRow extends StatelessWidget {
  const _AgentProgressRow({
    required this.step,
    required this.isDarkMode,
    required this.accent,
  });

  final _AgentStepView step;
  final bool isDarkMode;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final color = switch (step.status) {
      _AgentStepStatus.queued => StudyUi.muted(isDarkMode),
      _AgentStepStatus.running => accent,
      _AgentStepStatus.completed => StudyUi.success,
      _AgentStepStatus.failed => StudyUi.danger,
      _AgentStepStatus.waitingConfirmation => StudyUi.warning,
      _AgentStepStatus.undone => StudyUi.pathMint,
      _AgentStepStatus.info => StudyUi.secondary,
    };
    final icon = switch (step.status) {
      _AgentStepStatus.queued => Icons.pending_actions_rounded,
      _AgentStepStatus.running => Icons.autorenew_rounded,
      _AgentStepStatus.completed => Icons.check_circle_rounded,
      _AgentStepStatus.failed => Icons.error_rounded,
      _AgentStepStatus.waitingConfirmation => Icons.verified_user_rounded,
      _AgentStepStatus.undone => Icons.undo_rounded,
      _AgentStepStatus.info => Icons.info_rounded,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: StudyUi.title(isDarkMode),
                  fontSize: 11.5,
                  fontWeight: AppTypography.emphasis,
                ),
              ),
              if (step.detail.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  step.detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: StudyUi.body(isDarkMode),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _UndoAgentActionsBar extends StatefulWidget {
  const _UndoAgentActionsBar({
    required this.entry,
    required this.isDarkMode,
    required this.accent,
  });

  final _ChatEntry entry;
  final bool isDarkMode;
  final Color accent;

  @override
  State<_UndoAgentActionsBar> createState() => _UndoAgentActionsBarState();
}

class _UndoAgentActionsBarState extends State<_UndoAgentActionsBar> {
  bool _working = false;

  @override
  Widget build(BuildContext context) {
    final count = widget.entry.undoResults.length;
    final color = StudyUi.warning;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _working
          ? null
          : () async {
              final pageState =
                  context.findAncestorStateOfType<_AiChatPageState>();
              if (pageState == null) return;
              setState(() => _working = true);
              await pageState._undoAgentActions(widget.entry);
              if (mounted) setState(() => _working = false);
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: StudyUi.chipBackground(color, widget.isDarkMode),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: widget.isDarkMode ? 0.24 : 0.18),
          ),
        ),
        child: Row(
          children: [
            if (_working)
              SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            else
              Icon(Icons.undo_rounded, size: 15, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '本次帮你改了 $count 项，可撤销',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: StudyUi.title(widget.isDarkMode),
                  fontSize: 11.5,
                  fontWeight: AppTypography.emphasis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _working ? '撤销中' : '撤销',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: AppTypography.emphasis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubbleQuickActions extends StatelessWidget {
  const _ChatBubbleQuickActions({
    required this.isDarkMode,
    required this.mutedColor,
    this.onCopy,
    this.onEdit,
  });

  final bool isDarkMode;
  final Color mutedColor;
  final VoidCallback? onCopy;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ChatBubbleQuickAction(
          tooltip: '复制消息',
          icon: Icons.copy_rounded,
          color: mutedColor,
          onTap: onCopy,
        ),
        const SizedBox(width: 8),
        _ChatBubbleQuickAction(
          tooltip: '编辑消息',
          icon: Icons.edit_rounded,
          color: mutedColor,
          onTap: onEdit,
        ),
      ],
    );
  }
}

class _ChatBubbleQuickAction extends StatelessWidget {
  const _ChatBubbleQuickAction({
    required this.tooltip,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: SizedBox(
          width: 20,
          height: 20,
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}

class _ChatMemorySources extends StatefulWidget {
  const _ChatMemorySources({
    required this.sources,
    required this.isDarkMode,
    required this.accent,
  });

  final List<String> sources;
  final bool isDarkMode;
  final Color accent;

  @override
  State<_ChatMemorySources> createState() => _ChatMemorySourcesState();
}

class _ChatMemorySourcesState extends State<_ChatMemorySources> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final visible = widget.sources.take(3).toList(growable: false);
    final hiddenCount = widget.sources.length - visible.length;
    return Container(
      decoration: BoxDecoration(
        color: StudyUi.chipBackground(widget.accent, widget.isDarkMode),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.accent.withValues(
            alpha: widget.isDarkMode ? 0.22 : 0.16,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_stories_rounded,
                    size: 14,
                    color: widget.accent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '参考了最近 ${widget.sources.length} 条学习记录',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: StudyUi.body(widget.isDarkMode),
                        fontSize: 11,
                        fontWeight: AppTypography.emphasis,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 16,
                    color: StudyUi.muted(widget.isDarkMode),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(
              height: 1,
              color: widget.accent.withValues(alpha: 0.10),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final source in visible) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: widget.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            source,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: StudyUi.body(widget.isDarkMode),
                              fontSize: 11,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (hiddenCount > 0)
                    Text(
                      '还有 $hiddenCount 条已收起',
                      style: TextStyle(
                        color: StudyUi.muted(widget.isDarkMode),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AgentActionGroup {
  const _AgentActionGroup({
    required this.safe,
    required this.dangerous,
  });

  final List<AiAppAction> safe;
  final List<AiAppAction> dangerous;
}

class _LegacyActionTurn {
  const _LegacyActionTurn({
    required this.reply,
    required this.actions,
  });

  final String reply;
  final List<AiAppAction> actions;
}

class _TextRange {
  const _TextRange(this.start, this.end);

  final int start;
  final int end;
}

enum _AgentStepStatus {
  queued,
  running,
  completed,
  failed,
  waitingConfirmation,
  undone,
  info,
}

class _AgentStepView {
  const _AgentStepView({
    required this.title,
    required this.detail,
    required this.status,
  });

  final String title;
  final String detail;
  final _AgentStepStatus status;

  Map<String, dynamic> toJson() => {
        'title': title,
        'detail': detail,
        'status': status.name,
      };

  factory _AgentStepView.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status']?.toString();
    return _AgentStepView(
      title: json['title']?.toString() ?? '',
      detail: json['detail']?.toString() ?? '',
      status: _AgentStepStatus.values.firstWhere(
        (item) => item.name == rawStatus,
        orElse: () => _AgentStepStatus.info,
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
      _ when type.name == 'createLog' =>
        '记录学习：${widget.action.sourceText ?? ""}',
      _ when type.name == 'markTaskStatus' =>
        '标记任务「$_targetLabel」为 $_statusLabel',
      _ when type.name == 'saveNote' => '保存笔记：${widget.action.title ?? ""}',
      _ when type == AiAppActionType.deleteTask => '将任务移入回收站：$_targetLabel',
      _ when type == AiAppActionType.deleteLog => '将学习记录移入回收站：$_targetLabel',
      _ when type == AiAppActionType.deleteNote => '将笔记移入回收站：$_targetLabel',
      _ when type == AiAppActionType.deleteFlashcard =>
        '将闪卡移入回收站：$_targetLabel',
      _ when type == AiAppActionType.overwriteNote => '覆盖已有笔记：$_targetLabel',
      _ when type == AiAppActionType.emptyTrash => '永久清空回收站，无法恢复',
      _ when type == AiAppActionType.logout => '退出当前账号',
      _ when type == AiAppActionType.deleteCourse => '删除课程及相关归属：$_targetLabel',
      _ => '确认这项更改',
    };
  }

  String get _targetLabel {
    return widget.action.targetTitle ??
        widget.action.title ??
        widget.action.sourceText ??
        '这项内容';
  }

  String get _statusLabel {
    return switch ((widget.action.status ?? '').trim()) {
      'completed' => '已完成',
      'in_progress' => '进行中',
      'not_started' => '未开始',
      'starred' => '已收藏',
      'unstarred' => '未收藏',
      'toggle' => '切换状态',
      _ => '新的状态',
    };
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
          const Icon(Icons.check_circle, size: 16, color: StudyUi.success),
          const SizedBox(width: 6),
          Text('已确认',
              style: TextStyle(
                  color: StudyUi.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
      );
    }
    if (_cancelled) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          const Icon(Icons.cancel, size: 16, color: StudyUi.danger),
          const SizedBox(width: 6),
          Text('已取消',
              style: TextStyle(
                  color: StudyUi.danger,
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
                color: StudyUi.title(widget.isDarkMode),
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _ChatActionPill(
            icon: Icons.close_rounded,
            label: '取消',
            accent: StudyUi.muted(widget.isDarkMode),
            isDarkMode: widget.isDarkMode,
            onTap: _cancel,
          ),
          const SizedBox(width: 8),
          _ChatActionPill(
            icon: Icons.check_rounded,
            label: '确认',
            accent: widget.accent,
            isDarkMode: widget.isDarkMode,
            onTap: _execute,
            filled: true,
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
          StudyToast.show(context, '短片链接已复制');
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.copy_rounded, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title ?? '复制短片链接',
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
              const Icon(Icons.chevron_right_rounded, size: 18),
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
    this.memorySources = const [],
    this.agentSteps = const [],
    this.undoResults = const [],
    this.resultShortcuts = const [],
    this.undoApplied = false,
    this.confirmActions = const [],
  });
  final String id;
  final _ChatRole role;
  final String text;
  final List<AiChatAttachment> attachments;
  final List<String> memorySources;
  final List<_AgentStepView> agentSteps;
  final List<AiActionResult> undoResults;
  final List<_ChatResultShortcut> resultShortcuts;
  final bool undoApplied;
  final List<AiAppAction> confirmActions; // 待确认的危险动作

  _ChatEntry copyWith({
    String? text,
    List<AiChatAttachment>? attachments,
    List<String>? memorySources,
    List<_AgentStepView>? agentSteps,
    List<AiActionResult>? undoResults,
    List<_ChatResultShortcut>? resultShortcuts,
    bool? undoApplied,
    List<AiAppAction>? confirmActions,
  }) {
    return _ChatEntry(
      id: id,
      role: role,
      text: text ?? this.text,
      attachments: attachments ?? this.attachments,
      memorySources: memorySources ?? this.memorySources,
      agentSteps: agentSteps ?? this.agentSteps,
      undoResults: undoResults ?? this.undoResults,
      resultShortcuts: resultShortcuts ?? this.resultShortcuts,
      undoApplied: undoApplied ?? this.undoApplied,
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
    if (trimmed.startsWith('- [ ] ') ||
        trimmed.startsWith('- [x] ') ||
        trimmed.startsWith('* [ ] ') ||
        trimmed.startsWith('* [x] ')) {
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
    if (trimmed.startsWith('**') &&
        trimmed.endsWith('**') &&
        trimmed.length > 4) {
      blocks.add({
        'id': bid(),
        'type': 'heading',
        'content': trimmed.substring(2, trimmed.length - 2).trim(),
      });
      continue;
    }

    // 普通文本：长段自动切成多个可编辑块，避免保存成一整坨。
    blocks.addAll(_smartMarkdownTextBlocks(trimmed, bid));
  }

  return blocks;
}

List<Map<String, dynamic>> _smartMarkdownTextBlocks(
  String text,
  String Function() bid,
) {
  return _smartMarkdownParagraphs(text)
      .map((paragraph) => {
            'id': bid(),
            'type': 'text',
            'content': paragraph,
          })
      .toList(growable: false);
}

List<String> _smartMarkdownParagraphs(String text) {
  final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) return const [];
  if (normalized.length <= 120) return [normalized];

  final sentences = RegExp(r'[^。！？!?；;]+[。！？!?；;]?')
      .allMatches(normalized)
      .map((match) => match.group(0)?.trim() ?? '')
      .where((sentence) => sentence.isNotEmpty)
      .toList(growable: false);
  if (sentences.length <= 1) {
    return _splitLongMarkdownText(normalized, 120);
  }

  final result = <String>[];
  final buffer = StringBuffer();
  for (final sentence in sentences) {
    final nextLength = buffer.length + sentence.length;
    if (buffer.isNotEmpty && nextLength > 140) {
      result.add(buffer.toString().trim());
      buffer.clear();
    }
    if (sentence.length > 160) {
      if (buffer.isNotEmpty) {
        result.add(buffer.toString().trim());
        buffer.clear();
      }
      result.addAll(_splitLongMarkdownText(sentence, 120));
    } else {
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(sentence);
    }
  }
  if (buffer.isNotEmpty) result.add(buffer.toString().trim());
  return result.where((item) => item.isNotEmpty).toList(growable: false);
}

List<String> _splitLongMarkdownText(String text, int maxLength) {
  final result = <String>[];
  var start = 0;
  while (start < text.length) {
    var end = (start + maxLength).clamp(0, text.length).toInt();
    if (end < text.length) {
      final comma = text.lastIndexOf(RegExp(r'[，,、：:]'), end);
      if (comma > start + 40) end = comma + 1;
    }
    result.add(text.substring(start, end).trim());
    start = end;
  }
  return result.where((item) => item.isNotEmpty).toList(growable: false);
}
