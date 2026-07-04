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

class AiReflectionEmotion {
  const AiReflectionEmotion({
    this.label = '',
    this.intensity = 0,
  });

  final String label;
  final double intensity;

  factory AiReflectionEmotion.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AiReflectionEmotion();
    final rawIntensity = json['intensity'];
    return AiReflectionEmotion(
      label: (json['label'] as String?)?.trim() ?? '',
      intensity:
          rawIntensity is num ? rawIntensity.toDouble().clamp(0, 1).toDouble() : 0.0,
    );
  }
}

class AiReflectionAnalysis {
  const AiReflectionAnalysis({
    this.summary = '',
    this.blockers = const [],
    this.emotion = const AiReflectionEmotion(),
    this.mastery = const {},
    this.forgettingRisk = '',
    this.nextActions = const [],
    this.explanation = '',
  });

  final String summary;
  final List<String> blockers;
  final AiReflectionEmotion emotion;
  final Map<String, double> mastery;
  final String forgettingRisk;
  final List<String> nextActions;
  final String explanation;

  bool get hasContent =>
      summary.isNotEmpty ||
      blockers.isNotEmpty ||
      emotion.label.isNotEmpty ||
      mastery.isNotEmpty ||
      forgettingRisk.isNotEmpty ||
      nextActions.isNotEmpty ||
      explanation.isNotEmpty;

  factory AiReflectionAnalysis.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AiReflectionAnalysis();
    return AiReflectionAnalysis(
      summary: (json['summary'] as String?)?.trim() ?? '',
      blockers: _stringList(json['blockers']),
      emotion: AiReflectionEmotion.fromJson(
        json['emotion'] is Map<String, dynamic>
            ? json['emotion'] as Map<String, dynamic>
            : null,
      ),
      mastery: _masteryMap(json['mastery']),
      forgettingRisk: (json['forgettingRisk'] as String?)?.trim() ??
          (json['risk'] as String?)?.trim() ??
          '',
      nextActions: _stringList(json['nextActions']),
      explanation: (json['explanation'] as String?)?.trim() ?? '',
    );
  }
}

class AiLearningSourceEvidence {
  const AiLearningSourceEvidence({
    required this.type,
    required this.summary,
    this.confidence = 0,
  });

  final String type;
  final String summary;
  final double confidence;

  factory AiLearningSourceEvidence.fromJson(Map<String, dynamic> json) {
    final rawConfidence = json['confidence'];
    return AiLearningSourceEvidence(
      type: (json['type'] as String?)?.trim() ??
          (json['sourceType'] as String?)?.trim() ??
          '',
      summary: (json['summary'] as String?)?.trim() ??
          (json['sourceSummary'] as String?)?.trim() ??
          '',
      confidence: rawConfidence is num
          ? rawConfidence.toDouble().clamp(0, 1).toDouble()
          : 0,
    );
  }
}

class AiLearningActionCard {
  const AiLearningActionCard({
    required this.title,
    this.steps = const [],
    this.reason = '',
    this.deadline,
    this.priority = '',
    this.durationMinutes = 0,
    this.successCriteria = '',
    this.source = '',
  });

  final String title;
  final List<String> steps;
  final String reason;
  final DateTime? deadline;
  final String priority;
  final int durationMinutes;
  final String successCriteria;
  final String source;

  factory AiLearningActionCard.fromJson(Map<String, dynamic> json) {
    final rawDuration = json['durationMinutes'] ?? json['duration'];
    return AiLearningActionCard(
      title: (json['title'] as String?)?.trim() ?? '',
      steps: _stringList(json['steps']),
      reason: (json['reason'] as String?)?.trim() ??
          (json['explanation'] as String?)?.trim() ??
          '',
      deadline: DateTime.tryParse((json['deadline'] as String?) ?? ''),
      priority: (json['priority'] as String?)?.trim() ?? '',
      durationMinutes:
          rawDuration is num ? rawDuration.toInt().clamp(0, 240).toInt() : 0,
      successCriteria: (json['successCriteria'] as String?)?.trim() ?? '',
      source: (json['source'] as String?)?.trim() ??
          (json['sourceSummary'] as String?)?.trim() ??
          '',
    );
  }
}

class AiLearningLoopPlan {
  const AiLearningLoopPlan({
    this.loopSchemaVersion = '',
    required this.summary,
    this.courseName = '',
    this.concepts = const [],
    this.sourceEvidence = const [],
    this.taskDrafts = const [],
    this.noteDraft = const AiLearningLoopNoteDraft(title: '', content: ''),
    this.flashcards = const [],
    this.reviewPlan = const [],
    this.reflectionAnalysis = const AiReflectionAnalysis(),
    this.actionCards = const [],
    this.reviewCards = const [],
    this.vivoCapabilitiesUsed = const [],
    this.capabilityTraces = const [],
  });

  final String loopSchemaVersion;
  final String summary;
  final String courseName;
  final List<String> concepts;
  final List<AiLearningSourceEvidence> sourceEvidence;
  final List<AiLearningLoopTaskDraft> taskDrafts;
  final AiLearningLoopNoteDraft noteDraft;
  final List<AiLearningLoopFlashcardDraft> flashcards;
  final List<AiLearningLoopReviewItem> reviewPlan;
  final AiReflectionAnalysis reflectionAnalysis;
  final List<AiLearningActionCard> actionCards;
  final List<AiLearningLoopReviewItem> reviewCards;
  final List<String> vivoCapabilitiesUsed;
  final List<AiCapabilityTrace> capabilityTraces;

  factory AiLearningLoopPlan.fromJson(Map<String, dynamic> json) {
    return AiLearningLoopPlan(
      loopSchemaVersion: (json['loopSchemaVersion'] as String?)?.trim() ?? '',
      summary: (json['summary'] as String?)?.trim() ?? '',
      courseName: (json['courseName'] as String?)?.trim() ?? '',
      concepts: _stringList(json['concepts']),
      sourceEvidence: _mapList(json['sourceEvidence'])
          .map(AiLearningSourceEvidence.fromJson)
          .where((item) => item.summary.isNotEmpty || item.type.isNotEmpty)
          .toList(),
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
      reflectionAnalysis: AiReflectionAnalysis.fromJson(
        json['reflectionAnalysis'] is Map<String, dynamic>
            ? json['reflectionAnalysis'] as Map<String, dynamic>
            : null,
      ),
      actionCards: _mapList(json['actionCards'])
          .map(AiLearningActionCard.fromJson)
          .where((item) => item.title.isNotEmpty)
          .toList(),
      reviewCards: _mapList(json['reviewCards'])
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

Map<String, double> _masteryMap(dynamic value) {
  if (value is! Map) return const {};
  final result = <String, double>{};
  for (final entry in value.entries) {
    final key = entry.key.toString().trim();
    final raw = entry.value;
    if (key.isEmpty || raw is! num) continue;
    result[key] = raw.toDouble().clamp(0, 1).toDouble();
  }
  return result;
}

StudyTaskType _taskTypeFromJson(String? raw) {
  return StudyTaskType.values.firstWhere(
    (item) => item.name == raw,
    orElse: () => StudyTaskType.other,
  );
}
