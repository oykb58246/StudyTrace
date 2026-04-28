class StudyLogItem {
  final String id;
  final DateTime date;
  final String courseName;
  final String content;
  final String problems;
  final String thoughts;
  final String nextPlan;
  final DateTime createdAt;

  const StudyLogItem({
    required this.id,
    required this.date,
    required this.courseName,
    this.content = '',
    this.problems = '',
    this.thoughts = '',
    this.nextPlan = '',
    required this.createdAt,
  });

  StudyLogItem copyWith({
    DateTime? date,
    String? courseName,
    String? content,
    String? problems,
    String? thoughts,
    String? nextPlan,
  }) {
    return StudyLogItem(
      id: id,
      date: date ?? this.date,
      courseName: courseName ?? this.courseName,
      content: content ?? this.content,
      problems: problems ?? this.problems,
      thoughts: thoughts ?? this.thoughts,
      nextPlan: nextPlan ?? this.nextPlan,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'courseName': courseName,
        'content': content,
        'problems': problems,
        'thoughts': thoughts,
        'nextPlan': nextPlan,
        'createdAt': createdAt.toIso8601String(),
      };

  factory StudyLogItem.fromJson(Map<String, dynamic> json) {
    return StudyLogItem(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      courseName: json['courseName'] as String? ?? '',
      content: json['content'] as String? ?? '',
      problems: json['problems'] as String? ?? '',
      thoughts: json['thoughts'] as String? ?? '',
      nextPlan: json['nextPlan'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
