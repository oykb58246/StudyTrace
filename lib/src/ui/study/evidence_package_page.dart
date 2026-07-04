import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/ai_action_record.dart';
import '../../models/ai_flash_card.dart';
import '../../models/learning_moment.dart';
import '../../models/study_log_item.dart';
import '../../models/study_task_item.dart';
import '../../theme/app_theme.dart';
import '../shared/common_widgets.dart';

class EvidencePackagePage extends StatelessWidget {
  const EvidencePackagePage({
    super.key,
    required this.isDarkMode,
    required this.controller,
    this.onOpenTasks,
    this.onOpenFlashCards,
    this.onOpenLearningMoments,
    this.onOpenNotes,
    this.onOpenCourse,
    this.onStartReview,
  });

  final bool isDarkMode;
  final AppDataController controller;
  final VoidCallback? onOpenTasks;
  final VoidCallback? onOpenFlashCards;
  final VoidCallback? onOpenLearningMoments;
  final VoidCallback? onOpenNotes;
  final ValueChanged<String>? onOpenCourse;
  final VoidCallback? onStartReview;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final now = DateTime.now();
        final weekStart = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 6));
        final logs = controller.studyLogs
            .where((log) => !log.date.isBefore(weekStart))
            .toList();
        final tasks = controller.studyTasks
            .where((task) => _taskTouchesWeek(task, weekStart))
            .toList();
        final cards = controller.flashCards
            .where((card) => !card.createdAt.isBefore(weekStart) ||
                (card.lastReviewedAt != null &&
                    !card.lastReviewedAt!.isBefore(weekStart)))
            .toList();
        final allActions = controller.recentActionRecords
            .where((record) => !record.createdAt.isBefore(weekStart))
            .toList();
        final focusActions = allActions.where(_isCompletedFocusAction).toList();
        final actions =
            allActions.where((record) => !_isFocusTool(record.toolId)).toList();
        final events = controller.learningTraceEvents
            .where((event) => !event.happenedAt.isBefore(weekStart))
            .toList();
        final titleColor = StudyUi.title(isDarkMode);
        final bodyColor = StudyUi.body(isDarkMode);
        final accent = controller.primaryColor;
        final totalActionUnits = tasks.fold<int>(
          0,
          (sum, task) => sum + task.totalCount,
        );
        final completedActionUnits = tasks.fold<int>(
          0,
          (sum, task) => sum + task.completedCount,
        );
        final reviewedCards = cards.where((card) => card.reviewCount > 0).length;
        final mastery = _averageMastery(cards);
        final blockers = _recentBlockers(actions, cards);
        final focusMinutes = focusActions.fold<int>(0, (sum, action) {
          final raw = action.params?['durationMinutes'];
          return sum + (raw is num ? raw.toInt() : 0);
        });

        return StudyFontScope(
          child: ListView(
            key: const Key('page_evidence_package'),
            padding: const EdgeInsets.fromLTRB(22, 54, 22, 124),
            children: [
              _WeekRangeSelector(
                isDarkMode: isDarkMode,
                accent: accent,
                start: weekStart,
                end: now,
              ),
              const SizedBox(height: 14),
              _MetricGrid(
                isDarkMode: isDarkMode,
                metrics: [
                  _EvidenceMetric(
                    '学习时长',
                    _formatDuration(focusMinutes),
                    '本周累计',
                    accent,
                    Icons.timer_rounded,
                  ),
                  _EvidenceMetric(
                    '专注次数',
                    '${focusActions.length}',
                    '完成计时',
                    StudyUi.danger,
                    Icons.track_changes_rounded,
                  ),
                  _EvidenceMetric(
                    '完成任务',
                    '$completedActionUnits',
                    totalActionUnits == 0 ? '暂无步骤' : '共 $totalActionUnits 步',
                    StudyUi.success,
                    Icons.check_box_rounded,
                  ),
                  _EvidenceMetric(
                    '复习记录',
                    '$reviewedCards',
                    cards.isEmpty ? '待创建' : '共 ${cards.length} 张',
                    StudyUi.secondary,
                    Icons.menu_book_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _TimelinePanel(
                isDarkMode: isDarkMode,
                titleColor: titleColor,
                bodyColor: bodyColor,
                events: events,
                onOpenTasks: onOpenTasks,
                onOpenFlashCards: onOpenFlashCards,
                onOpenLearningMoments: onOpenLearningMoments,
                onOpenNotes: onOpenNotes,
                onOpenCourse: onOpenCourse,
              ),
              const SizedBox(height: 14),
              _HeroEvidenceCard(
                isDarkMode: isDarkMode,
                accent: accent,
                logs: logs.length,
                actions: totalActionUnits,
                completedActions: completedActionUnits,
                reviewedCards: reviewedCards,
                mastery: mastery,
                onOpenTasks: onOpenTasks,
                onOpenFlashCards: onOpenFlashCards,
                onOpenLearningMoments: onOpenLearningMoments,
              ),
              const SizedBox(height: 14),
              _InsightCard(
                isDarkMode: isDarkMode,
                accent: accent,
                logs: logs.length,
                blockers: blockers,
                dueCards: cards.where((card) => card.isDueForReview).length,
              ),
              const SizedBox(height: 14),
              _ReviewSectionsPanel(
                isDarkMode: isDarkMode,
                titleColor: titleColor,
                bodyColor: bodyColor,
                accent: accent,
                logs: logs,
                tasks: tasks,
                focusActions: focusActions,
                cards: cards,
                actions: actions,
                onOpenLearningMoments: onOpenLearningMoments,
                onOpenTasks: onOpenTasks,
                onOpenFlashCards: onOpenFlashCards,
                onStartReview: onStartReview,
              ),
              const SizedBox(height: 14),
              _WeaknessPanel(
                isDarkMode: isDarkMode,
                titleColor: titleColor,
                bodyColor: bodyColor,
                cards: cards,
                blockers: blockers,
              ),
            ],
          ),
        );
      },
    );
  }

  int _averageMastery(List<AiFlashCard> cards) {
    final reviewed = cards.where((card) => card.reviewCount > 0).toList();
    if (reviewed.isEmpty) return 0;
    final total = reviewed.fold<int>(
      0,
      (sum, card) => sum + card.masteryPercent,
    );
    return total ~/ reviewed.length;
  }

  String _formatDuration(int minutes) {
    if (minutes <= 0) return '0 min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (hours == 0) return '$minutes min';
    if (rest == 0) return '$hours h';
    return '$hours h $rest m';
  }

  bool _taskTouchesWeek(StudyTaskItem task, DateTime weekStart) {
    if (!task.createdAt.isBefore(weekStart) ||
        !task.updatedAt.isBefore(weekStart)) {
      return true;
    }
    return task.subTasks.any((subTask) {
      final completedAt = subTask.completedAt;
      return !subTask.updatedAt.isBefore(weekStart) ||
          (completedAt != null && !completedAt.isBefore(weekStart));
    });
  }

  List<String> _recentBlockers(
    List<AiActionRecord> actions,
    List<AiFlashCard> cards,
  ) {
    final result = <String>[];
    for (final action in actions) {
      final params = action.params;
      final analysis = params?['reflectionAnalysis'];
      if (analysis is Map && analysis['blockers'] is List) {
        result.addAll(
          (analysis['blockers'] as List)
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty),
        );
      }
    }
    result.addAll(cards.expand((card) => card.weakTags));
    return result.toSet().take(5).toList();
  }

  bool _isCompletedFocusAction(AiActionRecord record) =>
      record.params?['completedFromTimer'] == true &&
      _isFocusTool(record.toolId);

  bool _isFocusTool(String toolId) =>
      toolId == 'timer.start_focus' || toolId == 'timer.start_focus_with_task';
}

