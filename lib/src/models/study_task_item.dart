enum StudyTaskType {
  courseVideo,
  paperReading,
  programmingHomework,
  labReport,
  projectDevelopment,
  other;

  String get label {
    switch (this) {
      case StudyTaskType.courseVideo:
        return '课程视频';
      case StudyTaskType.paperReading:
        return '论文阅读';
      case StudyTaskType.programmingHomework:
        return '编程作业';
      case StudyTaskType.labReport:
        return '实验报告';
      case StudyTaskType.projectDevelopment:
        return '项目开发';
      case StudyTaskType.other:
        return '其他';
    }
  }
}

enum StudyTaskStatus {
  notStarted,
  inProgress,
  completed;

  String get label {
    switch (this) {
      case StudyTaskStatus.notStarted:
        return '未开始';
      case StudyTaskStatus.inProgress:
        return '进行中';
      case StudyTaskStatus.completed:
        return '已完成';
    }
  }
}

class StudyTaskItem {
  final String id;
  final String title;
  final StudyTaskType type;
  final String courseName;
  final DateTime deadline;
  final StudyTaskStatus status;
  final String note;
  final List<String> subtasks;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudyTaskItem({
    required this.id,
    required this.title,
    required this.type,
    required this.courseName,
    required this.deadline,
    this.status = StudyTaskStatus.notStarted,
    this.note = '',
    this.subtasks = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  StudyTaskItem copyWith({
    String? title,
    StudyTaskType? type,
    String? courseName,
    DateTime? deadline,
    StudyTaskStatus? status,
    String? note,
    List<String>? subtasks,
    DateTime? updatedAt,
  }) {
    return StudyTaskItem(
      id: id,
      title: title ?? this.title,
      type: type ?? this.type,
      courseName: courseName ?? this.courseName,
      deadline: deadline ?? this.deadline,
      status: status ?? this.status,
      note: note ?? this.note,
      subtasks: subtasks ?? this.subtasks,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type.name,
        'courseName': courseName,
        'deadline': deadline.toIso8601String(),
        'status': status.name,
        'note': note,
        'subtasks': subtasks,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory StudyTaskItem.fromJson(Map<String, dynamic> json) {
    return StudyTaskItem(
      id: json['id'] as String,
      title: json['title'] as String,
      type: StudyTaskType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => StudyTaskType.other,
      ),
      courseName: json['courseName'] as String? ?? '',
      deadline: DateTime.parse(json['deadline'] as String),
      status: StudyTaskStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => StudyTaskStatus.notStarted,
      ),
      note: json['note'] as String? ?? '',
      subtasks: (json['subtasks'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
