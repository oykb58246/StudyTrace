import 'study_task_item.dart';

class AiPlannedSubTask {
  final String title;
  final DateTime? startAt;
  final DateTime deadline;
  final String note;

  const AiPlannedSubTask({
    required this.title,
    this.startAt,
    required this.deadline,
    this.note = '',
  });

  factory AiPlannedSubTask.fromJson(Map<String, dynamic> json) {
    DateTime? startAt;
    if (json['startAt'] != null) {
      startAt = DateTime.tryParse(json['startAt'] as String);
    }
    return AiPlannedSubTask(
      title: json['title'] as String,
      startAt: startAt,
      deadline: DateTime.parse(json['deadline'] as String),
      note: json['note'] as String? ?? '',
    );
  }
}

class AiTaskPlan {
  final String mainTitle;
  final StudyTaskType taskType;
  final String courseName;
  final DateTime deadline;
  final String difficulty;
  final List<String> subTasks;
  final List<AiPlannedSubTask> plannedSubTasks;
  final String schedule;

  const AiTaskPlan({
    required this.mainTitle,
    required this.taskType,
    required this.courseName,
    required this.deadline,
    this.difficulty = '中等',
    this.subTasks = const [],
    this.plannedSubTasks = const [],
    this.schedule = '',
  });

  factory AiTaskPlan.fromJson(Map<String, dynamic> json) {
    final rawPlanned = json['plannedSubTasks'];
    final List<AiPlannedSubTask> planned = [];
    if (rawPlanned is List) {
      for (final item in rawPlanned) {
        if (item is Map<String, dynamic>) {
          planned.add(AiPlannedSubTask.fromJson(item));
        }
      }
    }

    return AiTaskPlan(
      mainTitle: json['mainTitle'] as String,
      taskType: _parseType(json['taskType'] as String? ?? 'other'),
      courseName: json['courseName'] as String? ?? '',
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'] as String)
          : DateTime.now().add(const Duration(days: 7)),
      difficulty: json['difficulty'] as String? ?? '中等',
      subTasks: (json['subTasks'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      plannedSubTasks: planned,
      schedule: json['schedule'] as String? ?? '',
    );
  }

  static StudyTaskType _parseType(String raw) {
    return StudyTaskType.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => StudyTaskType.other,
    );
  }
}
