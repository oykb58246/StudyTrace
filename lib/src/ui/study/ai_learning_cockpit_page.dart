import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/ai_action_record.dart';
import '../../models/ai_flash_card.dart';
import '../../models/ai_learning_loop.dart';
import '../../models/learning_moment.dart';
import '../../models/note_block.dart';
import '../../models/study_sub_task_item.dart';
import '../../models/study_task_item.dart';
import '../../services/ai_app_context_builder.dart';
import '../../services/local_today_mission_builder.dart';
import '../../services/ocr_service.dart';
import '../../theme/app_theme.dart';
import '../shared/common_widgets.dart';
import '../shared/markdown_styles.dart';
import 'timer_page.dart';

class _LoopMaterialItem {
  const _LoopMaterialItem({
    required this.id,
    required this.type,
    required this.title,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String text;
  final DateTime createdAt;
}

class AiLearningCockpitPage extends StatefulWidget {
  const AiLearningCockpitPage({
    super.key,
    required this.isDarkMode,
    required this.controller,
    this.onOpenAiChat,
    this.onOpenTasks,
    this.onOpenFlashCards,
    this.onStartFlashCardReview,
    this.onOpenEvidencePackage,
    this.onOpenLearningMoments,
    this.debugAutoOpenSavedNextStepDialog = false,
  });

  final bool isDarkMode;
  final AppDataController controller;
  final VoidCallback? onOpenAiChat;
  final VoidCallback? onOpenTasks;
  final VoidCallback? onOpenFlashCards;
  final ValueChanged<List<String>>? onStartFlashCardReview;
  final VoidCallback? onOpenEvidencePackage;
  final VoidCallback? onOpenLearningMoments;
  final bool debugAutoOpenSavedNextStepDialog;

  @override
  State<AiLearningCockpitPage> createState() => _AiLearningCockpitPageState();
}

class _AiLearningCockpitPageState extends State<AiLearningCockpitPage> {
  final _sourceController = TextEditingController();
  final _blockerController = TextEditingController();
  final _nextStepController = TextEditingController();
  late final OcrService _ocrService;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final ImagePicker _imagePicker = ImagePicker();
  final List<_LoopMaterialItem> _materialItems = [];

  AiLearningLoopPlan? _plan;
  bool _isGeneratingLoop = false;
  bool _isGeneratingMission = false;
  bool _isPreparingMaterial = false;
  bool _isApplying = false;
  String _statusText = '';
  String? _pendingLoopImageBase64;
  String _pendingLoopSourceKind = 'manual';
  String _planCheckText = '';
  bool _saveLog = true;
  bool _saveTasks = true;
  bool _saveNote = true;
  bool _saveFlashCards = true;
  bool _isCheckingPlan = false;
  bool _isRecordingReview = false;
  List<String> _lastCreatedFlashCardIds = const [];
  bool _didOpenDebugSavedNextStepDialog = false;

  @override
  void initState() {
    super.initState();
    _ocrService = widget.controller.createOcrService();
    _sourceController.addListener(_handleMaterialInputChanged);
    _blockerController.addListener(_handleMaterialInputChanged);
    _nextStepController.addListener(_handleMaterialInputChanged);
    if (widget.debugAutoOpenSavedNextStepDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _openDebugSavedNextStepDialog();
      });
    }
  }

  Future<void> _openDebugSavedNextStepDialog() async {
    if (_didOpenDebugSavedNextStepDialog || !mounted) return;
    _didOpenDebugSavedNextStepDialog = true;
    final plan = _debugSavedNextStepPlan();
    setState(() {
      _plan = plan;
      _statusText = '已生成一份可保存的学习路径';
      _planCheckText = '· 今日安排密度适中，可以先保存并进入第一段专注。';
      _saveLog = false;
      _saveTasks = true;
      _saveNote = false;
      _saveFlashCards = true;
      _lastCreatedFlashCardIds = const [
        'ui_review_flashcard_1',
        'ui_review_flashcard_2',
      ];
    });
    await _showSavedNextStepDialog(3);
  }

  AiLearningLoopPlan _debugSavedNextStepPlan() {
    final now = DateTime.now();
    return AiLearningLoopPlan(
      summary: '已把高数错题复盘整理成今天可执行的下一步。',
      courseName: '高等数学',
      concepts: const ['洛必达法则', '极限未定式', '复习闪卡'],
      taskDrafts: [
        AiLearningLoopTaskDraft(
          title: '复盘洛必达法则错题',
          type: StudyTaskType.examReview,
          deadline: DateTime(now.year, now.month, now.day, 22),
          note: '先判断是否满足未定式条件，再重做一道同类极限题检查理解。',
          subTasks: const [
            AiLearningLoopSubTaskDraft(title: '标出题目里的 0/0 或 ∞/∞ 条件'),
            AiLearningLoopSubTaskDraft(title: '重做一道同类极限题'),
          ],
        ),
      ],
      flashcards: const [
        AiLearningLoopFlashcardDraft(
          question: '洛必达法则使用前要先确认什么？',
          answer: '要先确认极限形式属于 0/0 或 ∞/∞ 这类未定式，并且分子分母在邻域内可导。',
          hint: '先判断形式，再考虑求导。',
          courseName: '高等数学',
        ),
        AiLearningLoopFlashcardDraft(
          question: '为什么不能一看到极限就直接用洛必达？',
          answer: '如果不是未定式，直接求导可能改变原极限含义，容易把本来能代入或化简的问题算错。',
          hint: '把“先判断未定式”放在第一步。',
          courseName: '高等数学',
        ),
      ],
      reviewPlan: [
        AiLearningLoopReviewItem(
          title: '复盘洛必达法则错题',
          date: DateTime(now.year, now.month, now.day, 20),
          minutes: 25,
          reason: '趁热整理判断条件，降低下次同类题误用风险。',
        ),
      ],
      actionCards: [
        AiLearningActionCard(
          title: '先做 25 分钟错题复盘',
          steps: const ['判断未定式', '重做同类题', '记录难点'],
          reason: '把下一步压缩成能立刻开始的一段专注。',
          durationMinutes: 25,
          priority: 'high',
          successCriteria: '能不用看笔记讲清什么时候可以用洛必达法则。',
          source: '高数错题复盘材料',
        ),
      ],
    );
  }

