/// AI 学习风险提醒
class AiRiskWarning {
  final String title;
  final String description;
  final RiskLevel level;
  final String category; // deadline, gap, completionRate, logFrequency, repeatedProblem

  const AiRiskWarning({
    required this.title,
    required this.description,
    this.level = RiskLevel.medium,
    this.category = 'deadline',
  });
}

enum RiskLevel { low, medium, high }

extension RiskLevelMeta on RiskLevel {
  String get label {
    switch (this) {
      case RiskLevel.low:
        return '低风险';
      case RiskLevel.medium:
        return '中风险';
      case RiskLevel.high:
        return '高风险';
    }
  }
}
