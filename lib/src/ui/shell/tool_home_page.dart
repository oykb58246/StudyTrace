import 'dart:async';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../controllers/app_data_controller.dart';
import '../../models/study_sub_task_item.dart';
import '../../models/study_task_item.dart';
import '../../services/ai_study_service.dart';
import '../../theme/app_theme.dart';
import '../shared/common_widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.isDarkMode,
    required this.controller,
    required this.onGenerateReport,
    this.onOpenAiAssistant,
    this.onOpenAiChat,
  });

  final bool isDarkMode;
  final AppDataController controller;
  final VoidCallback onGenerateReport;
  final VoidCallback? onOpenAiAssistant;
  final VoidCallback? onOpenAiChat;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final accent = controller.primaryColor;
        final logs = controller.studyLogs;
        final tasks = controller.studyTasks;

        final now = DateTime.now();
        final weekAgo = now.subtract(const Duration(days: 7));
        final recentLogs =
            logs.where((l) => !l.date.isBefore(weekAgo)).toList();

        final completedTasks =
            tasks.where((t) => t.status == StudyTaskStatus.completed).length;
        final totalTasks = tasks.length;
        final progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;

        final recentCourseNames = recentLogs
            .map((l) => l.courseName)
            .where((n) => n.isNotEmpty)
            .toSet()
            .toList();

        return ListView(
          key: const Key('page_home'),
          padding: const EdgeInsets.fromLTRB(22, 82, 22, 124),
          children: [
            Image.asset(
              isDarkMode ? 'logo/logo白透明.png' : 'logo/logo黑透明.png',
              height: 36,
              fit: BoxFit.fitHeight,
            ),
            const SizedBox(height: 12),
            Text(
              '学习周报助手',
              style: TextStyle(
                color: isDarkMode
                    ? const Color(0xFFC2C8D6)
                    : AppColors.body,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 18),
            // --- Quick Actions: Voice + AI ---
            _QuickActionBar(
              isDarkMode: isDarkMode,
              controller: controller,
              onOpenAiAssistant: onOpenAiAssistant,
            ),
            const SizedBox(height: 18),
            // --- AI Assistant Entry ---
            GestureDetector(
              onTap: onOpenAiAssistant,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent,
                      const Color(0xFF8D5EFF).withValues(alpha: 0.85),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AI 学习助手',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'AI 生成日志 · 智能拆解任务 · 风险提醒',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onOpenAiChat != null)
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: onOpenAiChat,
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Colors.white),
                            tooltip: '直接对话',
                          ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white.withValues(alpha: 0.7),
                          size: 16,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            // --- Streak Badge ---
            Row(
              children: [
                Expanded(
                  child: GlassCard(
                    color: isDarkMode
                        ? const Color(0xFF242B37).withValues(alpha: 0.9)
                        : null,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: const Color(0xFFFF6B35).withValues(alpha: 0.15),
                          ),
                          child: const Icon(
                            Icons.local_fire_department_rounded,
                            color: Color(0xFFFF6B35),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '连续学习',
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white54
                                      : AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '${controller.studyStreak} 天',
                                style: TextStyle(
                                  color:
                                      isDarkMode ? Colors.white : AppColors.ink,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (controller.studyStreak >= 7)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: const Color(0xFFFF6B35).withValues(alpha: 0.2),
                            ),
                            child: const Text(
                              '🔥 7天',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFFF6B35),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // --- Weekly Report Entry ---
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [accent, const Color(0xFF8D5EFF)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BadgePill(
                    label: '本周学习',
                    background: Color(0x33FFFFFF),
                    foreground: Colors.white,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '过去 7 天记录了 ${recentLogs.length} 条学习记录',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (recentCourseNames.isNotEmpty)
                    Text(
                      '课程：${recentCourseNames.join('、')}',
                      style: const TextStyle(
                        color: Color(0xD9FFFFFF),
                        fontSize: 14,
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      key: const Key('generate_report_button'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 0,
                      ),
                      onPressed: onGenerateReport,
                      child: const Text(
                        '生成学习周报',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            // --- Task Progress ---
            Text(
              '任务进度',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            GlassCard(
              color: isDarkMode
                  ? const Color(0xFF242B37).withValues(alpha: 0.9)
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          totalTasks > 0
                              ? '已完成 $completedTasks / $totalTasks 项任务'
                              : '还没有学习任务',
                          style: TextStyle(
                            color:
                                isDarkMode ? Colors.white : AppColors.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        totalTasks > 0
                            ? '${(progress * 100).toInt()}%'
                            : '0%',
                        style: TextStyle(
                          color: accent,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (totalTasks > 0)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: isDarkMode
                            ? Colors.white.withValues(alpha: 0.1)
                            : const Color(0xFFE8EBF5),
                        color: accent,
                        minHeight: 8,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            // --- Recent Logs Summary ---
            Text(
              '最近学习记录',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            if (recentLogs.isEmpty)
              GlassCard(
                key: const Key('home_logs_empty'),
                color: isDarkMode
                    ? const Color(0xFF242B37).withValues(alpha: 0.9)
                    : null,
                child: Text(
                  '近 7 天没有学习记录。去「学习记录」页添加你的第一条记录吧。',
                  style: TextStyle(
                    color: isDarkMode
                        ? const Color(0xFFC2C8D6)
                        : AppColors.body,
                    height: 1.55,
                  ),
                ),
              )
            else
              for (final log in recentLogs.take(5)) ...[
                GlassCard(
                  color: isDarkMode
                      ? const Color(0xFF242B37).withValues(alpha: 0.9)
                      : null,
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: const Color(0x197394F9),
                        ),
                        child: const Icon(
                          Icons.menu_book_rounded,
                          color: Color(0xFF7394F9),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log.courseName.isNotEmpty
                                  ? log.courseName
                                  : '未归课程',
                              style: TextStyle(
                                color: isDarkMode
                                    ? Colors.white
                                    : AppColors.ink,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              log.content.isNotEmpty
                                  ? log.content
                                  : '无内容摘要',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDarkMode
                                    ? const Color(0xFFC2C8D6)
                                    : AppColors.body,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _fmtDate(log.date),
                        style: TextStyle(
                          color: isDarkMode
                              ? Colors.white54
                              : AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (log != recentLogs.take(5).last)
                  const SizedBox(height: 10),
              ],
          ],
        );
      },
    );
  }
}

String _fmtDate(DateTime date) {
  return '${date.month}/${date.day}';
}

class _QuickActionBar extends StatelessWidget {
  const _QuickActionBar({
    required this.isDarkMode,
    required this.controller,
    this.onOpenAiAssistant,
  });

  final bool isDarkMode;
  final AppDataController controller;
  final VoidCallback? onOpenAiAssistant;

  @override
  Widget build(BuildContext context) {
    final accent = controller.primaryColor;
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.keyboard_voice_rounded,
            label: '语音创建任务',
            color: accent,
            isDarkMode: isDarkMode,
            onTap: () => _startVoiceTask(context),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            icon: Icons.camera_alt_rounded,
            label: '拍照记录学习',
            color: const Color(0xFF4BC4A1),
            isDarkMode: isDarkMode,
            onTap: () => _openCameraLog(context),
          ),
        ),
      ],
    );
  }

  void _openCameraLog(BuildContext context) {
    // Opens AI assistant directly — user can use OCR there
    onOpenAiAssistant?.call();
  }

  void _startVoiceTask(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _VoiceTaskInput(
          isDarkMode: isDarkMode,
          controller: controller,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDarkMode,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool isDarkMode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isDarkMode
                ? const Color(0xFF242B37).withValues(alpha: 0.9)
                : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: isDarkMode
                ? null
                : [
                    BoxShadow(
                      color: color.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: isDarkMode ? Colors.white70 : AppColors.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoiceTaskInput extends StatefulWidget {
  const _VoiceTaskInput({
    required this.isDarkMode,
    required this.controller,
  });

  final bool isDarkMode;
  final AppDataController controller;

  @override
  State<_VoiceTaskInput> createState() => _VoiceTaskInputState();
}

class _VoiceTaskInputState extends State<_VoiceTaskInput> {
  final _speech = stt.SpeechToText();
  bool _isListening = false;
  String _recognizedText = '';
  bool _isProcessing = false;
  bool _isInitialized = false;
  bool _isCheckingSpeech = true;
  String _speechError = '';
  final _aiService = AiStudyService();
  final _manualController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onError: (err) {
          if (mounted) {
            setState(() {
              _isInitialized = false;
              _speechError =
                  '语音功能需要 Google Play 服务支持，当前设备暂不支持';
              _isCheckingSpeech = false;
            });
          }
        },
      );
      if (mounted) {
        setState(() {
          _isInitialized = available;
          _isCheckingSpeech = false;
          if (!available) {
            _speechError =
                '语音功能需要 Google Play 服务支持，当前设备暂不支持';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitialized = false;
          _speechError = '语音功能需要 Google Play 服务支持，当前设备暂不支持';
          _isCheckingSpeech = false;
        });
      }
    }
  }

  Future<String?> _bestLocale() async {
    try {
      final locales = await _speech.locales();
      if (locales.isEmpty) return null;
      for (final localeId in ['zh_CN', 'zh_Hans_CN', 'zh_TW', 'zh_HK', 'zh']) {
        if (locales.any((l) => l.localeId == localeId)) return localeId;
      }
      return locales.first.localeId;
    } catch (_) {
      return 'zh_CN';
    }
  }

  Future<void> _startListening() async {
    if (!_isInitialized) return;
    final locale = await _bestLocale();
    if (locale == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到可用的语音语言包')),
        );
      }
      return;
    }
    setState(() {
      _isListening = true;
      _recognizedText = '';
    });
    _speech.listen(
      onResult: (result) {
        if (mounted) {
          setState(() => _recognizedText = result.recognizedWords);
        }
      },
      localeId: locale,
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 3),
    );
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _createTaskFromInput(String text) async {
    if (text.trim().isEmpty) return;
    setState(() => _isProcessing = true);

    try {
      final plan = await _aiService.generateTaskPlan(text);
      final now = DateTime.now();
      final subTasks = plan.plannedSubTasks.isNotEmpty
          ? plan.plannedSubTasks.map((p) => StudySubTaskItem(
                id: 'sub_v_${now.microsecondsSinceEpoch}_${plan.plannedSubTasks.indexOf(p)}',
                title: p.title, startAt: p.startAt,
                deadline: p.deadline, note: p.note,
                createdAt: now, updatedAt: now,
              )).toList()
          : plan.subTasks.map((s) => StudySubTaskItem(
                id: 'sub_v_${now.microsecondsSinceEpoch}_${plan.subTasks.indexOf(s)}',
                title: s, deadline: plan.deadline,
                createdAt: now, updatedAt: now,
              )).toList();
      await widget.controller.addStudyTask(
        title: plan.mainTitle,
        type: plan.taskType,
        courseName: plan.courseName,
        deadline: plan.deadline,
        subTasks: subTasks,
        note: '已通过语音创建',
      );
    } catch (_) {
      await widget.controller.addStudyTask(
        title: text,
        type: StudyTaskType.other,
        courseName: '',
        deadline: DateTime.now().add(const Duration(days: 7)),
        note: '已通过语音创建',
      );
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ 任务已创建')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _manualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.controller.primaryColor;
    final textColor = widget.isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor =
        widget.isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor:
          widget.isDarkMode ? const Color(0xFF141923) : const Color(0xFFF5F7FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        title: const Text('快速创建任务',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 40),
        children: [
          // Manual text input (always available)
          TextField(
            controller: _manualController,
            style: TextStyle(color: textColor, fontSize: 15),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: '输入任务描述，AI 自动拆解...',
              hintStyle: TextStyle(
                color: widget.isDarkMode
                    ? Colors.white.withValues(alpha: 0.35)
                    : Colors.black26,
              ),
              filled: true,
              fillColor: widget.isDarkMode
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFF2F5FC),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_manualController.text.isNotEmpty)
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                onPressed: _isProcessing
                    ? null
                    : () =>
                        _createTaskFromInput(_manualController.text),
                icon: _isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(
                  _isProcessing ? '创建中...' : 'AI 创建任务',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ),
          const SizedBox(height: 24),

          // Voice section (secondary — requires Google Play Services)
          if (_isCheckingSpeech)
            const SizedBox.shrink()
          else if (_speechError.isNotEmpty) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                '语音输入需要 Google Play 服务',
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.white30 : AppColors.muted,
                  fontSize: 12,
                ),
              ),
            ),
          ] else ...[
            // Mic button
            Center(
              child: GestureDetector(
                onTap: _isListening ? _stopListening : () => _startListening(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _isListening ? 120 : 100,
                  height: _isListening ? 120 : 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _isListening
                        ? LinearGradient(colors: [
                            const Color(0xFFFF6B35),
                            accent,
                          ])
                        : LinearGradient(colors: [
                            accent,
                            const Color(0xFF8D5EFF),
                          ]),
                    boxShadow: _isListening
                        ? [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.4),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Icon(
                      _isListening
                          ? Icons.mic_rounded
                          : Icons.mic_none_rounded,
                      color: Colors.white,
                      size: _isListening ? 44 : 36,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                _isListening ? '正在聆听...' : '或点击麦克风说话',
                style: TextStyle(color: bodyColor, fontSize: 13),
              ),
            ),
            if (_recognizedText.isNotEmpty) ...[
              const SizedBox(height: 16),
              GlassCard(
                color: widget.isDarkMode
                    ? const Color(0xFF242B37).withValues(alpha: 0.9)
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('识别结果',
                        style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(_recognizedText,
                        style: TextStyle(
                            color: bodyColor, fontSize: 16, height: 1.5)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: _isProcessing
                      ? null
                      : () =>
                          _createTaskFromInput(_recognizedText),
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.task_alt_rounded, size: 18),
                  label: Text(
                    _isProcessing ? '创建中...' : 'AI 创建任务',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
