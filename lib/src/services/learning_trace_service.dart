import '../models/ai_action_record.dart';
import '../models/ai_flash_card.dart';
import '../models/learning_moment.dart';
import '../models/study_log_item.dart';
import '../models/study_note.dart';
import '../models/study_task_item.dart';

class LearningTraceService {
  const LearningTraceService();

  List<LearningTraceEvent> buildTimeline({
    required List<LearningMoment> moments,
    required List<StudyLogItem> logs,
    required List<StudyTaskItem> tasks,
    required List<StudyNote> notes,
    required List<AiFlashCard> flashCards,
    required List<AiActionRecord> actionRecords,
  }) {
    final events = <LearningTraceEvent>[
      ...moments.map(_fromMoment),
      ...logs.map(_fromLog),
      ...tasks.where((task) => task.effectiveStatus == StudyTaskStatus.completed)
          .map(_fromCompletedTask),
      ...notes.where((note) => !note.isFolder).map(_fromNote),
      ...flashCards.map(_fromFlashCard),
      ...actionRecords
          .where((record) => record.status == AiActionStatus.executed)
          .map(_fromActionRecord),
    ];
    events.sort((a, b) => b.happenedAt.compareTo(a.happenedAt));
    return events;
  }

  LearningTraceEvent _fromMoment(LearningMoment moment) {
    final content = moment.content.trim();
    return LearningTraceEvent(
      id: 'moment_${moment.id}',
      type: LearningTraceEventType.moment,
      title: content.isEmpty ? '分享了一条学习动态' : content,
      summary: moment.courseName.isEmpty ? '' : '课程：${moment.courseName}',
      courseName: moment.courseName,
      imagePaths: moment.imagePaths,
      sourceId: moment.id,
      happenedAt: moment.createdAt,
      isShareable: false,
    );
  }

  LearningTraceEvent _fromLog(StudyLogItem log) {
    final content = _compact([
      log.content,
      if (log.problems.trim().isNotEmpty) '问题：${log.problems}',
      if (log.nextPlan.trim().isNotEmpty) '下一步：${log.nextPlan}',
    ]);
    return LearningTraceEvent(
      id: 'log_${log.id}',
      type: LearningTraceEventType.studyLog,
      title: log.courseName.isEmpty ? '记录了一次学习' : '学习了 ${log.courseName}',
      summary: content,
      courseName: log.courseName,
      sourceId: log.id,
      happenedAt: log.createdAt,
      isShareable: true,
    );
  }

  LearningTraceEvent _fromCompletedTask(StudyTaskItem task) {
    final summary = _compact([
      task.note,
      if (task.subTasks.isNotEmpty)
        '完成 ${task.completedCount}/${task.totalCount} 个子任务',
    ]);
    return LearningTraceEvent(
      id: 'task_${task.id}',
      type: LearningTraceEventType.taskCompleted,
      title: '完成任务：${task.title}',
      summary: summary,
      courseName: task.courseName,
      sourceId: task.id,
      happenedAt: task.updatedAt,
      isShareable: true,
    );
  }

  LearningTraceEvent _fromNote(StudyNote note) {
    final body = note.content.trim().isNotEmpty
        ? note.content
        : note.blocks.map((block) => block.content).join('\n');
    return LearningTraceEvent(
      id: 'note_${note.id}',
      type: LearningTraceEventType.noteCreated,
      title: '沉淀笔记：${note.title.isEmpty ? '未命名笔记' : note.title}',
      summary: _trim(body, 160),
      courseName: note.courseName,
      sourceId: note.id,
      happenedAt: note.createdAt,
      isShareable: true,
    );
  }

  LearningTraceEvent _fromFlashCard(AiFlashCard card) {
    return LearningTraceEvent(
      id: 'flashcard_${card.id}',
      type: LearningTraceEventType.flashcardCreated,
      title: '生成闪卡：${_trim(card.question, 48)}',
      summary: card.answer,
      courseName: card.courseName,
      sourceId: card.id,
      happenedAt: card.createdAt,
      isAiGenerated: true,
      isShareable: true,
    );
  }

  LearningTraceEvent _fromActionRecord(AiActionRecord record) {
    final title = record.targetTitle?.trim().isNotEmpty == true
        ? record.targetTitle!.trim()
        : record.toolId;
    return LearningTraceEvent(
      id: 'ai_${record.id}',
      type: LearningTraceEventType.aiAction,
      title: 'AI 已执行：$title',
      summary: record.resultMessage ?? '',
      sourceId: record.targetId,
      happenedAt: record.createdAt,
      isAiGenerated: true,
      isShareable: true,
    );
  }

  String _compact(List<String> parts) {
    return parts
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join('\n');
  }

  String _trim(String value, int maxLength) {
    final trimmed = value.trim();
    if (trimmed.length <= maxLength) return trimmed;
    return '${trimmed.substring(0, maxLength)}...';
  }
}