class _WeekRangeSelector extends StatelessWidget {
  const _WeekRangeSelector({
    required this.isDarkMode,
    required this.accent,
    required this.start,
    required this.end,
  });

  final bool isDarkMode;
  final Color accent;
  final DateTime start;
  final DateTime end;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    return Row(
      children: [
        _WeekRoundButton(
          icon: Icons.chevron_left_rounded,
          color: accent,
          isDarkMode: isDarkMode,
          enabled: false,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDarkMode
                    ? StudyUi.border(isDarkMode)
                    : Colors.white.withValues(alpha: 0.76),
              ),
              boxShadow: [
                if (!isDarkMode)
                  BoxShadow(
                    color: const Color(0xFF63708E).withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    '${start.month}.${start.day} - ${end.month}.${end.day}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: titleColor,
                      fontWeight: AppTypography.title,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '近 7 天',
                  style: TextStyle(
                    color: bodyColor,
                    fontSize: 12,
                    fontWeight: AppTypography.emphasis,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        _WeekRoundButton(
          icon: Icons.chevron_right_rounded,
          color: accent,
          isDarkMode: isDarkMode,
          enabled: false,
        ),
      ],
    );
  }
}

class _WeekRoundButton extends StatelessWidget {
  const _WeekRoundButton({
    required this.icon,
    required this.color,
    required this.isDarkMode,
    this.enabled = true,
  });

  final IconData icon;
  final Color color;
  final bool isDarkMode;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled ? color : StudyUi.muted(isDarkMode);
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDarkMode
            ? Colors.white.withValues(alpha: enabled ? 0.07 : 0.035)
            : Colors.white.withValues(alpha: enabled ? 0.84 : 0.48),
        border: Border.all(
          color: effectiveColor.withValues(alpha: isDarkMode ? 0.16 : 0.12),
        ),
      ),
      child: Icon(icon, color: effectiveColor, size: 20),
    );
  }
}

class _ReviewSectionsPanel extends StatelessWidget {
  const _ReviewSectionsPanel({
    required this.isDarkMode,
    required this.titleColor,
    required this.bodyColor,
    required this.accent,
    required this.logs,
    required this.tasks,
    required this.focusActions,
    required this.cards,
    required this.actions,
    required this.onOpenLearningMoments,
    required this.onOpenTasks,
    required this.onOpenFlashCards,
    required this.onStartReview,
  });

