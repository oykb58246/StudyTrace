/// AI 分析型学习周报输出
class AiStudyAnalysis {
  final String mainTopics;
  final String courseDistribution;
  final String frequentProblems;
  final String completedTasks;
  final String riskTasks;
  final String statusEvaluation;
  final String nextWeekPriority;

  const AiStudyAnalysis({
    this.mainTopics = '',
    this.courseDistribution = '',
    this.frequentProblems = '',
    this.completedTasks = '',
    this.riskTasks = '',
    this.statusEvaluation = '',
    this.nextWeekPriority = '',
  });

  String toFormattedText() {
    final buffer = StringBuffer();
    buffer.writeln('## AI 学习周报分析');
    buffer.writeln();
    if (mainTopics.isNotEmpty) {
      buffer.writeln('### 本周主要学习主题');
      buffer.writeln(mainTopics);
      buffer.writeln();
    }
    if (courseDistribution.isNotEmpty) {
      buffer.writeln('### 各课程投入情况');
      buffer.writeln(courseDistribution);
      buffer.writeln();
    }
    if (frequentProblems.isNotEmpty) {
      buffer.writeln('### 高频问题分析');
      buffer.writeln(frequentProblems);
      buffer.writeln();
    }
    if (completedTasks.isNotEmpty) {
      buffer.writeln('### 完成情况');
      buffer.writeln(completedTasks);
      buffer.writeln();
    }
    if (riskTasks.isNotEmpty) {
      buffer.writeln('### 延期风险');
      buffer.writeln(riskTasks);
      buffer.writeln();
    }
    if (statusEvaluation.isNotEmpty) {
      buffer.writeln('### 学习状态评价');
      buffer.writeln(statusEvaluation);
      buffer.writeln();
    }
    if (nextWeekPriority.isNotEmpty) {
      buffer.writeln('### 下周优先级建议');
      buffer.writeln(nextWeekPriority);
    }
    return buffer.toString();
  }
}
