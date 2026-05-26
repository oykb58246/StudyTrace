import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/ai_action_record.dart';
import '../../models/ai_capability_trace.dart';
import '../../models/ai_flash_card.dart';
import '../../models/ai_learning_loop.dart';
import '../../models/note_block.dart';
import '../../models/study_sub_task_item.dart';
import '../../models/study_task_item.dart';
import '../../services/ai_app_context_builder.dart';
import '../../services/ai_semantic_search_service.dart';
import '../../services/ocr_service.dart';
import '../../theme/app_theme.dart';
import '../shared/common_widgets.dart';
import 'timer_page.dart';

class AiLearningCockpitPage extends StatefulWidget {
  const AiLearningCockpitPage({
    super.key,
    required this.isDarkMode,
    required this.controller,
    this.onOpenAiChat,
  });

  final bool isDarkMode;
  final AppDataController controller;
  final VoidCallback? onOpenAiChat;

  @override
  State<AiLearningCockpitPage> createState() => _AiLearningCockpitPageState();
}

class _AiLearningCockpitPageState extends State<AiLearningCockpitPage> {
  final _sourceController = TextEditingController();
  final _memoryController = TextEditingController();
  late final OcrService _ocrService;
  final AudioRecorder _audioRecorder = AudioRecorder();

  AiLearningLoopPlan? _plan;
  bool _isGeneratingLoop = false;
  bool _isGeneratingMission = false;
  bool _isApplying = false;
  String _statusText = '';
  String _memoryAnswer = '';
  String _planCheckText = '';
  List<_MemoryEvidence> _memoryEvidence = const [];
  List<AiCapabilityTrace> _memoryCapabilityTraces = const [];
  bool _saveLog = true;
  bool _saveTasks = true;
  bool _saveNote = true;
  bool _saveFlashcards = true;
  bool _isCheckingPlan = false;
  bool _isRecordingReview = false;

