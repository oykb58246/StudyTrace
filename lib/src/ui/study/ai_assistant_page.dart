import 'dart:convert';

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
import '../../services/ai_study_service.dart';
import '../../services/ai_exceptions.dart';
import '../../theme/app_theme.dart';
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
  });

  final bool isDarkMode;
  final AppDataController controller;
  final VoidCallback? onOpenSettings;
  final AiActionHandler? onExecuteActions;

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  late final AiStudyService _aiService;
  final _imagePicker = ImagePicker();
  final _speech = stt.SpeechToText();
  final _logInputController = TextEditingController();
  final _taskInputController = TextEditingController();

  // 生成学习日志
  AiGeneratedLog? _generatedLog;
  bool _isGeneratingLog = false;

  // 拆解学习任务
  AiTaskPlan? _taskPlan;
  bool _isGeneratingTask = false;

  // AI 分析周报
  AiStudyAnalysis? _analysis;
  bool _isGeneratingAnalysis = false;

  // AI 风险提醒
  List<AiRiskWarning>? _warnings;
  bool _isGeneratingWarnings = false;

  // AI 生成今日闪卡
  bool _isGeneratingFlashcards = false;
  String? _flashcardsMessage;
  bool _flashcardsSuccess = false;

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
    final accent = widget.controller.primaryColor;
    final titleColor = widget.isDarkMode ? Colors.white : Colors.black;
    final bodyColor =
        widget.isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;

    return ListView(
      key: const Key('page_ai_assistant'),
      padding: const EdgeInsets.fromLTRB(22, 82, 22, 124),
      children: [
        // Header
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: accent.withValues(alpha: 0.15),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: accent,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI 学习助手',
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '输入自然语言，AI 自动完成学习记录与分析',
                    style: TextStyle(color: bodyColor, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    transitionDuration: const Duration(milliseconds: 340),
                    reverseTransitionDuration: const Duration(milliseconds: 240),
                    pageBuilder: (_, __, ___) => AiChatPage(
                      isDarkMode: widget.isDarkMode,
                      controller: widget.controller,
                      onExecuteActions: widget.onExecuteActions,
                      currentLocation: widget.controller.currentPrimaryTab,
                    ),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      final curved = CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      );
                      return FadeTransition(
                        opacity: curved,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.96, end: 1)
                              .animate(curved),
                          child: child,
                        ),
                      );
                    },
                  ),
                );
              },
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: const Text('AI 对话'),
            ),
            if (widget.onOpenSettings != null) ...[
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'AI 设置',
                onPressed: widget.onOpenSettings,
                icon: const Icon(Icons.tune_rounded, size: 20),
              ),
            ],
          ],
        ),
        const SizedBox(height: 22),
        _buildAiModeBanner(),
        const SizedBox(height: 14),

        // 1. AI 生成学习日志
        _buildSectionCard(
          icon: Icons.edit_note_rounded,
          iconColor: const Color(0xFF7394F9),
          title: 'AI 生成学习日志',
          subtitle: '输入一句话学习情况，自动整理为结构化学习记录',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _logInputController,
                maxLines: 3,
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.white : AppColors.ink,
                  fontSize: 14,
                ),
                decoration: _inputDeco(
                  '例：今天学习了数据库索引和B+树，不太理解为什么不用普通二叉树...',
                ),
              ),
              const SizedBox(height: 10),
              _buildSmartInputBar(
                target: _SmartInputTarget.log,
                controller: _logInputController,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7394F9),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isGeneratingLog ? null : _handleGenerateLog,
                  icon: _isGeneratingLog
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: Text(
                    _isGeneratingLog ? '生成中...' : 'AI 生成学习日志',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 显示 AI 日志生成结果
        if (_generatedLog != null && !_generatedLog!.isEmpty) ...[
          const SizedBox(height: 14),
          _AiResultCard(
            isDarkMode: widget.isDarkMode,
            title: 'AI 生成结果',
            onEdit: (updated) {
              setState(() => _generatedLog = updated);
            },
            generatedLog: _generatedLog!,
            onSave: _handleSaveLog,
          ),
        ],

        const SizedBox(height: 22),

        // 2. AI 拆解学习任务
        _buildSectionCard(
          icon: Icons.account_tree_rounded,
          iconColor: accent,
          title: 'AI 拆解学习任务',
          subtitle: '输入复杂任务描述，自动生成子任务和安排建议',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _taskInputController,
                maxLines: 3,
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.white : AppColors.ink,
                  fontSize: 14,
                ),
                decoration: _inputDeco(
                  '例：下周五前完成操作系统实验报告和答辩PPT',
                ),
              ),
              const SizedBox(height: 10),
              _buildSmartInputBar(
                target: _SmartInputTarget.task,
                controller: _taskInputController,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isGeneratingTask ? null : _handleGenerateTask,
                  icon: _isGeneratingTask
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: Text(
                    _isGeneratingTask ? '拆解中...' : 'AI 拆解任务',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 显示 AI 任务拆解结果
        if (_taskPlan != null && _taskPlan!.mainTitle.isNotEmpty) ...[
          const SizedBox(height: 14),
          _TaskPlanResultCard(
            isDarkMode: widget.isDarkMode,
            plan: _taskPlan!,
            onAddTask: _handleAddTask,
            accentColor: accent,
          ),
        ],

        const SizedBox(height: 22),

        // 3. AI 分析本周学习
        _buildSectionCard(
          icon: Icons.analytics_rounded,
          iconColor: const Color(0xFF4BC4A1),
          title: 'AI 分析本周学习',
          subtitle: '根据日志和任务数据生成带分析结论的学习周报',
          child: SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4BC4A1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed: _isGeneratingAnalysis ? null : _handleGenerateAnalysis,
              icon: _isGeneratingAnalysis
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(
                _isGeneratingAnalysis ? '分析中...' : 'AI 分析本周学习',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),

        // 显示 AI 分析结果
        if (_analysis != null) ...[
          const SizedBox(height: 14),
          _AnalysisResultCard(
            isDarkMode: widget.isDarkMode,
            analysis: _analysis!,
            onSave: _handleSaveAnalysis,
            onCopy: _handleCopyAnalysis,
          ),
        ],

        const SizedBox(height: 22),

        // 4. AI 风险提醒
        _buildSectionCard(
          icon: Icons.warning_amber_rounded,
          iconColor: const Color(0xFFF8AA5B),
          title: 'AI 风险提醒',
          subtitle: '检查任务截止、学习断档和完成率等风险',
          child: SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF8AA5B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed: _isGeneratingWarnings ? null : _handleGenerateWarnings,
              icon: _isGeneratingWarnings
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(
                _isGeneratingWarnings ? '检查中...' : 'AI 检查风险',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
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
          GlassCard(
            color: widget.isDarkMode
                ? const Color(0xFF242B37).withValues(alpha: 0.9)
                : null,
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF4BC4A1), size: 24),
                const SizedBox(width: 12),
                Text(
                  '当前没有发现学习风险，继续保持！',
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

        // 5. AI 生成今日闪卡
        _buildSectionCard(
          icon: Icons.style_rounded,
          iconColor: const Color(0xFF4BC4A1),
          title: 'AI 生成今日闪卡',
          subtitle: '从今日学习日志生成问答闪卡，强化复习',
          child: SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4BC4A1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed: _isGeneratingFlashcards
                  ? null
                  : _handleGenerateFlashcards,
              icon: _isGeneratingFlashcards
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(
                _isGeneratingFlashcards ? '生成中...' : '根据今日日志生成闪卡',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        if (_flashcardsMessage != null) ...[
          const SizedBox(height: 10),
          GlassCard(
            color: widget.isDarkMode
                ? const Color(0xFF242B37).withValues(alpha: 0.9)
                : null,
            child: Row(
              children: [
                Icon(
                  _flashcardsSuccess
                      ? Icons.check_circle_rounded
                      : Icons.info_outline_rounded,
                  color: _flashcardsSuccess
                      ? const Color(0xFF4BC4A1)
                      : const Color(0xFFF8AA5B),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _flashcardsMessage!,
                    style: TextStyle(color: bodyColor, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ============ Build Helpers ============

  Widget _buildSectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final titleColor = widget.isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor =
        widget.isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;

    return GlassCard(
      color: widget.isDarkMode
          ? const Color(0xFF242B37).withValues(alpha: 0.9)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: iconColor.withValues(alpha: 0.15),
                ),
                child: Icon(icon, color: iconColor, size: 20),
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
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(color: bodyColor, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildAiModeBanner() {
    final usingRealAi = widget.controller.isUsingRealAi;
    const aiDetail = '云端 AI 服务已连接';
    final isLoggedIn = widget.controller.isLoggedIn;
    final color =
        isLoggedIn ? const Color(0xFF4BC4A1) : const Color(0xFFF8AA5B);
    final textColor = widget.isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor =
        widget.isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;

    final (String label, String detail) = isLoggedIn
        ? ('学迹 AI', aiDetail)
        : ('AI 服务未就绪', '请登录后使用云端 AI');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: widget.isDarkMode ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        children: [
          Icon(
            usingRealAi ? Icons.cloud_done_rounded : Icons.offline_bolt_rounded,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLoggedIn ? '学迹 AI' : label,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(color: bodyColor, fontSize: 12),
                ),
              ],
            ),
          ),
          if (!usingRealAi && widget.onOpenSettings != null)
            TextButton(
              onPressed: widget.onOpenSettings,
              child: const Text('去配置'),
            ),
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
        child: IconButton.filledTonal(
          style: IconButton.styleFrom(
            backgroundColor: color.withValues(alpha: 0.14),
            foregroundColor: color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: onPressed,
          icon: Icon(icon, size: 19),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String? hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: widget.isDarkMode
            ? Colors.white.withValues(alpha: 0.4)
            : Colors.black.withValues(alpha: 0.35),
        fontSize: 13,
      ),
      filled: true,
      fillColor: widget.isDarkMode
          ? Colors.white.withValues(alpha: 0.06)
          : const Color(0xFFF2F5FC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
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
          // 云端 AI 分析图片内容
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
    } on PlatformException catch (error) {
      _showSnack('图片识别失败：${error.message ?? error.code}');
    } catch (error) {
      _showSnack('图片识别失败：$error');
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
        final textColor = widget.isDarkMode ? Colors.white : AppColors.ink;
        return AlertDialog(
          backgroundColor:
              widget.isDarkMode ? const Color(0xFF242B37) : Colors.white,
          title: Text(title, style: TextStyle(color: textColor)),
          content: TextField(
            controller: controller,
            maxLines: 8,
            style: TextStyle(color: textColor, fontSize: 14),
            decoration: _inputDeco(null),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('填入'),
            ),
          ],
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
        _showSnack('语音识别失败：${error.errorMsg}');
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _handleGenerateLog() async {
    final input = _logInputController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先输入学习情况描述')),
      );
      return;
    }
    setState(() => _isGeneratingLog = true);
    try {
      final result = await _aiService.generateStudyLog(input);
      setState(() => _generatedLog = result);
    } on AiServiceException catch (error) {
      _showSnack(error.message);
    } catch (error) {
      _showSnack('AI 生成失败：$error');
    } finally {
      if (mounted) setState(() => _isGeneratingLog = false);
    }
  }

  Future<void> _handleSaveLog() async {
    if (_generatedLog == null) return;
    final log = _generatedLog!;
    await widget.controller.addStudyLog(
      date: DateTime.now(),
      courseName: log.courseName,
      content: log.content,
      problems: log.problems,
      thoughts: log.thoughts,
      nextPlan: log.nextPlan,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('AI 学习日志已保存'),
        backgroundColor: Color(0xFF4BC4A1),
      ),
    );
    setState(() {
      _generatedLog = null;
      _logInputController.clear();
    });
  }

  Future<void> _handleGenerateTask() async {
    final input = _taskInputController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先输入任务描述')),
      );
      return;
    }
    setState(() => _isGeneratingTask = true);
    try {
      final result = await _aiService.generateTaskPlan(input);
      setState(() => _taskPlan = result);
    } on AiServiceException catch (error) {
      _showSnack(error.message);
    } catch (error) {
      _showSnack('AI 拆解失败：$error');
    } finally {
      if (mounted) setState(() => _isGeneratingTask = false);
    }
  }

  Future<void> _handleAddTask() async {
    final accent = widget.controller.primaryColor;
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
        ? plan.plannedSubTasks.map((p) => StudySubTaskItem(
              id: 'sub_${now.microsecondsSinceEpoch}_${plan.plannedSubTasks.indexOf(p)}',
              title: p.title,
              startAt: p.startAt,
              deadline: p.deadline,
              note: p.note,
              createdAt: now,
              updatedAt: now,
            )).toList()
        : plan.subTasks.map((s) => StudySubTaskItem(
              id: 'sub_${now.microsecondsSinceEpoch}_${plan.subTasks.indexOf(s)}',
              title: s,
              deadline: plan.deadline,
              createdAt: now,
              updatedAt: now,
            )).toList();

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('AI 任务已添加到任务列表'),
        backgroundColor: accent,
      ),
    );
    setState(() {
      _taskPlan = null;
      _taskInputController.clear();
    });
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
      _showSnack(error.message);
    } catch (error) {
      _showSnack('AI 分析失败：$error');
    } finally {
      if (mounted) setState(() => _isGeneratingAnalysis = false);
    }
  }

  Future<void> _handleSaveAnalysis() async {
    if (_analysis == null) return;
    final content = _analysis!.toFormattedText();
    final now = DateTime.now();
    await widget.controller.saveWeeklyReport(
      content,
      startDate: now.subtract(const Duration(days: 7)),
      endDate: now,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('AI 分析周报已保存'),
        backgroundColor: Color(0xFF4BC4A1),
      ),
    );
  }

  void _handleCopyAnalysis() {
    if (_analysis == null) return;
    Clipboard.setData(ClipboardData(text: _analysis!.toFormattedText()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制到剪贴板')),
    );
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
      _showSnack(error.message);
    } catch (error) {
      _showSnack('AI 检查失败：$error');
    } finally {
      if (mounted) setState(() => _isGeneratingWarnings = false);
    }
  }

  Future<void> _handleGenerateFlashcards() async {
    setState(() {
      _isGeneratingFlashcards = true;
      _flashcardsMessage = null;
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
          _flashcardsMessage = '今天还没有学习日志，先记录一些再生成闪卡';
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
          _flashcardsMessage = 'AI 没有生成有效闪卡，请稍后再试';
          _flashcardsSuccess = false;
        });
        return;
      }
      await widget.controller.addFlashCards(cards);
      setState(() {
        _flashcardsMessage = '已根据今日日志生成 ${cards.length} 张闪卡，前往「知识闪卡」查看';
        _flashcardsSuccess = true;
      });
    } on AiServiceException catch (error) {
      setState(() {
        _flashcardsMessage = error.message;
        _flashcardsSuccess = false;
      });
    } catch (error) {
      setState(() {
        _flashcardsMessage = 'AI 生成闪卡失败：$error';
        _flashcardsSuccess = false;
      });
    } finally {
      if (mounted) setState(() => _isGeneratingFlashcards = false);
    }
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
    final titleColor = isDarkMode ? Colors.white : AppColors.ink;

    return GlassCard(
      color: isDarkMode ? const Color(0xFF242B37).withValues(alpha: 0.9) : null,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: Color(0xFF7394F9), size: 18),
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
                  color: const Color(0xFF4BC4A1).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('AI 生成',
                    style: TextStyle(
                        color: Color(0xFF4BC4A1),
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
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7394F9),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed: onSave,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('保存为学习记录',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
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
                color: widget.isDarkMode ? Colors.white70 : AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          controller: _controller,
          maxLines: widget.maxLines,
          style: TextStyle(
            color: widget.isDarkMode ? Colors.white : AppColors.ink,
            fontSize: 13,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: widget.isDarkMode
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFF2F5FC),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
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
    final titleColor = isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor = isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;

    return GlassCard(
      color: isDarkMode ? const Color(0xFF242B37).withValues(alpha: 0.9) : null,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_tree_rounded,
                  color: accentColor, size: 18),
              const SizedBox(width: 8),
              Text('AI 拆解结果',
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
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('📖 ${plan.courseName}',
              style: TextStyle(color: bodyColor, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
              '截止：${_fmtPlanDate(plan.deadline)}',
              style: TextStyle(
                  color: isDarkMode ? Colors.white54 : AppColors.muted,
                  fontSize: 12)),
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
                              style: TextStyle(
                                  color: titleColor, fontSize: 13)),
                          Text(
                              '截止：${_fmtPlanDate(plan.plannedSubTasks[i].deadline)}',
                              style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white54
                                      : AppColors.muted,
                                  fontSize: 11)),
                          if (plan.plannedSubTasks[i].note.isNotEmpty)
                            Text(plan.plannedSubTasks[i].note,
                                style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.white38
                                        : Colors.black38,
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
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed: onAddTask,
              icon: const Icon(Icons.add_task_rounded, size: 18),
              label: const Text('一键加入任务列表',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
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

  const _AnalysisResultCard({
    required this.isDarkMode,
    required this.analysis,
    required this.onSave,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = isDarkMode ? Colors.white : AppColors.ink;

    return GlassCard(
      color: isDarkMode ? const Color(0xFF242B37).withValues(alpha: 0.9) : null,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_rounded,
                  color: Color(0xFF4BC4A1), size: 18),
              const SizedBox(width: 8),
              Text('AI 分析结果',
                  style: TextStyle(
                      color: titleColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4BC4A1).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('AI 分析',
                    style: TextStyle(
                        color: Color(0xFF4BC4A1),
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
              label: '延期风险', text: analysis.riskTasks, isDarkMode: isDarkMode),
          const SizedBox(height: 10),
          _SectionText(
              label: '学习状态评价',
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
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4BC4A1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: onSave,
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text('保存周报',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4BC4A1),
                      side: const BorderSide(color: Color(0xFF4BC4A1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: onCopy,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('复制',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
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
    final bodyColor = isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: isDarkMode ? Colors.white70 : AppColors.muted,
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
          const Color(0xFFF77D8E).withValues(alpha: 0.12),
          const Color(0xFFF77D8E),
          const Color(0xFFF77D8E).withValues(alpha: 0.3),
        ),
      RiskLevel.medium => (
          const Color(0xFFF8AA5B).withValues(alpha: 0.12),
          const Color(0xFFF8AA5B),
          const Color(0xFFF8AA5B).withValues(alpha: 0.3),
        ),
      RiskLevel.low => (
          const Color(0xFF7394F9).withValues(alpha: 0.12),
          const Color(0xFF7394F9),
          const Color(0xFF7394F9).withValues(alpha: 0.3),
        ),
    };

    final bodyColor = isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;

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
                              color: isDarkMode ? Colors.white : AppColors.ink,
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
