class AiFlashCard {
  final String id;
  final String question;
  final String answer;
  final String courseName;
  final String hint;
  final bool isStarred;
  final String groupName;
  final DateTime createdAt;

  const AiFlashCard({
    required this.id,
    required this.question,
    required this.answer,
    this.courseName = '',
    this.hint = '',
    this.isStarred = false,
    this.groupName = '',
    required this.createdAt,
  });

  AiFlashCard copyWith({
    String? question,
    String? answer,
    String? courseName,
    String? hint,
    bool? isStarred,
    String? groupName,
  }) =>
      AiFlashCard(
        id: id,
        question: question ?? this.question,
        answer: answer ?? this.answer,
        courseName: courseName ?? this.courseName,
        hint: hint ?? this.hint,
        isStarred: isStarred ?? this.isStarred,
        groupName: groupName ?? this.groupName,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'answer': answer,
        'courseName': courseName,
        'hint': hint,
        if (isStarred) 'isStarred': isStarred,
        if (groupName.isNotEmpty) 'groupName': groupName,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AiFlashCard.fromJson(Map<String, dynamic> json) => AiFlashCard(
        id: json['id'] as String? ?? '',
        question: (json['question'] as String?) ?? '',
        answer: (json['answer'] as String?) ?? '',
        courseName: (json['courseName'] as String?) ?? '',
        hint: (json['hint'] as String?) ?? '',
        isStarred: json['isStarred'] as bool? ?? false,
        groupName: (json['groupName'] as String?) ?? '',
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );
}
