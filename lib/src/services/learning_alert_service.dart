import '../models/ai_flash_card.dart';
import '../models/learning_alert.dart';
import '../models/study_log_item.dart';
import '../models/study_task_item.dart';

class LearningAlertService {
  const LearningAlertService();

  List<LearningAlert> buildAlerts({
    required List<StudyTaskItem> tasks,
    required List<StudyLogItem> logs,
    required List<AiFlashCard> flashCards,
    required LearningAlertSettings settings,
    DateTime? now,
  }) {
    if (!settings.enabled) return const [];
    final current = now ?? DateTime.now();
    final alerts = <LearningAlert>[];

    if (settings.deadlineWarningEnabled) {
      alerts.addAll(_deadlineAlerts(tasks, current, settings));
      alerts.addAll(_progressAlerts(tasks, current));
    }
    if (settings.studyGapWarningEnabled) {
      final gap = _studyGapAlert(logs, current, settings);
      if (gap != null) alerts.add(gap);
    }
    if (settings.flashcardReviewEnabled) {
      final review = _flashcardReviewAlert(flashCards, current);
      if (review != null) alerts.add(review);
    }

    alerts.sort((a, b) {
      final level = _rankLevel(b.level).compareTo(_rankLevel(a.level));
      if (level != 0) return level;
      final aDue = a.dueAt ?? a.createdAt;
      final bDue = b.dueAt ?? b.createdAt;
      return aDue.compareTo(bDue);
    });
    return alerts.take(8).toList(growable: false);
  }

  List<LearningAlert> _deadlineAlerts(
    List<StudyTaskItem> tasks,
    DateTime now,
    LearningAlertSettings settings,
  ) {
    final alerts = <LearningAlert>[];
    for (final task in tasks) {
      if (task.effectiveStatus == StudyTaskStatus.completed) continue;
      final diff = task.deadline.difference(now);
      if (diff.isNegative) {
        alerts.add(LearningAlert(
          id: 'overdue_${task.id}',
          type: LearningAlertType.overdue,
          level: LearningAlertLevel.high,
          title: '任务已逾期：${task.title}',
          description: _taskBody(task, '建议今天先拆出 1 个可完成的小步骤。'),
          sourceType: 'study_task',
          sourceId: task.id,
          courseName: task.courseName,
          createdAt: now,
          dueAt: task.deadline,
        ));
        continue;
      }
      if (diff.inHours <= settings.deadlineLeadHours) {
        alerts.add(LearningAlert(
          id: 'deadline_${task.id}',
          type: LearningAlertType.deadline,
          level: diff.inHours <= 6
              ? LearningAlertLevel.high
              : LearningAlertLevel.medium,
          title: '截止临近：${task.title}',
          description: _taskBody(
            task,
            '剩余约 ${diff.inHours.clamp(0, 999)} 小时，建议安排一个专注块。',
          ),
          sourceType: 'study_task',
          sourceId: task.id,
          courseName: task.courseName,
          createdAt: now,
          dueAt: task.deadline,
        ));
      }
    }
    return alerts;
  }

  List<LearningAlert> _progressAlerts(List<StudyTaskItem> tasks, DateTime now) {
    final alerts = <LearningAlert>[];
    for (final task in tasks) {
      if (task.effectiveStatus == StudyTaskStatus.completed) continue;
      if (task.subTasks.length < 3) continue;
      final hoursLeft = task.deadline.difference(now).inHours;
      if (hoursLeft > 72 || hoursLeft < 0) continue;
      if (task.progress >= 0.34) continue;
      alerts.add(LearningAlert(
        id: 'progress_${task.id}',
        type: LearningAlertType.weakProgress,
        level: hoursLeft <= 24
            ? LearningAlertLevel.high
            : LearningAlertLevel.medium,
        title: '进度偏慢：${task.title}',
        description:
            '当前完成 ${task.completedCount}/${task.totalCount} 个子任务，建议先处理最短的一项。',
        sourceType: 'study_task',
        sourceId: task.id,
        courseName: task.courseName,
        createdAt: now,
        dueAt: task.deadline,
      ));
    }
    return alerts;
  }

  LearningAlert? _studyGapAlert(
    List<StudyLogItem> logs,
    DateTime now,
    LearningAlertSettings settings,
  ) {
    if (logs.isEmpty) {
      return LearningAlert(
        id: 'study_gap_empty',
        type: LearningAlertType.studyGap,
        level: LearningAlertLevel.medium,
        title: '还没有学习记录',
        description: '建议今天记录一次学习内容，让学迹开始形成可复盘的轨迹。',
        createdAt: now,
      );
    }
    final latest = logs
        .map((log) => log.date)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final gapDays = DateTime(now.year, now.month, now.day)
        .difference(DateTime(latest.year, latest.month, latest.day))
        .inDays;
    if (gapDays < settings.studyGapDays) return null;
    return LearningAlert(
      id: 'study_gap_$gapDays',
      type: LearningAlertType.studyGap,
      level: gapDays >= settings.studyGapDays + 2
          ? LearningAlertLevel.high
          : LearningAlertLevel.medium,
      title: '学习记录断档 $gapDays 天',
      description: '建议补一条最近学习记录，或让 AI 帮你生成今日学习路径。',
      createdAt: now,
    );
  }

  LearningAlert? _flashcardReviewAlert(
    List<AiFlashCard> flashCards,
    DateTime now,
  ) {
    final due = flashCards.where((card) => card.isDueForReview).toList();
    if (due.isEmpty) return null;
    due.sort((a, b) {
      final aDate = a.nextReviewDate ?? DateTime(2000);
      final bDate = b.nextReviewDate ?? DateTime(2000);
      return aDate.compareTo(bDate);
    });
    final first = due.first;
    return LearningAlert(
      id: 'flashcard_review_${due.length}_${first.id}',
      type: LearningAlertType.flashcardReview,
      level: due.length >= 10 ? LearningAlertLevel.medium : LearningAlertLevel.low,
      title: '${due.length} 张闪卡需要复习',
      description: '最早到期：${_trim(first.question, 36)}。建议用 10 分钟快速过一遍。',
      sourceType: 'flash_card',
      sourceId: first.id,
      courseName: first.courseName,
      createdAt: now,
      dueAt: first.nextReviewDate,
    );
  }

  String _taskBody(StudyTaskItem task, String hint) {
    final course = task.courseName.isEmpty ? '未归类课程' : task.courseName;
    return '$course · ${task.type.label}\n$hint';
  }

  int _rankLevel(LearningAlertLevel level) {
    switch (level) {
      case LearningAlertLevel.low:
        return 1;
      case LearningAlertLevel.medium:
        return 2;
      case LearningAlertLevel.high:
        return 3;
    }
  }

  String _trim(String value, int maxLength) {
    final trimmed = value.trim();
    if (trimmed.length <= maxLength) return trimmed;
    return '${trimmed.substring(0, maxLength)}...';
  }
}
