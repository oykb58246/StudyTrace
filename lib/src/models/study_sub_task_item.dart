enum SubTaskStatus {
  notStarted,
  inProgress,
  completed;

  String get label {
    switch (this) {
      case SubTaskStatus.notStarted:
        return '未开始';
      case SubTaskStatus.inProgress:
        return '进行中';
      case SubTaskStatus.completed:
        return '已完成';
    }
  }
}

class StudySubTaskItem {
  final String id;
  final String title;
  final DateTime? startAt;
  final DateTime deadline;
  final SubTaskStatus status;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudySubTaskItem({
    required this.id,
    required this.title,
    this.startAt,
    required this.deadline,
    this.status = SubTaskStatus.notStarted,
    this.note = '',
    required this.createdAt,
    required this.updatedAt,
  });

  StudySubTaskItem copyWith({
    String? title,
    DateTime? startAt,
    DateTime? deadline,
    SubTaskStatus? status,
    String? note,
    DateTime? updatedAt,
  }) =>
      StudySubTaskItem(
        id: id,
        title: title ?? this.title,
        startAt: startAt ?? this.startAt,
        deadline: deadline ?? this.deadline,
        status: status ?? this.status,
        note: note ?? this.note,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (startAt != null) 'startAt': startAt!.toIso8601String(),
        'deadline': deadline.toIso8601String(),
        'status': status.name,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory StudySubTaskItem.fromJson(Map<String, dynamic> json) {
    DateTime? startAt;
    if (json['startAt'] != null) {
      startAt = DateTime.tryParse(json['startAt'] as String);
    }
    return StudySubTaskItem(
      id: json['id'] as String,
      title: json['title'] as String,
      startAt: startAt,
      deadline: DateTime.parse(json['deadline'] as String),
      status: SubTaskStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SubTaskStatus.notStarted,
      ),
      note: json['note'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
