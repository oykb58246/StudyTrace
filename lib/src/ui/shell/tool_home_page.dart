import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../controllers/app_data_controller.dart';
import '../../models/ai_action_record.dart';
import '../../models/study_log_item.dart';
import '../../models/study_sub_task_item.dart';
import '../../models/study_task_item.dart';
import '../../services/ai_exceptions.dart';
import '../../services/local_storage_service.dart';
import '../../services/ocr_service.dart';
import '../../theme/app_theme.dart';
import '../shared/app_assets.dart';
import '../shared/common_widgets.dart';
import '../shared/rive_safe_widget.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.isDarkMode,
    required this.controller,
    required this.onGenerateReport,
    this.onOpenAiAssistant,
    this.onOpenAiChat,
    this.onOpenLogs,
    this.onOpenCalendar,
    this.onOpenTasks,
    this.onOpenOverdueTasks,
    this.onOpenNotes,
    this.onOpenTimer,
    this.onOpenFlashCards,
    this.onStartFlashCardReview,
    this.onOpenLearningMoments,
    this.onOpenEvidencePackage,
    this.onOpenStudyGroup,
    this.onOpenLeaderboard,
    this.onOpenSyncSettings,
    this.onOpenTaskPlanning,
  });

  final bool isDarkMode;
  final AppDataController controller;
  final VoidCallback onGenerateReport;
  final VoidCallback? onOpenAiAssistant;
  final VoidCallback? onOpenAiChat;
  final VoidCallback? onOpenLogs;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenTasks;
  final VoidCallback? onOpenOverdueTasks;
  final VoidCallback? onOpenNotes;
  final VoidCallback? onOpenTimer;
  final VoidCallback? onOpenFlashCards;
  final VoidCallback? onStartFlashCardReview;
  final VoidCallback? onOpenLearningMoments;
  final VoidCallback? onOpenEvidencePackage;
  final VoidCallback? onOpenStudyGroup;
  final VoidCallback? onOpenLeaderboard;
  final VoidCallback? onOpenSyncSettings;
  final VoidCallback? onOpenTaskPlanning;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final accent = controller.primaryColor;
        final logs = controller.studyLogs;
        final tasks = controller.studyTasks;

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final tomorrow = today.add(const Duration(days: 1));
        final weekAgo = now.subtract(const Duration(days: 7));
        final recentLogs =
            logs.where((l) => !l.date.isBefore(weekAgo)).toList();

        final todayTasks = tasks
            .where((t) =>
                !t.deadline.isBefore(today) && t.deadline.isBefore(tomorrow))
            .toList();
        final overdueTasks = tasks
            .where((t) =>
                t.effectiveStatus != StudyTaskStatus.completed &&
                t.deadline.isBefore(today))
            .length;
        final todayCompletedTasks = todayTasks
            .where((t) => t.effectiveStatus == StudyTaskStatus.completed)
            .length;
        final todayTotalTasks = todayTasks.length;
        final recentAiActions = controller.recentActionRecords
            .where((r) => !r.createdAt.isBefore(weekAgo))
            .length;
        final recentTraceMoments = controller.learningMoments.where((moment) {
          final sourceType = (moment.sourceType ?? '').trim();
          return (sourceType == 'learning_loop' ||
                  sourceType == 'synced_learning_loop' ||
                  sourceType == 'task_progress' ||
                  sourceType == 'synced_task_progress') &&
              !moment.createdAt.isBefore(weekAgo);
        }).toList(growable: false);
        final dueFlashcards =
            controller.flashCards.where((card) => card.isDueForReview).length;
        final todayFocusMinutes = _todayFocusMinutes(
          controller.recentActionRecords,
          now,
        );
        final sprintAction = _SprintAction.from(
          tasks: tasks,
          logs: logs,
          streak: controller.studyStreak,
        );
        final sprintActionTap = switch (sprintAction.target) {
          _SprintActionTarget.task => onOpenTasks,
          _SprintActionTarget.log => onOpenLogs,
          _SprintActionTarget.review => onOpenAiAssistant,
        };
        Future<void> completeSprintAction() async {
          final taskId = sprintAction.taskId;
          if (taskId == null) {
            sprintActionTap?.call();
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
                isDarkMode: isDarkMode,
                accent: StudyUi.success,
                icon: Icons.task_alt_rounded,
                title: '确认完成这一步？',
                subtitle: '确认后会更新任务状态，并把这次推进写入学迹。',
                actions: [
                  Row(
                    children: [
                      Expanded(
                        child: StudyActionPill(
                          icon: Icons.close_rounded,
                          label: '取消',
                          color: StudyUi.muted(isDarkMode),
                          isDarkMode: isDarkMode,
                          filled: false,
                          expand: true,
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StudyActionPill(
                          icon: Icons.done_rounded,
                          label: '确认完成',
                          color: StudyUi.success,
                          isDarkMode: isDarkMode,
                          expand: true,
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                        ),
                      ),
                    ],
                  ),
                ],
                child: Text(
                  sprintAction.title,
                  style: TextStyle(
                    color: StudyUi.body(isDarkMode),
                    height: 1.45,
                  ),
                ),
              ),
            ),
          );
          if (confirmed != true || !context.mounted) return;
          final updated = await controller.completeStudyTaskAction(
            taskId,
            subTaskId: sprintAction.subTaskId,
          );
          if (!context.mounted) return;
          if (updated == null) {
            StudyToast.show(context, '今日行动已变化，请刷新后再试');
            return;
          }
          StudyToast.show(
            context,
            updated.effectiveStatus == StudyTaskStatus.completed
                ? '今日行动已完成，学迹已更新'
                : '已完成一个下一步，学迹已更新',
          );
        }

        void handleTraceEntryAction(_HomeTraceEntry entry) {
          final action = switch (entry.actionKind) {
            _HomeTraceActionKind.log =>
              onOpenLearningMoments ?? onOpenLogs ?? onOpenAiAssistant,
            _HomeTraceActionKind.task =>
              onOpenTasks ?? onOpenTaskPlanning ?? onOpenAiAssistant,
            _HomeTraceActionKind.flashcard =>
              onStartFlashCardReview ?? onOpenFlashCards ?? onOpenAiAssistant,
            _HomeTraceActionKind.report => onGenerateReport,
            _HomeTraceActionKind.assistant => onOpenAiChat ?? onOpenAiAssistant,
          };
          if (action != null) {
            action();
            return;
          }
          StudyToast.show(context, '这个入口还在整理，先去学习助手看看');
        }

        final traceEntries = _HomeTraceEntry.build(
          logs: recentLogs,
          tasks: tasks,
          action: sprintAction,
          now: now,
        );
        final recentCourseNames = recentLogs
            .map((l) => l.courseName)
            .where((n) => n.isNotEmpty)
            .toSet()
            .toList();
        final textColor = isDarkMode ? Colors.white : AppColors.ink;
        final bodyColor = isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;
        final media = MediaQuery.of(context);
        final compactMobile = media.size.width <= 480;
        final topPadding = media.padding.top + (compactMobile ? 44 : 38);

        return Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  _HomeRiveBackground(isDarkMode: isDarkMode),
                  RefreshIndicator(
                    onRefresh: controller.load,
                    child: ListView(
                      key: const Key('page_home'),
                      padding: EdgeInsets.fromLTRB(
                        20,
                        topPadding,
                        20,
                        compactMobile ? 168 : 144,
                      ),
                      children: [
                        _HomeStudyDashboardPanel(
                          isDarkMode: isDarkMode,
                          accent: accent,
                          compact: compactMobile,
                          action: sprintAction,
                          completedTasks: todayCompletedTasks,
                          totalTasks: todayTotalTasks,
                          recentAiActions: recentAiActions,
                          todayFocusMinutes: todayFocusMinutes,
                          recentLearningLoopCount: recentTraceMoments.length,
                          overdueTasks: overdueTasks,
                          onStartReview: onOpenAiAssistant,
                          onActionTap: sprintActionTap,
                          onOpenOverdueTasks: onOpenOverdueTasks,
                          onCompleteAction: sprintAction.taskId == null
                              ? null
                              : completeSprintAction,
                          onAskAi: onOpenAiChat ?? onOpenAiAssistant,
                          onVoiceCreate: () => _openAiCreate(
                            context,
                            source: _AiCreateSource.voice,
                          ),
                          onPhotoCreate: () => _openAiCreate(
                            context,
                            source: _AiCreateSource.photo,
                          ),
                          onOpenNotes: onOpenNotes,
                          onOpenLearningMoments: onOpenLearningMoments,
                          onGenerateSummary: onGenerateReport,
                        ),
                        const SizedBox(height: 18),
                        _HomeTraceTimeline(
                          isDarkMode: isDarkMode,
                          accent: accent,
                          entries: traceEntries,
                          aiHint: _homeAiHint(
                            dueFlashcards: dueFlashcards,
                            action: sprintAction,
                          ),
                          now: now,
                          onEntryAction: handleTraceEntryAction,
                        ),
                        const SizedBox(height: 18),
                        _HomeAiSuggestion(
                          isDarkMode: isDarkMode,
                          controller: controller,
                          onOpenAssistant: onOpenAiAssistant,
                          onOpenTasks: onOpenTasks,
                          onOpenTimer: onOpenTimer,
                        ),
                        const SizedBox(height: 22),
                        Text(
                          '最近记录',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (recentCourseNames.isNotEmpty)
                          Text(
                            '本周课程：${recentCourseNames.join('、')}',
                            style: TextStyle(color: bodyColor, fontSize: 13),
                          ),
                        if (recentCourseNames.isNotEmpty)
                          const SizedBox(height: 12),
                        if (recentLogs.isEmpty)
                          _EmptyRecentCard(
                            isDarkMode: isDarkMode,
                            onStartReview: onOpenAiAssistant,
                            onOpenLogs: onOpenLogs,
                          )
                        else
                          for (final log in recentLogs.take(4)) ...[
                            _RecentLogCard(
                              courseName: log.courseName.isNotEmpty
                                  ? log.courseName
                                  : '未归课程',
                              content: log.content.isNotEmpty
                                  ? log.content
                                  : '无内容摘要',
                              date: _fmtDate(log.date),
                              isDarkMode: isDarkMode,
                            ),
                            if (log != recentLogs.take(4).last)
                              const SizedBox(height: 10),
                          ],
                      ],
                    ), // RefreshIndicator
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _openAiCreate(
    BuildContext context, {
    required _AiCreateSource source,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 340),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, __, ___) => _AiCreateInput(
          source: source,
          isDarkMode: isDarkMode,
          controller: controller,
          onOpenLearningCockpit: onOpenAiAssistant,
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
}

enum _SprintActionTarget { review, task, log }

class _SprintAction {
  const _SprintAction({
    required this.title,
    required this.reason,
    required this.expectedGain,
    required this.actionLabel,
    required this.target,
    this.taskId,
    this.subTaskId,
    this.completeLabel = '完成行动',
  });

  final String title;
  final String reason;
  final String expectedGain;
  final String actionLabel;
  final _SprintActionTarget target;
  final String? taskId;
  final String? subTaskId;
  final String completeLabel;

  static _SprintAction from({
    required List<StudyTaskItem> tasks,
    required List<StudyLogItem> logs,
    required int streak,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final pending = tasks
        .where((task) => task.effectiveStatus != StudyTaskStatus.completed)
        .toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));
    final dueToday = pending
        .where((task) =>
            !task.deadline.isBefore(today) && task.deadline.isBefore(tomorrow))
        .toList();
    if (dueToday.isNotEmpty) {
      final task = dueToday.first;
      final nextSubTask = _nextOpenSubTask(task);
      return _SprintAction(
        title: nextSubTask?.title ?? task.title,
        reason: nextSubTask == null
            ? '今天截止，适合先做 25 分钟推进。'
            : '来自任务：${task.title}。今天截止，先完成一个可交付步骤。',
        expectedGain: '把任务压力转成可完成行动。',
        actionLabel: '任务清单',
        target: _SprintActionTarget.task,
        taskId: task.id,
        subTaskId: nextSubTask?.id,
        completeLabel: nextSubTask == null ? '标记完成' : '完成一步',
      );
    }
    final hasTodayLog = logs.any((log) =>
        log.date.year == today.year &&
        log.date.month == today.month &&
        log.date.day == today.day);
    if (!hasTodayLog) {
      return const _SprintAction(
        title: '完成今晚 2 分钟学习记录',
        reason: '今天还没有记录学习事实和难点。',
        expectedGain: '留下今天的难点，明天更容易接着学。',
        actionLabel: '开始记录',
        target: _SprintActionTarget.review,
      );
    }
    final latestLog = logs.isEmpty ? null : logs.first;
    if (latestLog != null && latestLog.nextPlan.trim().isNotEmpty) {
      return _SprintAction(
        title: latestLog.nextPlan.trim(),
        reason: '来自最近一次学习记录的下一步安排。',
        expectedGain: '做完后，今天的学迹会更完整。',
        actionLabel: '继续学习',
        target: _SprintActionTarget.review,
      );
    }
    return _SprintAction(
      title: streak > 0 ? '保持连续学习第 $streak 天' : '记录第一次学习',
      reason: '当前没有明显截止压力，适合补一条主动记录。',
      expectedGain: '明天打开时，可以接上今天的思路。',
      actionLabel: '开始记录',
      target: _SprintActionTarget.review,
    );
  }

  static StudySubTaskItem? _nextOpenSubTask(StudyTaskItem task) {
    for (final subTask in task.subTasks) {
      if (subTask.status != SubTaskStatus.completed) {
        return subTask;
      }
    }
    return null;
  }
}

_HomeTraceActionKind _traceActionKindForSprintTarget(
  _SprintActionTarget target,
) {
  return switch (target) {
    _SprintActionTarget.task => _HomeTraceActionKind.task,
    _SprintActionTarget.log => _HomeTraceActionKind.log,
    _SprintActionTarget.review => _HomeTraceActionKind.assistant,
  };
}

String _traceActionLabelForSprintTarget(_SprintActionTarget target) {
  return switch (target) {
    _SprintActionTarget.task => '继续这一步',
    _SprintActionTarget.log => '去看记录',
    _SprintActionTarget.review => '整理下一步',
  };
}

int _todayFocusMinutes(List<AiActionRecord> records, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  var total = 0;
  for (final record in records) {
    if (record.createdAt.isBefore(today) ||
        !record.createdAt.isBefore(tomorrow)) {
      continue;
    }
    if (record.status != AiActionStatus.executed) continue;
    if (record.toolId != 'timer.start_focus' &&
        record.toolId != 'timer.start_focus_with_task') {
      continue;
    }
    final raw = record.params?['durationMinutes'];
    if (raw is num) {
      total += raw.toInt();
    }
  }
  return total;
}

String _formatFocusMinutes(int minutes) {
  if (minutes <= 0) return '0 分钟';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours <= 0) return '$minutes 分钟';
  if (rest == 0) return '$hours 小时';
  return '$hours 小时 $rest 分钟';
}

