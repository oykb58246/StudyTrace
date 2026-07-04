import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../controllers/app_data_controller.dart';
import '../../models/ai_app_action.dart';
import '../../models/ai_generated_log.dart';
import '../../models/ai_risk_warning.dart';
import '../../models/ai_study_analysis.dart';
import '../../models/ai_task_plan.dart';
import '../../models/study_sub_task_item.dart';
import '../../models/study_task_item.dart';
import '../../models/vivo_capability.dart';
import '../../services/ai_study_service.dart';
import '../../services/ai_exceptions.dart';
import '../../theme/app_theme.dart';
import '../shared/app_assets.dart';
import '../shared/common_widgets.dart';
import 'ai_chat_page.dart';

enum _SmartInputTarget { log, task }

class AiAssistantPage extends StatefulWidget {
  const AiAssistantPage({
    super.key,
    required this.isDarkMode,
    required this.controller,
    this.onOpenSettings,
    this.onExecuteActions,
    this.onOpenTasks,
    this.onOpenLogs,
    this.onOpenNotes,
    this.onOpenFlashCards,
    this.onStartFlashCardReview,
  });

  final bool isDarkMode;
  final AppDataController controller;
  final VoidCallback? onOpenSettings;
  final AiActionHandler? onExecuteActions;
  final VoidCallback? onOpenTasks;
  final VoidCallback? onOpenLogs;
  final VoidCallback? onOpenNotes;
  final VoidCallback? onOpenFlashCards;
  final ValueChanged<List<String>>? onStartFlashCardReview;

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  late final AiStudyService _aiService;
  final _imagePicker = ImagePicker();
  final _speech = stt.SpeechToText();
  final _logInputController = TextEditingController();
  final _taskInputController = TextEditingController();
  final _logSectionKey = GlobalKey();
  final _taskSectionKey = GlobalKey();
  final _analysisSectionKey = GlobalKey();
  final _warningSectionKey = GlobalKey();
  final _flashcardSectionKey = GlobalKey();

  // 整理学习日志
  AiGeneratedLog? _generatedLog;
  bool _isGeneratingLog = false;

  // 拆解学习任务
  AiTaskPlan? _taskPlan;
  bool _isGeneratingTask = false;

  // 分析周报
  AiStudyAnalysis? _analysis;
  bool _isGeneratingAnalysis = false;
  GeneratedVideoTask? _analysisVideoTask;
  bool _isGeneratingAnalysisVideo = false;
  bool _isRefreshingAnalysisVideo = false;

  // 风险提醒
  List<AiRiskWarning>? _warnings;
  bool _isGeneratingWarnings = false;

  // 整理今日闪卡
  bool _isGeneratingFlashcards = false;
  String? _flashcardsMessage;
  bool _flashcardsSuccess = false;
  String? _savedLogMessage;
  String? _savedTaskMessage;

  bool _isListening = false;
  TextEditingController? _speechTarget;

  @override
  void initState() {
    super.initState();
    _aiService = widget.controller.aiStudyService;
  }