  final bool isDarkMode;
  final Color titleColor;
  final Color bodyColor;
  final Color accent;
  final List<StudyLogItem> logs;
  final List<StudyTaskItem> tasks;
  final List<AiActionRecord> focusActions;
  final List<AiFlashCard> cards;
  final List<AiActionRecord> actions;
  final VoidCallback? onOpenLearningMoments;
  final VoidCallback? onOpenTasks;
  final VoidCallback? onOpenFlashCards;
  final VoidCallback? onStartReview;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '整理后的学习路径',
            style: TextStyle(
              color: titleColor,
              fontWeight: AppTypography.title,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '把最近 7 天放进复盘、行动、复习和回看，方便你快速看懂自己推进到了哪一步。',
            style: TextStyle(color: bodyColor, height: 1.4),
          ),
          const SizedBox(height: 12),
          _ReviewSectionBlock(
            isDarkMode: isDarkMode,
            icon: Icons.edit_note_rounded,
            color: accent,
            title: '复盘',
            caption: '你最近记录了什么',
            emptyText: '还没有复盘记录，先写下今天学了什么和卡在哪里。',
            emptyActionLabel: '去记录今天',
            emptyActionIcon: Icons.edit_note_rounded,
            onEmptyAction: onOpenLearningMoments,
            count: logs.length,
            items: _logItems(),
          ),
          const SizedBox(height: 10),
          _ReviewSectionBlock(
            isDarkMode: isDarkMode,
            icon: Icons.check_circle_rounded,
            color: StudyUi.success,
            title: '行动',
            caption: '任务、下一步和专注推进情况',
            emptyText: '暂无行动进展。保存下一步、完成任务或专注后会出现在这里。',
            emptyActionLabel: '打开任务清单',
            emptyActionIcon: Icons.checklist_rounded,
            onEmptyAction: onOpenTasks,
            count: tasks.length + focusActions.length,
            items: _taskItems(),
          ),
          const SizedBox(height: 10),
          _ReviewSectionBlock(
            isDarkMode: isDarkMode,
            icon: Icons.style_rounded,
            color: StudyUi.warning,
            title: '复习',
            caption: '闪卡熟悉度和下次复习',
            emptyText: '暂无闪卡复习。完成一次“我来答”后会显示熟悉变化。',
            emptyActionLabel: '去复习闪卡',
            emptyActionIcon: Icons.style_rounded,
            onEmptyAction: onOpenFlashCards,
            count: cards.length,
            items: _cardItems(),
          ),
          const SizedBox(height: 10),
          _ReviewSectionBlock(
            isDarkMode: isDarkMode,
            icon: Icons.auto_awesome_rounded,
            color: StudyUi.secondary,
            title: '学习整理',
            caption: '最近整理过的学习动作',
            emptyText: '暂无整理历史。完成一次 2 分钟复盘后会显示整理结果。',
            emptyActionLabel: '开始 2 分钟复盘',
            emptyActionIcon: Icons.auto_awesome_rounded,
            onEmptyAction: onStartReview,
            count: actions.length,
            items: _actionItems(),
          ),
        ],
      ),
    );
  }

  List<_ReviewLineData> _logItems() {
    final sorted = [...logs]..sort((a, b) => b.date.compareTo(a.date));
    return sorted.take(3).map((log) {
      final title = log.courseName.trim().isNotEmpty
          ? log.courseName.trim()
          : _clip(log.content, 18, fallback: '未命名复盘');
      final detail = [
        if (log.content.trim().isNotEmpty) _clip(log.content, 26),
        if (log.problems.trim().isNotEmpty) '难点：${_clip(log.problems, 18)}',
        if (log.nextPlan.trim().isNotEmpty) '下一步：${_clip(log.nextPlan, 18)}',
      ].join(' · ');
      return _ReviewLineData(
        title: title,
        meta: '${_dateLabel(log.date)} · ${detail.isEmpty ? '已留下学习近况' : detail}',
      );
    }).toList();
  }

  List<_ReviewLineData> _taskItems() {
    final sorted = [...tasks]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final taskItems = sorted.map((task) {
      final progress = task.totalCount == 0
          ? '暂无步骤'
          : '完成 ${task.completedCount}/${task.totalCount} 步';
      final course = task.courseName.trim().isEmpty ? task.type.label : task.courseName;
      return _ReviewLineData(
        title: _clip(task.title, 26, fallback: '未命名任务'),
        meta:
            '$progress · ${task.effectiveStatus.label} · $course · 截止 ${_dateLabel(task.deadline)}',
      );
    }).toList();
    final focusItems = focusActions.map((action) {
      final title = action.targetTitle?.trim().isNotEmpty == true
          ? action.targetTitle!.trim()
          : '完成专注';
      final rawMinutes = action.params?['durationMinutes'];
      final minutes = rawMinutes is num ? rawMinutes.toInt() : 0;
      return _ReviewLineData(
        title: _clip(title, 26, fallback: '完成专注'),
        meta:
            '${minutes > 0 ? '$minutes 分钟' : '已完成'} · ${_dateLabel(action.createdAt)}',
      );
    }).toList();
    return [...taskItems, ...focusItems].take(3).toList();
  }

  List<_ReviewLineData> _cardItems() {
    final sorted = [...cards]
      ..sort((a, b) =>
          (b.lastReviewedAt ?? b.createdAt).compareTo(a.lastReviewedAt ?? a.createdAt));
    return sorted.take(3).map((card) {
      final reviewedText = card.reviewCount == 0
          ? '待复习'
          : '${card.masteryLabel} · 复习 ${card.reviewCount} 次';
      final next = card.nextReviewDate == null
          ? '待安排'
          : '下次 ${_dateLabel(card.nextReviewDate!)}';
      return _ReviewLineData(
        title: _clip(card.question, 28, fallback: '未命名闪卡'),
        meta: '$reviewedText · $next',
      );
    }).toList();
  }

  List<_ReviewLineData> _actionItems() {
    final sorted = [...actions]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(3).map((action) {
      final targetTitle = action.targetTitle?.trim() ?? '';
      final title = targetTitle.isNotEmpty ? targetTitle : _actionLabel(action.toolId);
      final result = action.resultMessage?.trim();
      return _ReviewLineData(
        title: _clip(title, 26, fallback: '学习整理'),
        meta:
            '${action.statusLabel} · ${_dateLabel(action.createdAt)}${result == null || result.isEmpty ? '' : ' · ${_clip(result, 22)}'}',
      );
    }).toList();
  }

  String _actionLabel(String toolId) {
    return switch (toolId) {
      'loop.create_from_source' => '整理学习安排',
      'log.create' => '创建学习记录',
      'task.add' => '创建学习任务',
      'task.add_direct' => '创建学习任务',
      'note.save' => '保存学习笔记',
      'flashcard.add' => '整理复习闪卡',
      'flashcard.create_batch' => '整理闪卡',
      'mission.generate_today' => '整理今日安排',
      _ => '学习整理',
    };
  }
}

