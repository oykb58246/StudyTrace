import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/ai_generated_log.dart';
import '../../services/ai_study_service.dart';
import '../../theme/app_theme.dart';
import '../shared/common_widgets.dart';

class _FocusSession {
  final DateTime time;
  final int minutes;
  _FocusSession({required this.time, required this.minutes});
}

// ---------- Setup page (choose time) ----------

class TimerPage extends StatefulWidget {
  const TimerPage({
    super.key,
    required this.isDarkMode,
    required this.controller,
  });

  final bool isDarkMode;
  final AppDataController controller;

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  final List<int> _presetMinutes = [5, 15, 25, 45, 60];
  int _selectedPreset = 25;
  int _customMinutes = 25;
  int _sessionCount = 0;
  final List<_FocusSession> _sessionHistory = [];

  int get _effectiveMinutes => _customMinutes;

  @override
  Widget build(BuildContext context) {
    final accent = widget.controller.primaryColor;
    final titleColor = widget.isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor =
        widget.isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;

    return Scaffold(
      backgroundColor:
          widget.isDarkMode ? const Color(0xFF141923) : const Color(0xFFF5F7FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: titleColor,
        title: const Text(
          '学习计时器',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        key: const Key('page_timer'),
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 124),
        children: [
        Text('学习计时器',
            style: TextStyle(
                color: titleColor, fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('番茄工作法 · 已完成 $_sessionCount 个番茄钟',
            style: TextStyle(color: bodyColor, fontSize: 14)),
        const SizedBox(height: 24),
        // Time display
        Center(
          child: GestureDetector(
            onTap: _showCustomTimePicker,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: accent.withValues(alpha: 0.3),
                    width: 3),
                color: widget.isDarkMode
                    ? Colors.white.withValues(alpha: 0.04)
                    : const Color(0xFFF2F5FC),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$_effectiveMinutes',
                      style: TextStyle(
                          color: titleColor,
                          fontSize: 56,
                          fontWeight: FontWeight.w800,
                          height: 1.1)),
                  Text('分钟',
                      style: TextStyle(color: bodyColor, fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text('点击数字自定义时长',
              style: TextStyle(color: bodyColor, fontSize: 12)),
        ),
        const SizedBox(height: 24),
        // Preset buttons
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: _presetMinutes.map((minutes) {
            final isSelected = minutes == _selectedPreset;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedPreset = minutes;
                  _customMinutes = minutes;
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: isSelected
                      ? accent
                      : widget.isDarkMode
                          ? const Color(0xFF2A3040)
                          : const Color(0xFFEEF1FA),
                ),
                child: Text(
                  '$minutes 分钟',
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : widget.isDarkMode
                            ? Colors.white70
                            : AppColors.body,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 28),
        // Start button
        SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4BC4A1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              elevation: 0,
            ),
            onPressed: () async {
              final result = await Navigator.of(context).push<Map<String, dynamic>>(
                MaterialPageRoute(
                  builder: (_) => _FocusTimerPage(
                    isDarkMode: widget.isDarkMode,
                    controller: widget.controller,
                    minutes: _effectiveMinutes,
                  ),
                ),
              );
              if (result != null && mounted) {
                final count = result['count'] as int? ?? 0;
                final sessions = result['sessions'] as List<_FocusSession>? ?? [];
                setState(() {
                  _sessionCount += count;
                  _sessionHistory.insertAll(0, sessions);
                  if (_sessionHistory.length > 50) {
                    _sessionHistory.removeRange(50, _sessionHistory.length);
                  }
                });
              }
            },
            icon: const Icon(Icons.play_arrow_rounded, size: 24),
            label: const Text('开始专注',
                style:
                    TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ),
        ),
        const SizedBox(height: 18),
        // View history button
        if (_sessionHistory.isNotEmpty) ...[
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: titleColor,
                side: BorderSide(color: widget.isDarkMode ? Colors.white24 : accent.withValues(alpha: 0.2)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _FocusHistoryPage(
                      isDarkMode: widget.isDarkMode,
                      sessions: _sessionHistory,
                      totalCount: _sessionCount,
                      accentColor: accent,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.history_rounded, size: 18),
              label: const Text('查看全部专注记录',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ),
          ),
        ],
        if (_sessionCount > 0)
          GlassCard(
            color: widget.isDarkMode
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
                  child: const Icon(Icons.timer_rounded,
                      color: Color(0xFF7394F9), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('本日完成',
                          style: TextStyle(color: bodyColor, fontSize: 12)),
                      Text('$_sessionCount 个番茄钟',
                          style: TextStyle(
                              color: titleColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomTimePicker() {
    final accent = widget.controller.primaryColor;
    final controller = TextEditingController(text: '$_customMinutes');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDarkMode
            ? const Color(0xFF242B37)
            : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        title: Text('自定义时长',
            style: TextStyle(
                color:
                    widget.isDarkMode ? Colors.white : AppColors.ink)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: TextStyle(
              color: widget.isDarkMode ? Colors.white : AppColors.ink,
              fontSize: 24,
              fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            suffixText: '分钟',
            suffixStyle: TextStyle(
                color: widget.isDarkMode
                    ? Colors.white54
                    : AppColors.muted,
                fontSize: 16),
            filled: true,
            fillColor: widget.isDarkMode
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFF2F5FC),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value != null && value > 0 && value <= 180) {
                setState(() => _customMinutes = value);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('确定',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ---------- Fullscreen focus timer ----------

class _FocusTimerPage extends StatefulWidget {
  const _FocusTimerPage({
    required this.isDarkMode,
    required this.controller,
    required this.minutes,
  });

  final bool isDarkMode;
  final AppDataController controller;
  final int minutes;

  @override
  State<_FocusTimerPage> createState() => _FocusTimerPageState();
}

class _FocusTimerPageState extends State<_FocusTimerPage> {
  final _aiService = AiStudyService();
  late int _remainingSeconds;
  Timer? _timer;
  bool _isRunning = false;
  bool _isPaused = false;
  final List<_FocusSession> _sessions = [];
  int _completedCount = 0;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.minutes * 60;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    setState(() {
      _isRunning = true;
      _isPaused = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        }
        if (_remainingSeconds <= 0) {
          timer.cancel();
          _isRunning = false;
          _isPaused = false;
          _completedCount++;
          _sessions.add(_FocusSession(
              time: DateTime.now(), minutes: widget.minutes));
          _showCompleteDialog();
        }
      });
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() {
      _isPaused = true;
      _isRunning = false;
    });
  }

  void _resume() {
    _start();
  }

  void _quit() {
    _timer?.cancel();
    Navigator.of(context).pop({
      'count': _completedCount,
      'sessions': _sessions,
    });
  }

  String get _formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  double get _progress {
    if (widget.minutes == 0) return 1;
    return 1 - (_remainingSeconds / (widget.minutes * 60));
  }

  void _showCompleteDialog() {
    final accent = widget.controller.primaryColor;
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDarkMode
            ? const Color(0xFF242B37)
            : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF4BC4A1), size: 28),
            const SizedBox(width: 10),
            Text('专注完成！',
                style: TextStyle(
                    color:
                        widget.isDarkMode ? Colors.white : AppColors.ink,
                    fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '恭喜完成 ${widget.minutes} 分钟番茄钟！',
              style: TextStyle(
                  color: widget.isDarkMode
                      ? const Color(0xFFC2C8D6)
                      : AppColors.body,
                  height: 1.5),
            ),
            const SizedBox(height: 6),
            Text('需要记录这次学习了什么吗？',
                style: TextStyle(
                    color: widget.isDarkMode
                        ? const Color(0xFFC2C8D6)
                        : AppColors.body,
                    fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _quit();
            },
            child: const Text('跳过',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _showAiLogSheet();
            },
            icon: const Icon(Icons.auto_awesome_rounded, size: 16),
            label: const Text('AI 记录学习',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _showAiLogSheet() async {
    final accent = widget.controller.primaryColor;
    final descriptionController = TextEditingController();
    AiGeneratedLog? generatedLog;
    var isGenerating = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final titleColor =
              widget.isDarkMode ? Colors.white : AppColors.ink;
          final bodyColor = widget.isDarkMode
              ? const Color(0xFFC2C8D6)
              : AppColors.body;

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.85,
            decoration: BoxDecoration(
              color: widget.isDarkMode
                  ? const Color(0xFF1A1F2E)
                  : const Color(0xFFF5F7FF),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 34),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: widget.isDarkMode
                          ? Colors.white24
                          : Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text('记录本次学习',
                    style: TextStyle(
                        color: titleColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('描述刚才学了什么，AI 将自动整理为结构化日志',
                    style: TextStyle(color: bodyColor, fontSize: 13)),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  maxLines: 4,
                  style: TextStyle(color: titleColor, fontSize: 14),
                  decoration: InputDecoration(
                    hintText:
                        '例：今天学习了数据库索引和B+树...',
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
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: isGenerating
                        ? null
                        : () async {
                            final input =
                                descriptionController.text.trim();
                            if (input.isEmpty) return;
                            setSheetState(() => isGenerating = true);
                            try {
                              final result = await _aiService
                                  .generateStudyLog(input);
                              setSheetState(
                                  () => generatedLog = result);
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx)
                                    .showSnackBar(SnackBar(
                                        content:
                                            Text('AI 生成失败：$e')));
                              }
                            } finally {
                              setSheetState(
                                  () => isGenerating = false);
                            }
                          },
                    icon: isGenerating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white),
                          )
                        : const Icon(
                            Icons.auto_awesome_rounded,
                            size: 18),
                    label: Text(
                      isGenerating ? '生成中...' : 'AI 生成学习日志',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                if (generatedLog != null &&
                    generatedLog!.courseName.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  GlassCard(
                    color: widget.isDarkMode
                        ? const Color(0xFF242B37)
                            .withValues(alpha: 0.9)
                        : null,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded,
                                color: Color(0xFF7394F9), size: 18),
                            SizedBox(width: 8),
                            Text('AI 生成结果',
                                style: TextStyle(
                                    color: Color(0xFF7394F9),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _TimerLogField(
                            label: '课程',
                            value: generatedLog!.courseName,
                            isDarkMode: widget.isDarkMode),
                        _TimerLogField(
                            label: '学习内容',
                            value: generatedLog!.content,
                            isDarkMode: widget.isDarkMode),
                        _TimerLogField(
                            label: '问题',
                            value: generatedLog!.problems,
                            isDarkMode: widget.isDarkMode),
                        _TimerLogField(
                            label: '思考',
                            value: generatedLog!.thoughts,
                            isDarkMode: widget.isDarkMode),
                        _TimerLogField(
                            label: '计划',
                            value: generatedLog!.nextPlan,
                            isDarkMode: widget.isDarkMode),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFF4BC4A1),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            onPressed: () async {
                              await widget.controller.addStudyLog(
                                date: DateTime.now(),
                                courseName:
                                    generatedLog!.courseName,
                                content: generatedLog!.content,
                                problems:
                                    generatedLog!.problems,
                                thoughts:
                                    generatedLog!.thoughts,
                                nextPlan:
                                    generatedLog!.nextPlan,
                              );
                              if (!ctx.mounted) return;
                              Navigator.of(ctx).pop();
                              _quit();
                            },
                            icon: const Icon(Icons.save_rounded,
                                size: 18),
                            label: const Text('保存学习记录',
                                style: TextStyle(
                                    fontWeight:
                                        FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
    descriptionController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = widget.isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor =
        widget.isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;

    return PopScope(
      canPop: !_isRunning,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isRunning) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请先退出专注再返回')),
          );
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: widget.isDarkMode
            ? const Color(0xFF05070D)
            : const Color(0xFFF5F7FF),
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Timer circle
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: 260,
                    height: 260,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 260,
                          height: 260,
                          child: CircularProgressIndicator(
                            value: _progress,
                            strokeWidth: 10,
                            backgroundColor: widget.isDarkMode
                                ? Colors.white.withValues(alpha: 0.06)
                                : const Color(0xFFE8EBF5),
                            color: _isRunning
                                ? const Color(0xFF4BC4A1)
                                : const Color(0xFFF8AA5B),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formattedTime,
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 62,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isPaused
                                  ? '已暂停'
                                  : _isRunning
                                      ? '专注中...'
                                      : '计时结束',
                              style: TextStyle(
                                  color: bodyColor, fontSize: 15),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Control buttons
              Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!_isRunning && !_isPaused)
                      _TimerBtn(
                        icon: Icons.play_arrow_rounded,
                        label: '重新开始',
                        color: const Color(0xFF4BC4A1),
                        onTap: () {
                          setState(
                              () => _remainingSeconds = widget.minutes * 60);
                          _start();
                        },
                      )
                    else if (_isPaused)
                      _TimerBtn(
                        icon: Icons.play_arrow_rounded,
                        label: '继续',
                        color: const Color(0xFF4BC4A1),
                        onTap: _resume,
                      )
                    else
                      _TimerBtn(
                        icon: Icons.pause_rounded,
                        label: '暂停',
                        color: const Color(0xFFF8AA5B),
                        onTap: _pause,
                      ),
                    const SizedBox(width: 20),
                    _TimerBtn(
                      icon: Icons.exit_to_app_rounded,
                      label: '退出专注',
                      color: const Color(0xFFEF6850),
                      onTap: _isRunning
                          ? () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: widget.isDarkMode
                                      ? const Color(0xFF242B37)
                                      : Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(24)),
                                  title: Text('退出专注',
                                      style: TextStyle(
                                          color: widget.isDarkMode
                                              ? Colors.white
                                              : AppColors.ink)),
                                  content: const Text('确定要退出当前专注吗？'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(),
                                      child: const Text('继续专注'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFFEF6850),
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () {
                                        Navigator.of(ctx).pop();
                                        _quit();
                                      },
                                      child: const Text('退出',
                                          style: TextStyle(
                                              fontWeight:
                                                  FontWeight.w700)),
                                    ),
                                  ],
                                ),
                              );
                            }
                          : _quit,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimerBtn extends StatelessWidget {
  const _TimerBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: color.withValues(alpha: 0.15),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _TimerLogField extends StatelessWidget {
  final String label;
  final String value;
  final bool isDarkMode;
  const _TimerLogField(
      {required this.label, required this.value, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: isDarkMode ? Colors.white70 : AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  color:
                      isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body,
                  fontSize: 13,
                  height: 1.4)),
        ],
      ),
    );
  }
}

// ─── Focus History Full Page ───

class _FocusHistoryPage extends StatelessWidget {
  const _FocusHistoryPage({
    required this.isDarkMode,
    required this.sessions,
    required this.totalCount,
    required this.accentColor,
  });
  final bool isDarkMode;
  final List<_FocusSession> sessions;
  final int totalCount;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor = isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;

    final grouped = <String, List<_FocusSession>>{};
    for (final s in sessions) {
      final key = '${s.time.year}-${s.time.month.toString().padLeft(2, '0')}-${s.time.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(s);
    }
    final totalMinutes = sessions.fold<int>(0, (sum, s) => sum + s.minutes);

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF141923) : const Color(0xFFF5F7FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        title: const Text('专注记录', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: sessions.isEmpty
          ? Center(child: Text('暂无专注记录', style: TextStyle(color: bodyColor)))
          : ListView(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 40),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(colors: [accentColor, const Color(0xFF8D5EFF)]),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('累计专注', style: TextStyle(color: Color(0xD9FFFFFF), fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('$totalCount 次', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                        ]),
                      ),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('总时长', style: TextStyle(color: Color(0xD9FFFFFF), fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('${(totalMinutes / 60).toStringAsFixed(1)}h', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                        ]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                for (final entry in grouped.entries) ...[
                  Text(entry.key, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ...entry.value.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: GlassCard(
                          color: isDarkMode ? const Color(0xFF242B37).withValues(alpha: 0.9) : null,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(color: const Color(0xFF4BC4A1).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.timer_rounded, color: Color(0xFF4BC4A1), size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text('${s.minutes} 分钟专注', style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600))),
                            Text('${s.time.hour.toString().padLeft(2, '0')}:${s.time.minute.toString().padLeft(2, '0')}', style: TextStyle(color: bodyColor, fontSize: 13)),
                          ]),
                        ),
                      )),
                  const SizedBox(height: 14),
                ],
              ],
            ),
    );
  }
}