enum _HomeTraceActionKind { log, task, flashcard, report, assistant }

class _HomeTraceEntry {
  const _HomeTraceEntry({
    required this.date,
    required this.label,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.asset,
    required this.actionKind,
    required this.actionLabel,
  });

  final DateTime date;
  final String label;
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final String asset;
  final _HomeTraceActionKind actionKind;
  final String actionLabel;

  static List<_HomeTraceEntry> build({
    required List<StudyLogItem> logs,
    required List<StudyTaskItem> tasks,
    required _SprintAction action,
    required DateTime now,
  }) {
    final entries = <_HomeTraceEntry>[];
    final recentLogs = [...logs]..sort((a, b) => b.date.compareTo(a.date));
    for (final log in recentLogs.take(7)) {
      final course = log.courseName.trim();
      final content = _homeTrim(
        log.content.trim().isNotEmpty ? log.content : log.nextPlan,
        fallback: '记录了一次学习',
        maxLength: 140,
      );
      entries.add(
        _HomeTraceEntry(
          date: log.date,
          label: _homeDayLabel(log.date, now),
          title: course.isEmpty ? '学习记录' : course,
          subtitle: content,
          color: entries.isEmpty ? StudyUi.primary : StudyUi.secondary,
          icon: Icons.edit_note_rounded,
          asset: AppAssets.generatedHomeNotesIcon,
          actionKind: _HomeTraceActionKind.log,
          actionLabel: '去学迹回看',
        ),
      );
    }

    if (entries.length < 6) {
      final pending = tasks
          .where((task) => task.effectiveStatus != StudyTaskStatus.completed)
          .toList()
        ..sort((a, b) => a.deadline.compareTo(b.deadline));
      for (final task in pending.take(6 - entries.length)) {
        entries.add(
          _HomeTraceEntry(
            date: task.deadline,
            label: _homeDayLabel(task.deadline, now),
            title: _homeTrim(task.title, fallback: '待完成任务', maxLength: 18),
            subtitle: task.courseName.trim().isEmpty
                ? '先推进一小段'
                : '${task.courseName.trim()} · 先推进一小段',
            color: StudyUi.pathBlue,
            icon: Icons.flag_rounded,
            asset: AppAssets.homePlanV3Icon,
            actionKind: _HomeTraceActionKind.task,
            actionLabel: '打开任务清单',
          ),
        );
      }
    }

    final tomorrow = now.add(const Duration(days: 1));
    final nextStepDate = now.add(const Duration(days: 2));
    final daysUntilSunday = (DateTime.sunday - now.weekday + 7) % 7;
    final weekendDate = now.add(Duration(days: daysUntilSunday));
    final fallbackEntries = [
      _HomeTraceEntry(
        date: now,
        label: _homeDayLabel(now, now),
        title: action.title,
        subtitle: '说几句今天学了什么',
        color: StudyUi.primary,
        icon: Icons.auto_awesome_rounded,
        asset: AppAssets.homeTraceV3Icon,
        actionKind: _traceActionKindForSprintTarget(action.target),
        actionLabel: _traceActionLabelForSprintTarget(action.target),
      ),
      _HomeTraceEntry(
        date: tomorrow,
        label: _homeDayLabel(tomorrow, now),
        title: '课前看一眼',
        subtitle: '把小结和卡片再过一遍',
        color: StudyUi.success,
        icon: Icons.style_rounded,
        asset: AppAssets.homeFlashcardsV3Icon,
        actionKind: _HomeTraceActionKind.flashcard,
        actionLabel: '去复习',
      ),
      _HomeTraceEntry(
        date: weekendDate,
        label: _homeDayLabel(weekendDate, now),
        title: '看看本周小结',
        subtitle: '知道自己哪里变熟了',
        color: StudyUi.warning,
        icon: Icons.insights_rounded,
        asset: AppAssets.generatedHomeWeeklyReviewIcon,
        actionKind: _HomeTraceActionKind.report,
        actionLabel: '整理本周小结',
      ),
      _HomeTraceEntry(
        date: nextStepDate,
        label: _homeDayLabel(nextStepDate, now),
        title: '把不会的问清楚',
        subtitle: '把卡住的地方拆成小问题',
        color: StudyUi.secondary,
        icon: Icons.question_answer_rounded,
        asset: AppAssets.sideAiAssistantIcon,
        actionKind: _HomeTraceActionKind.assistant,
        actionLabel: '问问助手',
      ),
    ];
    var fallbackIndex = 0;
    while (entries.length < 4 && fallbackIndex < fallbackEntries.length) {
      entries.add(fallbackEntries[fallbackIndex]);
      fallbackIndex += 1;
    }

    return entries.take(7).toList(growable: false);
  }
}

class _HomeStudyDashboardPanel extends StatelessWidget {
  const _HomeStudyDashboardPanel({
    required this.isDarkMode,
    required this.accent,
    required this.compact,
    required this.action,
    required this.completedTasks,
    required this.totalTasks,
    required this.recentAiActions,
    required this.todayFocusMinutes,
    required this.recentLearningLoopCount,
    required this.overdueTasks,
    required this.onStartReview,
    required this.onActionTap,
    required this.onOpenOverdueTasks,
    required this.onCompleteAction,
    required this.onAskAi,
    required this.onVoiceCreate,
    required this.onPhotoCreate,
    required this.onOpenNotes,
    required this.onOpenLearningMoments,
    required this.onGenerateSummary,
  });

  final bool isDarkMode;
  final Color accent;
  final bool compact;
  final _SprintAction action;
  final int completedTasks;
  final int totalTasks;
  final int recentAiActions;
  final int todayFocusMinutes;
  final int recentLearningLoopCount;
  final int overdueTasks;
  final VoidCallback? onStartReview;
  final VoidCallback? onActionTap;
  final VoidCallback? onOpenOverdueTasks;
  final Future<void> Function()? onCompleteAction;
  final VoidCallback? onAskAi;
  final VoidCallback? onVoiceCreate;
  final VoidCallback? onPhotoCreate;
  final VoidCallback? onOpenNotes;
  final VoidCallback? onOpenLearningMoments;
  final VoidCallback? onGenerateSummary;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    final taskProgress = totalTasks <= 0
        ? 0.0
        : (completedTasks / totalTasks).clamp(0.0, 1.0).toDouble();
    final quickActions = [
      _HomeQuickAction(
        label: '语音整理',
        caption: '语音记录',
        asset: AppAssets.homeVoiceV3Icon,
        icon: Icons.mic_rounded,
        color: StudyUi.pathCyan,
        onTap: onVoiceCreate,
      ),
      _HomeQuickAction(
        label: '拍照整理',
        caption: '题目/板书',
        asset: AppAssets.homeCameraV3Icon,
        icon: Icons.photo_camera_rounded,
        color: StudyUi.pathWarm,
        onTap: onPhotoCreate,
      ),
      _HomeQuickAction(
        label: '学习笔记',
        caption: '回看重点',
        asset: AppAssets.homeNotesV3Icon,
        icon: Icons.edit_note_rounded,
        color: StudyUi.pathBlue,
        onTap: onOpenNotes,
      ),
      _HomeQuickAction(
        label: '学迹动态',
        caption: '分享学习',
        asset: AppAssets.homeTraceV3Icon,
        icon: Icons.dynamic_feed_rounded,
        color: StudyUi.secondary,
        onTap: onOpenLearningMoments ?? onGenerateSummary,
      ),
    ];

