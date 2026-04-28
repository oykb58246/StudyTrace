import 'package:flutter/foundation.dart';

import '../models/analysis_item.dart';
import '../models/ai_config.dart';
import '../models/history_item.dart';
import '../models/study_log_item.dart';
import '../models/study_note.dart';
import '../models/study_task_item.dart';
import '../models/todo_item.dart';
import '../models/user_profile.dart';
import '../models/weekly_report_item.dart';
import '../services/ai_credential_service.dart';
import '../services/deepseek_client.dart';
import '../services/local_storage_service.dart';
import '../services/weekly_report_service.dart';

class AppDataController extends ChangeNotifier {
  AppDataController({
    LocalStorageService? storage,
    AiCredentialService? credentials,
    DeepSeekClient? deepSeekClient,
    WeeklyReportService? reportService,
  })  : _storage = storage ?? LocalStorageService(),
        _credentials = credentials ?? AiCredentialService(),
        _deepSeekClient = deepSeekClient ?? DeepSeekClient(),
        _reportService = reportService ?? const WeeklyReportService();

  final LocalStorageService _storage;
  final AiCredentialService _credentials;
  final DeepSeekClient _deepSeekClient;
  final WeeklyReportService _reportService;

  // --- legacy ---
  final List<HistoryItem> _histories = [];
  final List<TodoItem> _todos = [];

  // --- StudyTrace ---
  final List<StudyTaskItem> _studyTasks = [];
  final List<StudyLogItem> _studyLogs = [];
  final List<WeeklyReportItem> _weeklyReports = [];

  UserProfile _userProfile = const UserProfile();
  final List<StudyNote> _studyNotes = [];

  bool _isLoaded = false;
  bool _darkMode = false;
  AiConfig _aiConfig = const AiConfig();
  bool _hasDeepSeekApiKey = false;

  // --- legacy getters ---
  List<HistoryItem> get histories => List.unmodifiable(_histories);
  List<TodoItem> get todos => List.unmodifiable(_todos);

  // --- StudyTrace getters ---
  List<StudyTaskItem> get studyTasks => List.unmodifiable(_studyTasks);
  List<StudyLogItem> get studyLogs => List.unmodifiable(_studyLogs);
  List<WeeklyReportItem> get weeklyReports => List.unmodifiable(_weeklyReports);
  UserProfile get userProfile => _userProfile;
  List<StudyNote> get studyNotes => List.unmodifiable(_studyNotes);

  bool get isLoaded => _isLoaded;
  bool get darkMode => _darkMode;
  AiConfig get aiConfig => _aiConfig;
  bool get hasDeepSeekApiKey => _hasDeepSeekApiKey;
  bool get isUsingRealAi => _aiConfig.isEnabled && _hasDeepSeekApiKey;

