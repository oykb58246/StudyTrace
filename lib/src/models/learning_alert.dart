import 'package:flutter/material.dart';

enum LearningAlertType {
  deadline,
  overdue,
  studyGap,
  flashcardReview,
  weakProgress,
}

enum LearningAlertLevel {
  low,
  medium,
  high,
}

class LearningAlertSettings {
  const LearningAlertSettings({
    required this.enabled,
    required this.deadlineWarningEnabled,
    required this.studyGapWarningEnabled,
    required this.flashcardReviewEnabled,
    required this.dailyDigestEnabled,
    required this.digestTime,
    required this.deadlineLeadHours,
    required this.studyGapDays,
  });

  static const defaults = LearningAlertSettings(
    enabled: true,
    deadlineWarningEnabled: true,
    studyGapWarningEnabled: true,
    flashcardReviewEnabled: true,
    dailyDigestEnabled: false,
    digestTime: TimeOfDay(hour: 8, minute: 30),
    deadlineLeadHours: 24,
    studyGapDays: 2,
  );

  final bool enabled;
  final bool deadlineWarningEnabled;
  final bool studyGapWarningEnabled;
  final bool flashcardReviewEnabled;
  final bool dailyDigestEnabled;
  final TimeOfDay digestTime;
  final int deadlineLeadHours;
  final int studyGapDays;

  LearningAlertSettings copyWith({
    bool? enabled,
    bool? deadlineWarningEnabled,
    bool? studyGapWarningEnabled,
    bool? flashcardReviewEnabled,
    bool? dailyDigestEnabled,
    TimeOfDay? digestTime,
    int? deadlineLeadHours,
    int? studyGapDays,
  }) {
    return LearningAlertSettings(
      enabled: enabled ?? this.enabled,
      deadlineWarningEnabled:
          deadlineWarningEnabled ?? this.deadlineWarningEnabled,
      studyGapWarningEnabled:
          studyGapWarningEnabled ?? this.studyGapWarningEnabled,
      flashcardReviewEnabled:
          flashcardReviewEnabled ?? this.flashcardReviewEnabled,
      dailyDigestEnabled: dailyDigestEnabled ?? this.dailyDigestEnabled,
      digestTime: digestTime ?? this.digestTime,
      deadlineLeadHours: deadlineLeadHours ?? this.deadlineLeadHours,
      studyGapDays: studyGapDays ?? this.studyGapDays,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'deadlineWarningEnabled': deadlineWarningEnabled,
        'studyGapWarningEnabled': studyGapWarningEnabled,
        'flashcardReviewEnabled': flashcardReviewEnabled,
        'dailyDigestEnabled': dailyDigestEnabled,
        'digestHour': digestTime.hour,
        'digestMinute': digestTime.minute,
        'deadlineLeadHours': deadlineLeadHours,
        'studyGapDays': studyGapDays,
      };

  factory LearningAlertSettings.fromJson(Map<String, dynamic> json) {
    return LearningAlertSettings(
      enabled: json['enabled'] as bool? ?? defaults.enabled,
      deadlineWarningEnabled: json['deadlineWarningEnabled'] as bool? ??
          defaults.deadlineWarningEnabled,
      studyGapWarningEnabled: json['studyGapWarningEnabled'] as bool? ??
          defaults.studyGapWarningEnabled,
      flashcardReviewEnabled: json['flashcardReviewEnabled'] as bool? ??
          defaults.flashcardReviewEnabled,
      dailyDigestEnabled:
          json['dailyDigestEnabled'] as bool? ?? defaults.dailyDigestEnabled,
      digestTime: TimeOfDay(
        hour: ((json['digestHour'] as num?)?.toInt() ??
                defaults.digestTime.hour)
            .clamp(0, 23)
            .toInt(),
        minute: ((json['digestMinute'] as num?)?.toInt() ??
                defaults.digestTime.minute)
            .clamp(0, 59)
            .toInt(),
      ),
      deadlineLeadHours: ((json['deadlineLeadHours'] as num?)?.toInt() ??
              defaults.deadlineLeadHours)
          .clamp(1, 168)
          .toInt(),
      studyGapDays:
          ((json['studyGapDays'] as num?)?.toInt() ?? defaults.studyGapDays)
              .clamp(1, 14)
              .toInt(),
    );
  }
}

class LearningAlert {
  const LearningAlert({
    required this.id,
    required this.type,
    required this.level,
    required this.title,
    required this.description,
    this.sourceType,
    this.sourceId,
    this.courseName = '',
    required this.createdAt,
    this.dueAt,
  });

  final String id;
  final LearningAlertType type;
  final LearningAlertLevel level;
  final String title;
  final String description;
  final String? sourceType;
  final String? sourceId;
  final String courseName;
  final DateTime createdAt;
  final DateTime? dueAt;

  String get levelLabel {
    switch (level) {
      case LearningAlertLevel.low:
        return '低风险';
      case LearningAlertLevel.medium:
        return '中风险';
      case LearningAlertLevel.high:
        return '高风险';
    }
  }

  IconData get icon {
    switch (type) {
      case LearningAlertType.deadline:
        return Icons.event_busy_rounded;
      case LearningAlertType.overdue:
        return Icons.error_rounded;
      case LearningAlertType.studyGap:
        return Icons.timeline_rounded;
      case LearningAlertType.flashcardReview:
        return Icons.style_rounded;
      case LearningAlertType.weakProgress:
        return Icons.trending_down_rounded;
    }
  }
}
