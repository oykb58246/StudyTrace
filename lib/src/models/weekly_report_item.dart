class WeeklyReportItem {
  final String id;
  final DateTime startDate;
  final DateTime endDate;
  final String content;
  final List<String> sourceLogIds;
  final DateTime createdAt;

  const WeeklyReportItem({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.content,
    this.sourceLogIds = const [],
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'content': content,
        'sourceLogIds': sourceLogIds,
        'createdAt': createdAt.toIso8601String(),
      };

  factory WeeklyReportItem.fromJson(Map<String, dynamic> json) {
    return WeeklyReportItem(
      id: json['id'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      content: json['content'] as String,
      sourceLogIds: (json['sourceLogIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