  @override
  void dispose() {
    _speech.stop();
    _logInputController.dispose();
    _taskInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = StudyUi.pathViolet;
    final titleColor = StudyUi.title(widget.isDarkMode);
    final bodyColor = StudyUi.body(widget.isDarkMode);
    final compactHeader = StudyCompactHeaderScope.of(context);

    return ListView(
      key: const Key('page_ai_assistant'),
      padding: EdgeInsets.fromLTRB(22, compactHeader ? 8 : 66, 22, 124),
      children: [
        _assistantHero(
          titleColor: titleColor,
          bodyColor: bodyColor,
        ),
        const SizedBox(height: 14),

        // 1. 2分钟复盘
        KeyedSubtree(
          key: _logSectionKey,
          child: _buildSectionCard(
            iconAsset: AppAssets.featureLogIcon,
            iconColor: StudyUi.secondary,
            tagLabel: '先做',
            tagColor: StudyUi.secondary,
            title: '说说今天学了什么',
            subtitle: '写下今天学了什么、卡在哪里，我帮你整理成一条清楚的复盘',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _logInputController,
                  maxLines: 3,
                  style: TextStyle(
                    color: StudyUi.title(widget.isDarkMode),
                    fontSize: 14,
                  ),
                  decoration: _inputDeco(
                    '例：今天做高数极限题，洛必达适用条件还不熟，下一步想整理判断清单...',
                  ),
                ),
                const SizedBox(height: 10),
                _buildSmartInputBar(
                  target: _SmartInputTarget.log,
                  controller: _logInputController,
                ),
                const SizedBox(height: 12),
                _AssistantActionButton(
                  icon: Icons.edit_note_rounded,
                  label: _isGeneratingLog ? '整理中...' : '帮我整理',
                  color: StudyUi.secondary,
                  isDarkMode: widget.isDarkMode,
                  expand: true,
                  onPressed: _isGeneratingLog ? null : _handleGenerateLog,
                  busyIcon: _isGeneratingLog
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),

        // 显示复盘整理结果
        if (_generatedLog != null && !_generatedLog!.isEmpty) ...[
          const SizedBox(height: 14),
          _AiResultCard(
            isDarkMode: widget.isDarkMode,
            title: '复盘结果',
            onEdit: (updated) {
              setState(() => _generatedLog = updated);
            },
            generatedLog: _generatedLog!,
            onSave: _handleSaveLog,
          ),
        ],
        if (_savedLogMessage != null) ...[
          const SizedBox(height: 14),
          _AssistantSaveNextStepCard(
            message: _savedLogMessage!,
            icon: Icons.edit_note_rounded,
            color: StudyUi.secondary,
            isDarkMode: widget.isDarkMode,
            actionLabel: '去学习记录',
            onTap: widget.onOpenLogs,
          ),
        ],

        const SizedBox(height: 22),

        // 2. 拆解学习任务
        KeyedSubtree(
          key: _taskSectionKey,
          child: _buildSectionCard(
            iconAsset: AppAssets.featureTaskPlanIcon,
            iconColor: accent,
            tagLabel: '常用',
            tagColor: accent,
            title: '把大任务拆小',
            subtitle: '把现在最卡的一件事写进来，我会帮你拆成能直接开做的小步骤',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _taskInputController,
                  maxLines: 3,
                  style: TextStyle(
                    color: StudyUi.title(widget.isDarkMode),
                    fontSize: 14,
                  ),
                  decoration: _inputDeco(
                    '例：下周五前完成操作系统实验报告和课堂汇报',
                  ),
                ),
                const SizedBox(height: 10),
                _buildSmartInputBar(
                  target: _SmartInputTarget.task,
                  controller: _taskInputController,
                ),
                const SizedBox(height: 12),
                _AssistantActionButton(
                  icon: Icons.account_tree_rounded,
                  label: _isGeneratingTask ? '拆解中...' : '帮我拆开',
                  color: accent,
                  isDarkMode: widget.isDarkMode,
                  expand: true,
                  onPressed: _isGeneratingTask ? null : _handleGenerateTask,
                  busyIcon: _isGeneratingTask
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),

        // 显示任务拆解结果
        if (_taskPlan != null && _taskPlan!.mainTitle.isNotEmpty) ...[
          const SizedBox(height: 14),
          _TaskPlanResultCard(
            isDarkMode: widget.isDarkMode,
            plan: _taskPlan!,
            onAddTask: _handleAddTask,
            accentColor: accent,
          ),
        ],
        if (_savedTaskMessage != null) ...[
          const SizedBox(height: 14),
          _AssistantSaveNextStepCard(
            message: _savedTaskMessage!,
            icon: Icons.flag_rounded,
            color: accent,
            isDarkMode: widget.isDarkMode,
            actionLabel: '打开任务清单',
            onTap: widget.onOpenTasks,
          ),
        ],

        const SizedBox(height: 22),

        // 3. 整理本周复盘
        KeyedSubtree(
          key: _analysisSectionKey,
          child: _buildSectionCard(
            iconAsset: AppAssets.sideDashboardIcon,
            iconColor: StudyUi.success,
            tagLabel: '回看',
            tagColor: StudyUi.success,
            title: '整理这周回顾',
            subtitle: '根据这周的记录和任务，帮你拉出一版能回看的学习总结',
            child: _AssistantActionButton(
              icon: Icons.analytics_rounded,
              label: _isGeneratingAnalysis ? '整理中...' : '开始整理',
              color: StudyUi.success,
              isDarkMode: widget.isDarkMode,
              expand: true,
              onPressed: _isGeneratingAnalysis ? null : _handleGenerateAnalysis,
              busyIcon: _isGeneratingAnalysis
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
          ),
        ),
        // 显示本周复盘结果
        if (_analysis != null) ...[
          const SizedBox(height: 14),
          _AnalysisResultCard(
            isDarkMode: widget.isDarkMode,
            analysis: _analysis!,
            onSave: _handleSaveAnalysis,
            onCopy: _handleCopyAnalysis,
            videoTask: _analysisVideoTask,
            isGeneratingVideo: _isGeneratingAnalysisVideo,
            isRefreshingVideo: _isRefreshingAnalysisVideo,
            onGenerateVideo: _handleGenerateAnalysisVideo,
            onRefreshVideo: _handleRefreshAnalysisVideo,
          ),
        ],

        const SizedBox(height: 22),

        // 4. 进度提醒
        KeyedSubtree(
          key: _warningSectionKey,
          child: _buildSectionCard(
            iconAsset: AppAssets.featureWarningIcon,
            iconColor: StudyUi.warning,
            tagLabel: '检查',
            tagColor: StudyUi.warning,
            title: '看看哪件事快来不及',
            subtitle: '帮你检查截止时间、断档和完成情况，先把容易掉线的地方找出来',
            child: _AssistantActionButton(
              icon: Icons.warning_amber_rounded,
              label: _isGeneratingWarnings ? '检查中...' : '帮我看看',
              color: StudyUi.warning,
              isDarkMode: widget.isDarkMode,
              expand: true,
              onPressed: _isGeneratingWarnings ? null : _handleGenerateWarnings,
              busyIcon: _isGeneratingWarnings
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
          ),
        ),
        // 显示风险提醒
        if (_warnings != null && _warnings!.isNotEmpty) ...[
          const SizedBox(height: 14),
          for (final warning in _warnings!)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _WarningCard(
                isDarkMode: widget.isDarkMode,
                warning: warning,
              ),
            ),
        ],
        if (_warnings != null && _warnings!.isEmpty) ...[
          const SizedBox(height: 14),
          StudyCard(
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: StudyUi.success, size: 24),
                const SizedBox(width: 12),
                Text(
                  '当前没有明显学习难点，继续保持！',
                  style: TextStyle(
                    color: bodyColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 22),

        // 5. 整理今日闪卡
        KeyedSubtree(
          key: _flashcardSectionKey,
          child: _buildSectionCard(
            iconAsset: AppAssets.featureFlashcardIcon,
            iconColor: StudyUi.success,
            tagLabel: '复习',
            tagColor: StudyUi.pathMint,
            title: '把今天内容变成闪卡',
            subtitle: '从今天的学习记录里抽问题和答案，顺手就能进入复习',
            child: _AssistantActionButton(
              icon: Icons.style_rounded,
              label: _isGeneratingFlashcards ? '整理中...' : '生成今日闪卡',
              color: StudyUi.success,
              isDarkMode: widget.isDarkMode,
              expand: true,
              onPressed:
                  _isGeneratingFlashcards ? null : _handleGenerateFlashcards,
              busyIcon: _isGeneratingFlashcards
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
          ),
        ),
        if (_flashcardsMessage != null) ...[
          const SizedBox(height: 10),
          _AssistantSaveNextStepCard(
            message: _flashcardsMessage!,
            icon: _flashcardsSuccess
                ? Icons.check_circle_rounded
                : Icons.info_outline_rounded,
            color: _flashcardsSuccess ? StudyUi.success : StudyUi.warning,
            isDarkMode: widget.isDarkMode,
            actionLabel: _flashcardsSuccess ? '去知识闪卡' : null,
            onTap: _flashcardsSuccess ? widget.onOpenFlashCards : null,
          ),
        ],
      ],
    );
  }

  // ============ Build Helpers ============

  Widget _assistantHero({
    required Color titleColor,
    required Color bodyColor,
  }) {
    final online = widget.controller.isLoggedIn;
    final statusColor = online ? StudyUi.pathMint : StudyUi.pathWarm;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayLogs = widget.controller.studyLogs
        .where((log) => !log.date.isBefore(today))
        .length;
    final openTasks = widget.controller.studyTasks
        .where((task) => task.effectiveStatus != StudyTaskStatus.completed)
        .toList();
    final overdueCount =
        openTasks.where((task) => task.deadline.isBefore(now)).length;
    final canReviewThisWeek = widget.controller.studyLogs.length >= 3;
    final focusAction = _resolveAssistantFocusAction(
      todayLogs: todayLogs,
      overdueCount: overdueCount,
      openTaskCount: openTasks.length,
      canReviewThisWeek: canReviewThisWeek,
    );

    return StudyPathHero(
      isDarkMode: widget.isDarkMode,
      accent: StudyUi.pathViolet,
      badge: '学习整理台',
      title: '先把眼前这件事理清楚',
      subtitle: '这里主要帮你整理复盘、拆任务、拉回顾和做闪卡，不用一上来把所有功能都点一遍。',
      icon: Icons.auto_awesome_rounded,
      child: Column(
        children: [
          StudyCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                StudyGlassIconNode(
                  icon: online
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_off_rounded,
                  accent: statusColor,
                  size: 42,
                  iconSize: 18,
                  isDarkMode: widget.isDarkMode,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        online ? '可以开始整理了' : '登录后可备份整理记录',
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 15,
                          fontWeight: AppTypography.hero,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        online ? '可以备份学习资料并整理复盘' : '本地内容可编辑，登录后可继续整理',
                        style: TextStyle(color: bodyColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                BadgePill(
                  label: online ? '在线' : '本地',
                  background: statusColor.withValues(
                    alpha: widget.isDarkMode ? 0.20 : 0.12,
                  ),
                  foreground: statusColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _AssistantFocusCard(
            title: focusAction.title,
            detail: focusAction.detail,
            actionLabel: focusAction.actionLabel,
            icon: focusAction.icon,
            color: focusAction.color,
            isDarkMode: widget.isDarkMode,
            onTap: focusAction.onTap,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _AssistantActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: '学习对话',
                  color: StudyUi.pathViolet,
                  isDarkMode: widget.isDarkMode,
                  filled: false,
                  expand: true,
                  onPressed: _openAiChatPage,
                ),
              ),
              if (widget.onOpenSettings != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _AssistantActionButton(
                    icon: Icons.tune_rounded,
                    label: '整理设置',
                    color: StudyUi.pathBlue,
                    isDarkMode: widget.isDarkMode,
                    filled: false,
                    expand: true,
                    onPressed: widget.onOpenSettings,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  _AssistantFocusAction _resolveAssistantFocusAction({
    required int todayLogs,
    required int overdueCount,
    required int openTaskCount,
    required bool canReviewThisWeek,
  }) {
    if (todayLogs == 0) {
      return _AssistantFocusAction(
        title: '今天先补一条复盘',
        detail: '先把今天学了什么、卡在哪里说出来，后面的拆任务和闪卡都会更准。',
        actionLabel: '去复盘',
        icon: Icons.edit_note_rounded,
        color: StudyUi.secondary,
        onTap: () => _scrollToSection(_logSectionKey),
      );
    }
    if (overdueCount > 0 || openTaskCount > 2) {
      return _AssistantFocusAction(
        title: '把最卡的一件任务拆小',
        detail: '现在更适合先把大任务拆成小步骤，做起来会更容易进入状态。',
        actionLabel: '去拆任务',
        icon: Icons.account_tree_rounded,
        color: StudyUi.pathViolet,
        onTap: () => _scrollToSection(_taskSectionKey),
      );
    }
    if (canReviewThisWeek && openTaskCount <= 1) {
      return _AssistantFocusAction(
        title: '把这周内容整理成回顾',
        detail: '这几天已经积累了一些学习记录，现在拉一版回顾，会更容易看见节奏。',
        actionLabel: '去看回顾',
        icon: Icons.analytics_rounded,
        color: StudyUi.success,
        onTap: () => _scrollToSection(_analysisSectionKey),
      );
    }
    if (todayLogs > 0) {
      return _AssistantFocusAction(
        title: '顺手把今天内容变成闪卡',
        detail: '已经有学习记录了，直接转成问答闪卡，晚点复习会很省力。',
        actionLabel: '去做闪卡',
        icon: Icons.style_rounded,
        color: StudyUi.pathMint,
        onTap: () => _scrollToSection(_flashcardSectionKey),
      );
    }
    return _AssistantFocusAction(
      title: '看看哪件事快来不及',
      detail: '如果你一时不知道先从哪下手，就先看看最近有没有快到期的事。',
      actionLabel: '去检查',
      icon: Icons.warning_amber_rounded,
      color: StudyUi.warning,
      onTap: () => _scrollToSection(_warningSectionKey),
    );
  }

  Future<void> _scrollToSection(GlobalKey key) async {
    final context = key.currentContext;
    if (context == null) return;
    await Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  void _openAiChatPage() {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 340),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, __, ___) => AiChatPage(
          isDarkMode: widget.isDarkMode,
          controller: widget.controller,
          onExecuteActions: widget.onExecuteActions,
          onOpenTasks: widget.onOpenTasks,
          onOpenLogs: widget.onOpenLogs,
          onOpenNotes: widget.onOpenNotes,
          onOpenFlashCards: widget.onOpenFlashCards,
          onStartFlashCardReview: widget.onStartFlashCardReview,
          currentLocation: widget.controller.currentPrimaryTab,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionCard({
    required String iconAsset,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget child,
    String? tagLabel,
    Color? tagColor,
  }) {
    final titleColor = StudyUi.title(widget.isDarkMode);
    final bodyColor = StudyUi.body(widget.isDarkMode);
    final badgeColor = tagColor ?? iconColor;

    return StudyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StudyGlassIconNode(
                asset: iconAsset,
                accent: iconColor,
                size: 40,
                iconSize: 20,
                isDarkMode: widget.isDarkMode,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: titleColor,
                            fontSize: 16,
                            fontWeight: AppTypography.hero)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(color: bodyColor, fontSize: 12)),
                  ],
                ),
              ),
              if (tagLabel != null)
                BadgePill(
                  label: tagLabel,
                  background: badgeColor.withValues(alpha: 0.12),
                  foreground: badgeColor,
                ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildSmartInputBar({
    required _SmartInputTarget target,
    required TextEditingController controller,
  }) {
    final activeSpeech = _isListening && identical(_speechTarget, controller);
    return Row(
      children: [
        _smartInputButton(
          tooltip: '从相册识别文字',
          icon: Icons.image_search_rounded,
          onPressed: () => _handleImageInput(
            target: target,
            source: ImageSource.gallery,
          ),
        ),
        const SizedBox(width: 8),
        _smartInputButton(
          tooltip: '拍照识别文字',
          icon: Icons.photo_camera_rounded,
          onPressed: () => _handleImageInput(
            target: target,
            source: ImageSource.camera,
          ),
        ),
        const SizedBox(width: 8),
        _smartInputButton(
          tooltip: activeSpeech ? '停止语音输入' : '语音输入',
          icon: activeSpeech ? Icons.stop_rounded : Icons.mic_rounded,
          isActive: activeSpeech,
          onPressed: () => _toggleSpeechInput(target, controller),
        ),
      ],
    );
  }

  Widget _smartInputButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    final accent = widget.controller.primaryColor;
    final color = isActive ? const Color(0xFFF77D8E) : accent;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 42,
        height: 38,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPressed,
            child: Ink(
              decoration: BoxDecoration(
                color: StudyUi.chipBackground(color, widget.isDarkMode),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: color.withValues(alpha: isActive ? 0.36 : 0.18),
                ),
                boxShadow: [
                  if (!widget.isDarkMode)
                    BoxShadow(
                      color: color.withValues(alpha: isActive ? 0.18 : 0.10),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                ],
              ),
              child: Center(
                child: Icon(icon, size: 19, color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String? hint) {
    final borderColor = StudyUi.border(widget.isDarkMode);
    final accent = widget.controller.primaryColor;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: widget.isDarkMode
            ? Colors.white.withValues(alpha: 0.4)
            : Colors.black.withValues(alpha: 0.35),
        fontSize: 13,
      ),
      filled: true,
      fillColor: StudyUi.surfaceAlt(widget.isDarkMode).withValues(
        alpha: widget.isDarkMode ? 0.72 : 0.86,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: accent.withValues(alpha: 0.48)),
      ),
    );
  }

  // ============ Handlers ============

  Future<void> _handleImageInput({
    required _SmartInputTarget target,
    required ImageSource source,
  }) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 92,
      );
      if (picked == null) return;

      InputImage inputImage;
      try {
        inputImage = InputImage.fromFilePath(picked.path);
      } catch (_) {
        _showSnack('图片文件读取失败，请重试');
        return;
      }

      // 优先使用云端图片理解，回退到设备端 OCR
      final bytes = await picked.readAsBytes();
      final imageBase64 = base64Encode(bytes);
      String text;
      try {
        if (widget.controller.isLoggedIn) {
          // 在线服务分析图片内容
          text = await _aiService.generateAssistantReply(
            input: target == _SmartInputTarget.log
                ? '请详细描述这张图片的内容，提取关键信息用于学习记录'
                : '请分析这张图片的任务要求，提取关键信息',
            imageBase64: imageBase64,
          );
        } else {
          // 回退到设备端 OCR
          final recognizer = TextRecognizer(
            script: TextRecognitionScript.chinese,
          );
          final result = await recognizer.processImage(inputImage);
          await recognizer.close();
          text = result.text.trim();
        }
      } catch (_) {
        // Fallback OCR
        try {
          final recognizer = TextRecognizer();
          final result = await recognizer.processImage(inputImage);
          await recognizer.close();
          text = result.text.trim();
        } catch (e) {
          _showSnack('图片识别失败，请重试');
          return;
        }
      }

      if (text.isEmpty) {
        _showSnack('没有识别到文字，请确保图片中包含清晰文字');
        return;
      }
      final confirmed = await _showSmartInputPreview(
        title: target == _SmartInputTarget.log ? '图片识别为学习描述' : '图片识别为任务描述',
        initialText: text,
      );
      if (confirmed == null || confirmed.trim().isEmpty) return;
      final targetController = _controllerFor(target);
      targetController.text = confirmed.trim();
      _moveCursorToEnd(targetController);
    } on PlatformException {
      _showSnack('图片识别失败，可手动输入内容');
    } catch (_) {
      _showSnack('图片识别失败，可手动输入内容');
    }
  }

  Future<String?> _showSmartInputPreview({
    required String title,
    required String initialText,
  }) async {
    final controller = TextEditingController(text: initialText);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final textColor = StudyUi.title(widget.isDarkMode);
        final accent = widget.controller.primaryColor;
        return Dialog(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.black.withValues(alpha: 0.12),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: _AssistantDialogSurface(
            isDarkMode: widget.isDarkMode,
            accent: accent,
            icon: Icons.document_scanner_rounded,
            title: title,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  maxLines: 8,
                  style: TextStyle(color: textColor, fontSize: 14),
                  decoration: _inputDeco('可以先检查识别文字，再填入学习内容'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _AssistantActionButton(
                        icon: Icons.close_rounded,
                        label: '取消',
                        color: StudyUi.muted(widget.isDarkMode),
                        isDarkMode: widget.isDarkMode,
                        filled: false,
                        expand: true,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _AssistantActionButton(
                        icon: Icons.input_rounded,
                        label: '填入',
                        color: accent,
                        isDarkMode: widget.isDarkMode,
                        expand: true,
                        onPressed: () =>
                            Navigator.of(context).pop(controller.text),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<void> _toggleSpeechInput(
    _SmartInputTarget target,
    TextEditingController controller,
  ) async {
    try {
      if (_isListening && identical(_speechTarget, controller)) {
        await _speech.stop();
        if (mounted) {
          setState(() {
            _isListening = false;
            _speechTarget = null;
          });
        }
        return;
      }

      if (_isListening) {
        await _speech.stop();
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
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _isListening = false;
            _speechTarget = null;
          });
          _showSnack('语音识别失败，可手动输入内容');
        },
      );
      if (!available) {
        _showSnack('当前设备不可用语音识别');
        return;
      }

      setState(() {
        _isListening = true;
        _speechTarget = controller;
      });
      await _speech.listen(
        localeId: 'zh_CN',
        listenFor: const Duration(minutes: 1),
        pauseFor: const Duration(seconds: 4),
        listenOptions: stt.SpeechListenOptions(partialResults: true),
        onResult: (result) {
          controller.text = result.recognizedWords;
          _moveCursorToEnd(controller);
          if (result.finalResult && mounted) {
            setState(() {
              _isListening = false;
              _speechTarget = null;
            });
          }
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _speechTarget = null;
      });
      _showSnack('语音识别不可用，可手动输入内容');
    }
  }

  TextEditingController _controllerFor(_SmartInputTarget target) {
    return target == _SmartInputTarget.log
        ? _logInputController
        : _taskInputController;
  }

  void _moveCursorToEnd(TextEditingController controller) {
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    StudyToast.show(context, message);
  }

  String _assistantErrorMessage(String fallback, AiServiceException error) {
    final message = error.message.trim();
    if (message.isEmpty ||
        message.contains('HTTP') ||
        message.contains('Exception') ||
        message.contains('服务器') ||
        message.contains('后端') ||
        message.contains('客户端') ||
        message.contains('status') ||
        message.contains('targetId')) {
      return fallback;
    }
    if (message.contains('在线整理') || message.contains('服务')) {
      return '学习助手暂时忙不过来，请稍后再试';
    }
    return message;
  }

  Future<void> _handleGenerateLog() async {
    final input = _logInputController.text.trim();
    if (input.isEmpty) {
      StudyToast.show(context, '请先输入学习情况描述');
      return;
    }
    setState(() {
      _isGeneratingLog = true;
      _savedLogMessage = null;
    });
    try {
      final result = await _aiService.generateStudyLog(input);
      setState(() => _generatedLog = result);
    } on AiServiceException catch (error) {
      _showSnack(_assistantErrorMessage('这次没有整理成学习记录，请稍后再试', error));
    } catch (_) {
      _showSnack('这次没有整理成学习记录，请稍后再试');
    } finally {
      if (mounted) setState(() => _isGeneratingLog = false);
    }
  }

  Future<void> _handleSaveLog() async {
    if (_generatedLog == null) return;
    final log = _generatedLog!;
    try {
      await widget.controller.addStudyLog(
        date: DateTime.now(),
        courseName: log.courseName,
        content: log.content,
        problems: log.problems,
        thoughts: log.thoughts,
        nextPlan: log.nextPlan,
      );
      if (!mounted) return;
      StudyToast.show(context, '学习记录已保存');
      setState(() {
        _generatedLog = null;
        _logInputController.clear();
        _savedLogMessage = '学习记录已保存，回到记录页就能接着补今天的难点。';
      });
    } catch (_) {
      _showSnack('学习记录暂时没有保存成功，请稍后再试');
    }
  }

  Future<void> _handleGenerateTask() async {
    final input = _taskInputController.text.trim();
    if (input.isEmpty) {
      StudyToast.show(context, '请先输入任务描述');
      return;
    }
    setState(() {
      _isGeneratingTask = true;
      _savedTaskMessage = null;
    });
    try {
      final result = await _aiService.generateTaskPlan(input);
      setState(() => _taskPlan = result);
    } on AiServiceException catch (error) {
      _showSnack(_assistantErrorMessage('这次没有拆成任务，请稍后再试', error));
    } catch (_) {
      _showSnack('这次没有拆成任务，请稍后再试');
    } finally {
      if (mounted) setState(() => _isGeneratingTask = false);
    }
  }

  Future<void> _handleAddTask() async {
    if (_taskPlan == null) return;
    final plan = _taskPlan!;

    final noteBuffer = StringBuffer();
    if (plan.difficulty.isNotEmpty) noteBuffer.writeln('难度：${plan.difficulty}');
    if (plan.schedule.isNotEmpty) {
      noteBuffer.writeln('推荐安排：');
      noteBuffer.writeln(plan.schedule);
    }

    // Convert AiPlannedSubTask → StudySubTaskItem
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
            .map((s) => StudySubTaskItem(
                  id: 'sub_${now.microsecondsSinceEpoch}_${plan.subTasks.indexOf(s)}',
                  title: s,
                  deadline: plan.deadline,
                  createdAt: now,
                  updatedAt: now,
                ))
            .toList();

    try {
      await widget.controller.addStudyTask(
        title: plan.mainTitle,
        type: plan.taskType,
        courseName: plan.courseName,
        deadline: plan.deadline,
        status: StudyTaskStatus.notStarted,
        note: noteBuffer.toString().trim(),
        subTasks: subTasks,
      );

      if (!mounted) return;
      StudyToast.show(context, '任务已添加到任务列表');
      setState(() {
        _taskPlan = null;
        _taskInputController.clear();
        _savedTaskMessage = '任务已加入清单，先打开看看最早该推进哪一步。';
      });
    } catch (_) {
      _showSnack('任务暂时没有保存成功，请稍后再试');
    }
  }

  Future<void> _handleGenerateAnalysis() async {
    setState(() => _isGeneratingAnalysis = true);
    try {
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      final result = await _aiService.generateWeeklyAnalysis(
        logs: widget.controller.studyLogs,
        tasks: widget.controller.studyTasks,
        startDate: weekAgo,
        endDate: now,
      );
      setState(() => _analysis = result);
    } on AiServiceException catch (error) {
      _showSnack(_assistantErrorMessage('本周复盘暂时没有整理成功，请稍后再试', error));
    } catch (_) {
      _showSnack('本周复盘暂时没有整理成功，请稍后再试');
    } finally {
      if (mounted) setState(() => _isGeneratingAnalysis = false);
    }
  }

  Future<void> _handleSaveAnalysis() async {
    if (_analysis == null) return;
    final content = _analysis!.toFormattedText();
    final now = DateTime.now();
    try {
      await widget.controller.saveWeeklyReport(
        content,
        startDate: now.subtract(const Duration(days: 7)),
        endDate: now,
      );
      if (!mounted) return;
      StudyToast.show(context, '本周复盘已保存');
    } catch (_) {
      _showSnack('本周复盘暂时没有保存成功，请稍后再试');
    }
  }

  void _handleCopyAnalysis() {
    if (_analysis == null) return;
    Clipboard.setData(ClipboardData(text: _analysis!.toFormattedText()));
    StudyToast.show(context, '已复制到剪贴板');
  }

  Future<void> _handleGenerateAnalysisVideo() async {
    final analysis = _analysis;
    if (analysis == null || _isGeneratingAnalysisVideo) return;
    setState(() => _isGeneratingAnalysisVideo = true);
    try {
      final task = await widget.controller.vivoCapabilityService.createVideo(
        prompt: _analysisVideoPrompt(analysis),
        purpose: 'weekly_review_video',
      );
      if (!mounted) return;
      setState(() => _analysisVideoTask = task);
      StudyToast.show(
        context,
        task.videosUrl.isNotEmpty ? '回顾短片已生成' : '回顾短片整理中，稍后可刷新',
      );
    } catch (_) {
      _showSnack('回顾短片暂时没有开始整理，请稍后再试');
    } finally {
      if (mounted) setState(() => _isGeneratingAnalysisVideo = false);
    }
  }

  Future<void> _handleRefreshAnalysisVideo() async {
    final taskId = _analysisVideoTask?.taskId ?? '';
    if (taskId.isEmpty || _isRefreshingAnalysisVideo) return;
    setState(() => _isRefreshingAnalysisVideo = true);
    try {
      final task = await widget.controller.vivoCapabilityService
          .refreshVideoTask(taskId);
      if (!mounted) return;
      setState(() => _analysisVideoTask = task);
      StudyToast.show(
        context,
        task.videosUrl.isNotEmpty ? '回顾短片已生成' : '短片还在生成中',
      );
    } catch (_) {
      _showSnack('回顾短片暂时没有刷新成功，请稍后再试');
    } finally {
      if (mounted) setState(() => _isRefreshingAnalysisVideo = false);
    }
  }

  String _analysisVideoPrompt(AiStudyAnalysis analysis) {
    return [
      '制作一段 5 秒、适合大学生学习周报的回顾短片，画面要简洁、有学习桌面、笔记、进度卡片和轻微镜头运动。',
      '本周主题：${analysis.mainTopics}',
      '学习近况：${analysis.statusEvaluation}',
      '下周重点：${analysis.nextWeekPriority}',
      '风格：明亮、真实、清爽，不要营销感，不要夸张文字。',
    ].join('\n');
  }

  Future<void> _handleGenerateWarnings() async {
    setState(() => _isGeneratingWarnings = true);
    try {
      final result = await _aiService.generateRiskWarnings(
        logs: widget.controller.studyLogs,
        tasks: widget.controller.studyTasks,
      );
      setState(() => _warnings = result);
    } on AiServiceException catch (error) {
      _showSnack(_assistantErrorMessage('学习进展暂时没有整理成功，请稍后再试', error));
    } catch (_) {
      _showSnack('学习进展暂时没有整理成功，请稍后再试');
    } finally {
      if (mounted) setState(() => _isGeneratingWarnings = false);
    }
  }

  Future<void> _handleGenerateFlashcards() async {
    setState(() {
      _isGeneratingFlashcards = true;
      _flashcardsMessage = null;
      _flashcardsSuccess = false;
    });
    try {
      final today = DateTime.now();
      final todayLogs = widget.controller.studyLogs.where((l) {
        return l.date.year == today.year &&
            l.date.month == today.month &&
            l.date.day == today.day;
      }).toList();
      if (todayLogs.isEmpty) {
        setState(() {
          _flashcardsMessage = '今天还没有学习日志，先记录一些再整理闪卡';
          _flashcardsSuccess = false;
        });
        return;
      }
      final cards = await _aiService.generateFlashCards(
        logs: todayLogs,
        count: 8,
      );
      if (cards.isEmpty) {
        setState(() {
          _flashcardsMessage = '这次没有整理出有效闪卡，请稍后再试';
          _flashcardsSuccess = false;
        });
        return;
      }
      await widget.controller.addFlashCards(cards);
      setState(() {
        _flashcardsMessage = '已根据今日日志整理 ${cards.length} 张闪卡，可以马上去复习。';
        _flashcardsSuccess = true;
      });
    } on AiServiceException catch (error) {
      setState(() {
        _flashcardsMessage =
            _assistantErrorMessage('今日闪卡暂时没有整理成功，请稍后再试', error);
        _flashcardsSuccess = false;
      });
    } catch (_) {
      setState(() {
        _flashcardsMessage = '今日闪卡暂时没有整理成功，请稍后再试';
        _flashcardsSuccess = false;
      });
    } finally {
      if (mounted) setState(() => _isGeneratingFlashcards = false);
    }
  }
}

class _AssistantFocusAction {
  const _AssistantFocusAction({
    required this.title,
    required this.detail,
    required this.actionLabel,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String detail;
  final String actionLabel;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _AssistantFocusCard extends StatelessWidget {
  const _AssistantFocusCard({
    required this.title,
    required this.detail,
    required this.actionLabel,
    required this.icon,
    required this.color,
    required this.isDarkMode,
    required this.onTap,
  });

  final String title;
  final String detail;
  final String actionLabel;
  final IconData icon;
  final Color color;
  final bool isDarkMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      padding: const EdgeInsets.all(14),
      borderColor: color.withValues(alpha: isDarkMode ? 0.22 : 0.14),
      child: Row(
        children: [
          StudyGlassIconNode(
            icon: icon,
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
                Text(
                  '今天先走这一小步',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: AppTypography.title,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: TextStyle(
                    color: StudyUi.title(isDarkMode),
                    fontSize: 15,
                    fontWeight: AppTypography.hero,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: TextStyle(
                    color: StudyUi.body(isDarkMode),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _AssistantActionButton(
            icon: Icons.arrow_forward_rounded,
            label: actionLabel,
            color: color,
            isDarkMode: isDarkMode,
            filled: false,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}

class _AssistantActionButton extends StatelessWidget {
  const _AssistantActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDarkMode,
    required this.onPressed,
    this.filled = true,
    this.expand = false,
    this.busyIcon,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool isDarkMode;
  final VoidCallback? onPressed;
  final bool filled;
  final bool expand;
  final Widget? busyIcon;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final foreground =
        filled ? Colors.white : (disabled ? StudyUi.muted(isDarkMode) : color);
    final background = filled
        ? color.withValues(alpha: disabled ? 0.48 : 1)
        : color.withValues(alpha: isDarkMode ? 0.12 : 0.08);
    final borderColor = filled
        ? Colors.white.withValues(alpha: disabled ? 0.08 : 0.18)
        : color.withValues(alpha: disabled ? 0.10 : 0.22);

    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: disabled ? null : onPressed,
        child: Ink(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
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
              busyIcon ?? Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 13,
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

class _AssistantSaveNextStepCard extends StatelessWidget {
  const _AssistantSaveNextStepCard({
    required this.message,
    required this.icon,
    required this.color,
    required this.isDarkMode,
    this.actionLabel,
    this.onTap,
  });

  final String message;
  final IconData icon;
  final Color color;
  final bool isDarkMode;
  final String? actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    final callback = onTap;
    final canAct = label != null && callback != null;
    return StudyCard(
      padding: const EdgeInsets.all(14),
      borderColor: color.withValues(alpha: isDarkMode ? 0.22 : 0.14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StudyGlassIconNode(
                icon: icon,
                accent: color,
                size: 38,
                iconSize: 18,
                isDarkMode: isDarkMode,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: StudyUi.body(isDarkMode),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          if (canAct) ...[
            const SizedBox(height: 12),
            _AssistantActionButton(
              icon: Icons.arrow_forward_rounded,
              label: label,
              color: color,
              isDarkMode: isDarkMode,
              filled: false,
              expand: true,
              onPressed: callback,
            ),
          ],
        ],
      ),
    );
  }
}

class _AssistantDialogSurface extends StatelessWidget {
  const _AssistantDialogSurface({
    required this.isDarkMode,
    required this.accent,
    required this.icon,
    required this.title,
    required this.child,
  });

  final bool isDarkMode;
  final Color accent;
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    final surface = StudyUi.surface(isDarkMode);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surface.withValues(alpha: isDarkMode ? 0.92 : 0.86),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDarkMode ? 0.08 : 0.72),
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: isDarkMode ? 0.18 : 0.12),
                blurRadius: 30,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StudyGlassIconNode(
                      icon: icon,
                      accent: accent,
                      size: 42,
                      iconSize: 19,
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
                              color: titleColor,
                              fontSize: 18,
                              fontWeight: AppTypography.hero,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '确认内容后再放进学习记录',
                            style: TextStyle(color: bodyColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============ Result Widgets ============

class _AiResultCard extends StatelessWidget {
  final bool isDarkMode;
  final String title;
  final ValueChanged<AiGeneratedLog> onEdit;
  final AiGeneratedLog generatedLog;
  final VoidCallback onSave;

  const _AiResultCard({
    required this.isDarkMode,
    required this.title,
    required this.onEdit,
    required this.generatedLog,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);

    return StudyCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const StudyAssetIcon(
                asset: AppAssets.featureLogIcon,
                color: StudyUi.secondary,
                size: 20,
                fallbackIcon: Icons.fact_check_rounded,
              ),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      color: titleColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: StudyUi.chipBackground(StudyUi.success, isDarkMode),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('已整理',
                    style: TextStyle(
                        color: StudyUi.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _EditableField(
            label: '所属课程',
            initialValue: generatedLog.courseName,
            isDarkMode: isDarkMode,
            onChanged: (v) => onEdit(AiGeneratedLog(
              courseName: v,
              content: generatedLog.content,
              problems: generatedLog.problems,
              thoughts: generatedLog.thoughts,
              nextPlan: generatedLog.nextPlan,
            )),
          ),
          const SizedBox(height: 10),
          _EditableField(
            label: '学习内容',
            initialValue: generatedLog.content,
            isDarkMode: isDarkMode,
            maxLines: 3,
            onChanged: (v) => onEdit(AiGeneratedLog(
              courseName: generatedLog.courseName,
              content: v,
              problems: generatedLog.problems,
              thoughts: generatedLog.thoughts,
              nextPlan: generatedLog.nextPlan,
            )),
          ),
          const SizedBox(height: 10),
          _EditableField(
            label: '遇到的问题',
            initialValue: generatedLog.problems,
            isDarkMode: isDarkMode,
            maxLines: 2,
            onChanged: (v) => onEdit(AiGeneratedLog(
              courseName: generatedLog.courseName,
              content: generatedLog.content,
              problems: v,
              thoughts: generatedLog.thoughts,
              nextPlan: generatedLog.nextPlan,
            )),
          ),
          const SizedBox(height: 10),
          _EditableField(
            label: '思考与收获',
            initialValue: generatedLog.thoughts,
            isDarkMode: isDarkMode,
            maxLines: 2,
            onChanged: (v) => onEdit(AiGeneratedLog(
              courseName: generatedLog.courseName,
              content: generatedLog.content,
              problems: generatedLog.problems,
              thoughts: v,
              nextPlan: generatedLog.nextPlan,
            )),
          ),
          const SizedBox(height: 10),
          _EditableField(
            label: '下一步计划',
            initialValue: generatedLog.nextPlan,
            isDarkMode: isDarkMode,
            maxLines: 2,
            onChanged: (v) => onEdit(AiGeneratedLog(
              courseName: generatedLog.courseName,
              content: generatedLog.content,
              problems: generatedLog.problems,
              thoughts: generatedLog.thoughts,
              nextPlan: v,
            )),
          ),
          const SizedBox(height: 16),
          _AssistantActionButton(
            icon: Icons.save_rounded,
            label: '保存为学习记录',
            color: StudyUi.secondary,
            isDarkMode: isDarkMode,
            expand: true,
            onPressed: onSave,
          ),
        ],
      ),
    );
  }
}

class _EditableField extends StatefulWidget {
  final String label;
  final String initialValue;
  final bool isDarkMode;
  final int maxLines;
  final ValueChanged<String> onChanged;

  const _EditableField({
    required this.label,
    required this.initialValue,
    required this.isDarkMode,
    this.maxLines = 1,
    required this.onChanged,
  });

  @override
  State<_EditableField> createState() => _EditableFieldState();
}

class _EditableFieldState extends State<_EditableField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant _EditableField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style: TextStyle(
                color: StudyUi.muted(widget.isDarkMode),
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          controller: _controller,
          maxLines: widget.maxLines,
          style: TextStyle(
            color: StudyUi.title(widget.isDarkMode),
            fontSize: 13,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: StudyUi.surfaceAlt(widget.isDarkMode).withValues(
              alpha: widget.isDarkMode ? 0.74 : 0.86,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: StudyUi.border(widget.isDarkMode)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: StudyUi.border(widget.isDarkMode)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: StudyUi.secondary.withValues(alpha: 0.48),
              ),
            ),
            isDense: true,
          ),
          onChanged: widget.onChanged,
        ),
      ],
    );
  }
}

String _fmtPlanDate(DateTime d) {
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} $h:$m';
}

class _TaskPlanResultCard extends StatelessWidget {
  final bool isDarkMode;
  final AiTaskPlan plan;
  final VoidCallback onAddTask;
  final Color accentColor;

  const _TaskPlanResultCard({
    required this.isDarkMode,
    required this.plan,
    required this.onAddTask,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);

    return StudyCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StudyAssetIcon(
                asset: AppAssets.featureTaskPlanIcon,
                color: accentColor,
                size: 20,
                fallbackIcon: Icons.account_tree_rounded,
              ),
              const SizedBox(width: 8),
              Text('任务拆解结果',
                  style: TextStyle(
                      color: titleColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(plan.difficulty,
                    style: TextStyle(
                        color: accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(plan.mainTitle,
              style: TextStyle(
                  color: titleColor,
                  fontSize: 16,
                  fontWeight: AppTypography.hero)),
          const SizedBox(height: 6),
          Text('课程：${plan.courseName}',
              style: TextStyle(color: bodyColor, fontSize: 13)),
          const SizedBox(height: 4),
          Text('截止：${_fmtPlanDate(plan.deadline)}',
              style: TextStyle(color: StudyUi.muted(isDarkMode), fontSize: 12)),
          if (plan.plannedSubTasks.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Text('子任务（带时间）',
                style: TextStyle(
                    color: titleColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            for (var i = 0; i < plan.plannedSubTasks.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${i + 1}. ',
                        style: TextStyle(
                            color: bodyColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(plan.plannedSubTasks[i].title,
                              style:
                                  TextStyle(color: titleColor, fontSize: 13)),
                          Text(
                              '截止：${_fmtPlanDate(plan.plannedSubTasks[i].deadline)}',
                              style: TextStyle(
                                  color: StudyUi.muted(isDarkMode),
                                  fontSize: 11)),
                          if (plan.plannedSubTasks[i].note.isNotEmpty)
                            Text(plan.plannedSubTasks[i].note,
                                style: TextStyle(
                                    color: StudyUi.muted(isDarkMode),
                                    fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ] else if (plan.subTasks.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Text('子任务',
                style: TextStyle(
                    color: titleColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            for (var i = 0; i < plan.subTasks.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${i + 1}. ',
                        style: TextStyle(
                            color: bodyColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    Expanded(
                      child: Text(plan.subTasks[i],
                          style: TextStyle(color: bodyColor, fontSize: 13)),
                    ),
                  ],
                ),
              ),
          ],
          if (plan.schedule.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Text('推荐安排',
                style: TextStyle(
                    color: titleColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(plan.schedule,
                style: TextStyle(color: bodyColor, fontSize: 13, height: 1.5)),
          ],
          const SizedBox(height: 16),
          _AssistantActionButton(
            icon: Icons.add_task_rounded,
            label: '加入任务列表',
            color: accentColor,
            isDarkMode: isDarkMode,
            expand: true,
            onPressed: onAddTask,
          ),
        ],
      ),
    );
  }
}

class _AnalysisResultCard extends StatelessWidget {
  final bool isDarkMode;
  final AiStudyAnalysis analysis;
  final VoidCallback onSave;
  final VoidCallback onCopy;
  final GeneratedVideoTask? videoTask;
  final bool isGeneratingVideo;
  final bool isRefreshingVideo;
  final VoidCallback onGenerateVideo;
  final VoidCallback onRefreshVideo;

  const _AnalysisResultCard({
    required this.isDarkMode,
    required this.analysis,
    required this.onSave,
    required this.onCopy,
    required this.videoTask,
    required this.isGeneratingVideo,
    required this.isRefreshingVideo,
    required this.onGenerateVideo,
    required this.onRefreshVideo,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);

    return StudyCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const StudyAssetIcon(
                asset: AppAssets.sideDashboardIcon,
                color: StudyUi.success,
                size: 20,
                fallbackIcon: Icons.analytics_rounded,
              ),
              const SizedBox(width: 8),
              Text('本周复盘结果',
                  style: TextStyle(
                      color: titleColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: StudyUi.chipBackground(StudyUi.success, isDarkMode),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('已整理',
                    style: TextStyle(
                        color: StudyUi.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionText(
              label: '本周主要学习主题',
              text: analysis.mainTopics,
              isDarkMode: isDarkMode),
          const SizedBox(height: 10),
          _SectionText(
              label: '各课程投入情况',
              text: analysis.courseDistribution,
              isDarkMode: isDarkMode),
          const SizedBox(height: 10),
          _SectionText(
              label: '高频问题分析',
              text: analysis.frequentProblems,
              isDarkMode: isDarkMode),
          const SizedBox(height: 10),
          _SectionText(
              label: '完成情况',
              text: analysis.completedTasks,
              isDarkMode: isDarkMode),
          const SizedBox(height: 10),
          _SectionText(
              label: '延期提醒', text: analysis.riskTasks, isDarkMode: isDarkMode),
          const SizedBox(height: 10),
          _SectionText(
              label: '学习近况',
              text: analysis.statusEvaluation,
              isDarkMode: isDarkMode),
          const SizedBox(height: 10),
          _SectionText(
              label: '下周优先级建议',
              text: analysis.nextWeekPriority,
              isDarkMode: isDarkMode),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _AssistantActionButton(
                  icon: Icons.save_rounded,
                  label: '保存周报',
                  color: StudyUi.success,
                  isDarkMode: isDarkMode,
                  expand: true,
                  onPressed: onSave,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AssistantActionButton(
                  icon: Icons.copy_rounded,
                  label: '复制',
                  color: StudyUi.success,
                  isDarkMode: isDarkMode,
                  filled: false,
                  expand: true,
                  onPressed: onCopy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AnalysisVideoPanel(
            task: videoTask,
            isDarkMode: isDarkMode,
            isGenerating: isGeneratingVideo,
            isRefreshing: isRefreshingVideo,
            onGenerate: onGenerateVideo,
            onRefresh: onRefreshVideo,
          ),
        ],
      ),
    );
  }
}

class _AnalysisVideoPanel extends StatelessWidget {
  const _AnalysisVideoPanel({
    required this.task,
    required this.isDarkMode,
    required this.isGenerating,
    required this.isRefreshing,
    required this.onGenerate,
    required this.onRefresh,
  });

  final GeneratedVideoTask? task;
  final bool isDarkMode;
  final bool isGenerating;
  final bool isRefreshing;
  final VoidCallback onGenerate;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final accent = StudyUi.pathViolet;
    final videoUrl =
        task?.videosUrl.isNotEmpty == true ? task!.videosUrl.first : '';
    final status = _videoTaskStatusLabel(task?.status);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: StudyUi.surfaceAlt(isDarkMode),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: StudyUi.border(isDarkMode)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.movie_creation_outlined, size: 18, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '回顾短片',
                  style: TextStyle(
                    color: StudyUi.title(isDarkMode),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                status,
                style: TextStyle(
                  color: StudyUi.muted(isDarkMode),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (videoUrl.isNotEmpty) ...[
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                Clipboard.setData(ClipboardData(text: videoUrl));
                StudyToast.show(context, '短片链接已复制');
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.copy_rounded, color: accent, size: 21),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '复制短片链接',
                            style: TextStyle(
                              color: StudyUi.title(isDarkMode),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            videoUrl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: StudyUi.body(isDarkMode),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: StudyUi.muted(isDarkMode), size: 16),
                  ],
                ),
              ),
            ),
          ] else
            Text(
              task == null ? '把这份周报变成 5 秒回顾短片。' : '短片生成中，稍后刷新查看链接。',
              style: TextStyle(color: StudyUi.body(isDarkMode), fontSize: 12),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _AssistantActionButton(
                  icon: Icons.movie_creation_rounded,
                  label: isGenerating ? '整理中...' : '做成短片',
                  color: accent,
                  isDarkMode: isDarkMode,
                  expand: true,
                  onPressed: isGenerating ? null : onGenerate,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AssistantActionButton(
                  icon: Icons.refresh_rounded,
                  label: isRefreshing ? '刷新中...' : '刷新',
                  color: accent,
                  isDarkMode: isDarkMode,
                  filled: false,
                  expand: true,
                  onPressed: task == null || isRefreshing ? null : onRefresh,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _videoTaskStatusLabel(String? status) {
  return switch ((status ?? '').trim().toLowerCase()) {
    '' => '未生成',
    'pending' || 'running' || 'processing' || 'queued' => '制作中',
    'succeeded' || 'success' || 'finished' || 'done' => '已生成',
    'failed' || 'error' => '没有生成成功',
    _ => '等待刷新',
  };
}

class _SectionText extends StatelessWidget {
  final String label;
  final String text;
  final bool isDarkMode;

  const _SectionText({
    required this.label,
    required this.text,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    final bodyColor = StudyUi.body(isDarkMode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: StudyUi.muted(isDarkMode),
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(text,
            style: TextStyle(color: bodyColor, fontSize: 13, height: 1.5)),
      ],
    );
  }
}

class _WarningCard extends StatelessWidget {
  final bool isDarkMode;
  final AiRiskWarning warning;

  const _WarningCard({
    required this.isDarkMode,
    required this.warning,
  });

  @override
  Widget build(BuildContext context) {
    final (Color bgColor, Color iconColor, Color borderColor) =
        switch (warning.level) {
      RiskLevel.high => (
          StudyUi.danger.withValues(alpha: 0.12),
          StudyUi.danger,
          StudyUi.danger.withValues(alpha: 0.3),
        ),
      RiskLevel.medium => (
          StudyUi.warning.withValues(alpha: 0.12),
          StudyUi.warning,
          StudyUi.warning.withValues(alpha: 0.3),
        ),
      RiskLevel.low => (
          StudyUi.secondary.withValues(alpha: 0.12),
          StudyUi.secondary,
          StudyUi.secondary.withValues(alpha: 0.3),
        ),
    };

    final bodyColor = StudyUi.body(isDarkMode);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            warning.level == RiskLevel.high
                ? Icons.error_rounded
                : warning.level == RiskLevel.medium
                    ? Icons.warning_rounded
                    : Icons.info_rounded,
            color: iconColor,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(warning.title,
                          style: TextStyle(
                              color: StudyUi.title(isDarkMode),
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(warning.level.label,
                          style: TextStyle(
                              color: iconColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(warning.description,
                    style:
                        TextStyle(color: bodyColor, fontSize: 13, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
