import 'package:flutter/material.dart';

import 'study_sub_task_item.dart';

enum StudyTaskType {
  classHomework,
  paperReading,
  programmingHomework,
  labReport,
  projectDev,
  examReview,
  readingNotes,
  other;

  String get label {
    switch (this) {
      case StudyTaskType.classHomework:
        return '课堂作业';
      case StudyTaskType.paperReading:
        return '论文阅读';
      case StudyTaskType.programmingHomework:
        return '编程作业';
      case StudyTaskType.labReport:
        return '实验报告';
      case StudyTaskType.projectDev:
        return '项目开发';
      case StudyTaskType.examReview:
        return '期末复习';
      case StudyTaskType.readingNotes:
        return '读书笔记';
      case StudyTaskType.other:
        return '其他任务';
    }
  }

  IconData get icon {
    switch (this) {
      case StudyTaskType.classHomework:
        return Icons.assignment_rounded;
      case StudyTaskType.paperReading:
        return Icons.menu_book_rounded;
      case StudyTaskType.programmingHomework:
        return Icons.code_rounded;
      case StudyTaskType.labReport:
        return Icons.science_rounded;
      case StudyTaskType.projectDev:
        return Icons.rocket_launch_rounded;
      case StudyTaskType.examReview:
        return Icons.quiz_rounded;
      case StudyTaskType.readingNotes:
        return Icons.auto_stories_rounded;
      case StudyTaskType.other:
        return Icons.more_horiz_rounded;
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
  final List<StudySubTaskItem> subTasks;
  final DateTime? reminderTime;
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
    this.subTasks = const [],
    this.reminderTime,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isTaskSet => subTasks.isNotEmpty;

  StudyTaskStatus get _derivedStatus {
    if (subTasks.isEmpty) return status;
    final allDone = subTasks.every((s) => s.status == SubTaskStatus.completed);
    if (allDone) return StudyTaskStatus.completed;
    final anyStarted = subTasks.any((s) => s.status != SubTaskStatus.notStarted);
    return anyStarted ? StudyTaskStatus.inProgress : StudyTaskStatus.notStarted;
  }

  StudyTaskStatus get effectiveStatus => subTasks.isEmpty ? status : _derivedStatus;

  double get progress {
    if (subTasks.isEmpty) return status == StudyTaskStatus.completed ? 1.0 : 0.0;
    if (subTasks.isEmpty) return 0.0;
    return subTasks.where((s) => s.status == SubTaskStatus.completed).length /
        subTasks.length;
  }

  int get completedCount =>
      subTasks.isEmpty
          ? (status == StudyTaskStatus.completed ? 1 : 0)
          : subTasks.where((s) => s.status == SubTaskStatus.completed).length;

  int get totalCount => subTasks.isEmpty ? 1 : subTasks.length;

  StudyTaskItem copyWith({
    String? title,
    StudyTaskType? type,
    String? courseName,
    DateTime? deadline,
    StudyTaskStatus? status,
    String? note,
    List<StudySubTaskItem>? subTasks,
    DateTime? reminderTime,
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
      subTasks: subTasks ?? this.subTasks,
      reminderTime: reminderTime ?? this.reminderTime,
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
        'subTasks': subTasks.map((s) => s.toJson()).toList(),
        if (reminderTime != null)
          'reminderTime': reminderTime!.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  static const _typeMigration = {
    'courseVideo': StudyTaskType.classHomework,
    'projectDevelopment': StudyTaskType.projectDev,
  };

  factory StudyTaskItem.fromJson(Map<String, dynamic> json) {
    final rawType = json['type'] as String? ?? 'other';
    final type = _typeMigration[rawType] ??
        StudyTaskType.values.firstWhere(
          (e) => e.name == rawType,
          orElse: () => StudyTaskType.other,
        );

    DateTime? reminderTime;
    if (json['reminderTime'] != null) {
      reminderTime = DateTime.tryParse(json['reminderTime'] as String);
    }

    final deadline = DateTime.parse(json['deadline'] as String);

    // Backward compatible: old List<String> → new List<StudySubTaskItem>
    final rawSubtasks = json['subtasks'] ?? json['subTasks'];
    final List<StudySubTaskItem> subTasks = [];
    if (rawSubtasks is List) {
      final now = DateTime.now();
      for (final item in rawSubtasks) {
        if (item is String) {
          // Old format: plain string → migrate to sub-task item
          subTasks.add(StudySubTaskItem(
            id: 'sub_${now.microsecondsSinceEpoch}_${subTasks.length}',
            title: item,
            deadline: deadline,
            createdAt: now,
            updatedAt: now,
          ));
        } else if (item is Map<String, dynamic>) {
          subTasks.add(StudySubTaskItem.fromJson(item));
        }
      }
    }

    return StudyTaskItem(
      id: json['id'] as String,
      title: json['title'] as String,
      type: type,
      courseName: json['courseName'] as String? ?? '',
      deadline: deadline,
      status: StudyTaskStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => StudyTaskStatus.notStarted,
      ),
      note: json['note'] as String? ?? '',
      subTasks: subTasks,
      reminderTime: reminderTime,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
