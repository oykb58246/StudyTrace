class TodoItem {
  const TodoItem({
    required this.id,
    required this.title,
    required this.description,
    required this.dueTime,
    required this.isCompleted,
    required this.sourceAnalysisId,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final DateTime dueTime;
  final bool isCompleted;
  final String sourceAnalysisId;
  final DateTime createdAt;

  TodoItem copyWith({
    String? title,
    String? description,
    DateTime? dueTime,
    bool? isCompleted,
    String? sourceAnalysisId,
  }) {
    return TodoItem(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueTime: dueTime ?? this.dueTime,
      isCompleted: isCompleted ?? this.isCompleted,
      sourceAnalysisId: sourceAnalysisId ?? this.sourceAnalysisId,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dueTime': dueTime.toIso8601String(),
      'isCompleted': isCompleted,
      'sourceAnalysisId': sourceAnalysisId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      dueTime: DateTime.tryParse(json['dueTime'] as String? ?? '') ??
          DateTime.now(),
      isCompleted: json['isCompleted'] as bool? ?? false,
      sourceAnalysisId: json['sourceAnalysisId'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