class _ReviewSectionBlock extends StatelessWidget {
  const _ReviewSectionBlock({
    required this.isDarkMode,
    required this.icon,
    required this.color,
    required this.title,
    required this.caption,
    required this.emptyText,
    this.emptyActionLabel,
    this.emptyActionIcon,
    this.onEmptyAction,
    required this.count,
    required this.items,
  });

  final bool isDarkMode;
  final IconData icon;
  final Color color;
  final String title;
  final String caption;
  final String emptyText;
  final String? emptyActionLabel;
  final IconData? emptyActionIcon;
  final VoidCallback? onEmptyAction;
  final int count;
  final List<_ReviewLineData> items;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: StudyUi.surfaceAlt(isDarkMode)
            .withValues(alpha: isDarkMode ? 0.78 : 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: StudyUi.chipBackground(color, isDarkMode),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 17),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: AppTypography.title,
                      ),
                    ),
                    Text(
                      caption,
                      style: TextStyle(
                        color: bodyColor,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              BadgePill(
                label: '$count',
                background: StudyUi.chipBackground(color, isDarkMode),
                foreground: color,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty) ...[
            Text(emptyText, style: TextStyle(color: bodyColor, height: 1.35)),
            if (emptyActionLabel != null && onEmptyAction != null) ...[
              const SizedBox(height: 10),
              _EvidenceActionPill(
                icon: emptyActionIcon ?? Icons.arrow_forward_rounded,
                label: emptyActionLabel!,
                color: color,
                isDarkMode: isDarkMode,
                onPressed: onEmptyAction,
                filled: false,
              ),
            ],
          ] else
            for (var i = 0; i < items.length; i++) ...[
              _ReviewLine(
                title: items[i].title,
                meta: items[i].meta,
                color: color,
                isDarkMode: isDarkMode,
              ),
              if (i != items.length - 1) const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _ReviewLine extends StatelessWidget {
  const _ReviewLine({
    required this.title,
    required this.meta,
    required this.color,
    required this.isDarkMode,
  });

  final String title;
  final String meta;
  final Color color;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.only(top: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.72),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
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
                  fontWeight: AppTypography.emphasis,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                meta,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: StudyUi.body(isDarkMode),
                  fontSize: 12,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewLineData {
  const _ReviewLineData({required this.title, required this.meta});

  final String title;
  final String meta;
}

class _HeroEvidenceCard extends StatelessWidget {
  const _HeroEvidenceCard({
    required this.isDarkMode,
    required this.accent,
    required this.logs,
    required this.actions,
    required this.completedActions,
    required this.reviewedCards,
    required this.mastery,
    required this.onOpenTasks,
    required this.onOpenFlashCards,
    required this.onOpenLearningMoments,
  });

  final bool isDarkMode;
  final Color accent;
  final int logs;
  final int actions;
  final int completedActions;
  final int reviewedCards;
  final int mastery;
  final VoidCallback? onOpenTasks;
  final VoidCallback? onOpenFlashCards;
  final VoidCallback? onOpenLearningMoments;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    final actionText = actions == 0
        ? '暂无下一步'
        : '完成 $completedActions/$actions 个行动';
    final masteryText = mastery == 0 ? '待复习' : '$mastery%';
    final nextStepText = actions == 0
        ? '下一步：先写一条今天的复盘，留下难点和准备继续做的事。'
        : completedActions < actions
            ? '下一步：挑一个还没完成的小行动，今天先推进 10 分钟。'
            : reviewedCards == 0
                ? '下一步：把一个概念做成闪卡，睡前用“我来答”过一遍。'
                : '下一步：找一张还不熟的闪卡再答一次，给明天留个清楚的起点。';
    final nextAction = actions == 0
        ? _HeroNextAction(
            label: '去记录今天',
            icon: Icons.edit_note_rounded,
            color: accent,
            onPressed: onOpenLearningMoments,
          )
        : completedActions < actions
            ? _HeroNextAction(
                label: '继续一个小行动',
                icon: Icons.checklist_rounded,
                color: StudyUi.success,
                onPressed: onOpenTasks,
              )
            : reviewedCards == 0
                ? _HeroNextAction(
                    label: '去复习闪卡',
                    icon: Icons.style_rounded,
                    color: StudyUi.warning,
                    onPressed: onOpenFlashCards,
                  )
                : _HeroNextAction(
                    label: '保存新的学迹',
                    icon: Icons.auto_stories_rounded,
                    color: accent,
                    onPressed: onOpenLearningMoments,
                  );
    return StudyCard(
      padding: EdgeInsets.zero,
      borderColor: accent.withValues(alpha: 0.2),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(StudyUi.radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [
                    const Color(0xFF17242C),
                    const Color(0xFF142029),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.96),
                    const Color(0xFFEFF8F6),
                  ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                BadgePill(
                  label: '7 天回顾',
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
                  child: Icon(Icons.route_rounded, color: accent, size: 19),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '这一周的学习路径',
              style: TextStyle(
                color: titleColor,
                fontSize: 22,
                fontWeight: AppTypography.hero,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '复盘 $logs 次，$actionText，$reviewedCards 张闪卡完成复习，平均熟悉度 $masteryText。',
              style: TextStyle(color: bodyColor, height: 1.45),
            ),
            const SizedBox(height: 10),
            Text(
              nextStepText,
              style: TextStyle(
                color: accent,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _EvidenceActionPill(
              icon: nextAction.icon,
              label: nextAction.label,
              color: nextAction.color,
              isDarkMode: isDarkMode,
              onPressed: nextAction.onPressed,
              expand: true,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _HeroSignalChip(
                  isDarkMode: isDarkMode,
                  color: accent,
                  label: '复盘',
                  value: '$logs 次',
                ),
                _HeroSignalChip(
                  isDarkMode: isDarkMode,
                  color: StudyUi.success,
                  label: '行动',
                  value: actions == 0 ? '待开始' : '$completedActions/$actions',
                ),
                _HeroSignalChip(
                  isDarkMode: isDarkMode,
                  color: StudyUi.warning,
                  label: '复习',
                  value: '$reviewedCards 张',
                ),
                _HeroSignalChip(
                  isDarkMode: isDarkMode,
                  color: StudyUi.secondary,
                  label: '熟悉度',
                  value: masteryText,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroNextAction {
  const _HeroNextAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
}

class _HeroSignalChip extends StatelessWidget {
  const _HeroSignalChip({
    required this.isDarkMode,
    required this.color,
    required this.label,
    required this.value,
  });

  final bool isDarkMode;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: StudyUi.chipBackground(color, isDarkMode),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: AppTypography.hero,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: StudyUi.body(isDarkMode),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.isDarkMode,
    required this.accent,
    required this.logs,
    required this.blockers,
    required this.dueCards,
  });

  final bool isDarkMode;
  final Color accent;
  final int logs;
  final List<String> blockers;
  final int dueCards;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    return StudyCard(
      padding: const EdgeInsets.all(16),
      color: isDarkMode
          ? StudyUi.surface(isDarkMode)
          : Colors.white.withValues(alpha: 0.92),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: StudyUi.chipBackground(accent, isDarkMode),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lightbulb_rounded, color: accent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '本周学习小结',
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: AppTypography.title,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            logs == 0
                ? '最近 7 天还没有学习记录，先写下今天学了什么。'
                : '最近 7 天里，你把难点整理成任务，再用闪卡复习。',
            style: TextStyle(color: bodyColor, height: 1.4),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill('待复习 $dueCards 张', StudyUi.warning, isDarkMode),
              for (final blocker in blockers.take(3))
                _pill(blocker, StudyUi.danger, isDarkMode),
              if (blockers.isEmpty)
                _pill('暂无明显难点', accent, isDarkMode),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, Color color, bool isDarkMode) {
    return BadgePill(
      label: label,
      background: StudyUi.chipBackground(color, isDarkMode),
      foreground: color,
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.isDarkMode, required this.metrics});

  final bool isDarkMode;
  final List<_EvidenceMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth > 420;
        final metricCards = metrics
            .map((metric) => _MetricCard(
                  isDarkMode: isDarkMode,
                  metric: metric,
                ))
            .toList();
        if (!twoColumns) {
          return _CompactMetricStrip(
            isDarkMode: isDarkMode,
            metrics: metrics,
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metricCards.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 116,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemBuilder: (context, index) => metricCards[index],
        );
      },
    );
  }
}

class _CompactMetricStrip extends StatelessWidget {
  const _CompactMetricStrip({
    required this.isDarkMode,
    required this.metrics,
  });

  final bool isDarkMode;
  final List<_EvidenceMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      color: isDarkMode
          ? StudyUi.surface(isDarkMode)
          : Colors.white.withValues(alpha: 0.92),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < metrics.length; i++) ...[
            Expanded(
              child: _CompactMetricCell(
                isDarkMode: isDarkMode,
                metric: metrics[i],
              ),
            ),
            if (i != metrics.length - 1)
              Container(
                width: 1,
                height: 58,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                color: StudyUi.border(isDarkMode).withValues(alpha: 0.56),
              ),
          ],
        ],
      ),
    );
  }
}

class _CompactMetricCell extends StatelessWidget {
  const _CompactMetricCell({
    required this.isDarkMode,
    required this.metric,
  });

  final bool isDarkMode;
  final _EvidenceMetric metric;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: StudyUi.chipBackground(metric.color, isDarkMode),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(metric.icon, color: metric.color, size: 15),
        ),
        const SizedBox(height: 7),
        SizedBox(
          height: 20,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              metric.value,
              maxLines: 1,
              style: TextStyle(
                color: StudyUi.title(isDarkMode),
                fontSize: 18,
                height: 1,
                fontWeight: AppTypography.hero,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          metric.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: StudyUi.body(isDarkMode),
            fontSize: 10,
            height: 1,
            fontWeight: AppTypography.emphasis,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.isDarkMode, required this.metric});

  final bool isDarkMode;
  final _EvidenceMetric metric;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      padding: const EdgeInsets.all(14),
      color: StudyUi.chipBackground(metric.color, isDarkMode),
      borderColor: metric.color.withValues(alpha: 0.14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: StudyUi.surface(isDarkMode)
                      .withValues(alpha: isDarkMode ? 0.62 : 0.74),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(metric.icon, color: metric.color, size: 17),
              ),
              const Spacer(),
              Text(
                metric.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: metric.color,
                  fontSize: 20,
                  fontWeight: AppTypography.hero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            metric.label,
            style: TextStyle(
              color: StudyUi.title(isDarkMode),
              fontWeight: AppTypography.title,
            ),
          ),
          Text(
            metric.caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: StudyUi.body(isDarkMode),
              fontSize: 12,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeaknessPanel extends StatelessWidget {
  const _WeaknessPanel({
    required this.isDarkMode,
    required this.titleColor,
    required this.bodyColor,
    required this.cards,
    required this.blockers,
  });

  final bool isDarkMode;
  final Color titleColor;
  final Color bodyColor;
  final List<AiFlashCard> cards;
  final List<String> blockers;

  @override
  Widget build(BuildContext context) {
    final reviewed = cards.where((card) => card.reviewCount > 0).toList();
    return StudyCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '防遗忘复习',
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: AppTypography.title,
                  ),
                ),
              ),
              BadgePill(
                label: reviewed.isEmpty ? '待开始' : '已复习 ${reviewed.length} 张',
                background: StudyUi.chipBackground(StudyUi.warning, isDarkMode),
                foreground: StudyUi.warning,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (reviewed.isEmpty)
            Text('暂无复习回写。完成一次闪卡“我来答”后，这里会展示熟悉度和难点标签。',
                style: TextStyle(color: bodyColor, height: 1.4))
          else
            for (var i = 0; i < reviewed.take(4).length; i++) ...[
              _ReviewMasteryCard(
                isDarkMode: isDarkMode,
                card: reviewed[i],
              ),
              if (i != reviewed.take(4).length - 1) const SizedBox(height: 10),
            ],
          if (blockers.isNotEmpty) ...[
            const Divider(height: 20),
            Text('最近难点：${blockers.take(5).join('、')}',
                style: TextStyle(color: bodyColor, fontSize: 12, height: 1.35)),
          ],
        ],
      ),
    );
  }
}

