import 'package:flutter/material.dart';

class DailyReminderSettings {
  const DailyReminderSettings({
    required this.enabled,
    required this.time,
  });

  static const defaults = DailyReminderSettings(
    enabled: false,
    time: TimeOfDay(hour: 20, minute: 0),
  );

  final bool enabled;
  final TimeOfDay time;

  DailyReminderSettings copyWith({
    bool? enabled,
    TimeOfDay? time,
  }) {
    return DailyReminderSettings(
      enabled: enabled ?? this.enabled,
      time: time ?? this.time,
    );
  }
}
