class AnalysisItem {
  const AnalysisItem({
    required this.id,
    required this.rawContent,
    required this.contentType,
    required this.summary,
    required this.keyPoints,
    required this.suggestedActions,
    required this.createdAt,
  });

  final String id;
  final String rawContent;
  final String contentType;
  final String summary;
  final List<String> keyPoints;
  final List<String> suggestedActions;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rawContent': rawContent,
      'contentType': contentType,
      'summary': summary,
      'keyPoints': keyPoints,
      'suggestedActions': suggestedActions,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AnalysisItem.fromJson(Map<String, dynamic> json) {
    return AnalysisItem(
      id: json['id'] as String? ?? '',
      rawContent: json['rawContent'] as String? ?? '',
      contentType: json['contentType'] as String? ?? '其他',
      summary: json['summary'] as String? ?? '',
      keyPoints: _stringList(json['keyPoints']),
      suggestedActions: _stringList(json['suggestedActions']),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

List<String> _stringList(Object? value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList();
  }
  return const [];
}