class _ReviewMasteryCard extends StatelessWidget {
  const _ReviewMasteryCard({
    required this.isDarkMode,
    required this.card,
  });

  final bool isDarkMode;
  final AiFlashCard card;

  @override
  Widget build(BuildContext context) {
    final percent = card.masteryPercent;
    final color = percent >= 80
        ? StudyUi.success
        : percent >= 60
            ? StudyUi.warning
            : StudyUi.danger;
    final progress = (percent / 100).clamp(0.0, 1.0).toDouble();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: StudyUi.surfaceAlt(isDarkMode)
            .withValues(alpha: isDarkMode ? 0.72 : 0.86),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  card.question,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: StudyUi.title(isDarkMode),
                    fontWeight: AppTypography.title,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              BadgePill(
                label: '$percent%',
                background: StudyUi.chipBackground(color, isDarkMode),
                foreground: color,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: progress,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '${card.masteryLabel} · 复习 ${card.reviewCount} 次 · 下次 ${_dateLabel(card.nextReviewDate)}',
            style: TextStyle(
              color: StudyUi.body(isDarkMode),
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  String _dateLabel(DateTime? value) {
    if (value == null) return '待安排';
    return '${value.month}/${value.day}';
  }
}

class _TimelinePanel extends StatelessWidget {
  const _TimelinePanel({
    required this.isDarkMode,
    required this.titleColor,
    required this.bodyColor,
    required this.events,
    this.onOpenTasks,
    this.onOpenFlashCards,
    this.onOpenLearningMoments,
    this.onOpenNotes,
    this.onOpenCourse,
  });

  final bool isDarkMode;
  final Color titleColor;
  final Color bodyColor;
  final List<LearningTraceEvent> events;
  final VoidCallback? onOpenTasks;
  final VoidCallback? onOpenFlashCards;
  final VoidCallback? onOpenLearningMoments;
  final VoidCallback? onOpenNotes;
  final ValueChanged<String>? onOpenCourse;

  @override
  Widget build(BuildContext context) {
    final visibleEvents = events.take(8).toList(growable: false);
    return StudyCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '学习历程',
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: AppTypography.title,
                  ),
                ),
              ),
              BadgePill(
                label: '${events.length} 条',
                background: StudyUi.chipBackground(StudyUi.secondary, isDarkMode),
                foreground: StudyUi.secondary,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '这一周的重要学习动作都排在这里，点开可以回到来源。',
            style: TextStyle(color: bodyColor, height: 1.4),
          ),
          const SizedBox(height: 14),
          if (events.isEmpty)
            Text('暂无学习记录。完成复盘、行动或闪卡复习后会显示在这里。',
                style: TextStyle(color: bodyColor, height: 1.4))
          else
            Stack(
              children: [
                Positioned(
                  left: 15,
                  top: 8,
                  bottom: 8,
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          StudyUi.secondary.withValues(alpha: 0.48),
                          StudyUi.primary.withValues(alpha: 0.24),
                          StudyUi.warning.withValues(alpha: 0.18),
                        ],
                      ),
                    ),
                  ),
                ),
                Column(
                  children: [
                    for (var i = 0; i < visibleEvents.length; i++)
                      _TimelineEventTile(
                        isDarkMode: isDarkMode,
                        titleColor: titleColor,
                        bodyColor: bodyColor,
                        event: visibleEvents[i],
                        accent: _eventAccent(visibleEvents[i]),
                        icon: _eventIcon(visibleEvents[i]),
                        isLast: i == visibleEvents.length - 1,
                        onTap: () => _showEventDetail(context, visibleEvents[i]),
                      ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Color _eventAccent(LearningTraceEvent event) {
    switch (event.type) {
      case LearningTraceEventType.moment:
        return StudyUi.primary;
      case LearningTraceEventType.studyLog:
        return StudyUi.secondary;
      case LearningTraceEventType.taskCompleted:
        return StudyUi.success;
      case LearningTraceEventType.noteCreated:
        return const Color(0xFF8A6CE7);
      case LearningTraceEventType.flashcardCreated:
        return StudyUi.warning;
      case LearningTraceEventType.focusCompleted:
        return const Color(0xFF4C9FD8);
      case LearningTraceEventType.aiAction:
        return const Color(0xFFBC6BD9);
    }
  }

  IconData _eventIcon(LearningTraceEvent event) {
    switch (event.type) {
      case LearningTraceEventType.moment:
        return Icons.auto_stories_rounded;
      case LearningTraceEventType.studyLog:
        return Icons.edit_note_rounded;
      case LearningTraceEventType.taskCompleted:
        return Icons.check_rounded;
      case LearningTraceEventType.noteCreated:
        return Icons.sticky_note_2_rounded;
      case LearningTraceEventType.flashcardCreated:
        return Icons.style_rounded;
      case LearningTraceEventType.focusCompleted:
        return Icons.timer_rounded;
      case LearningTraceEventType.aiAction:
        return Icons.auto_awesome_rounded;
    }
  }

  Future<void> _showEventDetail(
    BuildContext context,
    LearningTraceEvent event,
  ) {
    final sourceAction = _sourceActionFor(event);
    return showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: _TimelineEventDetailCard(
          isDarkMode: isDarkMode,
          event: event,
          accent: _eventAccent(event),
          icon: _eventIcon(event),
          dateText: _fullDate(event.happenedAt),
          sourceAction: sourceAction,
          onClose: () => Navigator.of(ctx).pop(),
          onOpenSource: sourceAction == null
              ? null
              : () {
                  Navigator.of(ctx).pop();
                  sourceAction.onOpen();
                },
        ),
      ),
    );
  }

  String _fullDate(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.month}/${value.day} $hour:$minute';
  }

  _TimelineSourceAction? _sourceActionFor(LearningTraceEvent event) {
    switch (event.type) {
      case LearningTraceEventType.studyLog:
        final course = event.courseName.trim();
        final openCourse = onOpenCourse;
        if (course.isEmpty || openCourse == null) return null;
        return _TimelineSourceAction(
          '打开课程记录',
          () => openCourse(course),
        );
      case LearningTraceEventType.taskCompleted:
      case LearningTraceEventType.focusCompleted:
        final openTasks = onOpenTasks;
        return openTasks == null
            ? null
            : _TimelineSourceAction('打开任务', openTasks);
      case LearningTraceEventType.flashcardCreated:
        final openCards = onOpenFlashCards;
        return openCards == null
            ? null
            : _TimelineSourceAction('打开闪卡', openCards);
      case LearningTraceEventType.noteCreated:
        final openNotes = onOpenNotes;
        return openNotes == null
            ? null
            : _TimelineSourceAction('打开笔记', openNotes);
      case LearningTraceEventType.moment:
        final openMoments = onOpenLearningMoments;
        return openMoments == null
            ? null
            : _TimelineSourceAction('打开学迹', openMoments);
      case LearningTraceEventType.aiAction:
        return null;
    }
  }
}

