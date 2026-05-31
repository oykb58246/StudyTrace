import '../models/ai_learning_loop.dart';
import '../models/study_log_item.dart';
import '../models/study_task_item.dart';

class LocalTodayMissionBuilder {
  const LocalTodayMissionBuilder();

  AiLearningLoopPlan build({
    required Iterable<StudyTaskItem> tasks,
    required Iterable<StudyLogItem> logs,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final pendingTasks = tasks
        .where((task) => task.effectiveStatus != StudyTaskStatus.completed)
        .take(3)
        .toList();
    final recentLogs = logs.take(2).toList();

    final reviewItems = <AiLearningLoopReviewItem>[];
    for (final task in pendingTasks) {
      final title = task.title.trim();
      if (title.isEmpty) continue;
      reviewItems.add(AiLearningLoopReviewItem(
        title: title,
        date: today,
        minutes: task.deadline.isBefore(today.add(const Duration(days: 1)))
            ? 45
            : 30,
        reason: task.courseName.isEmpty
            ? '来自未完成任务'
            : '来自 ${task.courseName} 的未完成任务',
      ));
    }
    for (final log in recentLogs) {
      final nextPlan = log.nextPlan.trim();
      if (nextPlan.isEmpty) continue;
      reviewItems.add(AiLearningLoopReviewItem(
        title: nextPlan,
        date: today,
        minutes: 25,
        reason: log.courseName.isEmpty
            ? '来自最近学习记录'
            : '来自 ${log.courseName} 的最近学习记录',
      ));
    }
    if (reviewItems.isEmpty) {
      reviewItems.addAll([
        AiLearningLoopReviewItem(
          title: '确定今天最重要的 1 个学习目标',
          date: today,
          minutes: 10,
          reason: '本地基础安排',
        ),
        AiLearningLoopReviewItem(
          title: '完成一个 25 分钟专注学习块',
          date: today,
          minutes: 25,
          reason: '本地基础安排',
        ),
        AiLearningLoopReviewItem(
          title: '记录完成情况和下一步计划',
          date: today,
          minutes: 10,
          reason: '本地基础安排',
        ),
      ]);
    }

    final courseName = pendingTasks
        .map((task) => task.courseName)
        .followedBy(recentLogs.map((log) => log.courseName))
        .firstWhere((name) => name.trim().isNotEmpty, orElse: () => '');
    final hasLocalData = pendingTasks.isNotEmpty || recentLogs.isNotEmpty;

    return AiLearningLoopPlan(
      summary: hasLocalData
          ? '已根据本地待办和最近记录整理出一版今日安排，云端可用时会继续优化。'
          : '还没有待办或学习记录，已先按通用学习节奏生成一版可编辑安排。',
      courseName: courseName,
      reviewPlan: reviewItems.take(4).toList(),
      vivoCapabilitiesUsed: const ['本地兜底'],
    );
  }
}
