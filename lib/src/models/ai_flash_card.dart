class AiFlashCard {
  final String id;
  final String question;
  final String answer;
  final String courseName;
  final String hint;
  final bool isStarred;
  final String groupName;
  final DateTime createdAt;
  // 间隔重复字段
  final int reviewCount;
  final int easeFactor; // SM-2 ease factor × 100（默认 250 = 2.5）
  final DateTime? nextReviewDate;

  const AiFlashCard({
    required this.id,
    required this.question,
    required this.answer,
    this.courseName = '',
    this.hint = '',
    this.isStarred = false,
    this.groupName = '',
    required this.createdAt,
    this.reviewCount = 0,
    this.easeFactor = 250,
    this.nextReviewDate,
  });

  AiFlashCard copyWith({
    String? question,
    String? answer,
    String? courseName,
    String? hint,
    bool? isStarred,
    String? groupName,
    int? reviewCount,
    int? easeFactor,
    DateTime? nextReviewDate,
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
        reviewCount: reviewCount ?? this.reviewCount,
        easeFactor: easeFactor ?? this.easeFactor,
        nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      );

  /// 简易 SM-2：根据用户评分（1-5）计算下次复习日期
  AiFlashCard recordReview(int quality) {
    // quality: 1=完全忘了, 2=大部分忘了, 3=勉强记得, 4=记得, 5=轻松
    final q = quality.clamp(1, 5);
    var ef = easeFactor + (80 - 50 * (5 - q));
    if (ef < 130) ef = 130; // 最低 1.3
    final n = reviewCount + 1;
    int intervalDays;
    if (q < 3) {
      // 忘了，重新开始
      intervalDays = 1;
    } else if (n == 1) {
      intervalDays = 1;
    } else if (n == 2) {
      intervalDays = 3;
    } else {
      // 之前的间隔 × EF
      final prevInterval = n <= 3 ? 3 : (3 * (ef / 100)).round();
      intervalDays = prevInterval;
    }
    return copyWith(
      reviewCount: n,
      easeFactor: ef,
      nextReviewDate: DateTime.now().add(Duration(days: intervalDays)),
    );
  }

  /// 是否到了该复习的时间
  bool get isDueForReview {
    if (nextReviewDate == null) return true; // 从未复习过
    return DateTime.now().isAfter(nextReviewDate!);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'answer': answer,
        'courseName': courseName,
        'hint': hint,
        if (isStarred) 'isStarred': isStarred,
        if (groupName.isNotEmpty) 'groupName': groupName,
        'createdAt': createdAt.toIso8601String(),
        if (reviewCount > 0) 'reviewCount': reviewCount,
        if (easeFactor != 250) 'easeFactor': easeFactor,
        if (nextReviewDate != null)
          'nextReviewDate': nextReviewDate!.toIso8601String(),
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
        reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
        easeFactor: (json['easeFactor'] as num?)?.toInt() ?? 250,
        nextReviewDate: json['nextReviewDate'] != null
            ? DateTime.tryParse(json['nextReviewDate'] as String)
            : null,
      );
}
