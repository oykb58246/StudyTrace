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
      loopSchemaVersion: 'local-fallback-v1',
      summary: hasLocalData
          ? '已根据待办和最近记录整理出一版今日安排，你可以继续编辑。'
          : '还没有待办或学习记录，已先按通用学习节奏生成一版可编辑安排。',
      courseName: courseName,
      sourceEvidence: [
        AiLearningSourceEvidence(
          type: hasLocalData ? 'local-history' : 'local-template',
          summary: hasLocalData ? '本地待办与最近学习记录' : '本地通用学习节奏模板',
          confidence: hasLocalData ? 0.62 : 0.38,
        ),
      ],
      reviewPlan: reviewItems.take(4).toList(),
      vivoCapabilitiesUsed: const ['本机记录整理'],
    );
  }
}

class LocalLearningLoopFallbackBuilder {
  const LocalLearningLoopFallbackBuilder();

  AiLearningLoopPlan build({
    required String sourceText,
    required Iterable<StudyTaskItem> tasks,
    required Iterable<StudyLogItem> logs,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cleanText = sourceText.trim().replaceAll(RegExp(r'\s+'), ' ');
    final summary = cleanText.isEmpty
        ? '已先整理一版可编辑内容。'
        : '复盘整理：${_clip(cleanText, 72)}';
    final courseName = _guessCourse(cleanText, tasks, logs);
    final blocker = cleanText.contains('错') || cleanText.contains('不会')
        ? '复盘文本中出现了错误或不确定表达'
        : '需要用下一步行动验证掌握情况';
    return AiLearningLoopPlan(
      loopSchemaVersion: 'local-fallback-v1',
      summary: summary,
      courseName: courseName,
      concepts: const ['复盘事实', '行动拆解', '防遗忘复习'],
      sourceEvidence: [
        AiLearningSourceEvidence(
          type: 'local-fallback',
          summary: cleanText.isEmpty ? '本机学习节奏模板' : _clip(cleanText, 40),
          confidence: 0.42,
        ),
      ],
      reflectionAnalysis: AiReflectionAnalysis(
        summary: '已先按现有记录整理，你可以继续编辑。',
        blockers: [blocker],
        emotion: const AiReflectionEmotion(label: '待确认', intensity: 0.35),
        mastery: const {'当前主题': 0.45},
        forgettingRisk: 'medium',
        nextActions: const ['先完成一个最小行动块', '用闪卡复习检验掌握度'],
        explanation: '当前内容来自输入文本和本机学习记录，可按实际情况调整。',
      ),
      actionCards: [
        AiLearningActionCard(
          title: courseName.isEmpty ? '完成 25 分钟复盘行动' : '$courseName 25 分钟复盘行动',
          steps: const ['重读今天的难点', '完成 1 个小练习', '记录错因和下一步'],
          reason: '先保留一个可以马上开始的学习动作',
          deadline: DateTime(today.year, today.month, today.day, 22),
          priority: 'high',
          durationMinutes: 25,
          successCriteria: '留下 1 条学习记录，并完成至少 1 张复习闪卡',
          source: '已有学习记录',
        ),
      ],
      flashcards: [
        AiLearningLoopFlashcardDraft(
          question: '今天复盘中最需要优先验证的难点是什么？',
          answer: blocker,
          hint: '先回答难点，再安排复习。',
          courseName: courseName,
        ),
      ],
      reviewPlan: [
        AiLearningLoopReviewItem(
          title: '本机复习安排',
          date: today,
          minutes: 25,
          reason: '保持今天的学习节奏不中断',
        ),
      ],
      reviewCards: [
        AiLearningLoopReviewItem(
          title: '明晚 5 分钟回忆测试',
          date: today.add(const Duration(days: 1)),
          minutes: 5,
          reason: '防止今天难点遗忘',
        ),
      ],
      vivoCapabilitiesUsed: const ['本机记录整理'],
    );
  }

  String _guessCourse(
    String text,
    Iterable<StudyTaskItem> tasks,
    Iterable<StudyLogItem> logs,
  ) {
    final known = [
      ...tasks.map((task) => task.courseName),
      ...logs.map((log) => log.courseName),
    ].where((name) => name.trim().isNotEmpty).toList();
    for (final name in known) {
      if (text.contains(name)) return name;
    }
    return known.isEmpty ? '' : known.first;
  }

  String _clip(String value, int maxLength) {
    final trimmed = value.trim();
    if (trimmed.length <= maxLength) return trimmed;
    return '${trimmed.substring(0, maxLength)}...';
  }
}
