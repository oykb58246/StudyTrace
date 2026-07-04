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
  final int? lastReviewScore;
  final DateTime? lastReviewedAt;
  final List<String> weakTags;

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
    this.lastReviewScore,
    this.lastReviewedAt,
    this.weakTags = const [],
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
    int? lastReviewScore,
    DateTime? lastReviewedAt,
    List<String>? weakTags,
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
        lastReviewScore: lastReviewScore ?? this.lastReviewScore,
        lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
        weakTags: weakTags ?? this.weakTags,
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
    final reviewedAt = DateTime.now();
    return copyWith(
      reviewCount: n,
      easeFactor: ef,
      nextReviewDate: reviewedAt.add(Duration(days: intervalDays)),
      lastReviewScore: q,
      lastReviewedAt: reviewedAt,
      weakTags: _deriveWeakTags(q),
    );
  }

  /// 是否到了该复习的时间
  bool get isDueForReview {
    if (nextReviewDate == null) return true; // 从未复习过
    return DateTime.now().isAfter(nextReviewDate!);
  }

  int get masteryPercent {
    if (lastReviewScore == null) {
      return reviewCount == 0 ? 0 : (easeFactor / 3).round().clamp(35, 85);
    }
    return (lastReviewScore!.clamp(1, 5) * 20).clamp(20, 100);
  }

  String get masteryLabel {
    final score = lastReviewScore;
    if (score == null) return reviewCount == 0 ? '待复习' : '复习中';
    if (score >= 5) return '稳固掌握';
    if (score >= 4) return '基本掌握';
    if (score >= 3) return '需要巩固';
    return '薄弱点';
  }

  static List<String> _deriveWeakTags(int score) {
    if (score >= 4) return const [];
    if (score == 3) return const ['待巩固'];
    return const ['薄弱', '优先复习'];
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
        if (lastReviewScore != null) 'lastReviewScore': lastReviewScore,
        if (lastReviewedAt != null)
          'lastReviewedAt': lastReviewedAt!.toIso8601String(),
        if (weakTags.isNotEmpty) 'weakTags': weakTags,
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
        lastReviewScore: (json['lastReviewScore'] as num?)?.toInt(),
        lastReviewedAt: json['lastReviewedAt'] != null
            ? DateTime.tryParse(json['lastReviewedAt'] as String)
            : null,
        weakTags: (json['weakTags'] as List<dynamic>?)
                ?.map((item) => item.toString().trim())
                .where((item) => item.isNotEmpty)
                .toList() ??
            const [],
      );
}
