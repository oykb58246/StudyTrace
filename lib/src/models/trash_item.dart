enum TrashEntityType {
  task,
  log,
  note,
  flashCard,
}

class TrashItem {
  const TrashItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.title,
    required this.payload,
    required this.deletedAt,
    this.sourceActionId,
  });

  final String id;
  final TrashEntityType entityType;
  final String entityId;
  final String title;
  final String payload; // 原实体完整 JSON
  final DateTime deletedAt;
  final String? sourceActionId;

  String get entityTypeLabel {
    return switch (entityType) {
      TrashEntityType.task => '任务',
      TrashEntityType.log => '记录',
      TrashEntityType.note => '笔记',
      TrashEntityType.flashCard => '闪卡',
    };
  }

  TrashItem copyWith({
    String? id,
    TrashEntityType? entityType,
    String? entityId,
    String? title,
    String? payload,
    DateTime? deletedAt,
    String? sourceActionId,
  }) {
    return TrashItem(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      title: title ?? this.title,
      payload: payload ?? this.payload,
      deletedAt: deletedAt ?? this.deletedAt,
      sourceActionId: sourceActionId ?? this.sourceActionId,
    );
  }

  factory TrashItem.fromJson(Map<String, dynamic> json) {
    return TrashItem(
      id: json['id'] as String? ?? '',
      entityType: _parseEntityType(json['entityType'] as String? ?? ''),
      entityId: json['entityId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      payload: json['payload'] as String? ?? '',
      deletedAt: json['deletedAt'] != null
          ? DateTime.parse(json['deletedAt'] as String)
          : DateTime.now(),
      sourceActionId: json['sourceActionId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entityType': entityType.name,
      'entityId': entityId,
      'title': title,
      'payload': payload,
      'deletedAt': deletedAt.toIso8601String(),
      if (sourceActionId != null) 'sourceActionId': sourceActionId,
    };
  }

  static TrashEntityType _parseEntityType(String value) {
    return switch (value) {
      'task' => TrashEntityType.task,
      'log' => TrashEntityType.log,
      'note' => TrashEntityType.note,
      'flashCard' => TrashEntityType.flashCard,
      _ => TrashEntityType.task,
    };
  }
}
