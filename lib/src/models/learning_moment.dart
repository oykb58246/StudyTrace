enum LearningMomentVisibility {
  private,
  public,
  includeGroups,
  excludeGroups,
}

class LearningMomentAuthor {
  const LearningMomentAuthor({
    this.id = '',
    this.username = '',
    this.nickname = '学习者',
    this.avatarEmoji = '🎓',
    this.avatarImageUrl,
  });

  final String id;
  final String username;
  final String nickname;
  final String avatarEmoji;
  final String? avatarImageUrl;

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        if (username.isNotEmpty) 'username': username,
        'nickname': nickname,
        'avatarEmoji': avatarEmoji,
        if (avatarImageUrl != null && avatarImageUrl!.isNotEmpty)
          'avatarImageUrl': avatarImageUrl,
      };

  factory LearningMomentAuthor.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const LearningMomentAuthor();
    return LearningMomentAuthor(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '学习者',
      avatarEmoji: json['avatarEmoji'] as String? ?? '🎓',
      avatarImageUrl: json['avatarImageUrl'] as String?,
    );
  }
}

class LearningMomentComment {
  const LearningMomentComment({
    required this.id,
    required this.content,
    required this.createdAt,
    this.author = const LearningMomentAuthor(),
    this.isMine = false,
  });

  final String id;
  final String content;
  final DateTime createdAt;
  final LearningMomentAuthor author;
  final bool isMine;

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'author': author.toJson(),
        'isMine': isMine,
      };

  factory LearningMomentComment.fromJson(Map<String, dynamic> json) {
    return LearningMomentComment(
      id: json['id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      author: LearningMomentAuthor.fromJson(
        json['author'] is Map<String, dynamic>
            ? json['author'] as Map<String, dynamic>
            : null,
      ),
      isMine: json['isMine'] == true,
    );
  }
}

class LearningMoment {
  const LearningMoment({
    required this.id,
    required this.content,
    this.courseName = '',
    this.imagePaths = const [],
    this.visibility = LearningMomentVisibility.private,
    this.allowedGroupIds = const [],
    this.deniedGroupIds = const [],
    this.sourceType,
    this.sourceId,
    this.author = const LearningMomentAuthor(),
    this.likeCount = 0,
    this.commentCount = 0,
    this.likedByMe = false,
    this.comments = const [],
    this.isMine = true,
    required this.createdAt,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  final String id;
  final String content;
  final String courseName;
  final List<String> imagePaths;
  final LearningMomentVisibility visibility;
  final List<String> allowedGroupIds;
  final List<String> deniedGroupIds;
  final String? sourceType;
  final String? sourceId;
  final LearningMomentAuthor author;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final List<LearningMomentComment> comments;
  final bool isMine;
  final DateTime createdAt;
  final DateTime updatedAt;

  String? get groupId =>
      allowedGroupIds.isNotEmpty ? allowedGroupIds.first : null;

  LearningMoment copyWith({
    String? content,
    String? courseName,
    List<String>? imagePaths,
    LearningMomentVisibility? visibility,
    List<String>? allowedGroupIds,
    List<String>? deniedGroupIds,
    String? sourceType,
    String? sourceId,
    LearningMomentAuthor? author,
    int? likeCount,
    int? commentCount,
    bool? likedByMe,
    List<LearningMomentComment>? comments,
    bool? isMine,
    DateTime? updatedAt,
  }) {
    return LearningMoment(
      id: id,
      content: content ?? this.content,
      courseName: courseName ?? this.courseName,
      imagePaths: imagePaths ?? this.imagePaths,
      visibility: visibility ?? this.visibility,
      allowedGroupIds: allowedGroupIds ?? this.allowedGroupIds,
      deniedGroupIds: deniedGroupIds ?? this.deniedGroupIds,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      author: author ?? this.author,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      likedByMe: likedByMe ?? this.likedByMe,
      comments: comments ?? this.comments,
      isMine: isMine ?? this.isMine,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        if (courseName.isNotEmpty) 'courseName': courseName,
        if (imagePaths.isNotEmpty) 'imagePaths': imagePaths,
        'visibility': visibility.name,
        if (allowedGroupIds.isNotEmpty) 'allowedGroupIds': allowedGroupIds,
        if (deniedGroupIds.isNotEmpty) 'deniedGroupIds': deniedGroupIds,
        if (groupId != null && groupId!.isNotEmpty) 'groupId': groupId,
        if (sourceType != null && sourceType!.isNotEmpty)
          'sourceType': sourceType,
        if (sourceId != null && sourceId!.isNotEmpty) 'sourceId': sourceId,
        'author': author.toJson(),
        'likeCount': likeCount,
        'commentCount': commentCount,
        'likedByMe': likedByMe,
        if (comments.isNotEmpty)
          'comments': comments.map((comment) => comment.toJson()).toList(),
        'isMine': isMine,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory LearningMoment.fromJson(Map<String, dynamic> json) {
    final rawImages = json['imagePaths'];
    final images = rawImages is List
        ? rawImages.whereType<String>().toList(growable: false)
        : const <String>[];
    final rawVisibility = json['visibility'] as String? ?? 'private';
    final legacyGroupId = json['groupId'] as String?;
    final visibility = _parseVisibility(rawVisibility, legacyGroupId);
    final allowed = _stringList(json['allowedGroupIds']);
    final denied = _stringList(json['deniedGroupIds']);
    final rawComments = json['comments'];
    return LearningMoment(
      id: json['id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      courseName: json['courseName'] as String? ?? '',
      imagePaths: images,
      visibility: visibility,
      allowedGroupIds: visibility == LearningMomentVisibility.includeGroups &&
              allowed.isEmpty &&
              legacyGroupId != null &&
              legacyGroupId.isNotEmpty
          ? [legacyGroupId]
          : allowed,
      deniedGroupIds: denied,
      sourceType: json['sourceType'] as String?,
      sourceId: json['sourceId'] as String?,
      author: LearningMomentAuthor.fromJson(
        json['author'] is Map<String, dynamic>
            ? json['author'] as Map<String, dynamic>
            : null,
      ),
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      likedByMe: json['likedByMe'] == true,
      comments: rawComments is List
          ? rawComments
              .whereType<Map<String, dynamic>>()
              .map(LearningMomentComment.fromJson)
              .toList(growable: false)
          : const [],
      isMine: json['isMine'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }

  static LearningMomentVisibility _parseVisibility(
    String raw,
    String? legacyGroupId,
  ) {
    if (raw == 'group' && legacyGroupId != null && legacyGroupId.isNotEmpty) {
      return LearningMomentVisibility.includeGroups;
    }
    return LearningMomentVisibility.values.firstWhere(
      (v) => v.name == raw,
      orElse: () => LearningMomentVisibility.private,
    );
  }

  static List<String> _stringList(Object? raw) {
    return raw is List ? raw.whereType<String>().toList(growable: false) : [];
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
        return '助手整理';
    }
  }
}
