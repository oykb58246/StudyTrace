import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

import '../models/study_task_item.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _scheduledKey = 'studytrace_notification_ids_v1';
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
      await _loadScheduled();
      _initialized = true;
    } catch (_) {
      // ignore: notifications require a real device
      _initialized = false;
    }
  }

  Future<void> _loadScheduled() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_scheduledKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => e as int)
          .toSet();
      _scheduledIds.addAll(list);
    } catch (_) {}
  }

  Future<void> _saveScheduled() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scheduledKey, jsonEncode(_scheduledIds.toList()));
  }

  void _onTap(NotificationResponse? response) {}

  /// Schedule a notification for a task's reminder time
  Future<int?> scheduleTaskReminder(StudyTaskItem task) async {
    final reminderTime = task.reminderTime;
    if (reminderTime == null) return null;
    if (reminderTime.isBefore(DateTime.now())) return null;

    final id = task.id.hashCode.abs() % 100000;

    final androidDetails = AndroidNotificationDetails(
      'studytrace_task_reminder',
      '任务提醒',
      channelDescription: '学习任务截止和提醒通知',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final tzDate = tz.TZDateTime.from(reminderTime, tz.local);
    await _plugin.zonedSchedule(
      id: id,
      title: '📋 ${task.title}',
      body: _formatReminderBody(task),
      scheduledDate: tzDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );

    _scheduledIds.add(id);
    await _saveScheduled();
    return id;
  }

  /// Schedule a notification for task deadline
  Future<int?> scheduleDeadlineReminder(StudyTaskItem task) async {
    final deadline = task.deadline;
    final now = DateTime.now();

    var notifyTime = DateTime(
      deadline.year,
      deadline.month,
      deadline.day - 1,
      9,
      0,
    );

    if (notifyTime.isBefore(now)) {
      notifyTime = deadline.subtract(const Duration(hours: 2));
    }
    if (notifyTime.isBefore(now)) return null;

    final id = (task.id.hashCode.abs() % 100000) + 100000;

    final androidDetails = AndroidNotificationDetails(
      'studytrace_deadline',
      '截止提醒',
      channelDescription: '任务截止日期提醒',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final tzDate = tz.TZDateTime.from(notifyTime, tz.local);
    await _plugin.zonedSchedule(
      id: id,
      title: '⏰ 截止提醒：${task.title}',
      body: '截止时间：${_fmtDate(task.deadline)}\n状态：${task.status.label}',
      scheduledDate: tzDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );

    _scheduledIds.add(id);
    await _saveScheduled();
    return id;
  }

  /// Schedule all notifications for a task
  Future<void> scheduleForTask(StudyTaskItem task) async {
    if (!_initialized || task.status == StudyTaskStatus.completed) return;
    await scheduleTaskReminder(task);
    await scheduleDeadlineReminder(task);
  }

  /// Cancel all notifications for a task
  Future<void> cancelForTask(StudyTaskItem task) async {
    if (!_initialized) return;
    final id1 = task.id.hashCode.abs() % 100000;
    final id2 = (task.id.hashCode.abs() % 100000) + 100000;
    await _plugin.cancel(id: id1);
    await _plugin.cancel(id: id2);
    _scheduledIds.remove(id1);
    _scheduledIds.remove(id2);
    await _saveScheduled();
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    _scheduledIds.clear();
    await _saveScheduled();
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
