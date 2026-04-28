/// AI 生成的结构化学习日志结果
/// 用户输入自然语言后，AI 自动提取结构化字段
class AiGeneratedLog {
  final String courseName;
  final String content;
  final String problems;
  final String thoughts;
  final String nextPlan;

  const AiGeneratedLog({
    this.courseName = '',
    this.content = '',
    this.problems = '',
    this.thoughts = '',
    this.nextPlan = '',
  });

  bool get isEmpty =>
      courseName.isEmpty &&
      content.isEmpty &&
      problems.isEmpty &&
      thoughts.isEmpty &&
      nextPlan.isEmpty;
}
