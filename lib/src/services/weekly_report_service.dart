import '../models/study_log_item.dart';
import '../models/study_task_item.dart';

class WeeklyReportService {
  const WeeklyReportService();

  String generate({
    required DateTime startDate,
    required DateTime endDate,
    required List<StudyLogItem> logs,
    required List<StudyTaskItem> tasks,
  }) {
    final buffer = StringBuffer();

    final startStr = _fmt(startDate);
    final endStr = _fmt(endDate);

    buffer.writeln('## 学习周报 ($startStr - $endStr)');
    buffer.writeln();

    // 一、本周学习内容
    buffer.writeln('### 一、本周学习内容');
    if (logs.isEmpty) {
      buffer.writeln('本周暂无学习记录。');
    } else {
      final byCourse = <String, List<StudyLogItem>>{};
      for (final log in logs) {
        byCourse.putIfAbsent(log.courseName, () => []).add(log);
      }
      for (final entry in byCourse.entries) {
        buffer.writeln('- **${entry.key}**：');
        for (final log in entry.value) {
          if (log.content.isNotEmpty) {
            buffer.writeln('  - ${log.content}');
          }
        }
      }
    }
    buffer.writeln();

    // 二、本周完成进度
    buffer.writeln('### 二、本周完成进度');
    if (tasks.isEmpty) {
      buffer.writeln('本周暂无学习任务。');
    } else {
      final completed =
          tasks.where((t) => t.status == StudyTaskStatus.completed).length;
      buffer.writeln(
        '- 总体进度：$completed / ${tasks.length} 项已完成',
      );
      for (final task in tasks) {
        final mark =
            task.status == StudyTaskStatus.completed ? '[✓]' : '[ ]';
        buffer.writeln('- $mark ${task.title}（${task.type.label}）');
      }
    }
    buffer.writeln();

    // 三、遇到的问题
    buffer.writeln('### 三、遇到的问题');
    final problems = logs
        .where((l) => l.problems.isNotEmpty)
        .map((l) => l.problems)
        .toList();
    if (problems.isEmpty) {
      buffer.writeln('本周记录中未提及遇到的问题。');
    } else {
      for (final p in problems) {
        buffer.writeln('- $p');
      }
    }
    buffer.writeln();

    // 四、思考与收获
    buffer.writeln('### 四、思考与收获');
    final thoughts = logs
        .where((l) => l.thoughts.isNotEmpty)
        .map((l) => l.thoughts)
        .toList();
    if (thoughts.isEmpty) {
      buffer.writeln('本周记录中未提及思考与收获。');
    } else {
      for (final t in thoughts) {
        buffer.writeln('- $t');
      }
    }
    buffer.writeln();

    // 五、下周学习计划
    buffer.writeln('### 五、下周学习计划');
    final nextPlans = logs
        .where((l) => l.nextPlan.isNotEmpty)
        .map((l) => l.nextPlan)
        .toList();
    final pendingTasks =
        tasks.where((t) => t.status != StudyTaskStatus.completed).toList();
    if (nextPlans.isEmpty && pendingTasks.isEmpty) {
      buffer.writeln('暂无明确的下一步计划。');
    } else {
      for (final plan in nextPlans) {
        buffer.writeln('- $plan');
      }
      if (pendingTasks.isNotEmpty) {
        buffer.writeln('- 待完成任务：${pendingTasks.map((t) => t.title).join('、')}');
      }
    }

    return buffer.toString();
  }

  String _fmt(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