  @override
  void dispose() {
    _sourceController.removeListener(_handleMaterialInputChanged);
    _blockerController.removeListener(_handleMaterialInputChanged);
    _nextStepController.removeListener(_handleMaterialInputChanged);
    _sourceController.dispose();
    _blockerController.dispose();
    _nextStepController.dispose();
    _ocrService.dispose();
    unawaited(_audioRecorder.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = StudyUi.primary;
    final titleColor = StudyUi.title(widget.isDarkMode);

    return Scaffold(
      backgroundColor: StudyUi.background(widget.isDarkMode),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: titleColor,
        title: const SizedBox.shrink(),
        actions: [
          if (widget.onOpenAiChat != null)
            _CockpitIconButton(
              tooltip: '学习对话',
              icon: Icons.chat_bubble_outline_rounded,
              color: StudyUi.pathViolet,
              isDarkMode: widget.isDarkMode,
              onPressed: widget.onOpenAiChat,
            ),
          _CockpitIconButton(
            tooltip: '最近记录',
            icon: Icons.history_rounded,
            color: StudyUi.pathBlue,
            isDarkMode: widget.isDarkMode,
            onPressed: _showLearningHistorySheet,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StudyScreenBackground(
        isDarkMode: widget.isDarkMode,
        accent: accent,
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
              children: [
                _HeroPanel(
                  isDarkMode: widget.isDarkMode,
                  accent: accent,
                ),
                const SizedBox(height: 14),
                _ManualSourceCard(
                  isDarkMode: widget.isDarkMode,
                  learnedController: _sourceController,
                  blockerController: _blockerController,
                  nextStepController: _nextStepController,
                  isBusy: _isGeneratingLoop,
                  canGenerate: _hasPreparedMaterial,
                  statusText: _statusText,
                  statusColor: accent,
                  materialItems: _materialItems,
                  onCapturePhoto: _captureLoop,
                  onRecordVoice: _toggleVoiceReview,
                  onImportFile: _importLocalImageLoop,
                  onRemoveMaterial: _removeMaterialItem,
                  onAskAiNextStep: _askAiToDecideNextStep,
                  onGenerate: _generateFromCurrentMaterials,
                ),
                const SizedBox(height: 14),
                _LoopPromptCard(
                  isDarkMode: widget.isDarkMode,
                  accent: accent,
                  isBusy: _isGeneratingLoop,
                  canGenerate: _hasPreparedMaterial,
                  onGenerate: _generateFromCurrentMaterials,
                ),
                if (_plan != null) ...[
                  const SizedBox(height: 14),
                  _LoopPreview(
                    plan: _plan!,
                    isDarkMode: widget.isDarkMode,
                    accent: accent,
                    saveLog: _saveLog,
                    saveTasks: _saveTasks,
                    saveNote: _saveNote,
                    saveFlashCards: _saveFlashCards,
                    isApplying: _isApplying,
                    isCheckingPlan: _isCheckingPlan,
                    planCheckText: _planCheckText,
                    onSaveLogChanged: (value) =>
                        setState(() => _saveLog = value),
                    onSaveTasksChanged: (value) =>
                        setState(() => _saveTasks = value),
                    onSaveNoteChanged: (value) =>
                        setState(() => _saveNote = value),
                    onSaveFlashCardsChanged: (value) =>
                        setState(() => _saveFlashCards = value),
                    onCheckPlan: _checkPlanBeforeApply,
                    onApply: _applyPlan,
                    onStartFocus: _startFirstFocusBlock,
                  ),
                ],
                const SizedBox(height: 14),
                _TodayMissionCard(
                  isDarkMode: widget.isDarkMode,
                  isBusy: _isGeneratingMission,
                  onGenerate: _generateTodayMission,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _captureLoop() async {
    setState(() {
      _isPreparingMaterial = true;
      _statusText = '正在识别图片内容...';
    });
    try {
      final image = await _ocrService.captureImage(
        onStatus: (status) {
          if (mounted) setState(() => _statusText = status);
        },
      );
      if (image == null) {
        setState(() {
          _isPreparingMaterial = false;
          _statusText = '已取消拍摄，可以继续输入文字材料。';
        });
        return;
      }
      final imageBase64 = base64Encode(await image.readAsBytes());
      final text = (await _ocrService.recognizeImageWithCloudFallback(
        image,
        onStatus: (status) {
          if (mounted) setState(() => _statusText = status);
        },
      ))
          .trim();
      setState(() {
        _appendMaterialItem(
          type: 'photo',
          title: '拍照材料 ${_materialItems.length + 1}',
          text: text.isEmpty ? '这张图片没有识别出文字，请在这里补充图片内容。' : text,
        );
        _pendingLoopImageBase64 = imageBase64;
        _pendingLoopSourceKind = 'photo';
        _isPreparingMaterial = false;
        _statusText = text.isEmpty
            ? '图片已放进材料区。没识别到文字，可以直接补文字后再整理。'
            : '图片文字已填入材料区，确认后点“整理学习安排”。';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isPreparingMaterial = false;
        _statusText = '这次没有识别成功，可以换张图片或直接输入文字';
      });
    }
  }

  Future<void> _importLocalImageLoop() async {
    setState(() {
      _isPreparingMaterial = true;
      _statusText = '正在读取本地图片...';
    });
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        imageQuality: 90,
      );
      if (image == null) {
        if (!mounted) return;
        setState(() {
          _isPreparingMaterial = false;
          _statusText = '已取消选择本地图片。';
        });
        return;
      }
      final imageBase64 = base64Encode(await image.readAsBytes());
      final text = (await _ocrService.recognizeImageWithCloudFallback(
        image,
        onStatus: (status) {
          if (mounted) setState(() => _statusText = status);
        },
      ))
          .trim();
      if (!mounted) return;
      setState(() {
        _appendMaterialItem(
          type: 'localImage',
          title: '本地图片 ${_materialItems.length + 1}',
          text: text.isEmpty ? '这张本地图片没有识别出文字，请在这里补充图片内容。' : text,
        );
        _pendingLoopImageBase64 = imageBase64;
        _pendingLoopSourceKind = 'photo';
        _isPreparingMaterial = false;
        _statusText =
            text.isEmpty ? '本地图片已放进材料区，可以补充说明后再整理。' : '本地图片文字已追加到材料清单。';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isPreparingMaterial = false;
        _statusText = '本地图片暂时没有读取成功，可以换一张或直接输入文字。';
      });
    }
  }

  Future<void> _showLearningHistorySheet() async {
    final recentLogs = widget.controller.studyLogs.take(5).toList();
    final recentTasks = widget.controller.studyTasks.take(5).toList();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final titleColor = StudyUi.title(widget.isDarkMode);
        final bodyColor = StudyUi.body(widget.isDarkMode);
        return SafeArea(
          child: _CockpitSheetSurface(
            isDarkMode: widget.isDarkMode,
            accent: StudyUi.pathBlue,
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.72,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: bodyColor.withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      StudyGlassIconNode(
                        icon: Icons.history_rounded,
                        accent: StudyUi.pathBlue,
                        size: 42,
                        iconSize: 18,
                        isDarkMode: widget.isDarkMode,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '最近记录',
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 18,
                            fontWeight: AppTypography.hero,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (recentLogs.isNotEmpty)
                    ...recentLogs.map(
                      (log) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: StudyCard(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_shortDate(log.date)} · ${log.courseName}',
                                style: TextStyle(
                                  color: titleColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _clip(log.content, 90),
                                style:
                                    TextStyle(color: bodyColor, height: 1.45),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Text(
                      '还没有可查看的学习记录。',
                      style: TextStyle(color: bodyColor),
                    ),
                  if (recentTasks.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '最近任务',
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...recentTasks.map(
                      (task) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: BadgePill(
                          label: task.title,
                          background: StudyUi.chipBackground(
                            StudyUi.secondary,
                            widget.isDarkMode,
                          ),
                          foreground: StudyUi.secondary,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _CockpitActionButton(
                      icon: Icons.close_rounded,
                      label: '关闭',
                      color: StudyUi.pathBlue,
                      isDarkMode: widget.isDarkMode,
                      filled: false,
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool get _hasPreparedMaterial =>
      _pendingLoopImageBase64?.isNotEmpty == true ||
      _sourceController.text.trim().isNotEmpty ||
      _blockerController.text.trim().isNotEmpty ||
      _nextStepController.text.trim().isNotEmpty;

  void _handleMaterialInputChanged() {
    if (mounted) setState(() {});
  }

  String _manualReviewText() {
    final learned = _sourceController.text.trim();
    final blocker = _blockerController.text.trim();
    final nextStep = _nextStepController.text.trim();
    return [
      if (learned.isNotEmpty) '学了什么：$learned',
      if (blocker.isNotEmpty) '哪里不懂：$blocker',
      if (nextStep.isNotEmpty) '下一步怎么做：$nextStep',
    ].join('\n');
  }

  Future<void> _generateFromCurrentMaterials() {
    if (_isPreparingMaterial) {
      setState(() => _statusText = '材料还在准备中，稍等一下再整理。');
      return Future<void>.value();
    }
    return _generateLoop(
      sourceText: _manualReviewText(),
      sourceKind: _pendingLoopImageBase64?.isNotEmpty == true
          ? 'photo'
          : _pendingLoopSourceKind,
      imageBase64: _pendingLoopImageBase64,
    );
  }

  void _appendMaterialItem({
    required String type,
    required String title,
    required String text,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final existingManualText = _sourceController.text.trim();
    if (_materialItems.isEmpty && existingManualText.isNotEmpty) {
      _materialItems.add(_LoopMaterialItem(
        id: 'material_${DateTime.now().microsecondsSinceEpoch}_manual',
        type: 'manual',
        title: '手动输入',
        text: existingManualText,
        createdAt: DateTime.now(),
      ));
    }
    _materialItems.add(_LoopMaterialItem(
      id: 'material_${DateTime.now().microsecondsSinceEpoch}',
      type: type,
      title: title,
      text: trimmed,
      createdAt: DateTime.now(),
    ));
    _syncMaterialTextFromItems();
  }

  void _syncMaterialTextFromItems() {
    if (_materialItems.isEmpty) return;
    _sourceController.text = _materialItems
        .map((item) => '【${item.title}】\n${item.text}')
        .join('\n\n');
  }

  void _removeMaterialItem(String id) {
    setState(() {
      _materialItems.removeWhere((item) => item.id == id);
      if (_materialItems.isEmpty) {
        _sourceController.clear();
        _pendingLoopImageBase64 = null;
        _pendingLoopSourceKind = 'manual';
      } else {
        _syncMaterialTextFromItems();
      }
      _statusText =
          _materialItems.isEmpty ? '材料清单已清空，可以重新输入或导入。' : '已从材料清单移除一条内容。';
    });
  }

  void _askAiToDecideNextStep() {
    setState(() {
      _nextStepController.text = '请根据上面的学习材料帮我判断下一步怎么做。';
      _statusText = '下一步已交给 AI 判断，可以直接整理学习安排。';
    });
  }

  Future<void> _generateLoop({
    required String sourceText,
    required String sourceKind,
    String? imageBase64,
  }) async {
    final input = sourceText.trim();
    if (input.isEmpty && (imageBase64 == null || imageBase64.isEmpty)) {
      setState(() => _statusText = '请先输入或拍摄学习材料');
      return;
    }
    setState(() {
      _isGeneratingLoop = true;
      _isPreparingMaterial = false;
      _statusText = imageBase64 == null ? '正在整理学习安排...' : '正在结合图片与文字整理学习安排...';
      _planCheckText = '';
    });
    try {
      final plan = await widget.controller.aiStudyService.generateLearningLoop(
        sourceText: input,
        imageBase64: imageBase64,
        sourceKind: sourceKind,
        context: AiAppContextBuilder.build(
          widget.controller,
          currentLocation: 'ai_learning_cockpit',
        ),
      );
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _isGeneratingLoop = false;
        _pendingLoopImageBase64 = null;
        _pendingLoopSourceKind = 'manual';
        _statusText = '已整理好，可以继续修改';
        _saveLog = plan.summary.isNotEmpty;
        _saveTasks = _hasTaskLikeContent(plan);
        _saveNote = plan.noteDraft.title.isNotEmpty ||
            plan.noteDraft.content.isNotEmpty;
        _saveFlashCards = plan.flashcards.isNotEmpty;
      });
    } catch (error) {
      if (!mounted) return;
      final fallbackPlan = const LocalLearningLoopFallbackBuilder().build(
        sourceText: input,
        tasks: widget.controller.studyTasks,
        logs: widget.controller.studyLogs,
      );
      setState(() {
        _plan = fallbackPlan;
        _isGeneratingLoop = false;
        _pendingLoopImageBase64 = null;
        _pendingLoopSourceKind = 'manual';
        _statusText = '暂时整理较慢，已先给你一版可编辑内容';
        _saveLog = fallbackPlan.summary.isNotEmpty;
        _saveTasks = _hasTaskLikeContent(fallbackPlan);
        _saveNote = false;
        _saveFlashCards = fallbackPlan.flashcards.isNotEmpty;
      });
      StudyToast.show(context, '已先整理一版可编辑内容');
    }
  }

  Future<void> _generateTodayMission() async {
    if (_isGeneratingMission) return;
    final localPlan = const LocalTodayMissionBuilder().build(
      tasks: widget.controller.studyTasks,
      logs: widget.controller.studyLogs,
    );
    setState(() {
      _isGeneratingMission = true;
      _statusText = '已先整理今日安排，正在继续完善...';
    });
    _setTodayMissionPlan(
      localPlan,
      '已先整理今日安排，正在继续完善...',
      saveTasks: false,
      keepBusy: true,
    );
    try {
      final plan = await widget.controller.aiStudyService.generateTodayMission(
        context: _buildTodayMissionContext(),
      );
      if (!mounted) return;
      if (!_hasExecutableTodayPlan(plan)) {
        setState(() {
          _isGeneratingMission = false;
          _statusText = '暂时没有新的安排，已保留当前今日安排';
        });
        StudyToast.show(context, '已保留当前今日安排');
        return;
      }
      _setTodayMissionPlan(plan, '今日安排已整理好，可保存到记录和任务或开始专注');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isGeneratingMission = false;
        _statusText = '整理暂时较慢，已保留当前可编辑安排';
      });
      StudyToast.show(context, '已先使用当前安排');
    }
  }

  void _setTodayMissionPlan(
    AiLearningLoopPlan plan,
    String statusText, {
    bool? saveTasks,
    bool keepBusy = false,
  }) {
    setState(() {
      _plan = plan;
      _isGeneratingMission = keepBusy;
      _statusText = statusText;
      _saveLog = false;
      _saveTasks = saveTasks ?? _hasTaskLikeContent(plan);
      _saveNote = false;
      _saveFlashCards = plan.flashcards.isNotEmpty;
    });
  }

  List<String> _buildTodayMissionContext() {
    final pendingTasks = widget.controller.studyTasks
        .where((task) => task.effectiveStatus != StudyTaskStatus.completed)
        .take(6)
        .map((task) =>
            '${task.title}｜${task.courseName}｜截止 ${_shortDate(task.deadline)}｜${task.effectiveStatus.label}')
        .toList();
    final recentLogs = widget.controller.studyLogs
        .take(3)
        .map((log) =>
            '${_shortDate(log.date)}｜${log.courseName}｜${_clip(log.content, 48)}｜下一步 ${_clip(log.nextPlan, 36)}')
        .toList();
    return [
      '当前位置：today_mission',
      '可用课程：${widget.controller.courses.take(8).join('、')}',
      if (pendingTasks.isNotEmpty) '未完成任务：${pendingTasks.join('\n')}',
      if (recentLogs.isNotEmpty) '最近学习日志：${recentLogs.join('\n')}',
    ];
  }

  bool _hasExecutableTodayPlan(AiLearningLoopPlan plan) =>
      _hasTaskLikeContent(plan);

  bool _hasTaskLikeContent(AiLearningLoopPlan plan) =>
      plan.taskDrafts.isNotEmpty ||
      plan.actionCards.isNotEmpty ||
      plan.reviewPlan.isNotEmpty ||
      plan.reviewCards.isNotEmpty;

  String _shortDate(DateTime value) =>
      '${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String _clip(String value, int maxLength) {
    final trimmed = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.length <= maxLength) return trimmed;
    return '${trimmed.substring(0, maxLength)}...';
  }

  Future<void> _checkPlanBeforeApply() async {
    final plan = _plan;
    if (plan == null || _isCheckingPlan) return;
    setState(() {
      _isCheckingPlan = true;
      _planCheckText = '';
    });
    final pendingTasks = widget.controller.studyTasks
        .where((task) => task.effectiveStatus != StudyTaskStatus.completed)
        .take(12)
        .map((task) =>
            '${task.title}｜${task.courseName}｜截止 ${task.deadline.toIso8601String()}')
        .join('\n');
    final reviews =
        plan.reviewPlan.isNotEmpty ? plan.reviewPlan : plan.reviewCards;
    final planText = [
      '摘要：${plan.summary}',
      '课程：${plan.courseName}',
      '任务：${plan.taskDrafts.map((task) => task.title).join('；')}',
      '下一步：${plan.actionCards.map((card) => card.title).join('；')}',
      '复习路径：${reviews.map((item) => '${item.title}/${item.minutes}分钟').join('；')}',
    ].join('\n');
    try {
      final result =
          await widget.controller.aiStudyService.generateAssistantReply(
        input: '请对以下学习安排做保存前检查：检查截止时间冲突、任务密度、课程分布和是否适合今天执行。'
            '用 3 条以内中文提醒哪里需要改、今天适不适合做。\n\n待保存内容：\n$planText\n\n现有待办：\n$pendingTasks',
        purpose: 'chat',
      );
      if (!mounted) return;
      setState(() => _planCheckText = result.trim());
    } catch (_) {
      if (!mounted) return;
      setState(() => _planCheckText = _localPlanCheck(plan));
    } finally {
      if (mounted) setState(() => _isCheckingPlan = false);
    }
  }

  String _localPlanCheck(AiLearningLoopPlan plan) {
    final warnings = <String>[];
    final reviews =
        plan.reviewPlan.isNotEmpty ? plan.reviewPlan : plan.reviewCards;
    if (plan.taskDrafts.length + plan.actionCards.length >= 3 &&
        reviews.length >= 3) {
      warnings.add('今天内容有点满，建议先保存 1-2 件最关键的事。');
    }
    final courses = {
      ...widget.controller.studyTasks
          .where((task) => task.effectiveStatus != StudyTaskStatus.completed)
          .map((task) => task.courseName)
          .where((name) => name.trim().isNotEmpty),
      if (plan.courseName.trim().isNotEmpty) plan.courseName,
    };
    if (courses.length >= 4) {
      warnings.add('近期课程分布较散，建议今天先专心攻 1 门主课。');
    }
    if (reviews.any((item) => item.minutes > 60)) {
      warnings.add('部分专注时间较长，可拆成 25-45 分钟一段。');
    }
    if (warnings.isEmpty) {
      warnings.add('未发现明显冲突，可以先保存安排，再开始第一段专注。');
    }
    return warnings.map((item) => '· $item').join('\n');
  }

  Future<void> _applyPlan() async {
    final plan = _plan;
    if (plan == null || _isApplying) return;
    if (_planCheckText.trim().isEmpty) {
      await _checkPlanBeforeApply();
      if (!mounted) return;
      StudyToast.show(context, '看完建议后，再点一次保存即可');
      return;
    }
    setState(() => _isApplying = true);
    var created = 0;
    try {
      if (_saveLog && plan.summary.isNotEmpty) {
        await widget.controller.addStudyLog(
          date: DateTime.now(),
          courseName: plan.courseName,
          content: plan.summary,
          nextPlan: plan.reviewPlan.map((item) => item.title).join('；'),
        );
        created++;
      }
      if (_saveTasks) created += await _createTasks(plan);
      if (_saveNote &&
          (plan.noteDraft.title.isNotEmpty ||
              plan.noteDraft.content.isNotEmpty)) {
        await widget.controller.addStudyNote(
          title: plan.noteDraft.title.isNotEmpty
              ? plan.noteDraft.title
              : '${plan.courseName.isEmpty ? '学习' : plan.courseName}复盘笔记',
          content: plan.noteDraft.content.isNotEmpty
              ? plan.noteDraft.content
              : plan.summary,
          courseName: plan.courseName,
          blocks: _noteBlocks(plan),
        );
        created++;
      }
      var createdFlashCardIds = const <String>[];
      if (_saveFlashCards && plan.flashcards.isNotEmpty) {
        createdFlashCardIds = await _createFlashCards(plan);
        created += createdFlashCardIds.length;
      }
      if (created > 0) {
        await widget.controller.appendActionRecord(
          AiActionRecord(
            id: 'action_loop_${DateTime.now().microsecondsSinceEpoch}',
            toolId: 'loop.create_from_source',
            targetTitle: plan.courseName.isEmpty ? '学习安排' : plan.courseName,
            status: AiActionStatus.executed,
            resultMessage: '已保存 $created 项学习内容',
            params: {
              'loopSchemaVersion': plan.loopSchemaVersion,
              'summary': plan.summary,
              'sourceEvidence': plan.sourceEvidence
                  .map((source) => {
                        'type': source.type,
                        'summary': source.summary,
                        'confidence': source.confidence,
                      })
                  .toList(),
              'reflectionAnalysis': {
                'summary': plan.reflectionAnalysis.summary,
                'blockers': plan.reflectionAnalysis.blockers,
                'emotion': {
                  'label': plan.reflectionAnalysis.emotion.label,
                  'intensity': plan.reflectionAnalysis.emotion.intensity,
                },
                'mastery': plan.reflectionAnalysis.mastery,
                'forgettingRisk': plan.reflectionAnalysis.forgettingRisk,
                'nextActions': plan.reflectionAnalysis.nextActions,
                'explanation': plan.reflectionAnalysis.explanation,
              },
              'createdCount': created,
              'actionCards': plan.actionCards
                  .map((card) => {
                        'title': card.title,
                        'steps': card.steps,
                        'reason': card.reason,
                        'deadline': card.deadline?.toIso8601String(),
                        'priority': card.priority,
                        'durationMinutes': card.durationMinutes,
                        'successCriteria': card.successCriteria,
                        'source': card.source,
                      })
                  .toList(),
              'reviewCards': plan.reviewCards
                  .map((card) => {
                        'title': card.title,
                        'date': card.date?.toIso8601String(),
                        'minutes': card.minutes,
                        'reason': card.reason,
                      })
                  .toList(),
              'selfCheck': _planCheckText,
              'capabilities': plan.vivoCapabilitiesUsed,
              'capabilityTraces': plan.capabilityTraces
                  .map((trace) => {
                        'abilityName': trace.abilityName,
                        'endpoint': trace.endpoint,
                        'success': trace.success,
                        'durationMs': trace.durationMs,
                        'requestId': trace.requestId,
                      })
                  .toList(),
            },
            createdAt: DateTime.now(),
          ),
        );
        unawaited(
          widget.controller.activityService.create(
            type: 'aiLoopApplied',
            title: plan.courseName.isEmpty
                ? '学习内容已保存'
                : '${plan.courseName} 学习内容已保存',
            summary: '已保存 $created 项学习内容',
            sourceType: 'ai_action',
            sourceId: 'loop.create_from_source',
            payloadJson: {
              'createdCount': created,
              'courseName': plan.courseName,
              'capabilities': plan.vivoCapabilitiesUsed,
            },
          ).catchError((_) {}),
        );
      }
      if (!mounted) return;
      setState(() {
        _isApplying = false;
        _lastCreatedFlashCardIds = createdFlashCardIds;
        _statusText = created == 0 ? '没有勾选可保存内容' : '已保存 $created 项学习内容';
      });
      var momentSaved = false;
      if (created > 0) {
        momentSaved = await _savePrivateMomentForPlan(plan);
      }
      if (!mounted) return;
      StudyToast.show(
        context,
        created == 0
            ? '没有勾选可保存内容'
            : momentSaved
                ? '已保存 $created 项学习内容，并留下私密学迹'
                : '已保存 $created 项学习内容',
      );
      if (created > 0) {
        await _showSavedNextStepDialog(
          created,
          hasSavedMoment: momentSaved,
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isApplying = false;
        _statusText = '这次没有保存成功，内容还在，可以稍后再试';
      });
    }
  }

  Future<bool> _savePrivateMomentForPlan(AiLearningLoopPlan plan) async {
    final summary = plan.summary.trim();
    final nextActions = [
      ...plan.actionCards.map((card) => card.title.trim()),
      ...plan.taskDrafts.map((task) => task.title.trim()),
      ...plan.reviewPlan.map((item) => item.title.trim()),
    ].where((text) => text.isNotEmpty).take(3).toList(growable: false);
    final content = [
      if (summary.isNotEmpty) summary,
      if (nextActions.isNotEmpty) '下一步：${nextActions.join('；')}',
    ].join('\n');
    if (content.trim().isEmpty) return false;
    try {
      await widget.controller.publishLearningMoment(
        content: content,
        courseName: plan.courseName,
        visibility: LearningMomentVisibility.private,
        sourceType: 'learning_loop',
        sourceId: 'loop.create_from_source',
      );
      return true;
    } catch (_) {
      // 学迹沉淀失败不阻断已保存内容后的下一步路径。
      return false;
    }
  }

  Future<int> _createTasks(AiLearningLoopPlan plan) async {
    var created = 0;
    final now = DateTime.now();
    for (final draft in plan.taskDrafts.take(3)) {
      final subTasks = draft.subTasks.take(4).map((item) {
        final index = draft.subTasks.indexOf(item);
        return StudySubTaskItem(
          id: 'sub_loop_${now.microsecondsSinceEpoch}_$index',
          title: item.title,
          deadline: item.deadline ??
              draft.deadline ??
              now.add(const Duration(days: 3)),
          note: item.note,
          createdAt: now,
          updatedAt: now,
        );
      }).toList();
      await widget.controller.addStudyTask(
        title: draft.title,
        type: draft.type,
        courseName: plan.courseName,
        deadline: draft.deadline ?? now.add(const Duration(days: 3)),
        note: draft.note.isNotEmpty ? draft.note : plan.summary,
        subTasks: subTasks,
      );
      created++;
    }
    final existingTitles = plan.taskDrafts
        .take(3)
        .map((draft) => draft.title.trim())
        .where((title) => title.isNotEmpty)
        .toSet();
    for (final entry in plan.actionCards.take(3).toList().asMap().entries) {
      final cardIndex = entry.key;
      final card = entry.value;
      if (existingTitles.contains(card.title.trim())) continue;
      final subTasks = card.steps
          .take(4)
          .where((step) => step.trim().isNotEmpty)
          .toList()
          .asMap()
          .entries
          .map((stepEntry) {
        return StudySubTaskItem(
          id: 'sub_action_${now.microsecondsSinceEpoch}_${cardIndex}_${stepEntry.key}',
          title: stepEntry.value,
          deadline: card.deadline ?? DateTime(now.year, now.month, now.day, 22),
          note: card.successCriteria,
          createdAt: now,
          updatedAt: now,
        );
      }).toList();
      await widget.controller.addStudyTask(
        title: card.title,
        type: StudyTaskType.other,
        courseName: plan.courseName,
        deadline: card.deadline ?? DateTime(now.year, now.month, now.day, 22),
        note: [
          if (card.priority.isNotEmpty)
            '优先级：${_learningActionPriorityLabel(card.priority)}',
          if (card.durationMinutes > 0) '预计耗时：${card.durationMinutes} 分钟',
          if (card.reason.isNotEmpty) card.reason,
          if (card.successCriteria.isNotEmpty)
            '做到这些就算完成：${card.successCriteria}',
          if (card.source.isNotEmpty) '参考：${card.source}',
        ].join('\n').trim(),
        subTasks: subTasks,
      );
      created++;
    }
    if (created == 0) {
      final reviews =
          plan.reviewPlan.isNotEmpty ? plan.reviewPlan : plan.reviewCards;
      for (final item in reviews.take(4)) {
        await widget.controller.addStudyTask(
          title: item.title,
          type: StudyTaskType.other,
          courseName: plan.courseName,
          deadline: item.date ?? DateTime(now.year, now.month, now.day, 22),
          note: '${item.reason}\n建议专注 ${item.minutes} 分钟'.trim(),
        );
        created++;
      }
    }
    return created;
  }

  Future<void> _showSavedNextStepDialog(
    int createdCount, {
    bool hasSavedMoment = false,
  }) async {
    final plan = _plan;
    if (!mounted || plan == null) return;
    final actionCount = plan.actionCards.length + plan.taskDrafts.length;
    final flashcardIds = _lastCreatedFlashCardIds;
    final flashcardCount = flashcardIds.length;
    final choice = await showDialog<_SavedPlanNextStep>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: _SavedNextStepDialogContent(
          isDarkMode: widget.isDarkMode,
          createdCount: createdCount,
          actionCount: actionCount,
          flashcardCount: flashcardCount,
          hasSavedMoment: hasSavedMoment,
          canOpenTasks: widget.onOpenTasks != null,
          canOpenFlashcards: (widget.onStartFlashCardReview != null ||
                  widget.onOpenFlashCards != null) &&
              flashcardCount > 0,
          canOpenReview: widget.onOpenLearningMoments != null ||
              widget.onOpenEvidencePackage != null,
          onLater: () => Navigator.of(dialogContext).pop(),
          onFocus: () =>
              Navigator.of(dialogContext).pop(_SavedPlanNextStep.focus),
          onTasks: () =>
              Navigator.of(dialogContext).pop(_SavedPlanNextStep.tasks),
          onFlashcards: () =>
              Navigator.of(dialogContext).pop(_SavedPlanNextStep.flashcards),
          onReview: () =>
              Navigator.of(dialogContext).pop(_SavedPlanNextStep.review),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _SavedPlanNextStep.focus:
        _startFirstFocusBlock();
        return;
      case _SavedPlanNextStep.tasks:
        await _leavePageThen(widget.onOpenTasks);
        return;
      case _SavedPlanNextStep.review:
        await _leavePageThen(
          widget.onOpenLearningMoments ?? widget.onOpenEvidencePackage,
        );
        return;
      case _SavedPlanNextStep.flashcards:
        if (widget.onStartFlashCardReview != null) {
          await _leavePageThen(
            () => widget.onStartFlashCardReview!(flashcardIds),
          );
        } else {
          await _leavePageThen(widget.onOpenFlashCards);
        }
        return;
    }
  }

  Future<void> _leavePageThen(VoidCallback? action) async {
    if (action == null || !mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      await navigator.maybePop();
    }
    action();
  }

  Future<List<String>> _createFlashCards(AiLearningLoopPlan plan) async {
    final now = DateTime.now();
    final cards = plan.flashcards.take(8).map((draft) {
      final index = plan.flashcards.indexOf(draft);
      return AiFlashCard(
        id: 'fc_loop_${now.microsecondsSinceEpoch}_$index',
        question: draft.question,
        answer: draft.answer,
        hint: draft.hint,
        courseName:
            draft.courseName.isNotEmpty ? draft.courseName : plan.courseName,
        groupName: plan.courseName.isEmpty ? '学习复盘' : '${plan.courseName}复盘',
        createdAt: now,
      );
    }).toList();
    if (cards.isEmpty) return const [];
    await widget.controller.addFlashCards(cards);
    return cards.map((card) => card.id).toList(growable: false);
  }

  List<NoteBlock> _noteBlocks(AiLearningLoopPlan plan) {
    var idCounter = DateTime.now().microsecondsSinceEpoch;
    String id() => 'block_${idCounter++}';
    if (plan.noteDraft.blocks.isEmpty) {
      final source = plan.noteDraft.content.isNotEmpty
          ? plan.noteDraft.content
          : plan.summary;
      return source
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .map((line) => NoteBlock(id: id(), content: line))
          .toList();
    }
    return plan.noteDraft.blocks.map((block) {
      final type = switch (block.type) {
        'heading' => NoteBlockType.heading,
        'bullet' => NoteBlockType.bullet,
        'todo' => NoteBlockType.todo,
        'markdown' => NoteBlockType.markdown,
        'image' => NoteBlockType.image,
        'code' => NoteBlockType.code,
        _ => NoteBlockType.text,
      };
      return NoteBlock(id: id(), type: type, content: block.content);
    }).toList();
  }

  void _startFirstFocusBlock() {
    final plan = _plan;
    final rawMinutes = plan == null
        ? 25
        : plan.actionCards.map((card) => card.durationMinutes).firstWhere(
              (value) => value > 0,
              orElse: () => plan.reviewPlan.isNotEmpty
                  ? plan.reviewPlan.first.minutes
                  : plan.reviewCards.isNotEmpty
                      ? plan.reviewCards.first.minutes
                      : 25,
            );
    final minutes = rawMinutes.clamp(5, 180).toInt();
    final focusTitles = plan == null
        ? const <String>[]
        : [
            ...plan.actionCards.map((card) => card.title),
            ...plan.taskDrafts.map((task) => task.title),
            ...plan.reviewPlan.map((item) => item.title),
            ...plan.reviewCards.map((item) => item.title),
            plan.summary,
          ]
            .map((title) => title.trim())
            .where((title) => title.isNotEmpty)
            .toList();
    final focusTitle = focusTitles.isEmpty ? null : focusTitles.first;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TimerPage(
          isDarkMode: widget.isDarkMode,
          controller: widget.controller,
          initialMinutes: minutes,
          focusTitle: focusTitle,
          autoStart: true,
        ),
      ),
    );
  }

  Future<void> _toggleVoiceReview() async {
    try {
      if (_isRecordingReview) {
        final path = await _audioRecorder.stop();
        if (!mounted) return;
        setState(() {
          _isRecordingReview = false;
          _isPreparingMaterial = true;
          _statusText = '正在转写语音内容...';
        });
        if (path == null || path.isEmpty) {
          setState(() {
            _isPreparingMaterial = false;
            _statusText = '未获取到录音文件，可直接输入文字材料';
          });
          return;
        }
        final text = await widget.controller.cloudSpeechService.transcribeBytes(
          await XFile(path).readAsBytes(),
          mimeType: 'audio/m4a',
          longForm: true,
        );
        if (!mounted) return;
        if (text.trim().isEmpty) {
          setState(() {
            _isPreparingMaterial = false;
            _statusText = '语音转写未返回内容，可使用文字模式继续';
          });
          return;
        }
        unawaited(
          widget.controller.activityService
              .create(
                type: 'voiceReview',
                title: '语音材料',
                summary: text.trim(),
                sourceType: 'voice_review',
                sourceId: 'voice_${DateTime.now().microsecondsSinceEpoch}',
              )
              .catchError((_) {}),
        );
        setState(() {
          _appendMaterialItem(
            type: 'voice',
            title: '语音材料 ${_materialItems.length + 1}',
            text: text,
          );
          _pendingLoopImageBase64 = null;
          _pendingLoopSourceKind = 'voice';
          _isPreparingMaterial = false;
          _statusText = '语音已追加到材料清单，确认后点“整理学习安排”。';
        });
        return;
      }
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        setState(() => _statusText = '未获得麦克风权限，可直接输入文字材料');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/studytrace_review_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      if (!mounted) return;
      setState(() {
        _isRecordingReview = true;
        _statusText = '正在录音材料，再次点击结束并转写';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isRecordingReview = false;
        _isPreparingMaterial = false;
        _statusText = '语音转写暂时不可用，可直接输入文字材料。';
      });
    }
  }
}

enum _SavedPlanNextStep { focus, tasks, flashcards, review }

class _SavedNextStepDialogContent extends StatelessWidget {
  const _SavedNextStepDialogContent({
    required this.isDarkMode,
    required this.createdCount,
    required this.actionCount,
    required this.flashcardCount,
    required this.hasSavedMoment,
    required this.canOpenTasks,
    required this.canOpenFlashcards,
    required this.canOpenReview,
    required this.onLater,
    required this.onFocus,
    required this.onTasks,
    required this.onFlashcards,
    required this.onReview,
  });

  final bool isDarkMode;
  final int createdCount;
  final int actionCount;
  final int flashcardCount;
  final bool hasSavedMoment;
  final bool canOpenTasks;
  final bool canOpenFlashcards;
  final bool canOpenReview;
  final VoidCallback onLater;
  final VoidCallback onFocus;
  final VoidCallback onTasks;
  final VoidCallback onFlashcards;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    const accent = StudyUi.primary;
    return StudyFontScope(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          child: Container(
            width: 360,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: StudyUi.surface(isDarkMode),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    BadgePill(
                      label: '保存完成',
                      background: StudyUi.chipBackground(accent, isDarkMode),
                      foreground: accent,
                    ),
                    const Spacer(),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: StudyUi.chipBackground(accent, isDarkMode),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.route_rounded,
                        color: accent,
                        size: 19,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '已保存，下一步去复习或回看',
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 21,
                    fontWeight: AppTypography.hero,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  [
                    '刚刚保存了 $createdCount 项学习内容。',
                    if (hasSavedMoment) '这次整理已进入私密学迹，稍后可以回看。',
                    if (actionCount > 0) '可以先从第一件事开始。',
                    if (flashcardCount > 0) '也可以用新闪卡巩固一下。',
                  ].join('\n'),
                  style: TextStyle(color: bodyColor, height: 1.42),
                ),
                const SizedBox(height: 14),
                _SavedPathPreview(
                  isDarkMode: isDarkMode,
                  hasTasks: actionCount > 0,
                  hasFlashcards: flashcardCount > 0,
                  hasReview: canOpenReview,
                ),
                const SizedBox(height: 16),
                _CockpitActionButton(
                  icon: Icons.play_arrow_rounded,
                  label: '先开始一段专注',
                  color: accent,
                  isDarkMode: isDarkMode,
                  expand: true,
                  onPressed: onFocus,
                ),
                const SizedBox(height: 10),
                if (canOpenTasks)
                  _SavedNextStepTile(
                    isDarkMode: isDarkMode,
                    color: StudyUi.success,
                    icon: Icons.task_alt_rounded,
                    title: '看今日安排',
                    subtitle: '看刚整理出的下一步',
                    onTap: onTasks,
                  ),
                if (canOpenFlashcards) ...[
                  if (canOpenTasks) const SizedBox(height: 8),
                  _SavedNextStepTile(
                    isDarkMode: isDarkMode,
                    color: StudyUi.warning,
                    icon: Icons.style_rounded,
                    title: '复习闪卡',
                    subtitle: '复习这次整理出的 $flashcardCount 张闪卡',
                    onTap: onFlashcards,
                  ),
                ],
                if (canOpenReview) ...[
                  if (canOpenTasks || canOpenFlashcards)
                    const SizedBox(height: 8),
                  _SavedNextStepTile(
                    isDarkMode: isDarkMode,
                    color: StudyUi.secondary,
                    icon: Icons.timeline_rounded,
                    title: '回看学迹',
                    subtitle: '回看这次整理留下的记录',
                    onTap: onReview,
                  ),
                ],
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: _CockpitActionButton(
                    icon: Icons.schedule_rounded,
                    label: '稍后再说',
                    color: StudyUi.muted(isDarkMode),
                    isDarkMode: isDarkMode,
                    filled: false,
                    onPressed: onLater,
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

class _SavedPathPreview extends StatelessWidget {
  const _SavedPathPreview({
    required this.isDarkMode,
    required this.hasTasks,
    required this.hasFlashcards,
    required this.hasReview,
  });

  final bool isDarkMode;
  final bool hasTasks;
  final bool hasFlashcards;
  final bool hasReview;

  @override
  Widget build(BuildContext context) {
    final steps = [
      _SavedPathStep('保存', Icons.done_all_rounded, StudyUi.primary, true),
      _SavedPathStep('专注', Icons.timer_rounded, StudyUi.success, hasTasks),
      _SavedPathStep('复习', Icons.style_rounded, StudyUi.warning, hasFlashcards),
      _SavedPathStep(
          '学迹', Icons.timeline_rounded, StudyUi.secondary, hasReview),
    ];
    return SizedBox(
      height: 64,
      child: Stack(
        children: [
          Positioned(
            left: 22,
            right: 22,
            top: 18,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  colors: [
                    StudyUi.primary.withValues(alpha: 0.5),
                    StudyUi.success.withValues(alpha: 0.3),
                    StudyUi.warning.withValues(alpha: 0.25),
                    StudyUi.secondary.withValues(alpha: 0.28),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final step in steps)
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: StudyUi.surface(isDarkMode),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: step.color.withValues(
                              alpha: step.active ? 0.42 : 0.16,
                            ),
                          ),
                        ),
                        child: Icon(
                          step.icon,
                          color: step.active
                              ? step.color
                              : StudyUi.muted(isDarkMode),
                          size: 17,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        step.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: step.active
                              ? StudyUi.title(isDarkMode)
                              : StudyUi.muted(isDarkMode),
                          fontSize: 11,
                          fontWeight: AppTypography.title,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SavedPathStep {
  const _SavedPathStep(this.label, this.icon, this.color, this.active);

  final String label;
  final IconData icon;
  final Color color;
  final bool active;
}

class _SavedNextStepTile extends StatelessWidget {
  const _SavedNextStepTile({
    required this.isDarkMode,
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool isDarkMode;
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: StudyUi.chipBackground(color, isDarkMode),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.14)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: StudyUi.surface(isDarkMode)
                      .withValues(alpha: isDarkMode ? 0.62 : 0.74),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 17),
              ),
              const SizedBox(width: 10),
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
                        fontWeight: AppTypography.title,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: StudyUi.body(isDarkMode),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color, size: 19),
            ],
          ),
        ),
      ),
    );
  }
}

String _learningActionPriorityLabel(String value) {
  return switch (value.toLowerCase()) {
    'high' => '高',
    'medium' => '中',
    'low' => '低',
    _ => value,
  };
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.isDarkMode,
    required this.accent,
  });

  final bool isDarkMode;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return StudyPathHero(
      isDarkMode: isDarkMode,
      accent: accent,
      badge: '学习整理台',
      title: '把今天的学习理顺',
      subtitle: '先放入学习材料，再整理下一步，保存后就能复习和回看。',
      icon: Icons.hub_rounded,
      steps: const ['学习材料', '整理下一步', '保存回看'],
      child: Column(
        children: [
          Row(
            children: [
              _HeroPathNode(
                icon: Icons.folder_rounded,
                label: '学习材料',
                color: StudyUi.pathBlue,
                isDarkMode: isDarkMode,
              ),
              const SizedBox(width: 8),
              _HeroPathNode(
                icon: Icons.auto_awesome_rounded,
                label: '整理下一步',
                color: StudyUi.pathViolet,
                isDarkMode: isDarkMode,
              ),
              const SizedBox(width: 8),
              _HeroPathNode(
                icon: Icons.check_rounded,
                label: '保存回看',
                color: StudyUi.pathMint,
                isDarkMode: isDarkMode,
              ),
            ],
          ),
          const SizedBox(height: 12),
          StudyCard(
            padding: const EdgeInsets.all(14),
            color: StudyUi.surface(isDarkMode).withValues(
              alpha: isDarkMode ? 0.72 : 0.86,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GoalBullet(
                  text: '输入或拍摄学习材料',
                  color: StudyUi.pathBlue,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(height: 6),
                _GoalBullet(
                  text: '整理今天可执行的下一步',
                  color: StudyUi.pathViolet,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(height: 6),
                _GoalBullet(
                  text: '保存后去专注、复习或回看学迹',
                  color: StudyUi.pathMint,
                  isDarkMode: isDarkMode,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPathNode extends StatelessWidget {
  const _HeroPathNode({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDarkMode,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          StudyGlassIconNode(
            icon: icon,
            accent: color,
            size: 46,
            iconSize: 20,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(height: 7),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: StudyUi.title(isDarkMode),
              fontSize: 12,
              fontWeight: AppTypography.title,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalBullet extends StatelessWidget {
  const _GoalBullet({
    required this.text,
    required this.color,
    required this.isDarkMode,
  });

  final String text;
  final Color color;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.18),
          ),
          child: Icon(
            Icons.check_rounded,
            size: 12,
            color: color,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: titleColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ManualSourceCard extends StatelessWidget {
  const _ManualSourceCard({
    required this.isDarkMode,
    required this.learnedController,
    required this.blockerController,
    required this.nextStepController,
    required this.isBusy,
    required this.canGenerate,
    required this.statusText,
    required this.statusColor,
    required this.materialItems,
    required this.onCapturePhoto,
    required this.onRecordVoice,
    required this.onImportFile,
    required this.onRemoveMaterial,
    required this.onAskAiNextStep,
    required this.onGenerate,
  });

  final bool isDarkMode;
  final TextEditingController learnedController;
  final TextEditingController blockerController;
  final TextEditingController nextStepController;
  final bool isBusy;
  final bool canGenerate;
  final String statusText;
  final Color statusColor;
  final List<_LoopMaterialItem> materialItems;
  final VoidCallback onCapturePhoto;
  final VoidCallback onRecordVoice;
  final VoidCallback onImportFile;
  final ValueChanged<String> onRemoveMaterial;
  final VoidCallback onAskAiNextStep;
  final VoidCallback onGenerate;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StudyGlassIconNode(
                icon: Icons.library_books_rounded,
                accent: StudyUi.secondary,
                size: 44,
                iconSize: 20,
                isDarkMode: isDarkMode,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '输入学习材料',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 17,
                        fontWeight: AppTypography.hero,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '拍照、语音、本地图片会先进入材料清单；你也可以直接补文字。',
                      style: TextStyle(
                        color: bodyColor,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StudyStatusChip(
                  label: '拍照',
                  color: StudyUi.secondary,
                  icon: Icons.photo_camera_rounded,
                  onTap: onCapturePhoto,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StudyStatusChip(
                  label: '语音',
                  color: StudyUi.pathCyan,
                  icon: Icons.mic_rounded,
                  onTap: onRecordVoice,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StudyStatusChip(
                  label: '本地图片',
                  color: StudyUi.pathMint,
                  icon: Icons.photo_library_rounded,
                  onTap: onImportFile,
                ),
              ),
            ],
          ),
          if (materialItems.isNotEmpty) ...[
            const SizedBox(height: 10),
            _MaterialListPanel(
              items: materialItems,
              isDarkMode: isDarkMode,
              onRemove: onRemoveMaterial,
            ),
          ],
          if (statusText.isNotEmpty) ...[
            const SizedBox(height: 8),
            _CockpitInlineStatus(
              text: statusText,
              isDarkMode: isDarkMode,
              color: statusColor,
            ),
          ],
          const SizedBox(height: 12),
          _ReviewInputBlock(
            index: 1,
            title: '学了什么',
            hint: '今天学了哪些内容？可以粘贴笔记、题目或课程通知。',
            controller: learnedController,
            isDarkMode: isDarkMode,
            color: StudyUi.secondary,
            minLines: 3,
          ),
          const SizedBox(height: 12),
          _ReviewInputBlock(
            index: 2,
            title: '哪里不懂',
            hint: '哪里还没弄懂？哪一步容易出错？',
            controller: blockerController,
            isDarkMode: isDarkMode,
            color: StudyUi.warning,
          ),
          const SizedBox(height: 12),
          _ReviewInputBlock(
            index: 3,
            title: '下一步怎么做',
            hint: '明天先做哪一道题、哪页笔记或哪段练习？',
            controller: nextStepController,
            isDarkMode: isDarkMode,
            color: StudyUi.primary,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: StudyStatusChip(
              label: 'AI 判断下一步',
              color: StudyUi.primary,
              icon: Icons.auto_awesome_rounded,
              onTap: onAskAiNextStep,
            ),
          ),
          const SizedBox(height: 12),
          _ReviewGradientButton(
            isBusy: isBusy,
            enabled: canGenerate,
            onTap: onGenerate,
          ),
        ],
      ),
    );
  }
}

class _MaterialListPanel extends StatelessWidget {
  const _MaterialListPanel({
    required this.items,
    required this.isDarkMode,
    required this.onRemove,
  });

  final List<_LoopMaterialItem> items;
  final bool isDarkMode;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
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
              Icon(Icons.playlist_add_check_rounded,
                  color: StudyUi.pathMint, size: 18),
              const SizedBox(width: 6),
              Text(
                '材料清单',
                style: TextStyle(
                  color: titleColor,
                  fontWeight: AppTypography.title,
                ),
              ),
              const Spacer(),
              Text(
                '${items.length} 条',
                style: TextStyle(color: bodyColor, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _materialIcon(item.type),
                      size: 17,
                      color: _materialColor(item.type),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: titleColor,
                              fontSize: 13,
                              fontWeight: AppTypography.emphasis,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: bodyColor,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: '移除',
                      icon: Icon(Icons.close_rounded,
                          size: 16, color: StudyUi.muted(isDarkMode)),
                      onPressed: () => onRemove(item.id),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  static IconData _materialIcon(String type) => switch (type) {
        'photo' => Icons.photo_camera_rounded,
        'localImage' => Icons.photo_library_rounded,
        'voice' => Icons.mic_rounded,
        _ => Icons.notes_rounded,
      };

  static Color _materialColor(String type) => switch (type) {
        'photo' => StudyUi.secondary,
        'localImage' => StudyUi.pathMint,
        'voice' => StudyUi.pathCyan,
        _ => StudyUi.primary,
      };
}

class _LoopPromptCard extends StatelessWidget {
  const _LoopPromptCard({
    required this.isDarkMode,
    required this.accent,
    required this.isBusy,
    required this.canGenerate,
    required this.onGenerate,
  });

  final bool isDarkMode;
  final Color accent;
  final bool isBusy;
  final bool canGenerate;
  final VoidCallback onGenerate;

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
              StudyGlassIconNode(
                icon: Icons.route_rounded,
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
                      '先把下一步理出来',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 16,
                        fontWeight: AppTypography.hero,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '先看一眼，再决定保存哪些内容。',
                      style: TextStyle(color: bodyColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              _LoopPromptStep(
                index: 1,
                title: '学了什么',
                subtitle: '先提炼今天的核心内容',
                color: StudyUi.secondary,
                isDarkMode: isDarkMode,
              ),
              const SizedBox(height: 8),
              _LoopPromptStep(
                index: 2,
                title: '哪里不懂',
                subtitle: '再定位容易出错的地方',
                color: StudyUi.pathViolet,
                isDarkMode: isDarkMode,
              ),
              const SizedBox(height: 8),
              _LoopPromptStep(
                index: 3,
                title: '下一步怎么做',
                subtitle: '最后给出可以马上开始的小练习',
                color: StudyUi.pathCyan,
                isDarkMode: isDarkMode,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _CockpitActionButton(
            icon: Icons.auto_awesome_rounded,
            label: isBusy ? '整理中...' : (canGenerate ? '整理学习安排' : '先输入学习材料'),
            color: accent,
            isDarkMode: isDarkMode,
            expand: true,
            onPressed: isBusy || !canGenerate ? null : onGenerate,
            busyIcon: isBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _LoopPromptStep extends StatelessWidget {
  const _LoopPromptStep({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isDarkMode,
  });

  final int index;
  final String title;
  final String subtitle;
  final Color color;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDarkMode ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.95),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: AppTypography.hero,
                fontSize: 12,
              ),
            ),
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
                    color: titleColor,
                    fontWeight: AppTypography.title,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: bodyColor,
                    fontSize: 11.5,
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

class _ReviewInputBlock extends StatelessWidget {
  const _ReviewInputBlock({
    required this.index,
    required this.title,
    required this.hint,
    required this.controller,
    required this.isDarkMode,
    required this.color,
    this.minLines = 2,
  });

  final int index;
  final String title;
  final String hint;
  final TextEditingController controller;
  final bool isDarkMode;
  final Color color;
  final int minLines;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDarkMode
              ? StudyUi.border(isDarkMode)
              : Colors.white.withValues(alpha: 0.78),
        ),
        boxShadow: [
          if (!isDarkMode)
            BoxShadow(
              color: color.withValues(alpha: 0.10),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: 0.92),
                      color.withValues(alpha: 0.56),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Text(
                  '$index',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: AppTypography.hero,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: titleColor,
                  fontWeight: AppTypography.title,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            minLines: minLines,
            maxLines: minLines + 2,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: bodyColor.withValues(alpha: 0.62)),
              filled: true,
              fillColor: StudyUi.surfaceAlt(isDarkMode).withValues(
                alpha: isDarkMode ? 0.72 : 0.88,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: StudyUi.border(isDarkMode)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: color.withValues(alpha: isDarkMode ? 0.18 : 0.12),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: color.withValues(alpha: 0.56)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CockpitIconButton extends StatelessWidget {
  const _CockpitIconButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.isDarkMode,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final bool isDarkMode;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final foreground = disabled ? StudyUi.muted(isDarkMode) : color;
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: disabled ? null : onPressed,
              child: Ink(
                decoration: BoxDecoration(
                  color: StudyUi.chipBackground(color, isDarkMode),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: color.withValues(alpha: disabled ? 0.08 : 0.18),
                  ),
                  boxShadow: [
                    if (!isDarkMode && !disabled)
                      BoxShadow(
                        color: color.withValues(alpha: 0.10),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      ),
                  ],
                ),
                child: Center(
                  child: Icon(icon, size: 19, color: foreground),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CockpitSheetSurface extends StatelessWidget {
  const _CockpitSheetSurface({
    required this.isDarkMode,
    required this.accent,
    required this.child,
    required this.maxHeight,
  });

  final bool isDarkMode;
  final Color accent;
  final Widget child;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: StudyUi.surface(isDarkMode).withValues(
                alpha: isDarkMode ? 0.92 : 0.88,
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDarkMode ? 0.08 : 0.68),
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: isDarkMode ? 0.16 : 0.10),
                  blurRadius: 30,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _CockpitActionButton extends StatelessWidget {
  const _CockpitActionButton({
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

class _ReviewGradientButton extends StatelessWidget {
  const _ReviewGradientButton({
    required this.isBusy,
    required this.enabled,
    required this.onTap,
  });

  final bool isBusy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final canTap = enabled && !isBusy;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: canTap
                ? const [
                    Color(0xFF5F91F5),
                    Color(0xFF7F7CF6),
                    Color(0xFFD49AF8),
                  ]
                : [
                    StudyUi.muted(
                            Theme.of(context).brightness == Brightness.dark)
                        .withValues(alpha: 0.32),
                    StudyUi.muted(
                            Theme.of(context).brightness == Brightness.dark)
                        .withValues(alpha: 0.18),
                  ],
          ),
          boxShadow: [
            if (canTap)
              BoxShadow(
                color: const Color(0xFF6E7DF5).withValues(alpha: 0.28),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: canTap ? onTap : null,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isBusy)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                const SizedBox(width: 8),
                Text(
                  isBusy ? '整理中...' : (enabled ? '整理学习安排' : '先输入学习材料'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: AppTypography.hero,
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

class _LoopPreview extends StatelessWidget {
  const _LoopPreview({
    required this.plan,
    required this.isDarkMode,
    required this.accent,
    required this.saveLog,
    required this.saveTasks,
    required this.saveNote,
    required this.saveFlashCards,
    required this.isApplying,
    required this.isCheckingPlan,
    required this.planCheckText,
    required this.onSaveLogChanged,
    required this.onSaveTasksChanged,
    required this.onSaveNoteChanged,
    required this.onSaveFlashCardsChanged,
    required this.onCheckPlan,
    required this.onApply,
    required this.onStartFocus,
  });

  final AiLearningLoopPlan plan;
  final bool isDarkMode;
  final Color accent;
  final bool saveLog;
  final bool saveTasks;
  final bool saveNote;
  final bool saveFlashCards;
  final bool isApplying;
  final bool isCheckingPlan;
  final String planCheckText;
  final ValueChanged<bool> onSaveLogChanged;
  final ValueChanged<bool> onSaveTasksChanged;
  final ValueChanged<bool> onSaveNoteChanged;
  final ValueChanged<bool> onSaveFlashCardsChanged;
  final VoidCallback onCheckPlan;
  final VoidCallback onApply;
  final VoidCallback onStartFocus;

  @override
  Widget build(BuildContext context) {
    final bodyColor = StudyUi.body(isDarkMode);
    return StudyCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LoopResultHeader(
            plan: plan,
            isDarkMode: isDarkMode,
            accent: accent,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ReflectionDiagnosisCard(
                  plan: plan,
                  isDarkMode: isDarkMode,
                  accent: accent,
                ),
                const SizedBox(height: 10),
                _TrustExplanationCard(
                  plan: plan,
                  isDarkMode: isDarkMode,
                  accent: accent,
                ),
                const SizedBox(height: 12),
                _SaveChoicesPanel(
                  isDarkMode: isDarkMode,
                  accent: accent,
                  saveLog: saveLog,
                  saveTasks: saveTasks,
                  saveNote: saveNote,
                  saveFlashCards: saveFlashCards,
                  canSaveLog: plan.summary.isNotEmpty,
                  canSaveTasks: _hasTaskLikeContent(plan),
                  canSaveNote: plan.noteDraft.title.isNotEmpty ||
                      plan.noteDraft.content.isNotEmpty,
                  canSaveFlashCards: plan.flashcards.isNotEmpty,
                  onSaveLogChanged: onSaveLogChanged,
                  onSaveTasksChanged: onSaveTasksChanged,
                  onSaveNoteChanged: onSaveNoteChanged,
                  onSaveFlashCardsChanged: onSaveFlashCardsChanged,
                ),
                if (plan.noteDraft.content.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _MarkdownNotePreview(
                    markdown: plan.noteDraft.content,
                    isDarkMode: isDarkMode,
                    accent: accent,
                  ),
                ],
                const SizedBox(height: 8),
                _PreviewList(
                    title: '今日安排',
                    items: plan.taskDrafts.map((t) => t.title).toList()),
                _ActionCardsPreview(
                  plan: plan,
                  isDarkMode: isDarkMode,
                  accent: accent,
                ),
                _PreviewList(
                    title: '复习闪卡',
                    items:
                        plan.flashcards.map((card) => card.question).toList()),
                if (planCheckText.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withValues(alpha: 0.16)),
                    ),
                    child: Text(
                      planCheckText,
                      style: TextStyle(color: bodyColor, height: 1.35),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _CockpitActionButton(
                  icon: Icons.fact_check_rounded,
                  label: isCheckingPlan ? '确认中...' : '看一眼再保存',
                  color: accent,
                  isDarkMode: isDarkMode,
                  filled: false,
                  expand: true,
                  onPressed: isCheckingPlan ? null : onCheckPlan,
                  busyIcon: isCheckingPlan
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _CockpitActionButton(
                        icon: Icons.play_arrow_rounded,
                        label: '开始专注',
                        color: StudyUi.pathCyan,
                        isDarkMode: isDarkMode,
                        filled: false,
                        expand: true,
                        onPressed: onStartFocus,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CockpitActionButton(
                        icon: Icons.done_all_rounded,
                        label: isApplying ? '保存中...' : '保存这些内容',
                        color: accent,
                        isDarkMode: isDarkMode,
                        expand: true,
                        onPressed: isApplying ? null : onApply,
                        busyIcon: isApplying
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _hasTaskLikeContent(AiLearningLoopPlan plan) =>
      plan.taskDrafts.isNotEmpty ||
      plan.actionCards.isNotEmpty ||
      plan.reviewPlan.isNotEmpty ||
      plan.reviewCards.isNotEmpty;
}

class _LoopResultHeader extends StatelessWidget {
  const _LoopResultHeader({
    required this.plan,
    required this.isDarkMode,
    required this.accent,
  });

  final AiLearningLoopPlan plan;
  final bool isDarkMode;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    final actionCount = plan.taskDrafts.length + plan.actionCards.length;
    final noteReady =
        plan.noteDraft.title.isNotEmpty || plan.noteDraft.content.isNotEmpty;
    final chips = [
      _LoopResultChipData(
        icon: Icons.history_edu_rounded,
        label: '学习记录',
        color: StudyUi.primary,
      ),
      if (actionCount > 0)
        _LoopResultChipData(
          icon: Icons.task_alt_rounded,
          label: '$actionCount 个下一步',
          color: StudyUi.success,
        ),
      if (plan.flashcards.isNotEmpty)
        _LoopResultChipData(
          icon: Icons.style_rounded,
          label: '${plan.flashcards.length} 张闪卡',
          color: StudyUi.warning,
        ),
      if (noteReady)
        _LoopResultChipData(
          icon: Icons.notes_rounded,
          label: '学习笔记',
          color: StudyUi.secondary,
        ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? const [
                  Color(0xFF1C3032),
                  Color(0xFF182633),
                  Color(0xFF251F34),
                ]
              : const [
                  Color(0xFFE9FAF4),
                  Color(0xFFF3F5FF),
                  Color(0xFFFFF8EF),
                ],
        ),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(StudyUi.radius),
        ),
        border: Border(
          bottom: BorderSide(color: StudyUi.border(isDarkMode)),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: -26,
            child: Container(
              width: 94,
              height: 94,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: isDarkMode ? 0.16 : 0.12),
              ),
            ),
          ),
          Positioned(
            right: 32,
            bottom: -34,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: StudyUi.secondary.withValues(
                  alpha: isDarkMode ? 0.13 : 0.09,
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: StudyUi.surface(isDarkMode)
                          .withValues(alpha: isDarkMode ? 0.7 : 0.9),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accent.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Icon(Icons.auto_awesome_rounded, color: accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '这次复盘整理好了',
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 18,
                            fontWeight: AppTypography.hero,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          plan.courseName.isEmpty
                              ? '先看一眼，再决定保存哪些内容'
                              : '${plan.courseName} · 先看一眼再保存',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: bodyColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                plan.summary.isEmpty ? '已整理出可编辑草稿。' : plan.summary,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: bodyColor, height: 1.42),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final chip in chips)
                    _LoopResultChip(
                      data: chip,
                      isDarkMode: isDarkMode,
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoopResultChipData {
  const _LoopResultChipData({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;
}

class _LoopResultChip extends StatelessWidget {
  const _LoopResultChip({
    required this.data,
    required this.isDarkMode,
  });

  final _LoopResultChipData data;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: StudyUi.surface(isDarkMode).withValues(
          alpha: isDarkMode ? 0.56 : 0.84,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: data.color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.icon, color: data.color, size: 15),
          const SizedBox(width: 5),
          Text(
            data.label,
            style: TextStyle(
              color: StudyUi.title(isDarkMode),
              fontSize: 12,
              fontWeight: AppTypography.emphasis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveChoicesPanel extends StatelessWidget {
  const _SaveChoicesPanel({
    required this.isDarkMode,
    required this.accent,
    required this.saveLog,
    required this.saveTasks,
    required this.saveNote,
    required this.saveFlashCards,
    required this.canSaveLog,
    required this.canSaveTasks,
    required this.canSaveNote,
    required this.canSaveFlashCards,
    required this.onSaveLogChanged,
    required this.onSaveTasksChanged,
    required this.onSaveNoteChanged,
    required this.onSaveFlashCardsChanged,
  });

  final bool isDarkMode;
  final Color accent;
  final bool saveLog;
  final bool saveTasks;
  final bool saveNote;
  final bool saveFlashCards;
  final bool canSaveLog;
  final bool canSaveTasks;
  final bool canSaveNote;
  final bool canSaveFlashCards;
  final ValueChanged<bool> onSaveLogChanged;
  final ValueChanged<bool> onSaveTasksChanged;
  final ValueChanged<bool> onSaveNoteChanged;
  final ValueChanged<bool> onSaveFlashCardsChanged;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    final choices = [
      _SaveChoiceData(
        icon: Icons.history_edu_rounded,
        title: '学习记录',
        subtitle: '保存这次复盘',
        color: StudyUi.primary,
        value: saveLog,
        enabled: canSaveLog,
        onChanged: onSaveLogChanged,
      ),
      _SaveChoiceData(
        icon: Icons.route_rounded,
        title: '今日安排',
        subtitle: '留下可以马上做的事',
        color: StudyUi.success,
        value: saveTasks,
        enabled: canSaveTasks,
        onChanged: onSaveTasksChanged,
      ),
      _SaveChoiceData(
        icon: Icons.notes_rounded,
        title: '学习笔记',
        subtitle: '把重点收进笔记',
        color: StudyUi.secondary,
        value: saveNote,
        enabled: canSaveNote,
        onChanged: onSaveNoteChanged,
      ),
      _SaveChoiceData(
        icon: Icons.style_rounded,
        title: '复习闪卡',
        subtitle: '留下后面复习的卡片',
        color: StudyUi.warning,
        value: saveFlashCards,
        enabled: canSaveFlashCards,
        onChanged: onSaveFlashCardsChanged,
      ),
    ];

    return Container(
      width: double.infinity,
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
              Icon(Icons.bookmark_added_rounded, color: accent, size: 18),
              const SizedBox(width: 8),
              Text(
                '保存到哪里，之后怎么回看',
                style: TextStyle(
                  color: titleColor,
                  fontWeight: AppTypography.title,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '不用全收下，先留下对今天最有用的部分，稍后可在任务、闪卡和学迹里继续看。',
            style: TextStyle(color: bodyColor, fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = constraints.maxWidth >= 430
                  ? (constraints.maxWidth - 8) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final choice in choices)
                    SizedBox(
                      width: tileWidth,
                      child: _SaveChoiceTile(
                        data: choice,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SaveChoiceData {
  const _SaveChoiceData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
}

class _SaveChoiceTile extends StatelessWidget {
  const _SaveChoiceTile({
    required this.data,
    required this.isDarkMode,
  });

  final _SaveChoiceData data;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final checked = data.enabled && data.value;
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: data.enabled ? () => data.onChanged(!data.value) : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: data.enabled ? 1 : 0.48,
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: checked
                  ? StudyUi.chipBackground(data.color, isDarkMode)
                  : StudyUi.surface(isDarkMode),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: checked
                    ? data.color.withValues(alpha: 0.24)
                    : StudyUi.border(isDarkMode),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: StudyUi.chipBackground(data.color, isDarkMode),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(data.icon, color: data.color, size: 17),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: titleColor,
                          fontWeight: AppTypography.title,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: bodyColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Transform.scale(
                  scale: 0.74,
                  child: Switch.adaptive(
                    value: checked,
                    onChanged: data.enabled ? data.onChanged : null,
                    activeThumbColor: data.color,
                    activeTrackColor: data.color.withValues(alpha: 0.28),
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

class _MarkdownNotePreview extends StatelessWidget {
  const _MarkdownNotePreview({
    required this.markdown,
    required this.isDarkMode,
    required this.accent,
  });

  final String markdown;
  final bool isDarkMode;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    return Container(
      width: double.infinity,
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
              Icon(Icons.article_rounded, color: accent, size: 18),
              const SizedBox(width: 8),
              Text(
                '学习笔记预览',
                style: TextStyle(
                  color: titleColor,
                  fontWeight: AppTypography.title,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          MarkdownBody(
            data: markdown,
            extensionSet: studyMarkdownExtensionSet,
            styleSheet: buildStudyMarkdownStyleSheet(
              isDarkMode: isDarkMode,
              bodyFontSize: 13,
              bodyHeight: 1.48,
            ),
            builders: buildStudyMarkdownBuilders(
              isDarkMode: isDarkMode,
              bodyFontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReflectionDiagnosisCard extends StatelessWidget {
  const _ReflectionDiagnosisCard({
    required this.plan,
    required this.isDarkMode,
    required this.accent,
  });

  final AiLearningLoopPlan plan;
  final bool isDarkMode;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final analysis = plan.reflectionAnalysis;
    final blockers = analysis.blockers.isNotEmpty
        ? analysis.blockers
        : plan.concepts.take(2).map((item) => '$item 需要继续巩固').toList();
    final actions = analysis.nextActions.isNotEmpty
        ? analysis.nextActions
        : plan.reviewPlan.take(3).map((item) => item.title).toList();
    final masteryItems = analysis.mastery.entries.toList();
    final risk = analysis.forgettingRisk.isNotEmpty
        ? analysis.forgettingRisk
        : (plan.reviewPlan.isNotEmpty ? 'medium' : 'low');
    final emotion = analysis.emotion.label.isNotEmpty
        ? '${analysis.emotion.label} ${(analysis.emotion.intensity * 100).round()}%'
        : '这次复盘里没有明显压力描述';
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: StudyUi.surfaceAlt(isDarkMode),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: StudyUi.border(isDarkMode)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_alt_rounded, color: accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '学习回顾卡',
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: AppTypography.title,
                  ),
                ),
              ),
              _RiskBadge(risk: risk, isDarkMode: isDarkMode),
            ],
          ),
          const SizedBox(height: 10),
          if (analysis.summary.isNotEmpty)
            Text(analysis.summary,
                style: TextStyle(color: bodyColor, height: 1.35)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniDiagnosisMetric(
                label: '今天状态',
                value: emotion,
                icon: Icons.mood_rounded,
                color: StudyUi.warning,
              ),
              _MiniDiagnosisMetric(
                label: '难点',
                value: blockers.isEmpty ? '暂未识别' : blockers.take(2).join('、'),
                icon: Icons.report_problem_rounded,
                color: StudyUi.danger,
              ),
              _MiniDiagnosisMetric(
                label: '熟悉程度',
                value: masteryItems.isEmpty
                    ? '待复盘'
                    : masteryItems
                        .take(2)
                        .map((e) => '${e.key}${(e.value * 100).round()}%')
                        .join('、'),
                icon: Icons.insights_rounded,
                color: StudyUi.success,
              ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('下一步',
                style: TextStyle(
                  color: titleColor,
                  fontWeight: AppTypography.title,
                )),
            const SizedBox(height: 4),
            ...actions.take(3).map((item) => Text(
                  '· $item',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: bodyColor, height: 1.35),
                )),
          ],
          if (analysis.explanation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              analysis.explanation,
              style: TextStyle(color: bodyColor, fontSize: 12, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrustExplanationCard extends StatelessWidget {
  const _TrustExplanationCard({
    required this.plan,
    required this.isDarkMode,
    required this.accent,
  });

  final AiLearningLoopPlan plan;
  final bool isDarkMode;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    final isLocal =
        plan.vivoCapabilitiesUsed.any((item) => item.contains('本地')) ||
            plan.loopSchemaVersion.contains('local');
    final sourceText = plan.sourceEvidence.isEmpty
        ? (isLocal ? '待办、学习记录或学习模板' : '本次复盘输入与学习上下文')
        : plan.sourceEvidence.take(2).map((source) => source.summary).join('；');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDarkMode ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: StudyFontScope(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isLocal ? Icons.offline_bolt_rounded : Icons.verified_rounded,
                  color: accent,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '参考内容',
                    style: TextStyle(
                      color: titleColor,
                      fontWeight: AppTypography.title,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isLocal
                  ? '当前先按已有记录整理，你可以继续编辑。'
                  : '助手只整理容易忘的内容、参考内容和下一步，后续通过任务与闪卡看是否真的推进。',
              style: TextStyle(color: bodyColor, fontSize: 12, height: 1.35),
            ),
            const SizedBox(height: 6),
            Text(
              '参考：$sourceText',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: titleColor,
                fontSize: 12,
                fontWeight: AppTypography.emphasis,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniDiagnosisMetric extends StatelessWidget {
  const _MiniDiagnosisMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 136, maxWidth: 220),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$label：$value',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: AppTypography.emphasis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskBadge extends StatelessWidget {
  const _RiskBadge({required this.risk, required this.isDarkMode});

  final String risk;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final normalized = risk.toLowerCase();
    final color = switch (normalized) {
      'high' => StudyUi.danger,
      'medium' => StudyUi.warning,
      _ => StudyUi.success,
    };
    final label = switch (normalized) {
      'high' => '容易忘',
      'medium' => '需要巩固',
      _ => '保持熟悉',
    };
    return BadgePill(
      label: label,
      background: StudyUi.chipBackground(color, isDarkMode),
      foreground: color,
    );
  }
}

class _ActionCardsPreview extends StatelessWidget {
  const _ActionCardsPreview({
    required this.plan,
    required this.isDarkMode,
    required this.accent,
  });

  final AiLearningLoopPlan plan;
  final bool isDarkMode;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cards = plan.actionCards
        .where((card) => card.title.trim().isNotEmpty)
        .take(3)
        .toList();
    final reviews =
        (plan.reviewPlan.isNotEmpty ? plan.reviewPlan : plan.reviewCards)
            .take(3)
            .toList();
    if (cards.isEmpty && reviews.isEmpty) return const SizedBox.shrink();
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cards.isEmpty ? '今日复习动作' : '今日下一步',
            style: TextStyle(
              color: titleColor,
              fontWeight: AppTypography.title,
            ),
          ),
          const SizedBox(height: 6),
          if (cards.isNotEmpty)
            ...cards.map((card) => _ActionCardPreviewTile(
                  card: card,
                  isDarkMode: isDarkMode,
                  accent: accent,
                ))
          else
            ...reviews.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '· ${item.title}${item.minutes > 0 ? ' · ${item.minutes} 分钟' : ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: bodyColor, height: 1.35),
                  ),
                )),
        ],
      ),
    );
  }
}

class _ActionCardPreviewTile extends StatelessWidget {
  const _ActionCardPreviewTile({
    required this.card,
    required this.isDarkMode,
    required this.accent,
  });

  final AiLearningActionCard card;
  final bool isDarkMode;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    final source = card.source.isNotEmpty ? card.source : card.reason;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: StudyUi.surfaceAlt(isDarkMode),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: StudyUi.border(isDarkMode)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: titleColor,
              fontWeight: AppTypography.title,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (card.priority.isNotEmpty)
                BadgePill(
                  label: '优先级：${_learningActionPriorityLabel(card.priority)}',
                  background: StudyUi.chipBackground(accent, isDarkMode),
                  foreground: accent,
                ),
              if (card.durationMinutes > 0)
                BadgePill(
                  label: '${card.durationMinutes} 分钟',
                  background:
                      StudyUi.chipBackground(StudyUi.success, isDarkMode),
                  foreground: StudyUi.success,
                ),
            ],
          ),
          if (card.steps.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...card.steps.take(3).map((step) => Text(
                  '· $step',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: bodyColor, height: 1.35),
                )),
          ],
          if (card.successCriteria.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '做到这些就算完成：${card.successCriteria}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: titleColor,
                fontSize: 12,
                fontWeight: AppTypography.emphasis,
                height: 1.35,
              ),
            ),
          ],
          if (source.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '参考：$source',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: bodyColor, fontSize: 12, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewList extends StatelessWidget {
  const _PreviewList({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: AppTypography.title)),
          const SizedBox(height: 4),
          ...items.take(4).map((item) => Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text('· $item',
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              )),
        ],
      ),
    );
  }
}

class _CockpitInlineStatus extends StatelessWidget {
  const _CockpitInlineStatus({
    required this.text,
    required this.isDarkMode,
    required this.color,
  });

  final String text;
  final bool isDarkMode;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: StudyUi.surfaceAlt(isDarkMode).withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StudyUi.border(isDarkMode)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: StudyUi.body(isDarkMode),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayMissionCard extends StatelessWidget {
  const _TodayMissionCard({
    required this.isDarkMode,
    required this.isBusy,
    required this.onGenerate,
  });

  final bool isDarkMode;
  final bool isBusy;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.route_rounded, color: StudyUi.success),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('不知道今天怎么学时，先把待办整理成可以马上开始的一小步。'),
          ),
          _CockpitActionButton(
            icon: Icons.auto_awesome_rounded,
            label: isBusy ? '整理中' : '整理',
            color: StudyUi.success,
            isDarkMode: isDarkMode,
            filled: false,
            onPressed: isBusy ? null : onGenerate,
          ),
        ],
      ),
    );
  }
}
