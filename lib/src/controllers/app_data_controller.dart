import 'package:flutter/material.dart';

import '../models/analysis_item.dart';
import '../models/ai_config.dart';
import '../models/ai_flash_card.dart';
import '../models/daily_reminder_settings.dart';
import '../models/history_item.dart';
import '../models/study_log_item.dart';
import '../models/note_block.dart';
import '../models/study_note.dart';
import '../models/study_sub_task_item.dart';
import '../models/study_task_item.dart';
import '../models/todo_item.dart';
import '../models/user_profile.dart';
import '../models/weekly_report_item.dart';
import '../services/ai_credential_service.dart';
import '../services/deepseek_client.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';
import '../services/sample_data_service.dart';
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
  final List<AiFlashCard> _flashCards = [];
  final List<String> _courses = [];

  bool _isLoaded = false;
  bool _darkMode = false;
  bool _skinVivo = true; // true=vivo蓝, false=传统紫
  String _apiBaseUrl = 'http://localhost:3000';
  bool _isLoggedIn = false;

  AiConfig _aiConfig = const AiConfig();
  bool _hasDeepSeekApiKey = false;
  bool _hasBlueHeartAppKey = true; // 蓝心内置 AppKey，默认可用

  // --- legacy getters ---
  List<HistoryItem> get histories => List.unmodifiable(_histories);
  List<TodoItem> get todos => List.unmodifiable(_todos);

  // --- StudyTrace getters ---
  List<StudyTaskItem> get studyTasks => List.unmodifiable(_studyTasks);
  List<StudyLogItem> get studyLogs => List.unmodifiable(_studyLogs);
  List<WeeklyReportItem> get weeklyReports => List.unmodifiable(_weeklyReports);
  UserProfile get userProfile => _userProfile;
  List<StudyNote> get studyNotes => List.unmodifiable(_studyNotes);
  List<AiFlashCard> get flashCards => List.unmodifiable(_flashCards);

  bool get isLoaded => _isLoaded;
  bool get darkMode => _darkMode;
  bool get skinVivo => _skinVivo;
  String get apiBaseUrl => _apiBaseUrl;
  bool get isLoggedIn => _isLoggedIn;

  AiConfig get aiConfig => _aiConfig;
  Color get primaryColor =>
      _skinVivo ? const Color(0xFF4470E8) : const Color(0xFF7040F2);
  bool get hasDeepSeekApiKey => _hasDeepSeekApiKey;
  bool get hasBlueHeartAppKey => _hasBlueHeartAppKey;
  bool get isUsingRealAi =>
      (_aiConfig.isEnabled && _hasDeepSeekApiKey) || _hasBlueHeartAppKey;

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
    _skinVivo = await _storage.loadSkinVivo();
    _apiBaseUrl = await _storage.loadServerBaseUrl() ?? 'http://localhost:3000';
    final token = await _credentials.getAuthToken();
    _isLoggedIn = token != null && token.isNotEmpty;
    _aiConfig = await _storage.loadAiConfig();
    _hasDeepSeekApiKey = await _credentials.hasDeepSeekApiKey();
    _hasBlueHeartAppKey = await _credentials.hasBlueHeartAppKey();
    final loadedCourses = await _storage.loadCourses();
    _courses
      ..clear()
      ..addAll(loadedCourses);

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
    final loadedCards = await _storage.loadFlashCards();
    _flashCards
      ..clear()
      ..addAll(loadedCards);
    _isLoaded = true;
    notifyListeners();
    await NotificationService().rescheduleForTasks(_studyTasks);
  }

  /// Load sample data (for testing/demo purposes with credentials "123"/"123")
  Future<void> loadSampleData() async {
    final sampleData = SampleDataService.generateSampleData();

    _studyTasks.clear();
    _studyLogs.clear();
    _weeklyReports.clear();
    _flashCards.clear();

    _studyTasks.addAll(sampleData.tasks);
    _studyLogs.addAll(sampleData.logs);
    _weeklyReports.addAll(sampleData.reports);
    _flashCards.addAll(sampleData.flashCards);

    await _storage.saveStudyTasks(_studyTasks);
    await _storage.saveStudyLogs(_studyLogs);
    await _storage.saveWeeklyReports(_weeklyReports);
    await _storage.saveFlashCardBatch(_flashCards);

    notifyListeners();
    await NotificationService().rescheduleForTasks(_studyTasks);
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
    List<StudySubTaskItem> subTasks = const [],
    DateTime? reminderTime,
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
      subTasks: subTasks,
      reminderTime: reminderTime,
      createdAt: now,
      updatedAt: now,
    );
    _studyTasks.insert(0, task);
    await _storage.saveStudyTasks(_studyTasks);
    notifyListeners();
    await NotificationService().scheduleForTask(task);
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
    if (status == StudyTaskStatus.completed) {
      await NotificationService().cancelForTask(_studyTasks[index]);
    } else {
      await NotificationService().scheduleForTask(_studyTasks[index]);
    }
  }

  Future<void> updateStudyTask(
    String taskId, {
    required String title,
    required StudyTaskType type,
    required String courseName,
    required DateTime deadline,
    required StudyTaskStatus status,
    required String note,
    List<StudySubTaskItem>? subTasks,
    DateTime? reminderTime,
  }) async {
    final index = _studyTasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    final previous = _studyTasks[index];
    await NotificationService().cancelForTask(previous);
    _studyTasks[index] = StudyTaskItem(
      id: previous.id,
      title: title,
      type: type,
      courseName: courseName,
      deadline: deadline,
      status: status,
      note: note,
      subTasks: subTasks ?? previous.subTasks,
      reminderTime: reminderTime,
      createdAt: previous.createdAt,
      updatedAt: DateTime.now(),
    );
    await _storage.saveStudyTasks(_studyTasks);
    notifyListeners();
    await NotificationService().scheduleForTask(_studyTasks[index]);
  }

  Future<void> deleteStudyTask(String taskId) async {
    final task = _studyTasks.cast<StudyTaskItem?>().firstWhere(
          (t) => t?.id == taskId,
          orElse: () => null,
    );
    if (task != null) {
      await NotificationService().cancelForTask(task);
    }
    _studyTasks.removeWhere((t) => t.id == taskId);
    await _storage.saveStudyTasks(_studyTasks);
    notifyListeners();
  }

  Future<DailyReminderSettings> loadDailyReminderSettings() {
    return NotificationService().loadDailyReminderSettings();
  }

  Future<void> saveDailyReminderSettings(
    DailyReminderSettings settings,
  ) async {
    await NotificationService().setDailyLearningReminder(
      enabled: settings.enabled,
      time: settings.time,
    );
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

  Future<void> setSkinVivo(bool value) async {
    _skinVivo = value;
    await _storage.saveSkinVivo(value);
    notifyListeners();
  }

  Future<void> setApiBaseUrl(String url) async {
    _apiBaseUrl = url;
    await _storage.saveServerBaseUrl(url);
    notifyListeners();
  }

  Future<void> logout() async {
    _isLoggedIn = false;
    await _credentials.clearAuthToken();
    notifyListeners();
  }

  Future<void> login(String token) async {
    _isLoggedIn = true;
    await _credentials.saveAuthToken(token);
    notifyListeners();
  }

  // --- AI Settings ---

  Future<void> saveAiSettings({
    required AiConfig config,
    String? deepSeekApiKey,
    String? blueHeartAppKey,
  }) async {
    _aiConfig = config;
    await _storage.saveAiConfig(config);
    if (deepSeekApiKey != null && deepSeekApiKey.trim().isNotEmpty) {
      await _credentials.saveDeepSeekApiKey(deepSeekApiKey);
    }
    if (blueHeartAppKey != null && blueHeartAppKey.trim().isNotEmpty) {
      await _credentials.saveBlueHeartAppKey(blueHeartAppKey);
    }
    _hasDeepSeekApiKey = await _credentials.hasDeepSeekApiKey();
    _hasBlueHeartAppKey = await _credentials.hasBlueHeartAppKey();
    notifyListeners();
  }

  Future<void> deleteDeepSeekApiKey() async {
    await _credentials.deleteDeepSeekApiKey();
    _hasDeepSeekApiKey = false;
    _aiConfig = _aiConfig.copyWith(isEnabled: false);
    await _storage.saveAiConfig(_aiConfig);
    notifyListeners();
  }

  Future<void> deleteBlueHeartAppKey() async {
    await _credentials.deleteBlueHeartAppKey();
    _hasBlueHeartAppKey = false;
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
    String? parentId,
    bool isFolder = false,
    List<NoteBlock> blocks = const [],
  }) async {
    final now = DateTime.now();
    final note = StudyNote(
      id: 'note_${now.microsecondsSinceEpoch}',
      title: title,
      content: content,
      courseName: courseName,
      parentId: parentId,
      isFolder: isFolder,
      blocks: blocks,
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
    String? parentId,
    List<NoteBlock>? blocks,
  }) async {
    final index = _studyNotes.indexWhere((n) => n.id == noteId);
    if (index == -1) return;
    _studyNotes[index] = _studyNotes[index].copyWith(
      title: title,
      content: content,
      courseName: courseName,
      parentId: parentId,
      blocks: blocks,
      updatedAt: DateTime.now(),
    );
    await _storage.saveStudyNotes(_studyNotes);
    notifyListeners();
  }

  Future<void> deleteStudyNote(String noteId) async {
    // Also delete children if it's a folder
    _studyNotes.removeWhere((n) => n.id == noteId || n.parentId == noteId);
    await _storage.saveStudyNotes(_studyNotes);
    notifyListeners();
  }

  List<StudyNote> notesForFolder(String? folderId) {
    return _studyNotes.where((n) => n.parentId == folderId).toList();
  }

  List<String> get flashCardGroups {
    final groups = _flashCards
        .where((c) => c.groupName.isNotEmpty)
        .map((c) => c.groupName)
        .toSet()
        .toList()
      ..sort();
    return groups;
  }

  List<AiFlashCard> flashCardsByDate(DateTime date) =>
      _flashCards.where((c) => _sameDay(c.createdAt, date)).toList();

  Future<void> loadFlashCards() async {
    final loaded = await _storage.loadFlashCards();
    _flashCards
      ..clear()
      ..addAll(loaded);
    notifyListeners();
  }

  Future<void> saveFlashCards(List<AiFlashCard> cards) async {
    _flashCards
      ..clear()
      ..addAll(cards);
    await _storage.saveFlashCardBatch(_flashCards);
    notifyListeners();
  }

  Future<void> addFlashCards(List<AiFlashCard> cards) async {
    _flashCards.addAll(cards);
    await _storage.saveFlashCardBatch(_flashCards);
    notifyListeners();
  }

  Future<void> updateFlashCard(String cardId,
      {bool? isStarred, String? groupName}) async {
    final i = _flashCards.indexWhere((c) => c.id == cardId);
    if (i == -1) return;
    _flashCards[i] =
        _flashCards[i].copyWith(isStarred: isStarred, groupName: groupName);
    await _storage.saveFlashCardBatch(_flashCards);
    notifyListeners();
  }

  Future<void> deleteFlashCard(String cardId) async {
    _flashCards.removeWhere((c) => c.id == cardId);
    await _storage.saveFlashCardBatch(_flashCards);
    notifyListeners();
  }

  // --- Course Management ---

  List<String> get courses => List.unmodifiable(_courses);

  /// Get all courses from all sources (manual + tasks + logs)
  List<String> get allCourses {
    final set = <String>{
      ..._courses,
      for (final t in _studyTasks)
        if (t.courseName.isNotEmpty) t.courseName,
      for (final l in _studyLogs)
        if (l.courseName.isNotEmpty) l.courseName,
    };
    final sorted = set.toList()..sort();
    return sorted;
  }

  Future<void> addCourse(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _courses.contains(trimmed)) return;
    _courses.add(trimmed);
    _courses.sort();
    await _storage.saveCourses(_courses);
    notifyListeners();
  }

  Future<void> deleteCourse(String name) async {
    _courses.remove(name);
    await _storage.saveCourses(_courses);
    notifyListeners();
  }

  Future<void> renameCourse(String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == oldName) return;
    final idx = _courses.indexOf(oldName);
    if (idx >= 0) {
      _courses[idx] = trimmed;
      await _storage.saveCourses(_courses);
    }
    for (var i = 0; i < _studyTasks.length; i++) {
      if (_studyTasks[i].courseName == oldName) {
        _studyTasks[i] = _studyTasks[i].copyWith(courseName: trimmed);
      }
    }
    await _storage.saveStudyTasks(_studyTasks);
    for (var i = 0; i < _studyLogs.length; i++) {
      if (_studyLogs[i].courseName == oldName) {
        _studyLogs[i] = _studyLogs[i].copyWith(courseName: trimmed);
      }
    }
    await _storage.saveStudyLogs(_studyLogs);
    notifyListeners();
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