    return StudyFontScope(
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      StudyAssetIcon(
                        asset: AppAssets.brandAppIcon,
                        preserveColor: true,
                        fallbackIcon: Icons.auto_stories_rounded,
                        size: compact ? 42 : 46,
                      ),
                      const SizedBox(width: 10),
                      Image.asset(
                        AppAssets.brandWordLogo,
                        width: compact ? 100 : 116,
                        height: compact ? 34 : 38,
                        fit: BoxFit.contain,
                        semanticLabel: '学迹',
                        errorBuilder: (_, __, ___) => Text(
                          '学迹',
                          style: TextStyle(
                            color: titleColor,
                            fontSize: compact ? 30 : 32,
                            height: 1.04,
                            fontWeight: AppTypography.hero,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    recentLearningLoopCount > 0
                        ? '学习记录已接到今天安排，先完成下一步'
                        : todayFocusMinutes > 0
                            ? '今天已专注 ${_formatFocusMinutes(todayFocusMinutes)}，先接着下一步'
                            : '先抓住今天最该推进的一小步',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: bodyColor,
                      fontSize: 14,
                      fontWeight: AppTypography.emphasis,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: compact ? 20 : 22),
            _HomeTodayActionCard(
              isDarkMode: isDarkMode,
              accent: accent,
              action: action,
              taskProgress: taskProgress,
              totalTasks: totalTasks,
              completedTasks: completedTasks,
              overdueTasks: overdueTasks,
              hasRecentLearningPath: recentLearningLoopCount > 0,
              onStartReview: onStartReview,
              onActionTap: onActionTap,
              onOverdueTap: onOpenOverdueTasks,
              onCompleteAction: onCompleteAction,
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final spacing = compact ? 7.0 : 10.0;
                final columns =
                    constraints.maxWidth < 340 ? 2 : quickActions.length;
                final width =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final action in quickActions)
                      SizedBox(
                        width: width,
                        child: _HomeQuickActionTile(
                          action: action,
                          isDarkMode: isDarkMode,
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            _HomeAiAgentEntry(
              isDarkMode: isDarkMode,
              onTap: onAskAi,
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTodayActionCard extends StatelessWidget {
  const _HomeTodayActionCard({
    required this.isDarkMode,
    required this.accent,
    required this.action,
    required this.taskProgress,
    required this.totalTasks,
    required this.completedTasks,
    required this.overdueTasks,
    required this.hasRecentLearningPath,
    required this.onStartReview,
    required this.onActionTap,
    required this.onOverdueTap,
    required this.onCompleteAction,
  });

  final bool isDarkMode;
  final Color accent;
  final _SprintAction action;
  final double taskProgress;
  final int totalTasks;
  final int completedTasks;
  final int overdueTasks;
  final bool hasRecentLearningPath;
  final VoidCallback? onStartReview;
  final VoidCallback? onActionTap;
  final VoidCallback? onOverdueTap;
  final Future<void> Function()? onCompleteAction;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    final actionTap = action.target == _SprintActionTarget.review
        ? onStartReview
        : (onActionTap ?? onStartReview);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
        boxShadow: [
          if (!isDarkMode)
            BoxShadow(
              color: accent.withValues(alpha: 0.10),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BadgePill(
                      label: hasRecentLearningPath ? '今天要做的一步' : '今天先走这一小步',
                      background: StudyUi.chipBackground(accent, isDarkMode),
                      foreground: accent,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      action.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 20,
                        height: 1.18,
                        fontWeight: AppTypography.hero,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      action.reason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: bodyColor,
                        fontSize: 13,
                        height: 1.38,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _MiniProgressRing(
                progress: taskProgress,
                color: accent,
                isDarkMode: isDarkMode,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            totalTasks > 0
                ? hasRecentLearningPath
                    ? '学习记录已接到今天安排，完成 $completedTasks / $totalTasks'
                    : '今天安排已完成 $completedTasks / $totalTasks'
                : action.expectedGain,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: AppTypography.emphasis,
            ),
          ),
          if (overdueTasks > 0) ...[
            const SizedBox(height: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onOverdueTap,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                  decoration: BoxDecoration(
                    color: StudyUi.danger.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: StudyUi.danger.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: StudyUi.danger,
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          onOverdueTap == null
                              ? '$overdueTasks 项任务已过期，可以稍后到任务清单处理'
                              : '$overdueTasks 项任务已过期，打开任务清单处理',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: StudyUi.danger,
                            fontSize: 11,
                            fontWeight: AppTypography.title,
                          ),
                        ),
                      ),
                      if (onOverdueTap != null) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: StudyUi.danger,
                          size: 17,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StudyActionPill(
                  icon: Icons.check_circle_rounded,
                  label: action.actionLabel,
                  color: accent,
                  isDarkMode: isDarkMode,
                  expand: true,
                  showShadow: !action.actionLabel.contains('任务清单'),
                  onPressed: actionTap,
                ),
              ),
              if (onCompleteAction != null) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 96,
                  child: StudyActionPill(
                    icon: Icons.done_rounded,
                    label: '完成',
                    color: StudyUi.success,
                    isDarkMode: isDarkMode,
                    filled: false,
                    expand: true,
                    onPressed: () => unawaited(onCompleteAction!()),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeQuickAction {
  const _HomeQuickAction({
    required this.label,
    required this.caption,
    required this.asset,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String caption;
  final String asset;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
}

class _HomeQuickActionTile extends StatelessWidget {
  const _HomeQuickActionTile({
    required this.action,
    required this.isDarkMode,
  });

  final _HomeQuickAction action;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: action.onTap,
        child: Container(
          height: 92,
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.055)
                : Colors.white.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.70)),
            boxShadow: [
              if (!isDarkMode)
                BoxShadow(
                  color: action.color.withValues(alpha: 0.09),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color:
                      action.color.withValues(alpha: isDarkMode ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: Center(
                    child: StudyAssetIcon(
                      asset: action.asset,
                      preserveColor: true,
                      fallbackIcon: action.icon,
                      size: 25,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 14,
                  height: 1.08,
                  fontWeight: AppTypography.title,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                action.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: bodyColor.withValues(alpha: 0.82),
                  fontSize: 12,
                  height: 1.08,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeAiAgentEntry extends StatelessWidget {
  const _HomeAiAgentEntry({
    required this.isDarkMode,
    required this.onTap,
  });

  final bool isDarkMode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = StudyUi.pathViolet;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: isDarkMode ? 0.42 : 0.84),
                StudyUi.secondary.withValues(alpha: isDarkMode ? 0.32 : 0.72),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDarkMode ? 0.13 : 0.42),
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: isDarkMode ? 0.16 : 0.24),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: StudyAssetIcon(
                    asset: AppAssets.brandWhiteTransparentLogo,
                    preserveColor: true,
                    fallbackIcon: Icons.auto_awesome_rounded,
                    size: 42,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '学迹Agent 学习对话',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: AppTypography.title,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '试试学迹Agent帮你解决学习问题吧~',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.86),
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.86),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeTraceTimeline extends StatelessWidget {
  const _HomeTraceTimeline({
    required this.isDarkMode,
    required this.accent,
    required this.entries,
    required this.aiHint,
    required this.now,
    required this.onEntryAction,
  });

  final bool isDarkMode;
  final Color accent;
  final List<_HomeTraceEntry> entries;
  final String aiHint;
  final DateTime now;
  final ValueChanged<_HomeTraceEntry> onEntryAction;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    return StudyFontScope(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '这几天的学迹',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 19,
                      fontWeight: AppTypography.hero,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: StudyUi.chipBackground(accent, isDarkMode),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swap_horiz_rounded, color: accent, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '近几天',
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: AppTypography.title,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: StudyUi.chipBackground(accent, isDarkMode),
              border: Border.all(color: accent.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: accent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    aiHint,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      height: 1.25,
                      fontWeight: AppTypography.emphasis,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 420;
              final height = compact ? 318.0 : 336.0;
              final gap = compact ? 220.0 : 264.0;
              final cardHeight = compact ? 174.0 : 190.0;
              final pathWidth = math
                  .max(
                    constraints.maxWidth,
                    132 + (entries.length - 1) * gap + 132,
                  )
                  .toDouble();
              final centers = _traceCenters(entries.length, gap, height);
              final cardWidth = compact ? 214.0 : 248.0;
              final paintOrder = _tracePaintOrder(entries, now);
              return SizedBox(
                height: height,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  clipBehavior: Clip.none,
                  child: SizedBox(
                    width: pathWidth,
                    height: height,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _TraceCurvePainter(
                              centers: centers,
                              accent: accent,
                              isDarkMode: isDarkMode,
                            ),
                          ),
                        ),
                        for (final i in paintOrder)
                          Positioned(
                            left: _traceCardLeft(
                              centers[i],
                              cardWidth,
                              pathWidth,
                            ),
                            top: _traceCardTop(
                              centers[i],
                              height,
                              cardHeight,
                            ),
                            child: SizedBox(
                              width: cardWidth,
                              height: cardHeight,
                              child: _HomeTraceFloatingCard(
                                entry: entries[i],
                                isDarkMode: isDarkMode,
                                compact: compact,
                                onActionTap: onEntryAction,
                              ),
                            ),
                          ),
                        for (final i in paintOrder)
                          Positioned(
                            left: centers[i].dx - (compact ? 19 : 22),
                            top: centers[i].dy - (compact ? 19 : 22),
                            child: _HomeTraceNode(
                              entry: entries[i],
                              isDarkMode: isDarkMode,
                              compact: compact,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<int> _tracePaintOrder(List<_HomeTraceEntry> entries, DateTime now) {
    final indices = List<int>.generate(entries.length, (index) => index);
    indices.sort((a, b) {
      final aDistance = _traceDayDistance(entries[a].date, now);
      final bDistance = _traceDayDistance(entries[b].date, now);
      final distanceOrder = bDistance.compareTo(aDistance);
      if (distanceOrder != 0) return distanceOrder;
      return b.compareTo(a);
    });
    return indices;
  }

  int _traceDayDistance(DateTime date, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    return today.difference(day).inDays.abs();
  }

  List<Offset> _traceCenters(int count, double gap, double height) {
    final yPattern = [
      height * 0.60,
      height * 0.34,
      height * 0.27,
      height * 0.56,
      height * 0.38,
      height * 0.64,
      height * 0.30,
    ];
    return [
      for (var i = 0; i < count; i++)
        Offset(78 + i * gap, yPattern[i % yPattern.length]),
    ];
  }

  double _traceCardLeft(Offset center, double width, double pathWidth) {
    return (center.dx - width / 2).clamp(6.0, pathWidth - width - 6).toDouble();
  }

  double _traceCardTop(Offset center, double height, double cardHeight) {
    final placeAbove = center.dy > height * 0.50;
    final top = placeAbove ? center.dy - cardHeight - 14 : center.dy + 18;
    return top.clamp(4.0, height - cardHeight - 4).toDouble();
  }
}

class _HomeTraceNode extends StatelessWidget {
  const _HomeTraceNode({
    required this.entry,
    required this.isDarkMode,
    required this.compact,
  });

  final _HomeTraceEntry entry;
  final bool isDarkMode;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 38.0 : 44.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withValues(alpha: isDarkMode ? 0.12 : 0.98),
            entry.color.withValues(alpha: isDarkMode ? 0.24 : 0.18),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDarkMode ? 0.16 : 0.88),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: entry.color.withValues(alpha: isDarkMode ? 0.30 : 0.24),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
          if (!isDarkMode)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.90),
              blurRadius: 8,
              offset: const Offset(0, -3),
            ),
        ],
      ),
      child: Center(
        child: StudyAssetIcon(
          asset: entry.asset,
          preserveColor: true,
          fallbackIcon: entry.icon,
          size: compact ? 25 : 29,
        ),
      ),
    );
  }
}

class _HomeTraceFloatingCard extends StatelessWidget {
  const _HomeTraceFloatingCard({
    required this.entry,
    required this.isDarkMode,
    required this.compact,
    required this.onActionTap,
  });

  final _HomeTraceEntry entry;
  final bool isDarkMode;
  final bool compact;
  final ValueChanged<_HomeTraceEntry> onActionTap;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    return Container(
      padding:
          EdgeInsets.fromLTRB(14, compact ? 12 : 14, 14, compact ? 12 : 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  const Color(0xFF172331).withValues(alpha: 0.92),
                  const Color(0xFF111C27).withValues(alpha: 0.82),
                ]
              : [
                  Colors.white.withValues(alpha: 0.90),
                  entry.color.withValues(alpha: 0.050),
                  Colors.white.withValues(alpha: 0.76),
                ],
        ),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.74),
        ),
        boxShadow: [
          if (!isDarkMode)
            BoxShadow(
              color: entry.color.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          BoxShadow(
            color: const Color(0xFF6D7EA5)
                .withValues(alpha: isDarkMode ? 0.16 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 10 : 12,
                    vertical: compact ? 5 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: entry.color
                        .withValues(alpha: isDarkMode ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: entry.color
                          .withValues(alpha: isDarkMode ? 0.16 : 0.08),
                    ),
                  ),
                  child: Text(
                    entry.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: entry.color,
                      fontSize: compact ? 11 : 12,
                      fontWeight: AppTypography.title,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: entry.actionLabel,
                child: Material(
                  color: entry.color.withValues(
                    alpha: isDarkMode ? 0.18 : 0.11,
                  ),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => onActionTap(entry),
                    child: SizedBox(
                      width: compact ? 22 : 24,
                      height: compact ? 22 : 24,
                      child: Icon(
                        Icons.arrow_outward_rounded,
                        size: compact ? 13 : 14,
                        color: entry.color,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 9 : 10),
          Text(
            entry.title,
            maxLines: compact ? 2 : 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: titleColor,
              fontSize: compact ? 14 : 15,
              height: 1.14,
              fontWeight: AppTypography.title,
            ),
          ),
          SizedBox(height: compact ? 5 : 6),
          Text(
            entry.subtitle,
            maxLines: compact ? 4 : 5,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: bodyColor,
              fontSize: compact ? 11.4 : 12,
              height: 1.28,
            ),
          ),
        ],
      ),
    );
  }
}

class _TraceCurvePainter extends CustomPainter {
  const _TraceCurvePainter({
    required this.centers,
    required this.accent,
    required this.isDarkMode,
  });

  final List<Offset> centers;
  final Color accent;
  final bool isDarkMode;

  @override
  void paint(Canvas canvas, Size size) {
    if (centers.length < 2) return;

    final path = Path()..moveTo(centers.first.dx, centers.first.dy);
    for (var i = 0; i < centers.length - 1; i++) {
      final current = centers[i];
      final next = centers[i + 1];
      final control = Offset(
        (current.dx + next.dx) / 2,
        (current.dy + next.dy) / 2 + (i.isEven ? -40 : 40),
      );
      path.quadraticBezierTo(control.dx, control.dy, next.dx, next.dy);
    }

    final glowPaint = Paint()
      ..color = accent.withValues(alpha: isDarkMode ? 0.16 : 0.18)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 14
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawPath(path, glowPaint);

    final basePaint = Paint()
      ..color = Colors.white.withValues(alpha: isDarkMode ? 0.20 : 0.82)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 7;
    canvas.drawPath(path, basePaint);

    final routePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          accent.withValues(alpha: isDarkMode ? 0.48 : 0.44),
          StudyUi.pathCyan.withValues(alpha: isDarkMode ? 0.52 : 0.46),
          StudyUi.pathMint.withValues(alpha: isDarkMode ? 0.44 : 0.38),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 2.8;
    canvas.drawPath(path, routePaint);

    final dotPaint = Paint()..color = accent.withValues(alpha: 0.14);
    for (var i = 0; i < centers.length; i++) {
      if (i.isOdd) {
        canvas.drawCircle(
          centers[i].translate(34, -30),
          2.2,
          dotPaint,
        );
      } else {
        canvas.drawCircle(
          centers[i].translate(-28, 30),
          1.8,
          dotPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TraceCurvePainter oldDelegate) {
    return oldDelegate.centers != centers ||
        oldDelegate.accent != accent ||
        oldDelegate.isDarkMode != isDarkMode;
  }
}

String _homeAiHint({
  required int dueFlashcards,
  required _SprintAction action,
}) {
  if (dueFlashcards > 0) {
    return '今天有 $dueFlashcards 张卡片适合再过一遍';
  }
  if (action.target == _SprintActionTarget.task) {
    return '先把最紧的一步做完，晚点再补记录';
  }
  return '睡前补一条学习记录，明天更好接上';
}

String _homeTrim(
  String value, {
  String fallback = '',
  int maxLength = 24,
}) {
  final text = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.isEmpty) return fallback;
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength)}...';
}

String _homeDayLabel(DateTime date, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return '今天';
  if (diff == 1) return '昨天';
  if (date.year != now.year) {
    return '${date.year}/${date.month}/${date.day}';
  }
  return '${date.month}/${date.day}';
}

// ignore: unused_element
class _FinalSprintHeroPanel extends StatelessWidget {
  const _FinalSprintHeroPanel({
    required this.isDarkMode,
    required this.accent,
    required this.action,
    required this.recentLogs,
    required this.completedTasks,
    required this.totalTasks,
    required this.recentAiActions,
    required this.onStartReview,
    required this.onActionTap,
    required this.onCompleteAction,
    required this.onOpenEvidencePackage,
  });

  final bool isDarkMode;
  final Color accent;
  final _SprintAction action;
  final int recentLogs;
  final int completedTasks;
  final int totalTasks;
  final int recentAiActions;
  final VoidCallback? onStartReview;
  final VoidCallback? onActionTap;
  final Future<void> Function()? onCompleteAction;
  final VoidCallback? onOpenEvidencePackage;

  @override
  Widget build(BuildContext context) {
    final completionLabel =
        totalTasks == 0 ? '-' : '${(completedTasks * 100 ~/ totalTasks)}%';

    return StudyPathHero(
      isDarkMode: isDarkMode,
      accent: accent,
      badge: '今日学习路径',
      title: '今天先走这一小步',
      subtitle: '记录、行动、复习和回顾连在一起，不用从一堆工具里找入口。',
      icon: Icons.route_rounded,
      steps: const ['记录', '行动', '复习', '回顾'],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TodayPathFocusCard(
            isDarkMode: isDarkMode,
            accent: accent,
            action: action,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SprintMetric(
                  label: '近7天记录',
                  value: '$recentLogs',
                  color: accent,
                  isDarkMode: isDarkMode,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SprintMetric(
                  label: '任务完成率',
                  value: completionLabel,
                  color: StudyUi.success,
                  isDarkMode: isDarkMode,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SprintMetric(
                  label: '学习整理',
                  value: '$recentAiActions',
                  color: StudyUi.secondary,
                  isDarkMode: isDarkMode,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: StudyActionPill(
                  icon: Icons.edit_note_rounded,
                  label: '开始记录',
                  color: accent,
                  isDarkMode: isDarkMode,
                  expand: true,
                  onPressed: onStartReview,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StudyActionPill(
                  icon: Icons.arrow_forward_rounded,
                  label: action.actionLabel,
                  color: accent,
                  isDarkMode: isDarkMode,
                  filled: false,
                  expand: true,
                  onPressed: onActionTap ?? onStartReview,
                ),
              ),
            ],
          ),
          if (onOpenEvidencePackage != null || onCompleteAction != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onCompleteAction != null)
                  _HeroTextAction(
                    icon: Icons.check_circle_rounded,
                    label: action.completeLabel,
                    color: StudyUi.success,
                    isDarkMode: isDarkMode,
                    onTap: () => unawaited(onCompleteAction!()),
                  ),
                if (onOpenEvidencePackage != null)
                  _HeroTextAction(
                    icon: Icons.timeline_rounded,
                    label: '本周回顾',
                    color: StudyUi.secondary,
                    isDarkMode: isDarkMode,
                    onTap: onOpenEvidencePackage!,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ignore: unused_element
class _MobileStudyPathPanel extends StatelessWidget {
  const _MobileStudyPathPanel({
    required this.isDarkMode,
    required this.accent,
    required this.action,
    required this.recentLogs,
    required this.completedTasks,
    required this.totalTasks,
    required this.progress,
    required this.todayFocusMinutes,
    required this.streak,
    required this.onStartReview,
    required this.onActionTap,
    required this.onFlashcards,
    required this.onReviewPage,
  });

  final bool isDarkMode;
  final Color accent;
  final _SprintAction action;
  final int recentLogs;
  final int completedTasks;
  final int totalTasks;
  final double progress;
  final int todayFocusMinutes;
  final int streak;
  final VoidCallback? onStartReview;
  final VoidCallback? onActionTap;
  final VoidCallback? onFlashcards;
  final VoidCallback? onReviewPage;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    final focusProgress = (todayFocusMinutes / 240).clamp(0.0, 1.0).toDouble();

    return StudyFontScope(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.68)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [
                    const Color(0xFF14222D),
                    const Color(0xFF171B2D),
                    const Color(0xFF15192A),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.98),
                    const Color(0xFFF7FCFF).withValues(alpha: 0.96),
                    const Color(0xFFFFFBF5).withValues(alpha: 0.94),
                  ],
          ),
          boxShadow: [
            if (!isDarkMode)
              BoxShadow(
                color: const Color(0xFF6D7EA5).withValues(alpha: 0.10),
                blurRadius: 34,
                offset: const Offset(0, 20),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '今日学习路径',
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 23,
                          height: 1.08,
                          fontWeight: AppTypography.hero,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '清晰安排，稳步推进',
                        style: TextStyle(
                          color: bodyColor,
                          fontSize: 13,
                          fontWeight: AppTypography.emphasis,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 42,
                  height: 42,
                  child: const Center(
                    child: StudyAssetIcon(
                      asset: AppAssets.brandAppIcon,
                      preserveColor: true,
                      fallbackIcon: Icons.auto_stories_rounded,
                      size: 34,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 360,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _MobileStudyPathPainter(
                        accent: accent,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 14,
                    right: 18,
                    child: _MobilePathNodeCard(
                      isDarkMode: isDarkMode,
                      color: accent,
                      icon: Icons.auto_awesome_rounded,
                      asset: AppAssets.generatedHomeReviewIcon,
                      label: '记录',
                      caption: '回顾今天的学习',
                      trailingIcon: Icons.check_rounded,
                      onTap: onStartReview,
                    ),
                  ),
                  Positioned(
                    top: 94,
                    left: 54,
                    right: 4,
                    child: _MobilePathNodeCard(
                      isDarkMode: isDarkMode,
                      color: StudyUi.secondary,
                      icon: Icons.flag_rounded,
                      asset: AppAssets.generatedHomePlanIcon,
                      label: '行动',
                      caption: action.target == _SprintActionTarget.task
                          ? '推进今日安排'
                          : '整理下一步',
                      trailingIcon: Icons.play_arrow_rounded,
                      onTap: onActionTap ?? onStartReview,
                    ),
                  ),
                  Positioned(
                    top: 188,
                    left: 14,
                    right: 18,
                    child: _MobilePathNodeCard(
                      isDarkMode: isDarkMode,
                      color: StudyUi.success,
                      icon: Icons.style_rounded,
                      asset: AppAssets.generatedHomeFlashcardsIcon,
                      label: '复习',
                      caption: '巩固知识点',
                      trailingIcon: Icons.play_arrow_rounded,
                      onTap: onFlashcards,
                    ),
                  ),
                  Positioned(
                    top: 282,
                    left: 54,
                    right: 4,
                    child: _MobilePathNodeCard(
                      isDarkMode: isDarkMode,
                      color: StudyUi.warning,
                      icon: Icons.timeline_rounded,
                      asset: AppAssets.generatedHomeWeeklyReviewIcon,
                      label: '回顾',
                      caption: '看看最近变化',
                      trailingIcon: Icons.radio_button_unchecked_rounded,
                      onTap: onReviewPage,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MobilePathMetric(
                    isDarkMode: isDarkMode,
                    color: accent,
                    label: '今日专注时长',
                    value: _formatFocusMinutes(todayFocusMinutes),
                    caption: '目标 4h',
                    progress: focusProgress,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MobilePathMetric(
                    isDarkMode: isDarkMode,
                    color: StudyUi.warning,
                    label: '连续学习',
                    value: '$streak 天',
                    caption: streak > 0 ? '继续加油' : '今天开始',
                    trailingIcon: Icons.local_fire_department_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 42),
          ],
        ),
      ),
    );
  }
}

class _MobilePathNodeCard extends StatelessWidget {
  const _MobilePathNodeCard({
    required this.isDarkMode,
    required this.color,
    required this.icon,
    required this.asset,
    required this.label,
    required this.caption,
    required this.trailingIcon,
    required this.onTap,
  });

  final bool isDarkMode;
  final Color color;
  final IconData icon;
  final String asset;
  final String label;
  final String caption;
  final IconData trailingIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          height: 78,
          padding: const EdgeInsets.fromLTRB(64, 10, 9, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.9),
            border: Border.all(color: Colors.white.withValues(alpha: 0.74)),
            boxShadow: [
              if (!isDarkMode)
                BoxShadow(
                  color: color.withValues(alpha: 0.18),
                  blurRadius: 26,
                  offset: const Offset(0, 14),
                ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -50,
                top: 3,
                child: _PathNodeOrb(
                  icon: icon,
                  asset: asset,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 18,
                            height: 1.05,
                            fontWeight: AppTypography.title,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: bodyColor,
                            fontSize: 12,
                            height: 1.18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: StudyUi.chipBackground(color, isDarkMode),
                    ),
                    child: Icon(trailingIcon, color: color, size: 17),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PathNodeOrb extends StatelessWidget {
  const _PathNodeOrb({
    required this.icon,
    required this.asset,
  });

  final IconData icon;
  final String asset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: Center(
        child: StudyAssetIcon(
          asset: asset,
          size: 46,
          preserveColor: true,
          fallbackIcon: icon,
        ),
      ),
    );
  }
}

class _MobilePathMetric extends StatelessWidget {
  const _MobilePathMetric({
    required this.isDarkMode,
    required this.color,
    required this.label,
    required this.value,
    required this.caption,
    this.progress,
    this.trailingIcon,
  });

  final bool isDarkMode;
  final Color color;
  final String label;
  final String value;
  final String caption;
  final double? progress;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      padding: const EdgeInsets.fromLTRB(11, 11, 10, 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.white.withValues(alpha: 0.88),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.10)
              : color.withValues(alpha: 0.14),
        ),
        boxShadow: [
          if (!isDarkMode)
            BoxShadow(
              color: const Color(0xFF17203A).withValues(alpha: 0.07),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: StudyUi.title(isDarkMode),
                    fontSize: 11,
                    height: 1,
                    fontWeight: AppTypography.title,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: 24,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      maxLines: 1,
                      style: TextStyle(
                        color: StudyUi.title(isDarkMode),
                        fontSize: 22,
                        height: 1,
                        fontWeight: AppTypography.hero,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: StudyUi.body(isDarkMode),
                    fontSize: 11,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          if (progress != null) ...[
            const SizedBox(width: 6),
            _MiniProgressRing(
              progress: progress!.clamp(0.0, 1.0).toDouble(),
              color: color,
              isDarkMode: isDarkMode,
            ),
          ] else if (trailingIcon != null) ...[
            const SizedBox(width: 8),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: StudyUi.chipBackground(color, isDarkMode),
              ),
              child: Icon(
                trailingIcon,
                color: color,
                size: 23,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniProgressRing extends StatelessWidget {
  const _MiniProgressRing({
    required this.progress,
    required this.color,
    required this.isDarkMode,
  });

  final double progress;
  final Color color;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: CustomPaint(
        painter: _MiniProgressRingPainter(
          progress: progress,
          color: color,
          isDarkMode: isDarkMode,
        ),
        child: Center(
          child: Text(
            '${(progress * 100).round()}%',
            style: TextStyle(
              color: color,
              fontSize: 10,
              height: 1,
              fontWeight: AppTypography.title,
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniProgressRingPainter extends CustomPainter {
  const _MiniProgressRingPainter({
    required this.progress,
    required this.color,
    required this.isDarkMode,
  });

  final double progress;
  final Color color;
  final bool isDarkMode;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = 5.0;
    final base = Paint()
      ..color = color.withValues(alpha: isDarkMode ? 0.18 : 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final active = Paint()
      ..color = color.withValues(alpha: 0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final insetRect = rect.deflate(stroke / 2);
    canvas.drawArc(insetRect, -math.pi / 2, math.pi * 2, false, base);
    canvas.drawArc(
      insetRect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      active,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.isDarkMode != isDarkMode;
}

class _MobileStudyPathPainter extends CustomPainter {
  const _MobileStudyPathPainter({
    required this.accent,
    required this.isDarkMode,
  });

  final Color accent;
  final bool isDarkMode;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.22, 44)
      ..cubicTo(
        size.width * 0.18,
        96,
        size.width * 0.76,
        78,
        size.width * 0.68,
        136,
      )
      ..cubicTo(
        size.width * 0.56,
        204,
        size.width * 0.18,
        180,
        size.width * 0.25,
        246,
      )
      ..cubicTo(
        size.width * 0.32,
        304,
        size.width * 0.68,
        276,
        size.width * 0.62,
        330,
      );

    final glowPaint = Paint()
      ..color = accent.withValues(alpha: isDarkMode ? 0.13 : 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, glowPaint);

    final linePaint = Paint()
      ..color = accent.withValues(alpha: isDarkMode ? 0.46 : 0.34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: isDarkMode ? 0.48 : 0.92)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = accent.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final point in [
      Offset(size.width * 0.22, 44),
      Offset(size.width * 0.68, 136),
      Offset(size.width * 0.25, 246),
      Offset(size.width * 0.62, 330),
    ]) {
      canvas.drawCircle(point, 9, dotPaint);
      canvas.drawCircle(point, 9, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MobileStudyPathPainter oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.isDarkMode != isDarkMode;
}

class _TodayPathFocusCard extends StatelessWidget {
  const _TodayPathFocusCard({
    required this.isDarkMode,
    required this.accent,
    required this.action,
  });

  final bool isDarkMode;
  final Color accent;
  final _SprintAction action;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent.withValues(alpha: isDarkMode ? 0.24 : 0.18),
        ),
        boxShadow: [
          if (!isDarkMode)
            BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: StudyUi.chipBackground(accent, isDarkMode),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accent.withValues(alpha: 0.28),
                  ),
                ),
                child: Icon(Icons.flag_rounded, color: accent, size: 18),
              ),
              Container(
                width: 2,
                height: 52,
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      accent.withValues(alpha: 0.48),
                      StudyUi.warning.withValues(alpha: 0.18),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BadgePill(
                  label: '今日下一步',
                  background: StudyUi.chipBackground(accent, isDarkMode),
                  foreground: accent,
                ),
                const SizedBox(height: 9),
                Text(
                  action.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 17,
                    height: 1.25,
                    fontWeight: AppTypography.title,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  action.reason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: bodyColor, height: 1.38),
                ),
                const SizedBox(height: 8),
                Text(
                  action.expectedGain,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: AppTypography.emphasis,
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

class _HeroTextAction extends StatelessWidget {
  const _HeroTextAction({
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: StudyUi.chipBackground(color, isDarkMode),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: AppTypography.title,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeIconAction extends StatelessWidget {
  const _HomeIconAction({
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
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 34,
        height: 34,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: disabled ? null : onPressed,
            child: Ink(
              decoration: BoxDecoration(
                color: StudyUi.chipBackground(color, isDarkMode),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: color.withValues(alpha: disabled ? 0.08 : 0.18),
                ),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 17,
                  color: disabled ? StudyUi.muted(isDarkMode) : color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _HomeLearningFlowStrip extends StatelessWidget {
  const _HomeLearningFlowStrip({
    required this.isDarkMode,
    required this.accent,
    required this.onReview,
    required this.onAction,
    required this.onFlashcards,
    required this.onReviewPage,
  });

  final bool isDarkMode;
  final Color accent;
  final VoidCallback? onReview;
  final VoidCallback? onAction;
  final VoidCallback? onFlashcards;
  final VoidCallback? onReviewPage;

  @override
  Widget build(BuildContext context) {
    final steps = [
      _HomeFlowStep(
        icon: Icons.edit_note_rounded,
        asset: AppAssets.generatedHomeReviewIcon,
        label: '记录',
        caption: '2 分钟',
        onTap: onReview,
      ),
      _HomeFlowStep(
        icon: Icons.flag_rounded,
        asset: AppAssets.generatedHomePlanIcon,
        label: '行动',
        caption: '先做一步',
        onTap: onAction,
      ),
      _HomeFlowStep(
        icon: Icons.style_rounded,
        asset: AppAssets.generatedHomeFlashcardsIcon,
        label: '复习',
        caption: '闪卡',
        onTap: onFlashcards,
      ),
      _HomeFlowStep(
        icon: Icons.timeline_rounded,
        asset: AppAssets.generatedHomeWeeklyReviewIcon,
        label: '回顾',
        caption: '看变化',
        onTap: onReviewPage,
      ),
    ];
    return StudyCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      color: isDarkMode
          ? StudyUi.surface(isDarkMode)
          : Colors.white.withValues(alpha: 0.9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '今天这样走',
            style: TextStyle(
              color: StudyUi.title(isDarkMode),
              fontWeight: AppTypography.title,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 96,
            child: Stack(
              children: [
                Positioned(
                  left: 26,
                  right: 26,
                  top: 28,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        colors: [
                          accent.withValues(alpha: 0.52),
                          StudyUi.secondary.withValues(alpha: 0.34),
                          StudyUi.warning.withValues(alpha: 0.28),
                        ],
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < steps.length; i++)
                      Expanded(
                        child: _HomeFlowStepTile(
                          step: steps[i],
                          accent: _flowAccent(i, accent),
                          isDarkMode: isDarkMode,
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

  Color _flowAccent(int index, Color fallback) {
    return switch (index) {
      0 => fallback,
      1 => StudyUi.success,
      2 => StudyUi.warning,
      _ => StudyUi.secondary,
    };
  }
}

class _HomeFlowStep {
  const _HomeFlowStep({
    required this.icon,
    required this.asset,
    required this.label,
    required this.caption,
    this.onTap,
  });

  final IconData icon;
  final String asset;
  final String label;
  final String caption;
  final VoidCallback? onTap;
}

class _HomeFlowStepTile extends StatelessWidget {
  const _HomeFlowStepTile({
    required this.step,
    required this.accent,
    required this.isDarkMode,
  });

  final _HomeFlowStep step;
  final Color accent;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: step.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 42,
              height: 42,
              child: Center(
                child: StudyAssetIcon(
                  asset: step.asset,
                  size: 34,
                  preserveColor: true,
                  fallbackIcon: step.icon,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              step.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: titleColor,
                fontWeight: AppTypography.title,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              step.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: bodyColor, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _SprintMetric extends StatelessWidget {
  const _SprintMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.isDarkMode,
  });

  final String label;
  final String value;
  final Color color;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: StudyUi.chipBackground(color, isDarkMode),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTypography.sans,
              fontFamilyFallback: AppTypography.fontFallbacks,
              color: color,
              fontSize: 17,
              fontWeight: AppTypography.hero,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTypography.sans,
              fontFamilyFallback: AppTypography.fontFallbacks,
              color: StudyUi.body(isDarkMode),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeRiveBackground extends StatelessWidget {
  const _HomeRiveBackground({required this.isDarkMode});

  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color:
                isDarkMode ? const Color(0xFF101625) : const Color(0xFFEAF2FF),
          ),
        ),
        Positioned(
          width: screenSize.width * 2.05,
          left: -screenSize.width * 0.52,
          top: -screenSize.height * 0.10,
          child: IgnorePointer(
            child: Opacity(
              opacity: isDarkMode ? 0.42 : 0.44,
              child: Image.asset(
                AppAssets.spline,
                fit: BoxFit.fitWidth,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: Opacity(
                opacity: isDarkMode ? 0.34 : 0.18,
                child: const SafeRiveAsset(
                  asset: AppAssets.shapes,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDarkMode
                      ? [
                          const Color(0xFF101625).withValues(alpha: 0.16),
                          const Color(0xFF0A0F1C).withValues(alpha: 0.36),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.42),
                          const Color(0xFFF1F6FF).withValues(alpha: 0.72),
                        ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.isDarkMode,
    required this.child,
    this.height,
    this.padding,
    this.radius = 26,
  });

  final bool isDarkMode;
  final Widget child;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: height,
          padding: padding,
          decoration: _softCardDecoration(isDarkMode, radius: radius),
          child: child,
        ),
      ),
    );
  }
}

class _HomeAnimatedIcon extends StatelessWidget {
  const _HomeAnimatedIcon({
    required this.asset,
    required this.size,
  });

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        Icons.auto_awesome_rounded,
        size: size * 0.62,
        color: StudyUi.primary,
      ),
    );
  }
}

// ignore: unused_element
class _HomeTabs extends StatelessWidget {
  const _HomeTabs({required this.isDarkMode});

  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final inactive = isDarkMode ? Colors.white54 : AppColors.muted;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '推荐',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : AppColors.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                width: 22,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF238BFF),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
          const SizedBox(width: 28),
          Text(
            '本周回顾',
            style: TextStyle(
              color: inactive,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 24),
          Text(
            '小组学习',
            style: TextStyle(
              color: inactive,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.title,
    required this.subtitle,
    required this.asset,
    required this.isDarkMode,
    // ignore: unused_element_parameter
    this.buttonLabel,
    // ignore: unused_element_parameter
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String asset;
  final String? buttonLabel;
  final bool isDarkMode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: _GlassCard(
        isDarkMode: isDarkMode,
        height: 176,
        padding: const EdgeInsets.all(16),
        radius: 24,
        child: Stack(
          children: [
            Positioned(
              right: -12,
              bottom: -12,
              child: _HomeAnimatedIcon(asset: asset, size: 92),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : AppColors.ink,
                    fontSize: 17,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white54 : AppColors.muted,
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (buttonLabel != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1687FF), Color(0xFF296DFF)],
                      ),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x221687FF),
                          blurRadius: 14,
                          offset: Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Text(
                      buttonLabel!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
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

// ignore: unused_element
class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({
    required this.isDarkMode,
    required this.accent,
    required this.completedTasks,
    required this.totalTasks,
    required this.progress,
    required this.streak,
  });

  final bool isDarkMode;
  final Color accent;
  final int completedTasks;
  final int totalTasks;
  final double progress;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      isDarkMode: isDarkMode,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.white.withValues(alpha: 0.34),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: const StudyAssetIcon(
                    asset: AppAssets.featureTaskPlanIcon,
                    size: 48,
                    color: StudyUi.warning,
                    fallbackIcon: Icons.local_fire_department_rounded,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '连续学习 $streak 天',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : AppColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      totalTasks > 0
                          ? '任务进度 $completedTasks / $totalTasks'
                          : '还没有学习任务',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white54 : AppColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                totalTasks > 0 ? '${(progress * 100).toInt()}%' : '0%',
                style: TextStyle(
                  color: accent,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
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
    );
  }
}

class _RecentLogCard extends StatelessWidget {
  const _RecentLogCard({
    required this.courseName,
    required this.content,
    required this.date,
    required this.isDarkMode,
  });

  final String courseName;
  final String content;
  final String date;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      isDarkMode: isDarkMode,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            height: 50,
            child: Center(
              child: _HomeAnimatedIcon(
                asset: AppAssets.generatedHomeNotesIcon,
                size: 48,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  courseName,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : AppColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white54 : AppColors.body,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            date,
            style: TextStyle(
              color: isDarkMode ? Colors.white38 : AppColors.muted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRecentCard extends StatelessWidget {
  const _EmptyRecentCard({
    required this.isDarkMode,
    required this.onStartReview,
    required this.onOpenLogs,
  });

  final bool isDarkMode;
  final VoidCallback? onStartReview;
  final VoidCallback? onOpenLogs;

  @override
  Widget build(BuildContext context) {
    final titleColor = isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor = isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;

    return _GlassCard(
      isDarkMode: isDarkMode,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '先留下一条今天的学习记录',
            style: TextStyle(
              color: titleColor,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '写下学了什么、卡在哪里、下一步做什么，后面回顾会更清楚。',
            style: TextStyle(color: bodyColor, height: 1.55),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              StudyActionPill(
                icon: Icons.edit_note_rounded,
                label: '开始 2 分钟记录',
                color: AppColors.studyPrimary,
                isDarkMode: isDarkMode,
                onPressed: onStartReview,
              ),
              StudyActionPill(
                icon: Icons.history_rounded,
                label: '查看全部记录',
                color: StudyUi.pathBlue,
                isDarkMode: isDarkMode,
                onPressed: onOpenLogs,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

BoxDecoration _softCardDecoration(bool isDarkMode, {double radius = 26}) {
  return BoxDecoration(
    color: isDarkMode
        ? const Color(0xFF242B37).withValues(alpha: 0.72)
        : Colors.white.withValues(alpha: 0.26),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: isDarkMode
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.36),
    ),
    boxShadow: isDarkMode
        ? null
        : const [
            BoxShadow(
              color: Color(0x0F123C78),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
            BoxShadow(
              color: Color(0xFFFFFFFF),
              blurRadius: 1,
              offset: Offset(0, -1),
            ),
          ],
  );
}

String _fmtDate(DateTime date) {
  return '${date.month}/${date.day}';
}

enum _AiCreateSource { voice, photo }

enum _AiCreateMode { log, task }

class _AiCreateInput extends StatefulWidget {
  const _AiCreateInput({
    required this.source,
    required this.isDarkMode,
    required this.controller,
    this.onOpenLearningCockpit,
  });

  final _AiCreateSource source;
  final bool isDarkMode;
  final AppDataController controller;
  final VoidCallback? onOpenLearningCockpit;

  @override
  State<_AiCreateInput> createState() => _AiCreateInputState();
}

class _AiCreateInputState extends State<_AiCreateInput> {
  final _inputController = TextEditingController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  late final OcrService _ocrService;

  _AiCreateMode _mode = _AiCreateMode.log;
  bool _isListening = false;
  bool _isProcessing = false;
  bool _didAutoPick = false;
  String? _recordingPath;
  String _statusText = '';

  bool get _isPhoto => widget.source == _AiCreateSource.photo;

  @override
  void initState() {
    super.initState();
    _ocrService = widget.controller.createOcrService();
    if (_isPhoto) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pickPhoto());
    }
  }

  Future<void> _toggleSpeech() async {
    if (_isListening) {
      final path = await _audioRecorder.stop();
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _isProcessing = true;
        _statusText = '正在识别语音...';
      });
      try {
        final audioPath = path ?? _recordingPath;
        if (audioPath == null || audioPath.isEmpty) {
          setState(() {
            _isProcessing = false;
            _statusText = '没有获取到录音，可手动输入内容';
          });
          return;
        }
        final text = await widget.controller.cloudSpeechService
            .transcribeBytes(
              await XFile(audioPath).readAsBytes(),
              mimeType: 'audio/m4a',
              longForm: true,
            )
            .then((value) => value.trim());
        if (!mounted) return;
        setState(() {
          _isProcessing = false;
          if (text.isNotEmpty) {
            _inputController.text = text;
            _inputController.selection = TextSelection.collapsed(
              offset: _inputController.text.length,
            );
            _statusText = '语音已识别，可继续编辑';
          } else {
            _statusText = '没有识别到语音内容，可手动输入';
          }
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _isProcessing = false;
          _statusText = '语音识别失败，可手动输入内容';
        });
      } finally {
        _recordingPath = null;
      }
      return;
    }
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (mounted) setState(() => _statusText = '未获得麦克风权限，可手动输入内容');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/studytrace_home_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          bitRate: 64000,
        ),
        path: path,
      );
      setState(() {
        _isListening = true;
        _recordingPath = path;
        _statusText = '正在录音，完成后点停止识别';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isListening = false;
          _recordingPath = null;
          _statusText = '语音录制暂时不可用，可手动输入内容';
        });
      }
    }
  }

  Future<void> _pickPhoto() async {
    if (_didAutoPick && _inputController.text.trim().isNotEmpty) return;
    _didAutoPick = true;
    try {
      setState(() => _statusText = '正在读取图片...');
      final text = (await _ocrService.captureAndRecognize(
            onStatus: (status) {
              if (mounted) setState(() => _statusText = status);
            },
          ))
              ?.trim() ??
          '';
      if (!mounted) return;
      setState(() {
        _inputController.text = text;
        _inputController.selection = TextSelection.collapsed(
          offset: _inputController.text.length,
        );
        _statusText = text.isEmpty ? '未识别到文字，可手动输入描述' : '已识别图片文字';
      });
    } on PlatformException {
      if (mounted) {
        setState(() => _statusText = '图片识别失败，可手动输入描述');
      }
    } catch (_) {
      if (mounted) setState(() => _statusText = '图片识别失败，可手动输入描述');
    }
  }

  Future<void> _pickLocalPhoto() async {
    try {
      setState(() => _statusText = '正在读取本地图片...');
      final text = (await _ocrService.pickAndRecognize(
            onStatus: (status) {
              if (mounted) setState(() => _statusText = status);
            },
          ))
              ?.trim() ??
          '';
      if (!mounted) return;
      setState(() {
        _inputController.text = text;
        _inputController.selection = TextSelection.collapsed(
          offset: _inputController.text.length,
        );
        _statusText = text.isEmpty ? '未识别到文字，可手动输入描述' : '已识别本地图片文字';
      });
    } on PlatformException {
      if (mounted) {
        setState(() => _statusText = '本地图片识别失败，可手动输入描述');
      }
    } catch (_) {
      if (mounted) setState(() => _statusText = '本地图片识别失败，可手动输入描述');
    }
  }

  void _openLearningCockpit() {
    final action = widget.onOpenLearningCockpit;
    if (action == null) return;
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) => action());
  }

  Future<void> _submit() async {
    final input = _inputController.text.trim();
    if (input.isEmpty || _isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      if (_mode == _AiCreateMode.log) {
        final log =
            await widget.controller.aiStudyService.generateStudyLog(input);
        await widget.controller.addStudyLog(
          date: DateTime.now(),
          courseName: log.courseName,
          content: log.content.isNotEmpty ? log.content : input,
          problems: log.problems,
          thoughts: log.thoughts,
          nextPlan: log.nextPlan,
        );
      } else {
        final plan =
            await widget.controller.aiStudyService.generateTaskPlan(input);
        final now = DateTime.now();
        final planned = plan.plannedSubTasks.isNotEmpty
            ? plan.plannedSubTasks
                .map((p) => StudySubTaskItem(
                      id: 'sub_ai_${now.microsecondsSinceEpoch}_${plan.plannedSubTasks.indexOf(p)}',
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
                      id: 'sub_ai_${now.microsecondsSinceEpoch}_${plan.subTasks.indexOf(s)}',
                      title: s,
                      deadline: plan.deadline,
                      createdAt: now,
                      updatedAt: now,
                    ))
                .toList();
        await widget.controller.addStudyTask(
          title: plan.mainTitle.isNotEmpty ? plan.mainTitle : input,
          type: plan.taskType,
          courseName: plan.courseName,
          deadline: plan.deadline,
          subTasks: planned,
          note: _isPhoto ? '已通过拍照创建' : '已通过语音创建',
        );
      }
      if (!mounted) return;
      StudyToast.show(
        context,
        _mode == _AiCreateMode.log ? '学习记录已保存' : '学习任务已创建',
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _statusText = '这次没有整理成功，内容还在，可以稍后再试';
      });
    }
  }

  @override
  void dispose() {
    unawaited(_audioRecorder.dispose());
    _ocrService.dispose();
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.controller.primaryColor;
    final textColor = StudyUi.title(widget.isDarkMode);
    final bodyColor = StudyUi.body(widget.isDarkMode);
    final title = _isPhoto ? '拍照创建' : '语音创建';
    final actionLabel = _mode == _AiCreateMode.log ? '整理学习记录' : '整理学习任务';

    return Scaffold(
      backgroundColor:
          widget.isDarkMode ? const Color(0xFF141923) : const Color(0xFFF5F7FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        title:
            Text(title, style: const TextStyle(fontWeight: AppTypography.hero)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 36),
        children: [
          StudyCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                StudyGlassIconNode(
                  icon: _isPhoto
                      ? Icons.photo_library_rounded
                      : Icons.graphic_eq_rounded,
                  accent: accent,
                  size: 40,
                  iconSize: 18,
                  isDarkMode: widget.isDarkMode,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isPhoto
                        ? '多张图片、语音和文字一起整理时，可以进入学习整理台。'
                        : '长语音、图片和文字一起整理时，可以进入学习整理台。',
                    style:
                        TextStyle(color: bodyColor, fontSize: 13, height: 1.35),
                  ),
                ),
                const SizedBox(width: 10),
                StudyActionPill(
                  icon: Icons.open_in_new_rounded,
                  label: '整理台',
                  color: accent,
                  isDarkMode: widget.isDarkMode,
                  filled: false,
                  onPressed: widget.onOpenLearningCockpit == null
                      ? null
                      : _openLearningCockpit,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _CreateModeToggle(
            isDarkMode: widget.isDarkMode,
            mode: _mode,
            onChanged: (mode) => setState(() => _mode = mode),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _inputController,
            minLines: 6,
            maxLines: 9,
            style: TextStyle(color: textColor, fontSize: 15, height: 1.45),
            decoration: InputDecoration(
              hintText: _isPhoto
                  ? '拍照识别后会填入这里，也可以手动描述图片内容...'
                  : '点击麦克风说出学习记录或任务，也可以手动输入...',
              hintStyle: TextStyle(color: bodyColor.withValues(alpha: 0.62)),
              filled: true,
              fillColor: StudyUi.surfaceAlt(widget.isDarkMode).withValues(
                alpha: widget.isDarkMode ? 0.72 : 0.88,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide:
                    BorderSide(color: StudyUi.border(widget.isDarkMode)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide:
                    BorderSide(color: StudyUi.border(widget.isDarkMode)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(color: accent.withValues(alpha: 0.50)),
              ),
              contentPadding: const EdgeInsets.all(18),
            ),
          ),
          if (_statusText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(_statusText, style: TextStyle(color: bodyColor, fontSize: 12)),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              if (_isPhoto)
                Expanded(
                  child: StudyActionPill(
                    icon: Icons.photo_camera_rounded,
                    label: '重新拍照',
                    color: accent,
                    isDarkMode: widget.isDarkMode,
                    filled: false,
                    expand: true,
                    onPressed: _isProcessing ? null : _pickPhoto,
                  ),
                )
              else
                Expanded(
                  child: StudyActionPill(
                    icon: _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                    label: _isListening ? '停止识别' : '开始录音',
                    color: accent,
                    isDarkMode: widget.isDarkMode,
                    filled: false,
                    expand: true,
                    onPressed: _isProcessing ? null : _toggleSpeech,
                  ),
                ),
              const SizedBox(width: 12),
              if (_isPhoto) ...[
                Expanded(
                  child: StudyActionPill(
                    icon: Icons.photo_library_rounded,
                    label: '本地图片',
                    color: StudyUi.pathMint,
                    isDarkMode: widget.isDarkMode,
                    filled: false,
                    expand: true,
                    onPressed: _isProcessing ? null : _pickLocalPhoto,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: StudyActionPill(
                  icon: Icons.auto_awesome_rounded,
                  label: _isProcessing ? '整理中...' : actionLabel,
                  color: accent,
                  isDarkMode: widget.isDarkMode,
                  expand: true,
                  onPressed: _isProcessing || _isListening ? null : _submit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreateModeToggle extends StatelessWidget {
  const _CreateModeToggle({
    required this.isDarkMode,
    required this.mode,
    required this.onChanged,
  });

  final bool isDarkMode;
  final _AiCreateMode mode;
  final ValueChanged<_AiCreateMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _modeButton('学习记录', _AiCreateMode.log),
          _modeButton('学习任务', _AiCreateMode.task),
        ],
      ),
    );
  }

  Widget _modeButton(String label, _AiCreateMode value) {
    final selected = mode == value;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF238BFF) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : StudyUi.title(isDarkMode).withValues(alpha: 0.72),
              fontWeight: AppTypography.title,
            ),
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
  final _manualController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _manualController.addListener(_handleManualInputChanged);
    _initSpeech();
  }

  void _handleManualInputChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onError: (err) {
          if (mounted) {
            setState(() {
              _isInitialized = false;
              _speechError = '当前设备暂时不可用语音输入，可手动输入任务';
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
            _speechError = '当前设备暂时不可用语音输入，可手动输入任务';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitialized = false;
          _speechError = '当前设备暂时不可用语音输入，可手动输入任务';
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
        await StudyToast.dialog(
          context,
          title: '语音不可用',
          message: '未找到可用的语音语言包',
        );
      }
      return;
    }
    setState(() {
      _isListening = true;
      _recognizedText = '';
    });
    try {
      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() => _recognizedText = result.recognizedWords);
          }
        },
        localeId: locale,
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _speechError = '语音识别不可用，可手动输入任务';
      });
      await StudyToast.dialog(
        context,
        title: '语音识别失败',
        message: '这次没有听清，可以手动输入任务内容。',
      );
    }
  }

  Future<void> _stopListening() async {
    try {
      await _speech.stop();
    } catch (_) {}
    if (mounted) setState(() => _isListening = false);
  }

  Future<void> _createTaskFromInput(String text) async {
    if (text.trim().isEmpty) return;
    setState(() => _isProcessing = true);

    try {
      final plan =
          await widget.controller.aiStudyService.generateTaskPlan(text);
      final now = DateTime.now();
      final subTasks = plan.plannedSubTasks.isNotEmpty
          ? plan.plannedSubTasks
              .map((p) => StudySubTaskItem(
                    id: 'sub_v_${now.microsecondsSinceEpoch}_${plan.plannedSubTasks.indexOf(p)}',
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
                    id: 'sub_v_${now.microsecondsSinceEpoch}_${plan.subTasks.indexOf(s)}',
                    title: s,
                    deadline: plan.deadline,
                    createdAt: now,
                    updatedAt: now,
                  ))
              .toList();
      await widget.controller.addStudyTask(
        title: plan.mainTitle.trim().isNotEmpty ? plan.mainTitle : text.trim(),
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
      StudyToast.show(context, '任务已创建');
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _manualController.removeListener(_handleManualInputChanged);
    _manualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.controller.primaryColor;
    final textColor = StudyUi.title(widget.isDarkMode);
    final bodyColor = StudyUi.body(widget.isDarkMode);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor:
          widget.isDarkMode ? const Color(0xFF141923) : const Color(0xFFF5F7FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        title: const Text('快速创建任务',
            style: TextStyle(fontWeight: AppTypography.hero)),
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
              hintText: '输入任务描述，我来帮你拆成几步...',
              hintStyle: TextStyle(
                color: StudyUi.muted(widget.isDarkMode),
              ),
              filled: true,
              fillColor: StudyUi.surfaceAlt(widget.isDarkMode).withValues(
                alpha: widget.isDarkMode ? 0.72 : 0.88,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    BorderSide(color: StudyUi.border(widget.isDarkMode)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    BorderSide(color: StudyUi.border(widget.isDarkMode)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: accent.withValues(alpha: 0.50)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_manualController.text.isNotEmpty)
            StudyActionPill(
              icon: Icons.auto_awesome_rounded,
              label: _isProcessing ? '创建中...' : '创建任务',
              color: accent,
              isDarkMode: widget.isDarkMode,
              expand: true,
              onPressed: _isProcessing
                  ? null
                  : () => _createTaskFromInput(_manualController.text),
            ),
          const SizedBox(height: 24),

          // Voice section (secondary — requires Google Play Services)
          if (_isCheckingSpeech)
            const SizedBox.shrink()
          else if (_speechError.isNotEmpty) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                '语音输入暂不可用',
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
                      _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
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
              StudyActionPill(
                icon: Icons.task_alt_rounded,
                label: _isProcessing ? '创建中...' : '创建任务',
                color: accent,
                isDarkMode: widget.isDarkMode,
                expand: true,
                onPressed: _isProcessing
                    ? null
                    : () => _createTaskFromInput(_recognizedText),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ── Home 顶部学习建议卡 ──
// 首次渲染异步读取缓存；过期 / 无缓存时生成一条下一步建议。
class _HomeAiSuggestion extends StatefulWidget {
  const _HomeAiSuggestion({
    required this.isDarkMode,
    required this.controller,
    this.onOpenAssistant,
    this.onOpenTasks,
    this.onOpenTimer,
  });

  final bool isDarkMode;
  final AppDataController controller;
  final VoidCallback? onOpenAssistant;
  final VoidCallback? onOpenTasks;
  final VoidCallback? onOpenTimer;

  @override
  State<_HomeAiSuggestion> createState() => _HomeAiSuggestionState();
}

class _HomeAiSuggestionState extends State<_HomeAiSuggestion> {
  static const _cacheKey = 'home_ai_suggestion_v1';
  static const _cacheDuration = Duration(minutes: 30);
  final _storage = LocalStorageService();

  String? _text;
  String? _errorText;
  bool _loading = false;
  bool _dismissed = false;
  bool _hasError = false;
  bool _usingLocalFallback = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOrFetch());
  }

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    // 在缓存里记一下 dismissed，缓存过期前不再打扰用户
    try {
      await _storage.setString(
        _cacheKey,
        jsonEncode({
          'savedAt': DateTime.now().toIso8601String(),
          'text': _text ?? '',
          'dismissed': true,
        }),
      );
    } catch (_) {}
  }

  Future<void> _loadOrFetch({bool force = false}) async {
    if (_dismissed) return;
    final storage = _storage;
    if (!force) {
      // 读缓存
      try {
        final raw = await storage.getString(_cacheKey);
        if (raw != null && raw.isNotEmpty) {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          final savedAt =
              DateTime.tryParse(decoded['savedAt'] as String? ?? '');
          final text = decoded['text'] as String? ?? '';
          final dismissed = decoded['dismissed'] as bool? ?? false;
          if (savedAt != null &&
              text.isNotEmpty &&
              !_isStaleUnavailableSuggestion(text) &&
              DateTime.now().difference(savedAt) < _cacheDuration) {
            if (mounted) {
              setState(() {
                _text = text;
                _dismissed = dismissed;
                _hasError = false;
                _errorText = null;
                _usingLocalFallback = false;
              });
            }
            return;
          }
        }
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _loading = true;
      _hasError = false;
      _errorText = null;
      _usingLocalFallback = false;
    });
    try {
      await _waitForControllerLoaded();
      if (!mounted) return;
      final tasks = widget.controller.studyTasks;
      final logs = widget.controller.studyLogs;
      if (tasks.isEmpty && logs.isEmpty) {
        if (mounted) {
          setState(() {
            _loading = false;
            _text = '还没记录学习数据，先开始 2 分钟学习记录吧。';
            _hasError = false;
            _errorText = null;
            _usingLocalFallback = false;
          });
        }
        return;
      }
      if (!force) {
        final localText = _buildLocalSuggestion(tasks, logs);
        await storage.setString(
          _cacheKey,
          jsonEncode({
            'savedAt': DateTime.now().toIso8601String(),
            'text': localText,
            'source': 'local',
          }),
        );
        if (mounted) {
          setState(() {
            _loading = false;
            _text = localText;
            _hasError = false;
            _errorText = null;
            _usingLocalFallback = true;
          });
        }
        return;
      }
      final aiService = widget.controller.aiStudyService;
      final warnings = await aiService.generateRiskWarnings(
        logs: logs,
        tasks: tasks,
      );
      String text;
      if (warnings.isEmpty) {
        text = '当前学习节奏比较稳，继续保持就好。';
      } else {
        final first = warnings.first;
        final buf = StringBuffer();
        if (first.title.isNotEmpty) buf.write(first.title);
        if (first.description.isNotEmpty) {
          if (buf.isNotEmpty) buf.write('：');
          buf.write(first.description);
        }
        text = buf.toString();
      }
      await storage.setString(
        _cacheKey,
        jsonEncode({
          'savedAt': DateTime.now().toIso8601String(),
          'text': text,
        }),
      );
      if (mounted) {
        setState(() {
          _text = text;
          _loading = false;
          _hasError = false;
          _errorText = null;
          _usingLocalFallback = false;
        });
      }
    } on AiServiceException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _hasError = true;
          _errorText = _friendlyAiSuggestionError(error.message);
          _usingLocalFallback = true;
          _text = _buildLocalSuggestion(
            widget.controller.studyTasks,
            widget.controller.studyLogs,
          );
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _hasError = true;
          _errorText = _friendlyAiSuggestionError(error.toString());
          _usingLocalFallback = true;
          _text = _buildLocalSuggestion(
            widget.controller.studyTasks,
            widget.controller.studyLogs,
          );
        });
      }
    }
  }

  bool _isStaleUnavailableSuggestion(String text) {
    final source = text.trim();
    if (source.isEmpty) return true;
    return source.contains('暂时无法获取') ||
        source.contains('暂不可用') ||
        source.contains('不可用') ||
        source.contains('无法获取') ||
        source.contains('请求失败') ||
        source.contains('生成失败') ||
        source.contains('暂时没有生成');
  }

  Future<void> _waitForControllerLoaded() async {
    if (widget.controller.isLoaded) return;
    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted || widget.controller.isLoaded) return;
    }
  }

  String _buildLocalSuggestion(
    List<StudyTaskItem> tasks,
    List<StudyLogItem> logs,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final pending = tasks
        .where((task) => task.effectiveStatus != StudyTaskStatus.completed)
        .toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));

    final overdue = pending.where((task) => task.deadline.isBefore(today));
    if (overdue.isNotEmpty) {
      final task = overdue.first;
      return '有 ${overdue.length} 项任务已过截止时间，先处理「${_taskTitle(task)}」，拆成 25 分钟一段来推进。';
    }

    final dueToday = pending.where((task) => _isSameDay(task.deadline, now));
    if (dueToday.isNotEmpty) {
      final task = dueToday.first;
      return '「${_taskTitle(task)}」今天截止，建议先完成一个 25 分钟核心步骤，再补充细节。';
    }

    final dueSoon = pending.where((task) {
      final diff = task.deadline.difference(now);
      return !diff.isNegative && diff.inHours <= 48;
    });
    if (dueSoon.isNotEmpty) {
      final task = dueSoon.first;
      return '「${_taskTitle(task)}」将在 48 小时内截止，今天先安排一个专注计时，减少临近截止的压力。';
    }

    if (logs.isEmpty) {
      return '还没有学习日志，先写一条今天学了什么、卡在哪里、下一步做什么，后续助手才能给出更准建议。';
    }

    final latestLog = logs.reduce(
      (a, b) => a.date.isAfter(b.date) ? a : b,
    );
    final latestDay = DateTime(
      latestLog.date.year,
      latestLog.date.month,
      latestLog.date.day,
    );
    final gapDays = today.difference(latestDay).inDays;
    if (gapDays >= 2) {
      return '已经 $gapDays 天没有新的学习日志了，今天先补一条 3 分钟学习记录，恢复记录节奏。';
    }

    if (pending.isNotEmpty) {
      final task = pending.first;
      return '当前优先推进「${_taskTitle(task)}」，完成后再记录一次学习日志，方便回看学习进展。';
    }

    return '当前没有明显待办压力，保持学习记录和回顾节奏就很好。';
  }

  String _taskTitle(StudyTaskItem task) {
    final title = task.title.trim();
    return title.isEmpty ? '未命名任务' : title;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _friendlyAiSuggestionError(String message) {
    final source = message.trim();
    if (source.isEmpty) return '暂时没有整理出建议';
    if (source.contains('BLUEHEART_API_KEY')) {
      return '学习助手还没有准备好';
    }
    if (source.contains('BLUEHEART_APP_ID')) {
      return '学习助手还没有准备好';
    }
    if (source.contains('请先登录') ||
        source.contains('401') ||
        source.contains('登录已过期')) {
      return '登录后可以继续整理';
    }
    if (source.contains('超时')) return '整理超时';
    if (source.contains('无法连接') ||
        source.contains('网络') ||
        source.contains('SocketException')) {
      return '暂时连不上学习助手';
    }
    return '智能整理暂时不稳定';
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: const SizedBox.shrink(key: ValueKey('dismissed')),
      );
    }
    if (_text == null && !_loading && !_hasError) {
      return const SizedBox.shrink();
    }

    final accent = widget.controller.primaryColor;
    final bg = widget.isDarkMode
        ? const Color(0xFF242B37).withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.85);
    final titleColor = widget.isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor =
        widget.isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;
    final primaryAction = _suggestionPrimaryAction(_text ?? '');

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Container(
        key: ValueKey('suggestion_${_hasError}_${_text}_$_errorText'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accent.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const StudyAssetIcon(
                asset: AppAssets.aiSuggestionIcon,
                preserveColor: true,
                fallbackIcon: Icons.lightbulb_rounded,
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _usingLocalFallback ? '今日参考' : '学习建议',
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: _dismiss,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(Icons.close_rounded,
                              size: 16, color: bodyColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_loading)
                    Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: accent),
                        ),
                        const SizedBox(width: 8),
                        Text('正在看看今天适合先做什么...',
                            style: TextStyle(color: bodyColor, fontSize: 12)),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _text ?? '',
                          style: TextStyle(
                            color: bodyColor,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        if (_hasError) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '已先给你一条参考，智能整理暂时不稳定。',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: bodyColor.withValues(alpha: 0.72),
                                    fontSize: 11,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                              _HomeIconAction(
                                tooltip: '重新整理建议',
                                icon: Icons.refresh_rounded,
                                color: accent,
                                isDarkMode: widget.isDarkMode,
                                onPressed: () => _loadOrFetch(force: true),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  if (!_loading && _text != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (primaryAction != null)
                            _HeroTextAction(
                              icon: primaryAction.icon,
                              label: primaryAction.label,
                              color: primaryAction.color,
                              isDarkMode: widget.isDarkMode,
                              onTap: primaryAction.onTap,
                            ),
                          if (widget.onOpenAssistant != null &&
                              primaryAction?.onTap != widget.onOpenAssistant)
                            _HeroTextAction(
                              icon: Icons.auto_awesome_rounded,
                              label: '整理下一步',
                              color: StudyUi.secondary,
                              isDarkMode: widget.isDarkMode,
                              onTap: widget.onOpenAssistant!,
                            ),
                          _HomeIconAction(
                            tooltip: '刷新建议',
                            icon: Icons.refresh_rounded,
                            color: accent,
                            isDarkMode: widget.isDarkMode,
                            onPressed: () => _loadOrFetch(force: true),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _SuggestionAction? _suggestionPrimaryAction(String text) {
    final source = text.trim();
    if (source.contains('专注计时')) {
      final onTap = widget.onOpenTimer ?? widget.onOpenTasks;
      if (onTap == null) return null;
      return _SuggestionAction(
        label: '开始专注',
        icon: Icons.timer_rounded,
        color: StudyUi.pathBlue,
        onTap: onTap,
      );
    }
    if (source.contains('任务') ||
        source.contains('截止') ||
        source.contains('待办') ||
        source.contains('优先推进')) {
      final onTap = widget.onOpenTasks;
      if (onTap == null) return null;
      return _SuggestionAction(
        label: '处理任务',
        icon: Icons.task_alt_rounded,
        color: StudyUi.success,
        onTap: onTap,
      );
    }
    if (source.contains('学习日志') ||
        source.contains('复盘') ||
        source.contains('记录学习数据')) {
      final onTap = widget.onOpenAssistant;
      if (onTap == null) return null;
      return _SuggestionAction(
        label: '开始 2 分钟记录',
        icon: Icons.edit_note_rounded,
        color: widget.controller.primaryColor,
        onTap: onTap,
      );
    }
    final onTap = widget.onOpenAssistant;
    if (onTap == null) return null;
    return _SuggestionAction(
      label: '整理下一步',
      icon: Icons.auto_awesome_rounded,
      color: StudyUi.secondary,
      onTap: onTap,
    );
  }
}

class _SuggestionAction {
  const _SuggestionAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}
