import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/daily_reminder_settings.dart';
import '../models/learning_alert.dart';
import '../models/study_task_item.dart';
import 'local_storage_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final LocalStorageService _storage = LocalStorageService();

  static const _scheduledKey = 'studytrace_notification_ids_v1';
  static const _dailyReminderId = 250000;
  static const _learningAlertDigestId = 250100;
  final Set<int> _scheduledIds = {};
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _onTap,
      );
      await _requestPlatformPermissions();
      await _loadScheduled();
      _initialized = true;
    } catch (_) {
      // Notifications require platform services; keep tests/simulators safe.
      _initialized = false;
    }
  }

  Future<DailyReminderSettings> loadDailyReminderSettings() {
    return _storage.loadDailyReminderSettings();
  }

  Future<LearningAlertSettings> loadLearningAlertSettings() {
    return _storage.loadLearningAlertSettings();
  }

  Future<void> setLearningAlertSettings(
    LearningAlertSettings settings, {
    List<LearningAlert> currentAlerts = const [],
  }) async {
    await _storage.saveLearningAlertSettings(settings);
    if (!settings.enabled || !settings.dailyDigestEnabled) {
      await cancelLearningAlertDigest();
      return;
    }
    await scheduleLearningAlertDigest(settings, currentAlerts);
  }

  Future<void> cancelLearningAlertDigest() async {
    try {
      if (!_initialized) await init();
      if (!_initialized) return;
      await _plugin.cancel(id: _learningAlertDigestId);
    } catch (_) {
      // ignore: platform notification services may be unavailable in tests
    }
  }

  Future<void> setDailyLearningReminder({
    required bool enabled,
    required TimeOfDay time,
  }) async {
    final settings = DailyReminderSettings(enabled: enabled, time: time);
    await _storage.saveDailyReminderSettings(settings);

    if (!enabled) {
      await cancelDailyLearningReminder();
      return;
    }
    await _scheduleDailyLearningReminder(time);
  }

  Future<void> cancelDailyLearningReminder() async {
    try {
      if (!_initialized) await init();
      if (!_initialized) return;
      await _plugin.cancel(id: _dailyReminderId);
    } catch (_) {
      // ignore: platform notification services may be unavailable in tests
    }
  }

  Future<void> rescheduleForTasks(List<StudyTaskItem> tasks) async {
    try {
      if (!_initialized) await init();
      if (!_initialized) return;

      final previousIds = Set<int>.from(_scheduledIds);
      for (final id in previousIds) {
        await _plugin.cancel(id: id);
      }
      _scheduledIds.clear();
      await _saveScheduled();

      for (final task in tasks) {
        if (task.effectiveStatus != StudyTaskStatus.completed) {
          await scheduleForTask(task);
        }
      }

      final daily = await loadDailyReminderSettings();
      if (daily.enabled) {
        await _scheduleDailyLearningReminder(daily.time);
      } else {
        await cancelDailyLearningReminder();
      }

      final alerts = await loadLearningAlertSettings();
      if (!alerts.enabled || !alerts.dailyDigestEnabled) {
        await cancelLearningAlertDigest();
      }
    } catch (_) {
      // ignore: do not let notification recovery block app startup
    }
  }

  Future<void> _requestPlatformPermissions() async {
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    } catch (_) {
      // ignore: permission APIs are platform/version dependent
    }
  }

  Future<void> _loadScheduled() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_scheduledKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List<dynamic>).map((e) => e as int);
      _scheduledIds.addAll(list);
    } catch (_) {}
  }

  Future<void> _saveScheduled() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scheduledKey, jsonEncode(_scheduledIds.toList()));
  }

  void _onTap(NotificationResponse? response) {
    final payload = response?.payload;
    if (payload == null || payload.isEmpty) return;
    // Payload is intentionally stored for future deep-link routing.
  }

  /// Schedule a notification for a task's reminder time.
  Future<int?> scheduleTaskReminder(StudyTaskItem task) async {
    final reminderTime = task.reminderTime;
    if (reminderTime == null) return null;
    if (reminderTime.isBefore(DateTime.now())) return null;

    final id = _taskReminderId(task);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'studytrace_task_reminder',
        '任务提醒',
        channelDescription: '学习任务提醒通知',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final tzDate = tz.TZDateTime.from(reminderTime, tz.local);
    await _plugin.zonedSchedule(
      id: id,
      title: task.title,
      body: _formatReminderBody(task),
      scheduledDate: tzDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: jsonEncode({
        'kind': 'task_reminder',
        'taskId': task.id,
      }),
    );

    _scheduledIds.add(id);
    await _saveScheduled();
    return id;
  }

  /// Schedule a notification before a task deadline.
  Future<int?> scheduleDeadlineReminder(StudyTaskItem task) async {
    final deadline = task.deadline;
    final now = DateTime.now();

    var notifyTime = DateTime(
      deadline.year,
      deadline.month,
      deadline.day - 1,
      9,
    );

    if (notifyTime.isBefore(now)) {
      notifyTime = deadline.subtract(const Duration(hours: 2));
    }
    if (notifyTime.isBefore(now)) return null;

    final id = _deadlineReminderId(task);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'studytrace_deadline',
        '截止提醒',
        channelDescription: '任务截止日期提醒',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final tzDate = tz.TZDateTime.from(notifyTime, tz.local);
    await _plugin.zonedSchedule(
      id: id,
      title: '截止提醒：${task.title}',
      body: '截止时间：${_fmtDate(task.deadline)}\n状态：${task.effectiveStatus.label}',
      scheduledDate: tzDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: jsonEncode({
        'kind': 'deadline',
        'taskId': task.id,
      }),
    );

    _scheduledIds.add(id);
    await _saveScheduled();
    return id;
  }

  /// Schedule all notifications for a task.
  Future<void> scheduleForTask(StudyTaskItem task) async {
    try {
      if (!_initialized) await init();
      if (!_initialized || task.effectiveStatus == StudyTaskStatus.completed) {
        return;
      }
      await scheduleTaskReminder(task);
      await scheduleDeadlineReminder(task);
    } catch (_) {
      // ignore: notification scheduling should never break task saving
    }
  }

  /// Cancel all notifications for a task.
  Future<void> cancelForTask(StudyTaskItem task) async {
    try {
      if (!_initialized) await init();
      if (!_initialized) return;
      final reminderId = _taskReminderId(task);
      final deadlineId = _deadlineReminderId(task);
      await _plugin.cancel(id: reminderId);
      await _plugin.cancel(id: deadlineId);
      _scheduledIds.remove(reminderId);
      _scheduledIds.remove(deadlineId);
      await _saveScheduled();
    } catch (_) {
      // ignore: platform notification services may be unavailable in tests
    }
  }

  /// Cancel all scheduled notifications.
  Future<void> cancelAll() async {
    try {
      if (!_initialized) await init();
      if (!_initialized) return;
      await _plugin.cancelAll();
      _scheduledIds.clear();
      await _saveScheduled();
    } catch (_) {
      // ignore: platform notification services may be unavailable in tests
    }
  }

  Future<void> _scheduleDailyLearningReminder(TimeOfDay time) async {
    try {
      if (!_initialized) await init();
      if (!_initialized) return;

      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          'studytrace_daily_learning',
          '每日学习提醒',
          channelDescription: '每日学习记录提醒',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          showWhen: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      final scheduledDate = _nextDailyTime(time);
      await _plugin.zonedSchedule(
        id: _dailyReminderId,
        title: '学习提醒',
        body: '今天也记录一下学习进展吧。',
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: jsonEncode({'kind': 'daily_learning'}),
      );
    } catch (_) {
      // ignore: do not let notification errors break settings UI
    }
  }

  tz.TZDateTime _nextDailyTime(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> scheduleLearningAlertDigest(
    LearningAlertSettings settings,
    List<LearningAlert> alerts,
  ) async {
    try {
      if (!_initialized) await init();
      if (!_initialized) return;
      if (alerts.isEmpty) {
        await cancelLearningAlertDigest();
        return;
      }

      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          'studytrace_learning_alerts',
          '学习预警',
          channelDescription: '学习风险、复习和任务进度预警',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      final highCount =
          alerts.where((a) => a.level == LearningAlertLevel.high).length;
      final first = alerts.first;
      await _plugin.zonedSchedule(
        id: _learningAlertDigestId,
        title: highCount > 0 ? '有 $highCount 条高风险学习预警' : '今日学习预警',
        body: first.title,
        scheduledDate: _nextDailyTime(settings.digestTime),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: jsonEncode({
          'kind': 'learning_alert_digest',
          'alertId': first.id,
          'sourceType': first.sourceType,
          'sourceId': first.sourceId,
        }),
      );
    } catch (_) {
      // ignore: platform notification services may be unavailable in tests
    }
  }

  Future<void> showLearningAlertNow(LearningAlert alert) async {
    try {
      if (!_initialized) await init();
      if (!_initialized) return;
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          'studytrace_learning_alerts',
          '学习预警',
          channelDescription: '学习风险、复习和任务进度预警',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );
      await _plugin.show(
        id: _stableNotificationId('alert_${alert.id}', 300000),
        title: alert.title,
        body: alert.description,
        notificationDetails: details,
        payload: jsonEncode({
          'kind': 'learning_alert',
          'alertId': alert.id,
          'sourceType': alert.sourceType,
          'sourceId': alert.sourceId,
        }),
      );
    } catch (_) {
      // ignore: manual alert notifications are best-effort
    }
  }

  int _taskReminderId(StudyTaskItem task) =>
      _stableNotificationId('task_${task.id}', 1000);

  int _deadlineReminderId(StudyTaskItem task) =>
      _stableNotificationId('deadline_${task.id}', 101000);

  int _stableNotificationId(String value, int offset) {
    var hash = 0;
    for (final unit in value.codeUnits) {
      hash = (hash * 31 + unit) & 0x3fffffff;
    }
    return offset + (hash % 90000);
  }

  String _formatReminderBody(StudyTaskItem task) {
    final buf = StringBuffer();
    buf.writeln('课程：${task.courseName.isNotEmpty ? task.courseName : '未归类'}');
    buf.writeln('类型：${task.type.label}');
    buf.writeln('截止：${_fmtDate(task.deadline)}');
    if (task.note.isNotEmpty) {
      buf.writeln('备注：${task.note}');
    }
    return buf.toString().trim();
  }

  String _fmtDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
