import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/ai_action_record.dart';
import '../../models/ai_learning_loop.dart';
import '../../models/note_block.dart';
import '../../models/study_sub_task_item.dart';
import '../../models/study_task_item.dart';
import '../../services/ai_app_context_builder.dart';
import '../../services/local_today_mission_builder.dart';
import '../../services/ocr_service.dart';
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
  late final OcrService _ocrService;
  final AudioRecorder _audioRecorder = AudioRecorder();

  AiLearningLoopPlan? _plan;
  bool _isGeneratingLoop = false;
  bool _isGeneratingMission = false;
  bool _isApplying = false;
  String _statusText = '';
  String _planCheckText = '';
  bool _saveLog = true;
  bool _saveTasks = true;
  bool _saveNote = true;
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
    _ocrService.dispose();
    unawaited(_audioRecorder.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = StudyUi.primary;
    final titleColor = StudyUi.title(widget.isDarkMode);
    final bodyColor = StudyUi.body(widget.isDarkMode);

    return Scaffold(
      backgroundColor: StudyUi.background(widget.isDarkMode),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: titleColor,
        title: const Text('AI学习助手', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: '学习对话',
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
                onVoiceReview: _toggleVoiceReview,
                isRecordingReview: _isRecordingReview,
              ),
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
                  isApplying: _isApplying,
                  isCheckingPlan: _isCheckingPlan,
                  planCheckText: _planCheckText,
                  onSaveLogChanged: (value) => setState(() => _saveLog = value),
                  onSaveTasksChanged: (value) => setState(() => _saveTasks = value),
                  onSaveNoteChanged: (value) => setState(() => _saveNote = value),
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
    );
  }

  Future<void> _captureLoop() async {
    setState(() {
      _isGeneratingLoop = true;
      _statusText = '正在识别图片内容，并整理学习资料...';
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
        setState(() => _statusText = '没有识别到文字，正在结合图片内容整理学习计划...');
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
        _statusText = '拍照整理失败：$error';
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
          ? '正在整理学习计划...'
          : '正在结合图片与文字整理学习计划...';
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
        _statusText = '已生成可编辑学习计划';
        _saveLog = plan.summary.isNotEmpty;
        _saveTasks = plan.taskDrafts.isNotEmpty || plan.reviewPlan.isNotEmpty;
        _saveNote = plan.noteDraft.title.isNotEmpty || plan.noteDraft.content.isNotEmpty;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isGeneratingLoop = false;
        _statusText = '学习计划生成失败：$error';
      });
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
      _statusText = '已先整理本地今日安排，正在尝试云端优化...';
    });
    _setTodayMissionPlan(
      localPlan,
      '已先整理本地今日安排，正在尝试云端优化...',
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
          _statusText = '云端没有返回可执行安排，已保留本地今日安排';
        });
        StudyToast.show(context, '已保留本地今日安排');
        return;
      }
      _setTodayMissionPlan(plan, '今日安排已生成，可保存到学习计划或启动专注');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isGeneratingMission = false;
        _statusText = '云端生成暂时较慢，已保留本地可编辑安排';
      });
      StudyToast.show(context, '云端生成较慢，已先使用本地安排');
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
      _saveTasks =
          saveTasks ?? (plan.taskDrafts.isNotEmpty || plan.reviewPlan.isNotEmpty);
      _saveNote = false;
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
      plan.taskDrafts.isNotEmpty || plan.reviewPlan.isNotEmpty;

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
    final planText = [
      '摘要：${plan.summary}',
      '课程：${plan.courseName}',
      '任务：${plan.taskDrafts.map((task) => task.title).join('；')}',
      '复习路径：${plan.reviewPlan.map((item) => '${item.title}/${item.minutes}分钟').join('；')}',
    ].join('\n');
    try {
      final result = await widget.controller.aiStudyService.generateAssistantReply(
        input: '请对以下学习计划做保存前检查：检查截止时间冲突、任务密度、课程分布和是否适合今天执行。'
            '用 3 条以内中文给出风险和调整建议。\n\n待保存计划：\n$planText\n\n现有待办：\n$pendingTasks',
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
      warnings.add('计划内容较满，建议先保存 1-2 个最关键任务。');
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
      warnings.add('未发现明显冲突，可以先保存任务，再启动第一个专注块。');
    }
    return warnings.map((item) => '· $item').join('\n');
  }

  Future<void> _applyPlan() async {
    final plan = _plan;
    if (plan == null || _isApplying) return;
    if (_planCheckText.trim().isEmpty) {
      await _checkPlanBeforeApply();
      if (!mounted) return;
      StudyToast.show(context, '请确认保存前检查建议，再次点击即可保存');
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
              : '${plan.courseName.isEmpty ? '学习' : plan.courseName}复盘笔记',
          content: plan.noteDraft.content.isNotEmpty
              ? plan.noteDraft.content
              : plan.summary,
          courseName: plan.courseName,
          blocks: _noteBlocks(plan),
        );
        created++;
      }
      if (created > 0) {
        await widget.controller.appendActionRecord(
          AiActionRecord(
            id: 'action_loop_${DateTime.now().microsecondsSinceEpoch}',
            toolId: 'loop.create_from_source',
            targetTitle: plan.courseName.isEmpty ? '学习计划' : plan.courseName,
            status: AiActionStatus.executed,
            resultMessage: '已保存 $created 项学习内容',
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
              )
              .catchError((_) {}),
        );
      }
      if (!mounted) return;
      setState(() {
        _isApplying = false;
        _statusText = created == 0 ? '没有勾选可保存内容' : '已保存 $created 项学习内容';
      });
      StudyToast.show(context, created == 0 ? '没有勾选可保存内容' : '已保存 $created 项学习内容');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isApplying = false;
        _statusText = '保存失败：$error';
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

}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.isDarkMode,
    required this.accent,
    required this.onPhotoLoop,
    required this.onVoiceReview,
    required this.isRecordingReview,
  });

  final bool isDarkMode;
  final Color accent;
  final VoidCallback onPhotoLoop;
  final VoidCallback onVoiceReview;
  final bool isRecordingReview;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    return StudyCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BadgePill(
            label: 'AI学习助手',
            background: StudyUi.chipBackground(accent, isDarkMode),
            foreground: accent,
          ),
          const SizedBox(height: 14),
          Text(
            '拍一下或说一句，整理出可执行学习安排',
            style: TextStyle(
              color: titleColor,
              fontSize: 24,
              height: 1.12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '资料识别和语音复盘集中在一个清楚流程里。',
            style: TextStyle(color: bodyColor, height: 1.4),
          ),
          const SizedBox(height: 16),
          _HeroAction(
            icon: Icons.photo_camera_rounded,
            title: '拍照整理学习',
            subtitle: '课件 / 笔记 / 题目 → 记录、任务、复习路径',
            color: StudyUi.secondary,
            onTap: onPhotoLoop,
          ),
          const SizedBox(height: 10),
          _HeroAction(
            icon: isRecordingReview ? Icons.stop_circle_rounded : Icons.mic_rounded,
            title: isRecordingReview ? '结束语音复盘' : '语音复盘',
            subtitle: '录音转文字，整理成下一步复习动作',
            color: StudyUi.primary,
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
    final titleColor = StudyUi.title(isDarkMode);
    return StudyCard(
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
              fillColor: StudyUi.surfaceAlt(isDarkMode),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: StudyUi.border(isDarkMode)),
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
                  : const Icon(Icons.route_rounded),
              label: Text(isBusy ? '生成中...' : '生成学习计划'),
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
    required this.isApplying,
    required this.isCheckingPlan,
    required this.planCheckText,
    required this.onSaveLogChanged,
    required this.onSaveTasksChanged,
    required this.onSaveNoteChanged,
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
  final bool isApplying;
  final bool isCheckingPlan;
  final String planCheckText;
  final ValueChanged<bool> onSaveLogChanged;
  final ValueChanged<bool> onSaveTasksChanged;
  final ValueChanged<bool> onSaveNoteChanged;
  final VoidCallback onCheckPlan;
  final VoidCallback onApply;
  final VoidCallback onStartFocus;

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
              Expanded(
                child: Text('计划预览', style: TextStyle(color: titleColor, fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              if (plan.courseName.isNotEmpty)
                BadgePill(label: plan.courseName, background: StudyUi.chipBackground(accent, isDarkMode), foreground: accent),
            ],
          ),
          const SizedBox(height: 8),
          Text(plan.summary.isEmpty ? '已整理出可编辑草稿。' : plan.summary,
              style: TextStyle(color: bodyColor, height: 1.38)),
          const Divider(height: 24),
          _PreviewSwitch(label: '保存学习记录', value: saveLog, enabled: plan.summary.isNotEmpty, onChanged: onSaveLogChanged),
          _PreviewSwitch(label: '创建任务拆解', value: saveTasks, enabled: plan.taskDrafts.isNotEmpty || plan.reviewPlan.isNotEmpty, onChanged: onSaveTasksChanged),
          _PreviewSwitch(label: '沉淀学习笔记', value: saveNote, enabled: plan.noteDraft.title.isNotEmpty || plan.noteDraft.content.isNotEmpty, onChanged: onSaveNoteChanged),
          const SizedBox(height: 8),
          _PreviewList(title: '任务', items: plan.taskDrafts.map((t) => t.title).toList()),
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
              label: Text(isCheckingPlan ? '检查中...' : '保存前检查'),
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
                  label: Text(isApplying ? '保存中...' : '保存到学习计划'),
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
    return StudyCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.route_rounded, color: StudyUi.success),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('不知道今天怎么学时，先按本地待办生成专注块，云端可用时自动优化。'),
          ),
          TextButton(
            onPressed: isBusy ? null : onGenerate,
            child: Text(isBusy ? '优化中' : '生成'),
          ),
        ],
      ),
    );
  }
}
