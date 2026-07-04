import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/ai_action_record.dart';
import '../../models/ai_generated_log.dart';
import '../../theme/app_theme.dart';
import '../shared/app_assets.dart';
import '../shared/common_widgets.dart';

class _FocusSession {
  final String? id;
  final DateTime time;
  final int minutes;
  final String? focusTitle;
  _FocusSession({
    this.id,
    required this.time,
    required this.minutes,
    this.focusTitle,
  });
}

// ---------- Setup page (choose time) ----------

class TimerPage extends StatefulWidget {
  const TimerPage({
    super.key,
    required this.isDarkMode,
    required this.controller,
    this.initialMinutes,
    this.focusTitle,
    this.autoStart = false,
    this.showAppBar = true,
  });

  final bool isDarkMode;
  final AppDataController controller;
  final int? initialMinutes;
  final String? focusTitle;
  final bool autoStart;
  final bool showAppBar;

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

  List<_FocusSession> get _combinedFocusSessions {
    final byKey = <String, _FocusSession>{};
    for (final session in [
      ..._storedFocusSessions(),
      ..._sessionHistory,
    ]) {
      final key = session.id ??
          '${session.time.toIso8601String()}_${session.minutes}_${session.focusTitle ?? ''}';
      byKey[key] = session;
    }
    final sessions = byKey.values.toList(growable: false)
      ..sort((a, b) => b.time.compareTo(a.time));
    return sessions;
  }

  List<_FocusSession> _storedFocusSessions() {
    return widget.controller.recentActionRecords
        .where((record) =>
            record.toolId == 'timer.start_focus' &&
            record.status == AiActionStatus.executed)
        .map(_focusSessionFromRecord)
        .whereType<_FocusSession>()
        .toList(growable: false);
  }

