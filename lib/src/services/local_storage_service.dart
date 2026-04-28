import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_config.dart';
import '../models/history_item.dart';
import '../models/study_log_item.dart';
import '../models/study_note.dart';
import '../models/study_task_item.dart';
import '../models/todo_item.dart';
import '../models/user_profile.dart';
import '../models/weekly_report_item.dart';

class LocalStorageService {
  static const _historyKey = 'linxi_analysis_history_v1';
  static const _todoKey = 'linxi_todo_items_v1';
  static const _studyTasksKey = 'studytrace_tasks_v1';
  static const _studyLogsKey = 'studytrace_logs_v1';
  static const _weeklyReportsKey = 'studytrace_weekly_reports_v1';
  static const _darkModeKey = 'studytrace_dark_mode_v1';
  static const _aiConfigKey = 'studytrace_ai_config_v1';

  // --- Histories ---

  Future<List<HistoryItem>> loadHistories() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => HistoryItem.fromJson(item.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveHistories(List<HistoryItem> histories) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(histories.map((item) => item.toJson()).toList());
    await prefs.setString(_historyKey, raw);
  }

  // --- Todos ---

  Future<List<TodoItem>> loadTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_todoKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => TodoItem.fromJson(item.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveTodos(List<TodoItem> todos) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(todos.map((item) => item.toJson()).toList());
    await prefs.setString(_todoKey, raw);
  }

  // --- Study Tasks ---

  Future<List<StudyTaskItem>> loadStudyTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_studyTasksKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => StudyTaskItem.fromJson(item.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveStudyTasks(List<StudyTaskItem> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(tasks.map((item) => item.toJson()).toList());
    await prefs.setString(_studyTasksKey, raw);
  }

  // --- Study Logs ---

  Future<List<StudyLogItem>> loadStudyLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_studyLogsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => StudyLogItem.fromJson(item.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveStudyLogs(List<StudyLogItem> logs) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(logs.map((item) => item.toJson()).toList());
    await prefs.setString(_studyLogsKey, raw);
  }

  // --- Weekly Reports ---

  Future<List<WeeklyReportItem>> loadWeeklyReports() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_weeklyReportsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
              (item) => WeeklyReportItem.fromJson(item.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveWeeklyReports(List<WeeklyReportItem> reports) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(reports.map((item) => item.toJson()).toList());
    await prefs.setString(_weeklyReportsKey, raw);
  }

  // --- Dark Mode ---

  Future<bool> loadDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_darkModeKey) ?? false;
  }

  Future<void> saveDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, value);
  }

  // --- AI Config ---

  Future<AiConfig> loadAiConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_aiConfigKey);
    if (raw == null || raw.isEmpty) return const AiConfig();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const AiConfig();
      return AiConfig.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {
      return const AiConfig();
    }
  }

  Future<void> saveAiConfig(AiConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_aiConfigKey, jsonEncode(config.toJson()));
  }

  // --- User Profile ---
  static const _profileKey = 'studytrace_user_profile_v1';

  Future<UserProfile> loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw == null || raw.isEmpty) return const UserProfile();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const UserProfile();
      return UserProfile.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {
      return const UserProfile();
    }
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  // --- Study Notes ---
  static const _notesKey = 'studytrace_notes_v1';

  Future<List<StudyNote>> loadStudyNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_notesKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => StudyNote.fromJson(item.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveStudyNotes(List<StudyNote> notes) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(notes.map((item) => item.toJson()).toList());
    await prefs.setString(_notesKey, raw);
  }
}
