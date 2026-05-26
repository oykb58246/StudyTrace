enum LearningMomentVisibility {
  private,
  group,
}

class LearningMoment {
  const LearningMoment({
    required this.id,
    required this.content,
    this.courseName = '',
    this.imagePaths = const [],
    this.visibility = LearningMomentVisibility.private,
    this.groupId,
    this.sourceType,
    this.sourceId,
    required this.createdAt,
  });

  final String id;
  final String content;
  final String courseName;
  final List<String> imagePaths;
  final LearningMomentVisibility visibility;
  final String? groupId;
  final String? sourceType;
  final String? sourceId;
  final DateTime createdAt;

  LearningMoment copyWith({
    String? content,
    String? courseName,
    List<String>? imagePaths,
    LearningMomentVisibility? visibility,
    String? groupId,
    String? sourceType,
    String? sourceId,
  }) {
    return LearningMoment(
      id: id,
      content: content ?? this.content,
      courseName: courseName ?? this.courseName,
      imagePaths: imagePaths ?? this.imagePaths,
      visibility: visibility ?? this.visibility,
      groupId: groupId ?? this.groupId,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        if (courseName.isNotEmpty) 'courseName': courseName,
        if (imagePaths.isNotEmpty) 'imagePaths': imagePaths,
        'visibility': visibility.name,
        if (groupId != null && groupId!.isNotEmpty) 'groupId': groupId,
        if (sourceType != null && sourceType!.isNotEmpty)
          'sourceType': sourceType,
        if (sourceId != null && sourceId!.isNotEmpty) 'sourceId': sourceId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory LearningMoment.fromJson(Map<String, dynamic> json) {
    final rawImages = json['imagePaths'];
    final images = rawImages is List
        ? rawImages.whereType<String>().toList(growable: false)
        : const <String>[];
    final rawVisibility = json['visibility'] as String? ?? 'private';
    return LearningMoment(
      id: json['id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      courseName: json['courseName'] as String? ?? '',
      imagePaths: images,
      visibility: LearningMomentVisibility.values.firstWhere(
        (v) => v.name == rawVisibility,
        orElse: () => LearningMomentVisibility.private,
      ),
      groupId: json['groupId'] as String?,
      sourceType: json['sourceType'] as String?,
      sourceId: json['sourceId'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

enum LearningTraceEventType {
  moment,
  studyLog,
  taskCompleted,
  noteCreated,
  flashcardCreated,
  aiAction,
}

class LearningTraceEvent {
  const LearningTraceEvent({
    required this.id,
    required this.type,
    required this.title,
    this.summary = '',
    this.courseName = '',
    this.imagePaths = const [],
    this.sourceId,
    required this.happenedAt,
    this.isAiGenerated = false,
    this.isShareable = false,
  });

  final String id;
  final LearningTraceEventType type;
  final String title;
  final String summary;
  final String courseName;
  final List<String> imagePaths;
  final String? sourceId;
  final DateTime happenedAt;
  final bool isAiGenerated;
  final bool isShareable;

  String get typeLabel {
    switch (type) {
      case LearningTraceEventType.moment:
        return '动态';
      case LearningTraceEventType.studyLog:
        return '学习记录';
      case LearningTraceEventType.taskCompleted:
        return '任务完成';
      case LearningTraceEventType.noteCreated:
        return '笔记沉淀';
      case LearningTraceEventType.flashcardCreated:
        return '闪卡复习';
      case LearningTraceEventType.aiAction:
        return 'AI 操作';
    }
  }
}
