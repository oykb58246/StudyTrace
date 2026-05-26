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

  factory AiRiskWarning.fromJson(Map<String, dynamic> json) {
    return AiRiskWarning(
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      level: _parseRiskLevel(json['level']?.toString()),
      category: json['category']?.toString() ?? 'deadline',
    );
  }

  static RiskLevel _parseRiskLevel(String? value) => switch (value) {
    'low' => RiskLevel.low,
    'high' => RiskLevel.high,
    _ => RiskLevel.medium,
  };
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
