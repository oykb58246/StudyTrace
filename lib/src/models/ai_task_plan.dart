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
      startAt = DateTime.tryParse(json['startAt'].toString());
    }
    final fallbackDeadline = DateTime.now().add(const Duration(days: 7));
    return AiPlannedSubTask(
      title: json['title']?.toString() ?? '',
      startAt: startAt,
      deadline: DateTime.tryParse(json['deadline']?.toString() ?? '') ??
          fallbackDeadline,
      note: json['note']?.toString() ?? '',
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
          final plannedSubTask = AiPlannedSubTask.fromJson(item);
          if (plannedSubTask.title.trim().isNotEmpty) planned.add(plannedSubTask);
        }
      }
    }

    final fallbackDeadline = DateTime.now().add(const Duration(days: 7));
    return AiTaskPlan(
      mainTitle: json['mainTitle']?.toString() ?? '',
      taskType: _parseType(json['taskType']?.toString() ?? 'other'),
      courseName: json['courseName']?.toString() ?? '',
      deadline: DateTime.tryParse(json['deadline']?.toString() ?? '') ??
          fallbackDeadline,
      difficulty: json['difficulty']?.toString() ?? '中等',
      subTasks: (json['subTasks'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      plannedSubTasks: planned,
      schedule: json['schedule']?.toString() ?? '',
    );
  }

  static StudyTaskType _parseType(String raw) {
    return StudyTaskType.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => StudyTaskType.other,
    );
  }
}