  @override
  void initState() {
    super.initState();
    _ocrService = widget.controller.createOcrService();
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _memoryController.dispose();
    _ocrService.dispose();
    unawaited(_audioRecorder.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.controller.primaryColor;
    final titleColor = widget.isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor =
        widget.isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;

    return Scaffold(
      backgroundColor:
          widget.isDarkMode ? const Color(0xFF111827) : const Color(0xFFF5F7FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: titleColor,
        title: const Text('AI 学习驾驶舱', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'AI 对话',
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            onPressed: widget.onOpenAiChat,
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
            children: [
              _HeroPanel(
                isDarkMode: widget.isDarkMode,
                accent: accent,
                onPhotoLoop: _captureLoop,
                onMission: _generateTodayMission,
                onMemoryTap: () => _showMemorySheet(context),
                onVoiceReview: _toggleVoiceReview,
                isRecordingReview: _isRecordingReview,
              ),
              const SizedBox(height: 14),
              _CapabilityChain(isDarkMode: widget.isDarkMode),
              const SizedBox(height: 14),
              _ManualSourceCard(
                isDarkMode: widget.isDarkMode,
                controller: _sourceController,
                isBusy: _isGeneratingLoop,
                onGenerate: () => _generateLoop(
                  sourceText: _sourceController.text.trim(),
                  sourceKind: 'manual',
                ),
              ),
              if (_statusText.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(_statusText, style: TextStyle(color: bodyColor, fontSize: 12)),
              ],
              if (_plan != null) ...[
                const SizedBox(height: 14),
                _LoopPreview(
                  plan: _plan!,
                  isDarkMode: widget.isDarkMode,
                  accent: accent,
                  saveLog: _saveLog,
                  saveTasks: _saveTasks,
                  saveNote: _saveNote,
                  saveFlashcards: _saveFlashcards,
                  isApplying: _isApplying,
                  isCheckingPlan: _isCheckingPlan,
                  planCheckText: _planCheckText,
                  onSaveLogChanged: (value) => setState(() => _saveLog = value),
                  onSaveTasksChanged: (value) => setState(() => _saveTasks = value),
                  onSaveNoteChanged: (value) => setState(() => _saveNote = value),
                  onSaveFlashcardsChanged: (value) =>
                      setState(() => _saveFlashcards = value),
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
              if (_memoryAnswer.isNotEmpty) ...[
                const SizedBox(height: 14),
                _MemoryAnswerCard(
                  isDarkMode: widget.isDarkMode,
                  answer: _memoryAnswer,
                  evidence: _memoryEvidence,
                  capabilityTraces: _memoryCapabilityTraces,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _captureLoop() async {
    setState(() {
      _isGeneratingLoop = true;
      _statusText = '正在调用 vivo OCR，并准备多模态理解...';
    });
    try {
      final image = await _ocrService.captureImage();
      if (image == null) {
        setState(() {
          _isGeneratingLoop = false;
          _statusText = '已取消拍摄';
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
      if (text.isEmpty) {
        setState(() => _statusText = 'OCR 未识别到文字，改用图片多模态理解生成闭环...');
      }
      _sourceController.text = text;
      await _generateLoop(
        sourceText: text,
        sourceKind: 'photo',
        imageBase64: imageBase64,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isGeneratingLoop = false;
        _statusText = '拍照闭环生成失败：$error';
      });
    }
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
      _statusText = imageBase64 == null
          ? '蓝心正在生成学习闭环...'
          : '蓝心正在结合图片与 OCR 生成学习闭环...';
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
        _statusText = '已生成可编辑闭环预览';
        _saveLog = plan.summary.isNotEmpty;
        _saveTasks = plan.taskDrafts.isNotEmpty;
        _saveNote = plan.noteDraft.title.isNotEmpty || plan.noteDraft.content.isNotEmpty;
        _saveFlashcards = plan.flashcards.isNotEmpty;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isGeneratingLoop = false;
        _statusText = 'AI 闭环生成失败：$error';
      });
    }
  }

  Future<void> _generateTodayMission() async {
    setState(() {
      _isGeneratingMission = true;
      _statusText = '正在生成今日最优学习路径...';
    });
    try {
      final plan = await widget.controller.aiStudyService.generateLearningLoop(
        sourceText: '请基于当前任务、日志、笔记、闪卡和学习 streak，生成今天最优学习路径。',
        sourceKind: 'manual',
        target: 'task',
        context: AiAppContextBuilder.build(
          widget.controller,
          currentLocation: 'today_mission',
        ),
      );
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _isGeneratingMission = false;
        _statusText = '今日路径已生成，可一键落地或启动专注';
        _saveLog = false;
        _saveTasks = plan.taskDrafts.isNotEmpty || plan.reviewPlan.isNotEmpty;
        _saveNote = false;
        _saveFlashcards = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isGeneratingMission = false;
        _statusText = '今日路径生成失败：$error';
      });
    }
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
    final planText = [
      '摘要：${plan.summary}',
      '课程：${plan.courseName}',
      '任务：${plan.taskDrafts.map((task) => task.title).join('；')}',
      '复习路径：${plan.reviewPlan.map((item) => '${item.title}/${item.minutes}分钟').join('；')}',
    ].join('\n');
    try {
      final result = await widget.controller.aiStudyService.generateAssistantReply(
        input: '请对以下学习闭环做落地前自检：检查截止时间冲突、任务密度、课程分布和是否适合今天执行。'
            '用 3 条以内中文给出风险和调整建议。\n\n待落地计划：\n$planText\n\n现有待办：\n$pendingTasks',
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
    if (plan.taskDrafts.length >= 3 && plan.reviewPlan.length >= 3) {
      warnings.add('计划内容较满，建议先落地 1-2 个最关键任务。');
    }
    final courses = {
      ...widget.controller.studyTasks
          .where((task) => task.effectiveStatus != StudyTaskStatus.completed)
          .map((task) => task.courseName)
          .where((name) => name.trim().isNotEmpty),
      if (plan.courseName.trim().isNotEmpty) plan.courseName,
    };
    if (courses.length >= 4) {
      warnings.add('近期课程分布较散，建议把今日专注块集中到 1 门主课。');
    }
    if (plan.reviewPlan.any((item) => item.minutes > 60)) {
      warnings.add('部分专注块较长，可拆成 25-45 分钟的小块。');
    }
    if (warnings.isEmpty) {
      warnings.add('未发现明显冲突，可以先落地任务和闪卡，再启动第一个专注块。');
    }
    return warnings.map((item) => '· $item').join('\n');
  }

  Future<void> _applyPlan() async {
    final plan = _plan;
    if (plan == null || _isApplying) return;
    if (_planCheckText.trim().isEmpty) {
      await _checkPlanBeforeApply();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请确认落地前自检建议，再次点击即可落地')),
      );
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
      if (_saveNote && (plan.noteDraft.title.isNotEmpty || plan.noteDraft.content.isNotEmpty)) {
        await widget.controller.addStudyNote(
          title: plan.noteDraft.title.isNotEmpty
              ? plan.noteDraft.title
              : '${plan.courseName.isEmpty ? '学习' : plan.courseName}闭环笔记',
          content: plan.noteDraft.content.isNotEmpty
              ? plan.noteDraft.content
              : plan.summary,
          courseName: plan.courseName,
          blocks: _noteBlocks(plan),
        );
        created++;
      }
      if (_saveFlashcards) created += await _createFlashcards(plan);
      if (created > 0) {
        await widget.controller.appendActionRecord(
          AiActionRecord(
            id: 'action_loop_${DateTime.now().microsecondsSinceEpoch}',
            toolId: 'loop.create_from_source',
            targetTitle: plan.courseName.isEmpty ? '学习闭环' : plan.courseName,
            status: AiActionStatus.executed,
            resultMessage: '已落地 $created 项学习内容',
            params: {
              'summary': plan.summary,
              'createdCount': created,
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
          widget.controller.activityService
              .create(
                type: 'aiLoopApplied',
                title: plan.courseName.isEmpty
                    ? 'AI 学习闭环已落地'
                    : '${plan.courseName} AI 学习闭环已落地',
                summary: '已从 AI 闭环落地 $created 项学习内容',
                sourceType: 'ai_action',
                sourceId: 'loop.create_from_source',
                payloadJson: {
                  'createdCount': created,
                  'courseName': plan.courseName,
                  'capabilities': plan.vivoCapabilitiesUsed,
                },
              )
              .catchError((_) {}),
        );
      }
      if (!mounted) return;
      setState(() {
        _isApplying = false;
        _statusText = created == 0 ? '没有勾选可落地内容' : '已落地 $created 项学习内容';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(created == 0 ? '没有勾选可落地内容' : '已落地 $created 项学习内容')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isApplying = false;
        _statusText = '落地失败：$error';
      });
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
          deadline: item.deadline ?? draft.deadline ?? now.add(const Duration(days: 3)),
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
    if (created == 0) {
      for (final item in plan.reviewPlan.take(4)) {
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

  Future<int> _createFlashcards(AiLearningLoopPlan plan) async {
    final now = DateTime.now();
    final cards = plan.flashcards.take(8).map((draft) {
      final index = plan.flashcards.indexOf(draft);
      return AiFlashCard(
        id: 'fc_loop_${now.microsecondsSinceEpoch}_$index',
        question: draft.question,
        answer: draft.answer,
        hint: draft.hint,
        courseName: draft.courseName.isNotEmpty ? draft.courseName : plan.courseName,
        createdAt: now,
      );
    }).toList();
    if (cards.isNotEmpty) await widget.controller.addFlashCards(cards);
    return cards.length;
  }

  List<NoteBlock> _noteBlocks(AiLearningLoopPlan plan) {
    var idCounter = DateTime.now().microsecondsSinceEpoch;
    String id() => 'block_${idCounter++}';
    if (plan.noteDraft.blocks.isEmpty) {
      final source = plan.noteDraft.content.isNotEmpty ? plan.noteDraft.content : plan.summary;
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
        _ => NoteBlockType.text,
      };
      return NoteBlock(id: id(), type: type, content: block.content);
    }).toList();
  }

  void _startFirstFocusBlock() {
    final plan = _plan;
    final minutes = plan?.reviewPlan.isNotEmpty == true
        ? plan!.reviewPlan.first.minutes
        : 25;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TimerPage(
          isDarkMode: widget.isDarkMode,
          controller: widget.controller,
          initialMinutes: minutes,
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
          _statusText = '正在调用云端语音能力转写复盘...';
        });
        if (path == null || path.isEmpty) {
          setState(() => _statusText = '未获取到录音文件，可直接输入文字复盘');
          return;
        }
        final text = await widget.controller.cloudSpeechService.transcribeBytes(
          await XFile(path).readAsBytes(),
          mimeType: 'audio/m4a',
          longForm: true,
        );
        if (!mounted) return;
        if (text.trim().isEmpty) {
          setState(() => _statusText = '语音转写未返回内容，可使用文字模式继续');
          return;
        }
        unawaited(
          widget.controller.activityService
              .create(
                type: 'voiceReview',
                title: '云端语音复盘',
                summary: text.trim(),
                sourceType: 'voice_review',
                sourceId: 'voice_${DateTime.now().microsecondsSinceEpoch}',
              )
              .catchError((_) {}),
        );
        _sourceController.text = text.trim();
        await _generateLoop(sourceText: text.trim(), sourceKind: 'voice');
        return;
      }
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        setState(() => _statusText = '未获得麦克风权限，可使用文字模式复盘');
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
        _statusText = '正在录音复盘，再次点击结束并转写';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isRecordingReview = false;
        _statusText = '云端语音暂不可用：$error。可使用文字模式继续。';
      });
    }
  }

  void _showMemorySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MemorySearchSheet(
        isDarkMode: widget.isDarkMode,
        controller: _memoryController,
        isBusy: false,
        onSearch: _searchMemory,
      ),
    );
  }

  Future<void> _searchMemory() async {
    final query = _memoryController.text.trim();
    if (query.isEmpty) return;
    Navigator.of(context).pop();
    setState(() {
      _statusText = '正在用查询改写和语义排序召回学习记忆...';
      _memoryAnswer = '';
      _memoryEvidence = const [];
      _memoryCapabilityTraces = const [];
    });
    try {
      List<_MemoryEvidence> evidence;
      try {
        final local = _localMemoryContext(query);
        await widget.controller.vivoCapabilityService.indexMemory(
          local
              .map((item) => {
                    'sourceType': item.type,
                    'sourceId': item.id,
                    'title': item.title,
                    'content': item.asContext,
                  })
              .toList(),
        );
        final result =
            await widget.controller.vivoCapabilityService.searchMemory(query);
        evidence = result.hits
            .map(
              (hit) => _MemoryEvidence(
                id: hit['sourceId']?.toString() ?? '',
                type: hit['sourceType']?.toString() ?? '向量记忆',
                title: hit['title']?.toString() ?? '',
                summary:
                    '${hit['content']?.toString() ?? ''}｜相似度 ${(num.tryParse(hit['score']?.toString() ?? '') ?? 0).toStringAsFixed(3)}',
              ),
            )
            .take(5)
            .toList();
        if (evidence.isEmpty) evidence = await _buildMemoryContext(query);
        if (mounted) {
          setState(() => _memoryCapabilityTraces = result.capabilityTraces);
        }
      } catch (_) {
        evidence = await _buildMemoryContext(query);
      }
      final reply = await widget.controller.aiStudyService.generateAssistantReply(
        input: '请根据召回的个人学习资料回答：$query。回答后给出一个下一步学习动作建议。',
        context: evidence.map((item) => item.asContext).toList(),
        purpose: 'chat',
      );
      if (!mounted) return;
      setState(() {
        _memoryAnswer = reply;
        _memoryEvidence = evidence.take(5).toList();
        _statusText = _memoryCapabilityTraces.isNotEmpty
            ? '已基于向量检索和学习证据返回回答'
            : '已基于查询改写、重排和学习证据返回回答';
      });
    } catch (error) {
      if (!mounted) return;
      final evidence = _localMemoryContext(query).take(5).toList();
      setState(() {
        _memoryAnswer = evidence.map((item) => item.asContext).join('\n');
        _memoryEvidence = evidence;
        _memoryCapabilityTraces = const [];
        _statusText = '语义检索失败，已显示本地召回结果';
      });
    }
  }

  Future<List<_MemoryEvidence>> _buildMemoryContext(String query) async {
    final local = _localMemoryContext(query);
    if (local.isEmpty) {
      return const [
        _MemoryEvidence(
          type: '空结果',
          title: '未找到明显相关资料',
          summary: '可以先记录学习日志或沉淀笔记，再回来检索。',
        ),
      ];
    }
    try {
      final service = widget.controller.createSemanticSearchService();
      final hits = await service.search<_MemoryEvidence>(
        query: query,
        candidates: local
            .map((item) => SemanticSearchCandidate<_MemoryEvidence>(
                  item: item,
                  text: item.asContext,
                  id: item.id,
                ))
            .toList(),
      );
      return hits.take(5).map((hit) => hit.item).toList();
    } catch (_) {
      return local.take(5).toList();
    }
  }

  List<_MemoryEvidence> _localMemoryContext(String query) {
    final q = query.toLowerCase();
    final all = <_MemoryEvidence>[
      ...widget.controller.studyTasks.map((task) => _MemoryEvidence(
            id: 'task_${task.id}',
            type: '任务',
            title: task.title,
            courseName: task.courseName,
            summary:
                '${task.note}｜截止 ${task.deadline.toIso8601String()}｜状态 ${task.effectiveStatus.name}',
          )),
      ...widget.controller.studyLogs.map((log) => _MemoryEvidence(
            id: 'log_${log.id}',
            type: '日志',
            title: log.courseName.isEmpty ? '学习日志' : log.courseName,
            courseName: log.courseName,
            summary:
                '${log.content}｜问题 ${log.problems}｜下一步 ${log.nextPlan}',
          )),
      ...widget.controller.studyNotes.where((note) => !note.isFolder).map(
            (note) => _MemoryEvidence(
              id: 'note_${note.id}',
              type: '笔记',
              title: note.title,
              courseName: note.courseName,
              summary: note.content,
            ),
          ),
      ...widget.controller.flashCards.map((card) => _MemoryEvidence(
            id: 'card_${card.id}',
            type: '闪卡',
            title: card.question,
            courseName: card.courseName,
            summary: card.answer,
          )),
      ...widget.controller.recentActionRecords.map((record) => _MemoryEvidence(
            id: 'ai_${record.id}',
            type: 'AI 操作',
            title: record.targetTitle ?? record.toolId,
            summary: record.resultMessage ?? record.errorMessage ?? '',
          )),
    ];
    final matches = all
        .where((item) => item.asContext.toLowerCase().contains(q))
        .toList();
    return matches.isEmpty ? all.take(12).toList() : matches.take(12).toList();
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.isDarkMode,
    required this.accent,
    required this.onPhotoLoop,
    required this.onMission,
    required this.onMemoryTap,
    required this.onVoiceReview,
    required this.isRecordingReview,
  });

  final bool isDarkMode;
  final Color accent;
  final VoidCallback onPhotoLoop;
  final VoidCallback onMission;
  final VoidCallback onMemoryTap;
  final VoidCallback onVoiceReview;
  final bool isRecordingReview;

  @override
  Widget build(BuildContext context) {
    final titleColor = isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor = isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;
    return GlassCard(
      color: isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.white,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BadgePill(
            label: 'vivo AIGC · AI 学习操作层',
            background: accent.withValues(alpha: 0.12),
            foreground: accent,
          ),
          const SizedBox(height: 14),
          Text(
            '拍一下或说一句，AI 直接安排学习',
            style: TextStyle(
              color: titleColor,
              fontSize: 24,
              height: 1.12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '材料感知、意图理解、个人记忆召回和任务执行串成一条闭环。',
            style: TextStyle(color: bodyColor, height: 1.4),
          ),
          const SizedBox(height: 16),
          _HeroAction(
            icon: Icons.photo_camera_rounded,
            title: '一拍成学习闭环',
            subtitle: '课件 / 笔记 / 题目 → 记录、任务、笔记、闪卡',
            color: const Color(0xFF238BFF),
            onTap: onPhotoLoop,
          ),
          const SizedBox(height: 10),
          _HeroAction(
            icon: Icons.route_rounded,
            title: '今日最优学习路径',
            subtitle: '按任务、日志、闪卡和 streak 生成专注块',
            color: const Color(0xFF4BC4A1),
            onTap: onMission,
          ),
          const SizedBox(height: 10),
          _HeroAction(
            icon: Icons.manage_search_rounded,
            title: '问我的学习记忆',
            subtitle: '查询改写 + 语义排序召回个人学习资料',
            color: const Color(0xFFFF9F50),
            onTap: onMemoryTap,
          ),
          const SizedBox(height: 10),
          _HeroAction(
            icon: isRecordingReview ? Icons.stop_circle_rounded : Icons.mic_rounded,
            title: isRecordingReview ? '结束语音复盘' : '云端语音复盘',
            subtitle: '主动录音 → 云端转写 → 生成可落地复盘闭环',
            color: const Color(0xFF7C3AED),
            onTap: onVoiceReview,
          ),
        ],
      ),
    );
  }
}

class _HeroAction extends StatelessWidget {
  const _HeroAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12, height: 1.25)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _CapabilityChain extends StatelessWidget {
  const _CapabilityChain({required this.isDarkMode});

  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final items = const [
      ('vivo OCR', Icons.document_scanner_rounded),
      ('查询改写', Icons.tune_rounded),
      ('语义排序', Icons.sort_rounded),
      ('蓝心决策', Icons.auto_awesome_rounded),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map((item) => Chip(
                avatar: Icon(item.$2, size: 16),
                label: Text(item.$1),
                visualDensity: VisualDensity.compact,
              ))
          .toList(),
    );
  }
}

class _ManualSourceCard extends StatelessWidget {
  const _ManualSourceCard({
    required this.isDarkMode,
    required this.controller,
    required this.isBusy,
    required this.onGenerate,
  });

  final bool isDarkMode;
  final TextEditingController controller;
  final bool isBusy;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final titleColor = isDarkMode ? Colors.white : AppColors.ink;
    return GlassCard(
      color: isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('手动材料输入', style: TextStyle(color: titleColor, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            minLines: 4,
            maxLines: 7,
            decoration: InputDecoration(
              hintText: '粘贴课程通知、课堂笔记、题目或复习目标...',
              filled: true,
              fillColor: isDarkMode
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFF3F6FC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isBusy ? null : onGenerate,
              icon: isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(isBusy ? '生成中...' : '生成学习闭环'),
            ),
          ),
        ],
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
    required this.saveFlashcards,
    required this.isApplying,
    required this.isCheckingPlan,
    required this.planCheckText,
    required this.onSaveLogChanged,
    required this.onSaveTasksChanged,
    required this.onSaveNoteChanged,
    required this.onSaveFlashcardsChanged,
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
  final bool saveFlashcards;
  final bool isApplying;
  final bool isCheckingPlan;
  final String planCheckText;
  final ValueChanged<bool> onSaveLogChanged;
  final ValueChanged<bool> onSaveTasksChanged;
  final ValueChanged<bool> onSaveNoteChanged;
  final ValueChanged<bool> onSaveFlashcardsChanged;
  final VoidCallback onCheckPlan;
  final VoidCallback onApply;
  final VoidCallback onStartFocus;

  @override
  Widget build(BuildContext context) {
    final titleColor = isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor = isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;
    return GlassCard(
      color: isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('闭环预览', style: TextStyle(color: titleColor, fontSize: 18, fontWeight: FontWeight.w900)),
              ),
              if (plan.courseName.isNotEmpty)
                BadgePill(label: plan.courseName, background: accent.withValues(alpha: 0.12), foreground: accent),
            ],
          ),
          const SizedBox(height: 8),
          Text(plan.summary.isEmpty ? 'AI 已生成可编辑草稿。' : plan.summary,
              style: TextStyle(color: bodyColor, height: 1.38)),
          if (plan.concepts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: plan.concepts.take(8).map((c) => Chip(label: Text(c), visualDensity: VisualDensity.compact)).toList(),
            ),
          ],
          if (plan.vivoCapabilitiesUsed.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: plan.vivoCapabilitiesUsed
                  .map(
                    (capability) => Chip(
                      avatar: const Icon(Icons.verified_rounded, size: 15),
                      label: Text(capability),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ],
          if (plan.capabilityTraces.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: plan.capabilityTraces
                    .map(
                      (trace) => Text(
                        '${trace.abilityName} · ${trace.success ? '成功' : '降级'} · ${trace.durationMs} ms'
                        '${trace.fallback == null ? '' : ' · ${trace.fallback}'}',
                        style: TextStyle(color: bodyColor, fontSize: 12, height: 1.35),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          const Divider(height: 24),
          _PreviewSwitch(label: '保存学习记录', value: saveLog, enabled: plan.summary.isNotEmpty, onChanged: onSaveLogChanged),
          _PreviewSwitch(label: '创建任务拆解', value: saveTasks, enabled: plan.taskDrafts.isNotEmpty || plan.reviewPlan.isNotEmpty, onChanged: onSaveTasksChanged),
          _PreviewSwitch(label: '沉淀学习笔记', value: saveNote, enabled: plan.noteDraft.title.isNotEmpty || plan.noteDraft.content.isNotEmpty, onChanged: onSaveNoteChanged),
          _PreviewSwitch(label: '生成知识闪卡', value: saveFlashcards, enabled: plan.flashcards.isNotEmpty, onChanged: onSaveFlashcardsChanged),
          const SizedBox(height: 8),
          _PreviewList(title: '任务', items: plan.taskDrafts.map((t) => t.title).toList()),
          _PreviewList(title: '闪卡', items: plan.flashcards.map((f) => f.question).toList()),
          _PreviewList(title: '复习路径', items: plan.reviewPlan.map((r) => '${r.title} · ${r.minutes} 分钟').toList()),
          if (planCheckText.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                planCheckText,
                style: TextStyle(color: bodyColor, height: 1.35),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isCheckingPlan ? null : onCheckPlan,
              icon: isCheckingPlan
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.fact_check_rounded),
              label: Text(isCheckingPlan ? '自检中...' : '落地前自检'),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onStartFocus,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('启动专注'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isApplying ? null : onApply,
                  icon: isApplying
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.done_all_rounded),
                  label: Text(isApplying ? '落地中...' : '一键落地'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewSwitch extends StatelessWidget {
  const _PreviewSwitch({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      value: enabled && value,
      onChanged: enabled ? onChanged : null,
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
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
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          ...items.take(4).map((item) => Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text('· $item', maxLines: 2, overflow: TextOverflow.ellipsis),
              )),
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
    return GlassCard(
      color: isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.route_rounded, color: Color(0xFF4BC4A1)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('不知道今天怎么学时，让 AI 直接生成 2-4 个可执行专注块。'),
          ),
          TextButton(
            onPressed: isBusy ? null : onGenerate,
            child: Text(isBusy ? '生成中' : '生成'),
          ),
        ],
      ),
    );
  }
}

class _MemoryAnswerCard extends StatelessWidget {
  const _MemoryAnswerCard({
    required this.isDarkMode,
    required this.answer,
    required this.evidence,
    required this.capabilityTraces,
  });

  final bool isDarkMode;
  final String answer;
  final List<_MemoryEvidence> evidence;
  final List<AiCapabilityTrace> capabilityTraces;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      color: isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(answer, style: const TextStyle(height: 1.45)),
          if (capabilityTraces.isNotEmpty) ...[
            const Divider(height: 24),
            const Text('能力调用证据', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            ...capabilityTraces.map(
              (trace) => Text(
                '${trace.abilityName} · ${trace.success ? '成功' : '失败'} · ${trace.endpoint} · ${trace.durationMs} ms',
                style: const TextStyle(fontSize: 12, height: 1.35),
              ),
            ),
          ],
          if (evidence.isNotEmpty) ...[
            const Divider(height: 24),
            const Text(
              '证据来源',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            ...evidence.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Chip(
                      label: Text(item.type),
                      visualDensity: VisualDensity.compact,
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
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          if (item.summary.trim().isNotEmpty)
                            Text(
                              item.summary,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, height: 1.3),
                            ),
                          if (item.id.trim().isNotEmpty)
                            Text(
                              '来源 ID：${item.id}',
                              style: const TextStyle(fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MemoryEvidence {
  const _MemoryEvidence({
    this.id = '',
    required this.type,
    required this.title,
    this.courseName = '',
    this.summary = '',
  });

  final String id;
  final String type;
  final String title;
  final String courseName;
  final String summary;

  String get asContext {
    return '$type：$title'
        '${courseName.trim().isEmpty ? '' : '｜$courseName'}'
        '${summary.trim().isEmpty ? '' : '｜$summary'}';
  }
}

class _MemorySearchSheet extends StatelessWidget {
  const _MemorySearchSheet({
    required this.isDarkMode,
    required this.controller,
    required this.isBusy,
    required this.onSearch,
  });

  final bool isDarkMode;
  final TextEditingController controller;
  final bool isBusy;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF161D2A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('问我的学习记忆', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '例如：上次数据库索引问题',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onSubmitted: (_) => onSearch(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isBusy ? null : onSearch,
                icon: const Icon(Icons.manage_search_rounded),
                label: const Text('语义检索'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