  int get studyStreak {
    if (_studyLogs.isEmpty) return 0;
    final dates = _studyLogs
        .map((l) => DateTime(l.date.year, l.date.month, l.date.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    if (dates.isEmpty) return 0;

    var streak = 0;
    var current = DateTime.now();
    // Check if studied today or yesterday to start streak
    final latest = dates.first;
    final diff = current.difference(latest).inDays;
    if (diff > 1) return 0; // Streak broken, no study in last 2 days

    // Count consecutive days from the latest log
    current = latest;
    for (final date in dates) {
      final dayDiff = current.difference(date).inDays;
      if (dayDiff <= 1) {
        if (dayDiff == 0 || dayDiff == 1) {
          streak++;
          current = date;
        }
      } else {
        break;
      }
    }
    return streak;
  }

  List<String> get courseNames {
    final names = <String>{};
    for (final task in _studyTasks) {
      if (task.courseName.isNotEmpty) names.add(task.courseName);
    }
    for (final log in _studyLogs) {
      if (log.courseName.isNotEmpty) names.add(log.courseName);
    }
    final sorted = names.toList()..sort();
    return sorted;
  }

  List<StudyTaskItem> tasksForCourse(String courseName) {
    return _studyTasks
        .where((t) => t.courseName == courseName)
        .toList(growable: false);
  }

  List<StudyLogItem> logsForCourse(String courseName) {
    return _studyLogs
        .where((l) => l.courseName == courseName)
        .toList(growable: false);
  }

  Future<void> load() async {
    final loadedHistories = await _storage.loadHistories();
    final loadedTodos = await _storage.loadTodos();
    final loadedTasks = await _storage.loadStudyTasks();
    final loadedLogs = await _storage.loadStudyLogs();
    final loadedReports = await _storage.loadWeeklyReports();
    _darkMode = await _storage.loadDarkMode();
    _aiConfig = await _storage.loadAiConfig();
    _hasDeepSeekApiKey = await _credentials.hasDeepSeekApiKey();

    _histories
      ..clear()
      ..addAll(loadedHistories);
    _todos
      ..clear()
      ..addAll(loadedTodos);
    _studyTasks
      ..clear()
      ..addAll(loadedTasks);
    _studyLogs
      ..clear()
      ..addAll(loadedLogs);
    _weeklyReports
      ..clear()
      ..addAll(loadedReports);
    _userProfile = await _storage.loadUserProfile();
    final loadedNotes = await _storage.loadStudyNotes();
    _studyNotes
      ..clear()
      ..addAll(loadedNotes);
    _isLoaded = true;
    notifyListeners();
  }

  // --- legacy ---

  bool hasHistory(String analysisId) {
    return _histories.any((item) => item.analysis.id == analysisId);
  }

  Future<void> saveAnalysis(AnalysisItem item) async {
    if (hasHistory(item.id)) return;
    _histories.insert(
      0,
      HistoryItem(
        id: 'history_${DateTime.now().microsecondsSinceEpoch}',
        analysis: item,
        createdAt: DateTime.now(),
      ),
    );
    await _storage.saveHistories(_histories);
    notifyListeners();
  }

  Future<TodoItem> addTodoFromAnalysis(AnalysisItem item) async {
    final todo = _todoFromAction(
      item: item,
      action: item.suggestedActions.isNotEmpty
          ? item.suggestedActions.first
          : item.summary,
      offsetDays: 1,
    );
    _todos.insert(0, todo);
    await _storage.saveTodos(_todos);
    notifyListeners();
    return todo;
  }

  Future<List<TodoItem>> generatePlanFromAnalysis(AnalysisItem item) async {
    final actions = item.suggestedActions.isEmpty
        ? const ['保存分析结果', '整理下一步行动', '完成后复盘']
        : item.suggestedActions;
    final generated = <TodoItem>[
      for (var i = 0; i < actions.length; i++)
        _todoFromAction(item: item, action: actions[i], offsetDays: i + 1),
    ];
    _todos.insertAll(0, generated.reversed);
    await _storage.saveTodos(_todos);
    notifyListeners();
    return generated;
  }

  Future<void> toggleTodo(String todoId) async {
    final index = _todos.indexWhere((item) => item.id == todoId);
    if (index == -1) return;
    final current = _todos[index];
    _todos[index] = current.copyWith(isCompleted: !current.isCompleted);
    await _storage.saveTodos(_todos);
    notifyListeners();
  }

  Future<void> deleteTodo(String todoId) async {
    _todos.removeWhere((item) => item.id == todoId);
    await _storage.saveTodos(_todos);
    notifyListeners();
  }

  TodoItem _todoFromAction({
    required AnalysisItem item,
    required String action,
    required int offsetDays,
  }) {
    final now = DateTime.now();
    return TodoItem(
      id: 'todo_${now.microsecondsSinceEpoch}_$offsetDays',
      title: action,
      description: item.summary,
      dueTime: DateTime(now.year, now.month, now.day + offsetDays, 20),
      isCompleted: false,
      sourceAnalysisId: item.id,
      createdAt: now,
    );
  }

  // --- StudyTrace: Tasks ---

  Future<StudyTaskItem> addStudyTask({
    required String title,
    required StudyTaskType type,
    required String courseName,
    required DateTime deadline,
    StudyTaskStatus status = StudyTaskStatus.notStarted,
    String note = '',
    List<String> subtasks = const [],
  }) async {
    final now = DateTime.now();
    final task = StudyTaskItem(
      id: 'task_${now.microsecondsSinceEpoch}',
      title: title,
      type: type,
      courseName: courseName,
      deadline: deadline,
      status: status,
      note: note,
      subtasks: subtasks,
      createdAt: now,
      updatedAt: now,
    );
    _studyTasks.insert(0, task);
    await _storage.saveStudyTasks(_studyTasks);
    notifyListeners();
    return task;
  }

  Future<void> updateStudyTaskStatus(
    String taskId,
    StudyTaskStatus status,
  ) async {
    final index = _studyTasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    _studyTasks[index] = _studyTasks[index].copyWith(
      status: status,
      updatedAt: DateTime.now(),
    );
    await _storage.saveStudyTasks(_studyTasks);
    notifyListeners();
  }

  Future<void> updateStudyTask(
    String taskId, {
    required String title,
    required StudyTaskType type,
    required String courseName,
    required DateTime deadline,
    required StudyTaskStatus status,
    required String note,
    List<String>? subtasks,
  }) async {
    final index = _studyTasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    _studyTasks[index] = _studyTasks[index].copyWith(
      title: title,
      type: type,
      courseName: courseName,
      deadline: deadline,
      status: status,
      note: note,
      subtasks: subtasks,
      updatedAt: DateTime.now(),
    );
    await _storage.saveStudyTasks(_studyTasks);
    notifyListeners();
  }

  Future<void> deleteStudyTask(String taskId) async {
    _studyTasks.removeWhere((t) => t.id == taskId);
    await _storage.saveStudyTasks(_studyTasks);
    notifyListeners();
  }

  // --- StudyTrace: Logs ---

  Future<StudyLogItem> addStudyLog({
    required DateTime date,
    required String courseName,
    String content = '',
    String problems = '',
    String thoughts = '',
    String nextPlan = '',
  }) async {
    final now = DateTime.now();
    final log = StudyLogItem(
      id: 'log_${now.microsecondsSinceEpoch}',
      date: date,
      courseName: courseName,
      content: content,
      problems: problems,
      thoughts: thoughts,
      nextPlan: nextPlan,
      createdAt: now,
    );
    _studyLogs.insert(0, log);
    _studyLogs.sort((a, b) => b.date.compareTo(a.date));
    await _storage.saveStudyLogs(_studyLogs);
    notifyListeners();
    return log;
  }

  Future<void> deleteStudyLog(String logId) async {
    _studyLogs.removeWhere((l) => l.id == logId);
    await _storage.saveStudyLogs(_studyLogs);
    notifyListeners();
  }

  // --- StudyTrace: Weekly Reports ---

  String generateWeeklyReportContent({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final logs = _studyLogs
        .where((l) => !l.date.isBefore(startDate) && !l.date.isAfter(endDate))
        .toList();
    final tasks = _studyTasks
        .where((t) =>
            !t.deadline.isBefore(startDate) && !t.deadline.isAfter(endDate))
        .toList();
    return _reportService.generate(
      startDate: startDate,
      endDate: endDate,
      logs: logs,
      tasks: tasks,
    );
  }

  Future<WeeklyReportItem> saveWeeklyReport(
    String content, {
    required DateTime startDate,
    required DateTime endDate,
    List<String> sourceLogIds = const [],
  }) async {
    final now = DateTime.now();
    final report = WeeklyReportItem(
      id: 'report_${now.microsecondsSinceEpoch}',
      startDate: startDate,
      endDate: endDate,
      content: content,
      sourceLogIds: sourceLogIds,
      createdAt: now,
    );
    _weeklyReports.insert(0, report);
    await _storage.saveWeeklyReports(_weeklyReports);
    notifyListeners();
    return report;
  }

  // --- Dark Mode ---

  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    await _storage.saveDarkMode(value);
    notifyListeners();
  }

  // --- AI Settings ---

  Future<void> saveAiSettings({
    required AiConfig config,
    String? deepSeekApiKey,
  }) async {
    _aiConfig = config;
    await _storage.saveAiConfig(config);
    if (deepSeekApiKey != null && deepSeekApiKey.trim().isNotEmpty) {
      await _credentials.saveDeepSeekApiKey(deepSeekApiKey);
    }
    _hasDeepSeekApiKey = await _credentials.hasDeepSeekApiKey();
    notifyListeners();
  }

  Future<void> deleteDeepSeekApiKey() async {
    await _credentials.deleteDeepSeekApiKey();
    _hasDeepSeekApiKey = false;
    _aiConfig = _aiConfig.copyWith(isEnabled: false);
    await _storage.saveAiConfig(_aiConfig);
    notifyListeners();
  }

  Future<bool> testDeepSeekConnection({
    String? candidateApiKey,
    AiConfig? config,
  }) async {
    final apiKey = candidateApiKey?.trim().isNotEmpty == true
        ? candidateApiKey!.trim()
        : await _credentials.loadDeepSeekApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw const AiServiceException('请先填写 DeepSeek API Key');
    }
    return _deepSeekClient.testConnection(
      config: config ?? _aiConfig,
      apiKey: apiKey,
    );
  }

  // --- User Profile ---

  Future<void> updateUserProfile(UserProfile profile) async {
    _userProfile = profile;
    await _storage.saveUserProfile(profile);
    notifyListeners();
  }

  // --- Study Notes ---

  Future<StudyNote> addStudyNote({
    required String title,
    required String content,
    String courseName = '',
  }) async {
    final now = DateTime.now();
    final note = StudyNote(
      id: 'note_${now.microsecondsSinceEpoch}',
      title: title,
      content: content,
      courseName: courseName,
      createdAt: now,
      updatedAt: now,
    );
    _studyNotes.insert(0, note);
    await _storage.saveStudyNotes(_studyNotes);
    notifyListeners();
    return note;
  }

  Future<void> updateStudyNote(
    String noteId, {
    required String title,
    required String content,
    String? courseName,
  }) async {
    final index = _studyNotes.indexWhere((n) => n.id == noteId);
    if (index == -1) return;
    _studyNotes[index] = _studyNotes[index].copyWith(
      title: title,
      content: content,
      courseName: courseName,
      updatedAt: DateTime.now(),
    );
    await _storage.saveStudyNotes(_studyNotes);
    notifyListeners();
  }

  Future<void> deleteStudyNote(String noteId) async {
    _studyNotes.removeWhere((n) => n.id == noteId);
    await _storage.saveStudyNotes(_studyNotes);
    notifyListeners();
  }
}