class _TimelineEventTile extends StatelessWidget {
  const _TimelineEventTile({
    required this.isDarkMode,
    required this.titleColor,
    required this.bodyColor,
    required this.event,
    required this.accent,
    required this.icon,
    required this.isLast,
    required this.onTap,
  });

  final bool isDarkMode;
  final Color titleColor;
  final Color bodyColor;
  final LearningTraceEvent event;
  final Color accent;
  final IconData icon;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final summary = event.summary.trim();
    final courseName = event.courseName.trim();
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: StudyUi.surface(isDarkMode),
                shape: BoxShape.circle,
                border: Border.all(
                  color: accent.withValues(alpha: isDarkMode ? 0.62 : 0.36),
                  width: 1.5,
                ),
                boxShadow: [
                  if (!isDarkMode)
                    BoxShadow(
                      color: accent.withValues(alpha: 0.16),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                ],
              ),
              child: Center(
                child: Icon(icon, color: accent, size: 16),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: StudyUi.surfaceAlt(isDarkMode)
                        .withValues(alpha: isDarkMode ? 0.7 : 0.82),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: StudyUi.border(isDarkMode)
                          .withValues(alpha: isDarkMode ? 0.9 : 0.72),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _TimelineChip(
                            isDarkMode: isDarkMode,
                            label: _dateLabel(event.happenedAt),
                            color: accent,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              event.typeLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: bodyColor,
                                fontSize: 12,
                                fontWeight: AppTypography.title,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: StudyUi.muted(isDarkMode),
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: titleColor,
                          fontWeight: AppTypography.title,
                          height: 1.25,
                        ),
                      ),
                      if (summary.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          _clip(summary, 56),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: bodyColor,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                      if (courseName.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          courseName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: StudyUi.muted(isDarkMode),
                            fontSize: 12,
                            fontWeight: AppTypography.title,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineChip extends StatelessWidget {
  const _TimelineChip({
    required this.isDarkMode,
    required this.label,
    required this.color,
  });

  final bool isDarkMode;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: StudyUi.chipBackground(color, isDarkMode),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: AppTypography.title,
        ),
      ),
    );
  }
}

