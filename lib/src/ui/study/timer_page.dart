import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/ai_generated_log.dart';
import '../../services/ai_study_service.dart';
import '../../theme/app_theme.dart';
import '../shared/common_widgets.dart';

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
  final _aiService = AiStudyService();
  static const int _defaultMinutes = 25;
  int _remainingSeconds = _defaultMinutes * 60;
  bool _isRunning = false;
  bool _isPaused = false;
  Timer? _timer;
  int _sessionCount = 0;

  final List<int> _presetMinutes = [5, 15, 25, 45, 60];
  int _selectedPreset = 25;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _isRunning = true;
    _isPaused = false;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 0) {
        timer.cancel();
        _isRunning = false;
        _sessionCount++;
        _showCompleteDialog();
        return;
      }
      setState(() => _remainingSeconds--);
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _isPaused = true);
  }

  void _resume() {
    setState(() => _isPaused = false);
    _start();
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isPaused = false;
      _remainingSeconds = _selectedPreset * 60;
    });
  }

  void _selectPreset(int minutes) {
    if (_isRunning) return;
    setState(() {
      _selectedPreset = minutes;
      _remainingSeconds = minutes * 60;
    });
  }

  void _showCompleteDialog() {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDarkMode
            ? const Color(0xFF242B37)
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF4BC4A1), size: 28),
            const SizedBox(width: 10),
            Text(
              '专注完成！',
              style: TextStyle(
                color: widget.isDarkMode ? Colors.white : AppColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '恭喜完成第 $_sessionCount 个番茄钟！\n休息一下，然后继续吧。',
              style: TextStyle(
                color: widget.isDarkMode
                    ? const Color(0xFFC2C8D6)
                    : AppColors.body,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '需要记录这次学习了什么吗？',
              style: TextStyle(
                color: widget.isDarkMode
                    ? const Color(0xFFC2C8D6)
                    : AppColors.body,
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _reset();
            },
            child: const Text('跳过',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7040F2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
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
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: widget.isDarkMode
                          ? Colors.white24
                          : Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Icon(Icons.timer_rounded,
                        color: Color(0xFF4BC4A1), size: 24),
                    const SizedBox(width: 10),
                    Text('记录本次学习',
                        style: TextStyle(
                            color: titleColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '描述刚才学了什么，AI 将自动整理为结构化日志',
                  style: TextStyle(color: bodyColor, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  maxLines: 4,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        '例：今天学习了数据库索引和B+树，理解了聚簇索引和非聚簇索引的区别...',
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
                      backgroundColor: const Color(0xFF7040F2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: isGenerating
                        ? null
                        : () async {
                            final input =
                                descriptionController.text.trim();
                            if (input.isEmpty) return;
                            setSheetState(
                                () => isGenerating = true);
                            try {
                              final result =
                                  await _aiService
                                      .generateStudyLog(input);
                              setSheetState(() =>
                                  generatedLog = result);
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
                  // AI result preview
                  GlassCard(
                    color: widget.isDarkMode
                        ? const Color(0xFF242B37)
                            .withValues(alpha: 0.9)
                        : null,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                                Icons.auto_awesome_rounded,
                                color: Color(0xFF7394F9),
                                size: 18),
                            const SizedBox(width: 8),
                            Text('AI 生成结果',
                                style: TextStyle(
                                    color: titleColor,
                                    fontSize: 15,
                                    fontWeight:
                                        FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _TimerLogField(
                            label: '课程',
                            value: generatedLog!.courseName,
                            isDarkMode: widget.isDarkMode),
                        const SizedBox(height: 8),
                        _TimerLogField(
                            label: '学习内容',
                            value: generatedLog!.content,
                            isDarkMode: widget.isDarkMode),
                        const SizedBox(height: 8),
                        _TimerLogField(
                            label: '问题',
                            value: generatedLog!.problems,
                            isDarkMode: widget.isDarkMode),
                        const SizedBox(height: 8),
                        _TimerLogField(
                            label: '思考',
                            value: generatedLog!.thoughts,
                            isDarkMode: widget.isDarkMode),
                        const SizedBox(height: 8),
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
                                    BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () async {
                              await widget.controller
                                  .addStudyLog(
                                date: DateTime.now(),
                                courseName: generatedLog!.courseName,
                                content: generatedLog!.content,
                                problems: generatedLog!.problems,
                                thoughts: generatedLog!.thoughts,
                                nextPlan: generatedLog!.nextPlan,
                              );
                              if (!ctx.mounted) return;
                              Navigator.of(ctx).pop();
                              _reset();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      '学习记录已保存！'),
                                  backgroundColor:
                                      Color(0xFF4BC4A1),
                                ),
                              );
                            },
                            icon: const Icon(
                                Icons.save_rounded,
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

  String get _formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  double get _progress {
    return 1 - (_remainingSeconds / (_selectedPreset * 60));
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = widget.isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor =
        widget.isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;

    return ListView(
      key: const Key('page_timer'),
      padding: const EdgeInsets.fromLTRB(22, 82, 22, 124),
      children: [
        Text(
          '学习计时器',
          style: TextStyle(
            color: titleColor,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '番茄工作法 · 已完成 $_sessionCount 个番茄钟',
          style: TextStyle(color: bodyColor, fontSize: 14),
        ),
        const SizedBox(height: 24),
        // Timer circle
        Center(
          child: SizedBox(
            width: 240,
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 240,
                  height: 240,
                  child: CircularProgressIndicator(
                    value: _progress,
                    strokeWidth: 10,
                    backgroundColor: widget.isDarkMode
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFFE8EBF5),
                    color: const Color(0xFF7040F2),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formattedTime,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 52,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      _isPaused
                          ? '已暂停'
                          : _isRunning
                              ? '专注中...'
                              : '准备开始',
                      style: TextStyle(
                        color: bodyColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        // Control buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_isRunning)
              _ControlButton(
                icon: Icons.play_arrow_rounded,
                label: '开始',
                color: const Color(0xFF4BC4A1),
                isDarkMode: widget.isDarkMode,
                onTap: _start,
              )
            else if (_isPaused)
              _ControlButton(
                icon: Icons.play_arrow_rounded,
                label: '继续',
                color: const Color(0xFF4BC4A1),
                isDarkMode: widget.isDarkMode,
                onTap: _resume,
              )
            else
              _ControlButton(
                icon: Icons.pause_rounded,
                label: '暂停',
                color: const Color(0xFFF8AA5B),
                isDarkMode: widget.isDarkMode,
                onTap: _pause,
              ),
            const SizedBox(width: 16),
            _ControlButton(
              icon: Icons.stop_rounded,
              label: '重置',
              color: const Color(0xFFF77D8E),
              isDarkMode: widget.isDarkMode,
              onTap: _reset,
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Preset time selection
        Text(
          '选择时长',
          style: TextStyle(
            color: titleColor,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _presetMinutes.map((minutes) {
            final isSelected = minutes == _selectedPreset;
            return GestureDetector(
              onTap: () => _selectPreset(minutes),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: isSelected
                      ? const Color(0xFF7040F2)
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
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        // Session count stats
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
                  child: const Icon(
                    Icons.timer_rounded,
                    color: Color(0xFF7394F9),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '本日完成',
                        style: TextStyle(
                          color: bodyColor,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '$_sessionCount 个番茄钟',
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TimerLogField extends StatelessWidget {
  final String label;
  final String value;
  final bool isDarkMode;

  const _TimerLogField({
    required this.label,
    required this.value,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color:
                    isDarkMode ? Colors.white70 : AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
              color:
                  isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body,
              fontSize: 13,
              height: 1.4,
            )),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDarkMode,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool isDarkMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: color.withValues(alpha: 0.15),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : AppColors.body,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