  _FocusSession? _focusSessionFromRecord(AiActionRecord record) {
    final params = record.params ?? const <String, dynamic>{};
    final rawMinutes = params['durationMinutes'];
    final minutes = rawMinutes is num
        ? rawMinutes.toInt()
        : int.tryParse(rawMinutes?.toString() ?? '');
    if (minutes == null || minutes <= 0) return null;
    final rawTitle = record.targetTitle ?? params['focusTitle']?.toString();
    final title = rawTitle?.trim();
    return _FocusSession(
      id: record.targetId ?? record.id,
      time: record.createdAt,
      minutes: minutes,
      focusTitle: title == null || title.isEmpty ? null : title,
    );
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initialMinutes;
    if (initial != null && initial > 0 && initial <= 180) {
      _customMinutes = initial;
      if (_presetMinutes.contains(initial)) {
        _selectedPreset = initial;
      }
    }
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startFocusSession();
      });
    }
  }

  Future<void> _startFocusSession() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => _FocusTimerPage(
          isDarkMode: widget.isDarkMode,
          controller: widget.controller,
          minutes: _effectiveMinutes,
          focusTitle: widget.focusTitle,
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
  }

  @override
  Widget build(BuildContext context) {
    const accent = StudyUi.primary;
    final titleColor = StudyUi.title(widget.isDarkMode);
    final bodyColor = StudyUi.body(widget.isDarkMode);
    final focusTitle = widget.focusTitle?.trim();
    final focusSessions = _combinedFocusSessions;

    return Scaffold(
      backgroundColor: StudyUi.background(widget.isDarkMode),
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StudyGlassIconNode(
                    icon: Icons.timer_rounded,
                    accent: accent,
                    size: 32,
                    iconSize: 16,
                    isDarkMode: widget.isDarkMode,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      '专注计时',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,
      body: ListView(
        key: const Key('page_timer'),
        padding: EdgeInsets.fromLTRB(22, widget.showAppBar ? 0 : 16, 22, 124),
        children: [
          if (widget.showAppBar) const SizedBox(height: 6),
          StudyPathHero(
            isDarkMode: widget.isDarkMode,
            accent: accent,
            badge: '专注计时',
            title: '把一段时间留给一件事',
            subtitle: focusTitle != null && focusTitle.isNotEmpty
                ? '这次先完成：$focusTitle'
                : '选一个时长，开始后只处理眼前这件事，结束后再补一条学习记录。',
            icon: Icons.timer_rounded,
            steps: const ['开始', '专注', '记录'],
          ),
          const SizedBox(height: 24),
          Center(
            child: _FocusSetupDial(
              minutes: _effectiveMinutes,
              focusTitle: focusTitle,
              isDarkMode: widget.isDarkMode,
              accent: accent,
              onTap: _showCustomTimePicker,
            ),
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
                child: StudyStatusChip(
                  label: '$minutes 分钟',
                  color: accent,
                  selected: isSelected,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),
          // Start button
          _TimerActionButton(
            icon: Icons.play_arrow_rounded,
            label: '开始专注',
            accent: accent,
            isDarkMode: widget.isDarkMode,
            filled: true,
            height: 56,
            textSize: 18,
            onPressed: () async {
              await _startFocusSession();
            },
          ),
          const SizedBox(height: 18),
          // View history button
          if (focusSessions.isNotEmpty) ...[
            _TimerActionButton(
              icon: Icons.history_rounded,
              label: '查看全部专注记录',
              accent: StudyUi.pathBlue,
              isDarkMode: widget.isDarkMode,
              height: 44,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _FocusHistoryPage(
                      isDarkMode: widget.isDarkMode,
                      sessions: focusSessions,
                    ),
                  ),
                );
              },
            ),
          ],
          if (_sessionCount > 0)
            StudyCard(
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: StudyUi.chipBackground(
                          StudyUi.secondary, widget.isDarkMode),
                    ),
                    child: const StudyAssetIcon(
                      asset: AppAssets.featureTimerIcon,
                      color: StudyUi.secondary,
                      size: 24,
                      fallbackIcon: Icons.timer_rounded,
                    ),
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
                                fontWeight: AppTypography.title)),
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
    const accent = StudyUi.primary;
    final controller = TextEditingController(text: '$_customMinutes');
    showDialog(
      context: context,
      builder: (ctx) => _TimerDialogSurface(
        isDarkMode: widget.isDarkMode,
        icon: Icons.tune_rounded,
        accent: accent,
        title: '自定义时长',
        subtitle: '1 到 180 分钟，留给这次专注。',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: TextStyle(
                color: StudyUi.title(widget.isDarkMode),
                fontSize: 28,
                fontWeight: AppTypography.hero,
              ),
              textAlign: TextAlign.center,
              decoration: _timerInputDecoration(
                isDarkMode: widget.isDarkMode,
                hintText: '25',
                suffixText: '分钟',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _TimerActionPill(
                    icon: Icons.close_rounded,
                    label: '取消',
                    accent: StudyUi.muted(widget.isDarkMode),
                    isDarkMode: widget.isDarkMode,
                    onTap: () => Navigator.of(ctx).pop(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TimerActionPill(
                    icon: Icons.check_rounded,
                    label: '确定',
                    accent: accent,
                    isDarkMode: widget.isDarkMode,
                    filled: true,
                    onTap: () {
                      final value = int.tryParse(controller.text.trim());
                      if (value != null && value > 0 && value <= 180) {
                        setState(() => _customMinutes = value);
                        Navigator.of(ctx).pop();
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimerActionButton extends StatelessWidget {
  const _TimerActionButton({
    required this.icon,
    required this.label,
    required this.accent,
    required this.isDarkMode,
    required this.onPressed,
    this.filled = false,
    this.height = 48,
    this.textSize = 14,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final bool isDarkMode;
  final VoidCallback? onPressed;
  final bool filled;
  final double height;
  final double textSize;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foreground = filled ? Colors.white : accent;
    final disabledForeground =
        StudyUi.muted(isDarkMode).withValues(alpha: 0.62);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Container(
          height: height,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: enabled
                ? (filled ? accent : StudyUi.chipBackground(accent, isDarkMode))
                : StudyUi.surfaceAlt(isDarkMode).withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: enabled
                  ? accent.withValues(alpha: filled ? 0.18 : 0.28)
                  : StudyUi.border(isDarkMode),
            ),
            boxShadow: [
              if (enabled && filled && !isDarkMode)
                BoxShadow(
                  color: accent.withValues(alpha: 0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 12),
                ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: enabled ? foreground : disabledForeground, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: enabled ? foreground : disabledForeground,
                    fontSize: textSize,
                    fontWeight:
                        filled ? AppTypography.hero : AppTypography.title,
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

class _TimerDialogSurface extends StatelessWidget {
  const _TimerDialogSurface({
    required this.isDarkMode,
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final bool isDarkMode;
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: StudyFontScope(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 390),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDarkMode
                      ? const [
                          Color(0xEE17222C),
                          Color(0xEE1D2A35),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.94),
                          const Color(0xFFF4FAFF).withValues(alpha: 0.88),
                        ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color:
                      Colors.white.withValues(alpha: isDarkMode ? 0.12 : 0.82),
                ),
                boxShadow: [
                  if (!isDarkMode)
                    BoxShadow(
                      color: accent.withValues(alpha: 0.16),
                      blurRadius: 32,
                      offset: const Offset(0, 18),
                    ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      StudyGlassIconNode(
                        icon: icon,
                        accent: accent,
                        isDarkMode: isDarkMode,
                        size: 46,
                        iconSize: 21,
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
                                fontSize: 21,
                                fontWeight: AppTypography.hero,
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
                  const SizedBox(height: 18),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimerSheetSurface extends StatelessWidget {
  const _TimerSheetSurface({
    required this.isDarkMode,
    required this.child,
    this.heightFactor = 0.86,
  });

  final bool isDarkMode;
  final Widget child;
  final double heightFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: heightFactor,
      alignment: Alignment.bottomCenter,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDarkMode
                    ? const [
                        Color(0xF0111A22),
                        Color(0xF0182530),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.94),
                        const Color(0xFFF1FAFE).withValues(alpha: 0.92),
                      ],
              ),
              border: Border(
                top: BorderSide(
                  color:
                      Colors.white.withValues(alpha: isDarkMode ? 0.12 : 0.86),
                ),
              ),
              boxShadow: [
                if (!isDarkMode)
                  BoxShadow(
                    color: StudyUi.primary.withValues(alpha: 0.12),
                    blurRadius: 30,
                    offset: const Offset(0, -10),
                  ),
              ],
            ),
            child: StudyFontScope(child: child),
          ),
        ),
      ),
    );
  }
}

class _TimerActionPill extends StatelessWidget {
  const _TimerActionPill({
    required this.icon,
    required this.label,
    required this.accent,
    required this.isDarkMode,
    required this.onTap,
    this.filled = false,
    this.height = 44,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final bool isDarkMode;
  final VoidCallback? onTap;
  final bool filled;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final foreground = filled ? Colors.white : accent;
    final disabledForeground =
        StudyUi.muted(isDarkMode).withValues(alpha: 0.62);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: enabled
                ? (filled ? accent : StudyUi.chipBackground(accent, isDarkMode))
                : StudyUi.surfaceAlt(isDarkMode).withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: enabled
                  ? accent.withValues(alpha: filled ? 0.18 : 0.28)
                  : StudyUi.border(isDarkMode),
            ),
            boxShadow: [
              if (enabled && filled && !isDarkMode)
                BoxShadow(
                  color: accent.withValues(alpha: 0.20),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  color: enabled ? foreground : disabledForeground, size: 18),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: enabled ? foreground : disabledForeground,
                    fontWeight: AppTypography.title,
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

InputDecoration _timerInputDecoration({
  required bool isDarkMode,
  required String hintText,
  String? suffixText,
  EdgeInsetsGeometry contentPadding =
      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(
      color: StudyUi.muted(isDarkMode),
      fontSize: 13,
    ),
    suffixText: suffixText,
    suffixStyle: TextStyle(
      color: StudyUi.muted(isDarkMode),
      fontSize: 16,
    ),
    filled: true,
    fillColor: StudyUi.surfaceAlt(isDarkMode).withValues(alpha: 0.86),
    contentPadding: contentPadding,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: StudyUi.border(isDarkMode)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: StudyUi.primary, width: 1.3),
    ),
  );
}

class _FocusSetupDial extends StatelessWidget {
  const _FocusSetupDial({
    required this.minutes,
    required this.focusTitle,
    required this.isDarkMode,
    required this.accent,
    required this.onTap,
  });

  final int minutes;
  final String? focusTitle;
  final bool isDarkMode;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    final hasFocus = focusTitle != null && focusTitle!.isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 222,
          height: 222,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: isDarkMode
                  ? [
                      accent.withValues(alpha: 0.22),
                      const Color(0xFF17222C),
                    ]
                  : const [
                      Colors.white,
                      Color(0xFFF1FBF7),
                      Color(0xFFF4F5FF),
                    ],
            ),
            border: Border.all(
              color: accent.withValues(alpha: isDarkMode ? 0.22 : 0.18),
              width: 1.4,
            ),
            boxShadow: [
              if (!isDarkMode)
                BoxShadow(
                  color: accent.withValues(alpha: 0.16),
                  blurRadius: 34,
                  offset: const Offset(0, 18),
                ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 18,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: StudyUi.chipBackground(accent, isDarkMode),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    hasFocus ? '这次先做' : '准备开始',
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: AppTypography.emphasis,
                    ),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$minutes',
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 58,
                      fontWeight: AppTypography.hero,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '分钟',
                    style: TextStyle(color: bodyColor, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 150,
                    child: Text(
                      hasFocus ? focusTitle! : '点一下可自定义时长',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color:
                            hasFocus ? titleColor : StudyUi.muted(isDarkMode),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                bottom: 18,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: StudyUi.chipBackground(accent, isDarkMode),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: StudyUi.border(isDarkMode),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        color: accent,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '调整时长',
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: AppTypography.emphasis,
                        ),
                      ),
                    ],
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

// ---------- Fullscreen focus timer ----------

class _FocusTimerPage extends StatefulWidget {
  const _FocusTimerPage({
    required this.isDarkMode,
    required this.controller,
    required this.minutes,
    this.focusTitle,
  });

  final bool isDarkMode;
  final AppDataController controller;
  final int minutes;
  final String? focusTitle;

  @override
  State<_FocusTimerPage> createState() => _FocusTimerPageState();
}

class _FocusTimerPageState extends State<_FocusTimerPage> {
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
          final completedAt = DateTime.now();
          final sourceId =
              'timer_${completedAt.microsecondsSinceEpoch}_$_completedCount';
          _sessions.add(_FocusSession(
            id: sourceId,
            time: completedAt,
            minutes: widget.minutes,
            focusTitle: widget.focusTitle?.trim(),
          ));
          unawaited(widget.controller.recordTimerCompleted(
            durationMinutes: widget.minutes,
            sourceId: sourceId,
            focusTitle: widget.focusTitle ?? '',
          ));
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

  Future<void> _showQuitConfirmDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _TimerDialogSurface(
        isDarkMode: widget.isDarkMode,
        icon: Icons.exit_to_app_rounded,
        accent: StudyUi.danger,
        title: '退出专注',
        subtitle: '确定要退出当前专注吗？这段计时不会记为完成。',
        child: Row(
          children: [
            Expanded(
              child: _TimerActionPill(
                icon: Icons.timer_rounded,
                label: '继续专注',
                accent: StudyUi.primary,
                isDarkMode: widget.isDarkMode,
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TimerActionPill(
                icon: Icons.exit_to_app_rounded,
                label: '退出',
                accent: StudyUi.danger,
                isDarkMode: widget.isDarkMode,
                filled: true,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _quit();
                },
              ),
            ),
          ],
        ),
      ),
    );
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
    final focusTitle = widget.focusTitle?.trim();
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: _FocusCompleteDialogContent(
          isDarkMode: widget.isDarkMode,
          minutes: widget.minutes,
          focusTitle: focusTitle,
          onLater: () {
            Navigator.of(ctx).pop();
            _quit();
          },
          onRecord: () {
            Navigator.of(ctx).pop();
            _showAiLogSheet();
          },
        ),
      ),
    );
  }

  Future<void> _showAiLogSheet() async {
    const accent = StudyUi.primary;
    final focusTitle = widget.focusTitle?.trim();
    final descriptionController = TextEditingController(
      text: focusTitle != null && focusTitle.isNotEmpty
          ? '刚才专注做了：$focusTitle'
          : '',
    );
    AiGeneratedLog? generatedLog;
    var isGenerating = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final titleColor = StudyUi.title(widget.isDarkMode);

          return _TimerSheetSurface(
            isDarkMode: widget.isDarkMode,
            heightFactor: 0.86,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 34),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color:
                          widget.isDarkMode ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _TimerLogSheetIntro(
                  isDarkMode: widget.isDarkMode,
                  focusTitle: focusTitle,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  maxLines: 4,
                  style: TextStyle(color: titleColor, fontSize: 14),
                  decoration: _timerInputDecoration(
                    isDarkMode: widget.isDarkMode,
                    hintText: '例：刚才完成了高数错题第 3 题，卡在洛必达适用条件，下一步整理判断清单...',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                  ),
                ),
                const SizedBox(height: 14),
                _TimerActionButton(
                  icon: Icons.edit_note_rounded,
                  label: isGenerating ? '整理中...' : '整理这次专注',
                  accent: accent,
                  isDarkMode: widget.isDarkMode,
                  filled: true,
                  height: 44,
                  onPressed: isGenerating
                      ? null
                      : () async {
                          final input = descriptionController.text.trim();
                          if (input.isEmpty) return;
                          setSheetState(() => isGenerating = true);
                          try {
                            final result = await widget
                                .controller.aiStudyService
                                .generateStudyLog(input);
                            if (!ctx.mounted) return;
                            setSheetState(() => generatedLog = result);
                          } catch (e) {
                            if (ctx.mounted) {
                              await StudyToast.dialog(
                                ctx,
                                title: '整理失败',
                                message: '这次没有整理成功，你可以先手动保存这次专注内容。',
                              );
                            }
                          } finally {
                            if (ctx.mounted) {
                              setSheetState(() => isGenerating = false);
                            }
                          }
                        },
                ),
                if (generatedLog != null &&
                    generatedLog!.courseName.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  StudyCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TimerLogPreviewHeader(
                          isDarkMode: widget.isDarkMode,
                          courseName: generatedLog!.courseName,
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _TimerLogField(
                                  label: '学了什么',
                                  value: generatedLog!.content,
                                  isDarkMode: widget.isDarkMode),
                              _TimerLogField(
                                  label: '难点',
                                  value: generatedLog!.problems,
                                  isDarkMode: widget.isDarkMode),
                              _TimerLogField(
                                  label: '想到的',
                                  value: generatedLog!.thoughts,
                                  isDarkMode: widget.isDarkMode),
                              _TimerLogField(
                                  label: '下一步',
                                  value: generatedLog!.nextPlan,
                                  isDarkMode: widget.isDarkMode),
                              const SizedBox(height: 16),
                              _TimerActionButton(
                                icon: Icons.save_rounded,
                                label: '保存这次学习',
                                accent: StudyUi.pathMint,
                                isDarkMode: widget.isDarkMode,
                                filled: true,
                                height: 44,
                                onPressed: () async {
                                  try {
                                    await widget.controller.addStudyLog(
                                      date: DateTime.now(),
                                      courseName: generatedLog!.courseName,
                                      content: generatedLog!.content,
                                      problems: generatedLog!.problems,
                                      thoughts: generatedLog!.thoughts,
                                      nextPlan: generatedLog!.nextPlan,
                                    );
                                    if (!ctx.mounted) return;
                                    Navigator.of(ctx).pop();
                                    _quit();
                                  } catch (error) {
                                    if (!ctx.mounted) return;
                                    await StudyToast.dialog(
                                      ctx,
                                      title: '保存学习记录失败',
                                      message: '学习记录暂时没有保存成功，请稍后再试。',
                                    );
                                  }
                                },
                              ),
                            ],
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
    final titleColor = StudyUi.title(widget.isDarkMode);
    final focusTitle = widget.focusTitle?.trim();

    return PopScope(
      canPop: !_isRunning,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isRunning) {
          StudyToast.show(context, '请先退出专注再返回');
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: StudyUi.background(widget.isDarkMode),
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              if (focusTitle != null && focusTitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                  child: StudyCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.flag_rounded,
                          color: StudyUi.secondary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '本次专注：$focusTitle',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: titleColor,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Timer circle
              Expanded(
                child: Center(
                  child: _FocusTimerDial(
                    progress: _progress,
                    timeText: _formattedTime,
                    statusText: _isPaused
                        ? '已暂停'
                        : _isRunning
                            ? '专注中'
                            : '计时结束',
                    isDarkMode: widget.isDarkMode,
                    accent: _isRunning ? StudyUi.primary : StudyUi.warning,
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
                      onTap: _isRunning ? _showQuitConfirmDialog : _quit,
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

class _FocusCompleteDialogContent extends StatelessWidget {
  const _FocusCompleteDialogContent({
    required this.isDarkMode,
    required this.minutes,
    required this.focusTitle,
    required this.onLater,
    required this.onRecord,
  });

  final bool isDarkMode;
  final int minutes;
  final String? focusTitle;
  final VoidCallback onLater;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    const accent = StudyUi.primary;
    final hasFocus = focusTitle != null && focusTitle!.isNotEmpty;
    final dialogWidth =
        math.max(260.0, math.min(360.0, MediaQuery.sizeOf(context).width - 44));
    return StudyFontScope(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          child: Container(
            width: dialogWidth,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: StudyUi.surface(isDarkMode),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                if (!isDarkMode)
                  BoxShadow(
                    color: const Color(0xFF24424A).withValues(alpha: 0.12),
                    blurRadius: 28,
                    offset: const Offset(0, 16),
                  ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color:
                            StudyUi.chipBackground(StudyUi.success, isDarkMode),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: StudyUi.success,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '这段专注完成了',
                            style: TextStyle(
                              color: titleColor,
                              fontSize: 20,
                              fontWeight: AppTypography.hero,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$minutes 分钟已经留下记录',
                            style: TextStyle(color: bodyColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: StudyUi.surfaceAlt(isDarkMode),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: StudyUi.border(isDarkMode)),
                  ),
                  child: Text(
                    hasFocus
                        ? '刚才完成了「$focusTitle」。趁记忆还新，可以把学了什么和下一步写下来。'
                        : '趁记忆还新，可以把刚才学了什么和下一步写下来。',
                    style: TextStyle(color: bodyColor, height: 1.42),
                  ),
                ),
                const SizedBox(height: 14),
                const _FocusCompletePath(),
                const SizedBox(height: 16),
                _TimerActionPill(
                  icon: Icons.edit_note_rounded,
                  label: '写下这次学习',
                  accent: accent,
                  isDarkMode: isDarkMode,
                  filled: true,
                  height: 46,
                  onTap: onRecord,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 132,
                    child: _TimerActionPill(
                      icon: Icons.schedule_rounded,
                      label: '稍后再记',
                      accent: StudyUi.muted(isDarkMode),
                      isDarkMode: isDarkMode,
                      height: 38,
                      onTap: onLater,
                    ),
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

class _FocusCompletePath extends StatelessWidget {
  const _FocusCompletePath();

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final steps = [
      _FocusCompleteStep('完成', Icons.check_circle_rounded, StudyUi.success),
      _FocusCompleteStep('记录', Icons.edit_note_rounded, StudyUi.primary),
      _FocusCompleteStep('回顾', Icons.timeline_rounded, StudyUi.secondary),
    ];
    return SizedBox(
      height: 62,
      child: Stack(
        children: [
          Positioned(
            left: 32,
            right: 32,
            top: 18,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  colors: [
                    StudyUi.success.withValues(alpha: 0.44),
                    StudyUi.primary.withValues(alpha: 0.34),
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
                            color: step.color.withValues(alpha: 0.26),
                          ),
                        ),
                        child: Icon(step.icon, color: step.color, size: 17),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        step.label,
                        style: TextStyle(
                          color: StudyUi.title(isDarkMode),
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

class _FocusCompleteStep {
  const _FocusCompleteStep(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

class _TimerLogSheetIntro extends StatelessWidget {
  const _TimerLogSheetIntro({
    required this.isDarkMode,
    required this.focusTitle,
  });

  final bool isDarkMode;
  final String? focusTitle;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    final hasFocus = focusTitle != null && focusTitle!.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? const [
                  Color(0xFF1B2F31),
                  Color(0xFF1A2634),
                ]
              : const [
                  Color(0xFFE9FAF4),
                  Color(0xFFF5F6FF),
                ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: StudyUi.border(isDarkMode)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: StudyUi.chipBackground(StudyUi.primary, isDarkMode),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.history_edu_rounded,
              color: StudyUi.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '把刚才这段留下来',
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 19,
                    fontWeight: AppTypography.hero,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasFocus ? '可以先写「$focusTitle」里最重要的收获。' : '简单写几句就行，后面回顾会用得上。',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(color: bodyColor, fontSize: 12, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerLogPreviewHeader extends StatelessWidget {
  const _TimerLogPreviewHeader({
    required this.isDarkMode,
    required this.courseName,
  });

  final bool isDarkMode;
  final String courseName;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: StudyUi.chipBackground(StudyUi.secondary, isDarkMode),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(StudyUi.radius),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: StudyUi.surface(isDarkMode).withValues(
                alpha: isDarkMode ? 0.62 : 0.82,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.fact_check_rounded,
              color: StudyUi.secondary,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '整理好了，先看一眼',
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: AppTypography.title,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  courseName.isEmpty ? '保存后会进入学习记录' : '$courseName · 学习记录',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: bodyColor, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : color;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isDarkMode
              ? color.withValues(alpha: 0.18)
              : color.withValues(alpha: 0.12),
          border: Border.all(
            color: color.withValues(alpha: isDarkMode ? 0.22 : 0.28),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _FocusTimerDial extends StatelessWidget {
  const _FocusTimerDial({
    required this.progress,
    required this.timeText,
    required this.statusText,
    required this.isDarkMode,
    required this.accent,
  });

  final double progress;
  final String timeText;
  final String statusText;
  final bool isDarkMode;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    final clampedProgress = progress.clamp(0.0, 1.0).toDouble();
    return Container(
      width: 282,
      height: 282,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: isDarkMode
              ? [
                  accent.withValues(alpha: 0.22),
                  const Color(0xFF17222C).withValues(alpha: 0.92),
                ]
              : [
                  Colors.white,
                  const Color(0xFFF3FBFA),
                  const Color(0xFFF7F8FF),
                ],
        ),
        boxShadow: [
          if (!isDarkMode)
            BoxShadow(
              color: accent.withValues(alpha: 0.18),
              blurRadius: 36,
              offset: const Offset(0, 18),
            ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _FocusTimerDialPainter(
                progress: clampedProgress,
                accent: accent,
                isDarkMode: isDarkMode,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDarkMode ? 0.18 : 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: AppTypography.title,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                timeText,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 60,
                  fontWeight: AppTypography.hero,
                  height: 1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '把注意力留给眼前这一步',
                style: TextStyle(color: bodyColor, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FocusTimerDialPainter extends CustomPainter {
  const _FocusTimerDialPainter({
    required this.progress,
    required this.accent,
    required this.isDarkMode,
  });

  final double progress;
  final Color accent;
  final bool isDarkMode;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 18;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..color = isDarkMode
          ? Colors.white.withValues(alpha: 0.08)
          : const Color(0xFFE4EEF0);
    canvas.drawCircle(center, radius, basePaint);

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -1.5708,
        endAngle: 4.7124,
        colors: [
          accent.withValues(alpha: 0.28),
          accent,
          StudyUi.secondary,
        ],
      ).createShader(rect);
    canvas.drawArc(rect, -1.5708, 6.28318 * progress, false, progressPaint);

    final dotAngle = -1.5708 + 6.28318 * progress;
    final dot = Offset(
      center.dx + radius * math.cos(dotAngle),
      center.dy + radius * math.sin(dotAngle),
    );
    canvas.drawCircle(
      dot,
      5,
      Paint()..color = Colors.white.withValues(alpha: isDarkMode ? 0.9 : 1),
    );
    canvas.drawCircle(dot, 3, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(covariant _FocusTimerDialPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.accent != accent ||
      oldDelegate.isDarkMode != isDarkMode;
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
                  color: StudyUi.muted(isDarkMode),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  color: isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body,
                  fontSize: 13,
                  height: 1.4)),
        ],
      ),
    );
  }
}

// ─── Focus History Full Page ───

class _FocusHistoryPage extends StatefulWidget {
  const _FocusHistoryPage({
    required this.isDarkMode,
    required this.sessions,
  });
  final bool isDarkMode;
  final List<_FocusSession> sessions;

  @override
  State<_FocusHistoryPage> createState() => _FocusHistoryPageState();
}

class _FocusHistoryPageState extends State<_FocusHistoryPage> {
  final _searchController = TextEditingController();
  String _query = '';
  int? _rangeDays;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_FocusSession> get _filteredSessions {
    final now = DateTime.now();
    final normalizedQuery = _query.trim().toLowerCase();
    return widget.sessions.where((session) {
      if (_rangeDays != null &&
          session.time.isBefore(now.subtract(Duration(days: _rangeDays!)))) {
        return false;
      }
      if (normalizedQuery.isEmpty) return true;
      final haystack = [
        session.focusTitle ?? '',
        '${session.minutes} 分钟',
        _fmtDate(session.time),
        _fmtClock(session.time),
      ].join(' ').toLowerCase();
      return haystack.contains(normalizedQuery);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.isDarkMode;
    final textColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    final sessions = _filteredSessions;

    final grouped = <String, List<_FocusSession>>{};
    for (final s in sessions) {
      final key = _fmtDate(s.time);
      grouped.putIfAbsent(key, () => []).add(s);
    }
    final totalMinutes = sessions.fold<int>(0, (sum, s) => sum + s.minutes);

    return Scaffold(
      backgroundColor: StudyUi.background(isDarkMode),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        title: const Text('专注记录',
            style: TextStyle(fontWeight: AppTypography.title)),
      ),
      body: widget.sessions.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 22),
                child: StudyEmptyState(
                  asset: AppAssets.uiRefreshFeatureTimer,
                  title: '暂无专注记录',
                  message: '完成一次专注后，这里会显示时长和历史记录。',
                  compact: true,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 40),
              children: [
                StudyCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _query = value),
                        style: TextStyle(color: textColor, fontSize: 14),
                        decoration: InputDecoration(
                          isDense: true,
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: StudyUi.muted(isDarkMode),
                          ),
                          hintText: '搜索专注内容、日期或时长',
                          hintStyle:
                              TextStyle(color: StudyUi.muted(isDarkMode)),
                          border: InputBorder.none,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _rangeChip('全部', null),
                          _rangeChip('今天', 1),
                          _rangeChip('7 天', 7),
                          _rangeChip('30 天', 30),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                StudyCard(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('累计专注',
                                  style: TextStyle(
                                      color: bodyColor, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text('${sessions.length} 次',
                                  style: TextStyle(
                                      color: textColor,
                                      fontSize: 28,
                                      fontWeight: AppTypography.hero)),
                            ]),
                      ),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('总时长',
                                  style: TextStyle(
                                      color: bodyColor, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text('${(totalMinutes / 60).toStringAsFixed(1)}h',
                                  style: TextStyle(
                                      color: textColor,
                                      fontSize: 28,
                                      fontWeight: AppTypography.hero)),
                            ]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                if (sessions.isEmpty)
                  StudyEmptyState(
                    asset: AppAssets.uiRefreshFeatureTimer,
                    title: '没有匹配记录',
                    message: '换个关键词或时间范围再查一次。',
                    compact: true,
                  )
                else
                  for (final entry in grouped.entries) ...[
                    Text(entry.key,
                        style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ...entry.value.map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: StudyCard(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                    color: StudyUi.chipBackground(
                                        StudyUi.success, isDarkMode),
                                    borderRadius: BorderRadius.circular(10)),
                                child: const StudyAssetIcon(
                                  asset: AppAssets.featureTimerIcon,
                                  color: StudyUi.success,
                                  size: 20,
                                  fallbackIcon: Icons.timer_rounded,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.focusTitle == null ||
                                              s.focusTitle!.isEmpty
                                          ? '${s.minutes} 分钟专注'
                                          : s.focusTitle!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${s.minutes} 分钟',
                                      style: TextStyle(
                                          color: bodyColor, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Text(_fmtClock(s.time),
                                  style: TextStyle(
                                      color: bodyColor, fontSize: 13)),
                            ]),
                          ),
                        )),
                    const SizedBox(height: 14),
                  ],
              ],
            ),
    );
  }

  Widget _rangeChip(String label, int? days) {
    final selected = _rangeDays == days;
    return StudyStatusChip(
      label: label,
      color: StudyUi.primary,
      selected: selected,
      onTap: () => setState(() => _rangeDays = days),
    );
  }

  static String _fmtDate(DateTime time) =>
      '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';

  static String _fmtClock(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}