class _TimelineEventDetailCard extends StatelessWidget {
  const _TimelineEventDetailCard({
    required this.isDarkMode,
    required this.event,
    required this.accent,
    required this.icon,
    required this.dateText,
    required this.sourceAction,
    required this.onClose,
    required this.onOpenSource,
  });

  final bool isDarkMode;
  final LearningTraceEvent event;
  final Color accent;
  final IconData icon;
  final String dateText;
  final _TimelineSourceAction? sourceAction;
  final VoidCallback onClose;
  final VoidCallback? onOpenSource;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    final dialogWidth =
        math.max(260.0, math.min(380.0, MediaQuery.sizeOf(context).width - 44));
    final summary = event.summary.trim();
    final courseName = event.courseName.trim();
    return StudyFontScope(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                width: dialogWidth,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: StudyUi.surface(isDarkMode).withValues(
                    alpha: isDarkMode ? 0.92 : 0.88,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color:
                        Colors.white.withValues(alpha: isDarkMode ? 0.08 : 0.68),
                  ),
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
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: StudyUi.chipBackground(accent, isDarkMode),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: accent, size: 21),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.typeLabel,
                            style: TextStyle(
                              color: accent,
                              fontSize: 12,
                              fontWeight: AppTypography.emphasis,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            dateText,
                            style: TextStyle(color: bodyColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  event.title,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 19,
                    fontWeight: AppTypography.hero,
                    height: 1.28,
                  ),
                ),
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: StudyUi.surfaceAlt(isDarkMode),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: StudyUi.border(isDarkMode)),
                    ),
                    child: Text(
                      summary,
                      style: TextStyle(color: bodyColor, height: 1.45),
                    ),
                  ),
                ],
                if (courseName.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _TimelineDetailTag(
                    isDarkMode: isDarkMode,
                    icon: Icons.menu_book_rounded,
                    label: courseName,
                    color: accent,
                  ),
                ],
                const SizedBox(height: 16),
                if (sourceAction != null)
                  _EvidenceActionPill(
                    icon: Icons.open_in_new_rounded,
                    label: sourceAction!.label,
                    color: accent,
                    isDarkMode: isDarkMode,
                    expand: true,
                    onPressed: onOpenSource,
                  ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: _EvidenceActionPill(
                    icon: Icons.keyboard_return_rounded,
                    label: '回到回顾',
                    color: StudyUi.muted(isDarkMode),
                    isDarkMode: isDarkMode,
                    filled: false,
                    onPressed: onClose,
                  ),
                ),
              ],
            ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineDetailTag extends StatelessWidget {
  const _TimelineDetailTag({
    required this.isDarkMode,
    required this.icon,
    required this.label,
    required this.color,
  });

  final bool isDarkMode;
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: StudyUi.chipBackground(color, isDarkMode),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 230),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
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

