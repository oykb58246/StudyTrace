import 'dart:convert';

import '../controllers/app_data_controller.dart';
import '../models/study_task_item.dart';
import 'ai_tool_registry.dart';

/// AI 应用上下文构建器
///
/// 将 AppDataController 中的当前状态构建为传给 AI 的上下文行，
/// 供 AiChatPage、AiAssistantPage、侧边栏等复用。
class AiAppContextBuilder {
  const AiAppContextBuilder._();

  /// 构建完整的上下文行列表
  static List<String> build(
    AppDataController controller, {
    String? currentLocation,
    bool includeLearningData = true,
  }) {
    final List<Map<String, dynamic>> unfinishedTasks = includeLearningData
        ? controller.studyTasks
            .where((task) => task.effectiveStatus != StudyTaskStatus.completed)
            .take(20)
            .map((task) => {
                  'id': task.id,
                  'title': task.title,
                  'courseName': task.courseName,
                  'deadline': task.deadline.toIso8601String(),
                  'status': task.effectiveStatus.name,
                  'subTasks': task.subTasks
                      .take(6)
                      .map((subTask) => {
                            'id': subTask.id,
                            'title': subTask.title,
                            'status': subTask.status.name,
                          })
                      .toList(),
                })
            .toList()
        : const <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> recentLogs = includeLearningData
        ? controller.studyLogs
            .take(8)
            .map((log) => {
                  'id': log.id,
                  'date': log.date.toIso8601String(),
                  'courseName': log.courseName,
                  'content': log.content,
                  'nextPlan': log.nextPlan,
                })
            .toList()
        : const <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> notes = includeLearningData
        ? controller.studyNotes
            .where((note) => !note.isFolder)
            .take(10)
            .map((note) => {
                  'id': note.id,
                  'title': note.title,
                  'courseName': note.courseName,
                })
            .toList()
        : const <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> starredCards = includeLearningData
        ? controller.flashCards
            .where((card) => card.isStarred)
            .take(10)
            .map((card) => {
                  'id': card.id,
                  'courseName': card.courseName,
                  'question': card.question,
                })
            .toList()
        : const <Map<String, dynamic>>[];
    return [
      '当前位置：${currentLocation ?? controller.currentPrimaryTab}',
      '主页面 targetId：assistant=首页，scenarios=记录，calendar=日历，create=任务，profile=归档',
      '用户可见回复规则：优先用 3 到 5 行，先给“下一步怎么做”，再补一句原因；不要把 action、tool、targetId、status、HTTP、服务器、后端等内部词写给用户。',
      AiToolRegistry.instance.buildOpenablePagesString(),
      AiToolRegistry.instance.buildToolListForPrompt(),
      '课程：${jsonEncode(controller.courses.take(20).toList())}',
      if (includeLearningData) ...[
        '未完成任务 JSON：${jsonEncode(unfinishedTasks)}',
        '最近学习日志 JSON：${jsonEncode(recentLogs)}',
        '笔记摘要 JSON：${jsonEncode(notes)}',
        '收藏闪卡 JSON：${jsonEncode(starredCards)}',
      ] else
        '个人学习数据：本轮未自动加载；只有用户明确需要任务、日志、笔记或闪卡时才注入。',
    ];
  }
}
