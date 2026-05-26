import 'study_task_item.dart';

import 'ai_capability_trace.dart';

class AiLearningLoopTaskDraft {
  const AiLearningLoopTaskDraft({
    required this.title,
    this.type = StudyTaskType.other,
    this.deadline,
    this.note = '',
    this.subTasks = const [],
  });

  final String title;
  final StudyTaskType type;
  final DateTime? deadline;
  final String note;
  final List<AiLearningLoopSubTaskDraft> subTasks;

  factory AiLearningLoopTaskDraft.fromJson(Map<String, dynamic> json) {
    final rawSubTasks = json['subTasks'];
    return AiLearningLoopTaskDraft(
      title: (json['title'] as String?)?.trim() ?? '',
      type: _taskTypeFromJson(json['type'] as String?),
      deadline: DateTime.tryParse((json['deadline'] as String?) ?? ''),
      note: (json['note'] as String?)?.trim() ?? '',
      subTasks: _mapList(rawSubTasks)
          .map(AiLearningLoopSubTaskDraft.fromJson)
          .where((item) => item.title.isNotEmpty)
          .toList(),
    );
  }
}

class AiLearningLoopSubTaskDraft {
  const AiLearningLoopSubTaskDraft({
    required this.title,
    this.deadline,
    this.note = '',
  });

  final String title;
  final DateTime? deadline;
  final String note;

  factory AiLearningLoopSubTaskDraft.fromJson(Map<String, dynamic> json) {
    return AiLearningLoopSubTaskDraft(
      title: (json['title'] as String?)?.trim() ?? '',
      deadline: DateTime.tryParse((json['deadline'] as String?) ?? ''),
      note: (json['note'] as String?)?.trim() ?? '',
    );
  }
}

class AiLearningLoopNoteDraft {
  const AiLearningLoopNoteDraft({
    required this.title,
    required this.content,
    this.blocks = const [],
  });

  final String title;
  final String content;
  final List<AiLearningLoopNoteBlockDraft> blocks;

  factory AiLearningLoopNoteDraft.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AiLearningLoopNoteDraft(title: '', content: '');
    final rawBlocks = json['blocks'];
    return AiLearningLoopNoteDraft(
      title: (json['title'] as String?)?.trim() ?? '',
      content: (json['content'] as String?)?.trim() ?? '',
      blocks: _mapList(rawBlocks)
          .map(AiLearningLoopNoteBlockDraft.fromJson)
          .where((item) => item.content.isNotEmpty)
          .toList(),
    );
  }
}

class AiLearningLoopNoteBlockDraft {
  const AiLearningLoopNoteBlockDraft({
    required this.type,
    required this.content,
  });

  final String type;
  final String content;

  factory AiLearningLoopNoteBlockDraft.fromJson(Map<String, dynamic> json) {
    return AiLearningLoopNoteBlockDraft(
      type: (json['type'] as String?)?.trim() ?? 'text',
      content: (json['content'] as String?)?.trim() ?? '',
    );
  }
}

class AiLearningLoopFlashcardDraft {
  const AiLearningLoopFlashcardDraft({
    required this.question,
    required this.answer,
    this.hint = '',
    this.courseName = '',
  });

  final String question;
  final String answer;
  final String hint;
  final String courseName;

  factory AiLearningLoopFlashcardDraft.fromJson(Map<String, dynamic> json) {
    return AiLearningLoopFlashcardDraft(
      question: (json['question'] as String?)?.trim() ?? '',
      answer: (json['answer'] as String?)?.trim() ?? '',
      hint: (json['hint'] as String?)?.trim() ?? '',
      courseName: (json['courseName'] as String?)?.trim() ?? '',
    );
  }
}

class AiLearningLoopReviewItem {
  const AiLearningLoopReviewItem({
    required this.title,
    this.date,
    this.minutes = 25,
    this.reason = '',
  });

  final String title;
  final DateTime? date;
  final int minutes;
  final String reason;

  factory AiLearningLoopReviewItem.fromJson(Map<String, dynamic> json) {
    final rawMinutes = json['minutes'];
    return AiLearningLoopReviewItem(
      title: (json['title'] as String?)?.trim() ?? '',
      date: DateTime.tryParse((json['date'] as String?) ?? ''),
      minutes:
          rawMinutes is num ? rawMinutes.toInt().clamp(5, 180).toInt() : 25,
      reason: (json['reason'] as String?)?.trim() ?? '',
    );
  }
}

class AiLearningLoopPlan {
  const AiLearningLoopPlan({
    required this.summary,
    this.courseName = '',
    this.concepts = const [],
    this.taskDrafts = const [],
    this.noteDraft = const AiLearningLoopNoteDraft(title: '', content: ''),
    this.flashcards = const [],
    this.reviewPlan = const [],
    this.vivoCapabilitiesUsed = const [],
    this.capabilityTraces = const [],
  });

  final String summary;
  final String courseName;
  final List<String> concepts;
  final List<AiLearningLoopTaskDraft> taskDrafts;
  final AiLearningLoopNoteDraft noteDraft;
  final List<AiLearningLoopFlashcardDraft> flashcards;
  final List<AiLearningLoopReviewItem> reviewPlan;
  final List<String> vivoCapabilitiesUsed;
  final List<AiCapabilityTrace> capabilityTraces;

  factory AiLearningLoopPlan.fromJson(Map<String, dynamic> json) {
    return AiLearningLoopPlan(
      summary: (json['summary'] as String?)?.trim() ?? '',
      courseName: (json['courseName'] as String?)?.trim() ?? '',
      concepts: _stringList(json['concepts']),
      taskDrafts: _mapList(json['taskDrafts'])
          .map(AiLearningLoopTaskDraft.fromJson)
          .where((item) => item.title.isNotEmpty)
          .toList(),
      noteDraft: AiLearningLoopNoteDraft.fromJson(
        json['noteDraft'] is Map<String, dynamic>
            ? json['noteDraft'] as Map<String, dynamic>
            : null,
      ),
      flashcards: _mapList(json['flashcards'])
          .map(AiLearningLoopFlashcardDraft.fromJson)
          .where((item) => item.question.isNotEmpty && item.answer.isNotEmpty)
          .toList(),
      reviewPlan: _mapList(json['reviewPlan'])
          .map(AiLearningLoopReviewItem.fromJson)
          .where((item) => item.title.isNotEmpty)
          .toList(),
      vivoCapabilitiesUsed: _stringList(json['vivoCapabilitiesUsed']),
      capabilityTraces: parseCapabilityTraces(json['capabilityTraces']),
    );
  }
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => item.cast<String, dynamic>())
      .toList();
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return value.map((item) => item.toString().trim()).where((s) => s.isNotEmpty).toList();
}

StudyTaskType _taskTypeFromJson(String? raw) {
  return StudyTaskType.values.firstWhere(
    (item) => item.name == raw,
    orElse: () => StudyTaskType.other,
  );
}