class _EvidenceActionPill extends StatelessWidget {
  const _EvidenceActionPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDarkMode,
    required this.onPressed,
    this.filled = true,
    this.expand = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool isDarkMode;
  final VoidCallback? onPressed;
  final bool filled;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final foreground = filled
        ? Colors.white
        : (disabled ? StudyUi.muted(isDarkMode) : color);
    final background = filled
        ? color.withValues(alpha: disabled ? 0.48 : 1)
        : StudyUi.chipBackground(color, isDarkMode);
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
            border: Border.all(
              color: filled
                  ? Colors.white.withValues(alpha: disabled ? 0.08 : 0.18)
                  : color.withValues(alpha: disabled ? 0.10 : 0.22),
            ),
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
              Icon(icon, color: foreground, size: 17),
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

class _TimelineSourceAction {
  const _TimelineSourceAction(this.label, this.onOpen);

  final String label;
  final VoidCallback onOpen;
}

class _EvidenceMetric {
  const _EvidenceMetric(
    this.label,
    this.value,
    this.caption,
    this.color,
    this.icon,
  );

  final String label;
  final String value;
  final String caption;
  final Color color;
  final IconData icon;
}

String _dateLabel(DateTime value) => '${value.month}/${value.day}';

String _clip(String value, int maxLength, {String fallback = ''}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return fallback;
  if (trimmed.length <= maxLength) return trimmed;
  return '${trimmed.substring(0, maxLength)}...';
}
