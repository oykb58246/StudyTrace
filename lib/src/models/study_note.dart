class StudyNote {
  final String id;
  final String title;
  final String content;
  final String courseName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudyNote({
    required this.id,
    required this.title,
    required this.content,
    this.courseName = '',
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'courseName': courseName,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory StudyNote.fromJson(Map<String, dynamic> json) => StudyNote(
        id: json['id'] as String,
        title: (json['title'] as String?) ?? '',
        content: (json['content'] as String?) ?? '',
        courseName: (json['courseName'] as String?) ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  StudyNote copyWith({
    String? title,
    String? content,
    String? courseName,
    DateTime? updatedAt,
  }) =>
      StudyNote(
        id: id,
        title: title ?? this.title,
        content: content ?? this.content,
        courseName: courseName ?? this.courseName,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
