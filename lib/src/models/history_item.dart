import 'analysis_item.dart';

class HistoryItem {
  const HistoryItem({
    required this.id,
    required this.analysis,
    required this.createdAt,
  });

  final String id;
  final AnalysisItem analysis;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'analysis': analysis.toJson(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id'] as String? ?? '',
      analysis: AnalysisItem.fromJson(
        (json['analysis'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
