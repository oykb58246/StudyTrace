import 'study_task_item.dart';

/// AI 拆解复杂学习任务后生成的计划
class AiTaskPlan {
  final String mainTitle;
  final StudyTaskType taskType;
  final String courseName;
  final DateTime deadline;
  final String difficulty;
  final List<String> subTasks;
  final String schedule;

  const AiTaskPlan({
    required this.mainTitle,
    required this.taskType,
    required this.courseName,
    required this.deadline,
    this.difficulty = '中等',
    this.subTasks = const [],
    this.schedule = '',
  });
}
