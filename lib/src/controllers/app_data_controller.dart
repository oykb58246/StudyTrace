import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/achievement.dart';
import '../models/analysis_item.dart';
import '../models/ai_action_record.dart';
import '../models/ai_config.dart';
import '../models/ai_flash_card.dart';
import '../models/daily_reminder_settings.dart';
import '../models/history_item.dart';
import '../models/learning_alert.dart';
import '../models/learning_moment.dart';
import '../models/study_log_item.dart';
import '../models/note_block.dart';
import '../models/study_note.dart';
import '../models/study_sub_task_item.dart';
import '../models/study_task_item.dart';
import '../models/todo_item.dart';
import '../models/trash_item.dart';
import '../models/user_profile.dart';
import '../models/weekly_report_item.dart';
import '../services/ai_credential_service.dart';
import '../services/ai_semantic_search_service.dart';
import '../services/ai_study_service.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/activity_service.dart';
import '../services/connectivity_service.dart';
import '../services/community_evidence_service.dart';
import '../services/cloud_speech_service.dart';
import '../services/gamification_service.dart';
import '../services/group_service.dart';
import '../services/leaderboard_service.dart';
import '../services/learning_alert_service.dart';
import '../services/learning_trace_service.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';
import '../services/ocr_service.dart';
import '../services/location_evidence_service.dart';
import '../services/platform_file_saver.dart';
import '../services/sync_service.dart';
import '../services/vivo_capability_service.dart';
import '../services/weekly_report_service.dart';

class AppDataController extends ChangeNotifier {
  AppDataController({
    LocalStorageService? storage,
    AiCredentialService? credentials,
    WeeklyReportService? reportService,
    AuthService? authService,
    SyncService? syncService,
    ApiClient? apiClient,
    ConnectivityService? connectivity,
  })  : _storage = storage ?? LocalStorageService(),
        _credentials = credentials ?? AiCredentialService(),
        _reportService = reportService ?? const WeeklyReportService(),
        _authService = authService ?? AuthService(),
        _syncService = syncService ?? SyncService(),
        _apiClient = apiClient,
        _connectivity = connectivity ?? ConnectivityService();

  final LocalStorageService _storage;
  final AiCredentialService _credentials;
  final WeeklyReportService _reportService;
  final AuthService _authService;
  final SyncService _syncService;
  final ActivityService _activityService = ActivityService();
  final ApiClient? _apiClient;
  final ConnectivityService _connectivity;

  /// 全局导航 key，在 AppShell 中注入，供深层页面（如 AI Chat）切换 Tab
  GlobalKey<NavigatorState>? navigatorKey;

  /// 当前选中的底部 Tab（由 AppShell 维护，供 ACTION 使用）
  String _currentPrimaryTab = 'assistant';
  String get currentPrimaryTab => _currentPrimaryTab;
  void setCurrentPrimaryTab(String tab) {
    _currentPrimaryTab = tab;
  }

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
  final List<TrashItem> _trashItems = [];
  final List<AiActionRecord> _actionRecords = [];
  final List<LearningMoment> _learningMoments = [];
  LearningAlertSettings _learningAlertSettings =
      LearningAlertSettings.defaults;
  final LearningAlertService _learningAlertService =
      const LearningAlertService();
  final LearningTraceService _learningTraceService =
      const LearningTraceService();

  GamificationState _gamificationState = const GamificationState();
  final GamificationService _gamificationService = GamificationService();

  bool _isLoaded = false;
  bool _darkMode = false;
  bool _skinVivo = true; // true=vivo蓝, false=传统紫
  String _apiBaseUrl = _defaultBaseUrl();

  static String _defaultBaseUrl() {
    final current = Uri.base;
    if ((current.scheme == 'http' || current.scheme == 'https') &&
        current.host == 'studytrace.oykb.cn') {
      return '${current.scheme}://${current.authority}';
    }
    return 'https://studytrace.oykb.cn';
  }

  static String _normalizeBaseUrl(String value) => _defaultBaseUrl();
  bool _isLoggedIn = false;
  ApiClient? _backendApi;

  AiConfig _aiConfig = const AiConfig();

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
  List<TrashItem> get trashItems => List.unmodifiable(_trashItems);
  List<AiActionRecord> get recentActionRecords =>
      List.unmodifiable(_actionRecords);
  List<LearningMoment> get learningMoments =>
      List.unmodifiable(_learningMoments);
  LearningAlertSettings get learningAlertSettings => _learningAlertSettings;
  List<LearningAlert> get learningAlerts => _learningAlertService.buildAlerts(
        tasks: _studyTasks,
        logs: _studyLogs,
        flashCards: _flashCards,
        settings: _learningAlertSettings,
      );
  List<LearningTraceEvent> get learningTraceEvents =>
      _learningTraceService.buildTimeline(
        moments: _learningMoments,
        logs: _studyLogs,
        tasks: _studyTasks,
        notes: _studyNotes,
        flashCards: _flashCards,
        actionRecords: _actionRecords,
      );

  GamificationState get gamificationState => _gamificationState;
  int get totalPoints => _gamificationState.totalPoints;
  List<UnlockedAchievement> get unlockedAchievements =>
      _gamificationState.unlockedAchievements;
  bool isAchievementUnlocked(AchievementType type) =>
      _gamificationState.isUnlocked(type);

  ConnectivityService get connectivity => _connectivity;
  bool get isOnline => _connectivity.isOnline;
  bool get isOffline => _connectivity.isOffline;

  bool get isLoaded => _isLoaded;

  @override
  void dispose() {
    _connectivity.dispose();
    super.dispose();
  }
  bool get darkMode => _darkMode;
  bool get skinVivo => _skinVivo;
  String get apiBaseUrl => _apiBaseUrl;
  bool get isLoggedIn => _isLoggedIn;

  AuthService get authService {
    if (_isLoggedIn) {
      final api = _ensureBackendClient();
      _authService.attach(api);
    }
    return _authService;
  }

  AiStudyService get aiStudyService {
    final backend = _isLoggedIn ? _ensureBackendClient() : null;
    return AiStudyService(backendClient: backend);
  }

  OcrService createOcrService() {
    final backend = _isLoggedIn ? _ensureBackendClient() : null;
    return OcrService(
      storage: _storage,
      credentials: _credentials,
      backendClient: backend,
    );
  }

  AiSemanticSearchService createSemanticSearchService() {
    final backend = _isLoggedIn ? _ensureBackendClient() : null;
    return AiSemanticSearchService(
      backendClient: backend,
    );
  }

  GroupService get groupService {
    final api = _isLoggedIn ? _ensureBackendClient() : null;
    return GroupService(apiClient: api);
  }

  LeaderboardService get leaderboardService {
    final api = _isLoggedIn ? _ensureBackendClient() : null;
    return LeaderboardService(apiClient: api);
  }

  ActivityService get activityService {
    final api = _isLoggedIn ? _ensureBackendClient() : null;
    return ActivityService(apiClient: api);
  }

  CommunityEvidenceService get communityEvidenceService {
    final api = _isLoggedIn ? _ensureBackendClient() : null;
    return CommunityEvidenceService(apiClient: api);
  }

  VivoCapabilityService get vivoCapabilityService {
    final api = _isLoggedIn ? _ensureBackendClient() : null;
    return VivoCapabilityService(apiClient: api);
  }

  CloudSpeechService get cloudSpeechService =>
      CloudSpeechService(vivoCapabilityService);

  LocationEvidenceService get locationEvidenceService =>
      LocationEvidenceService(vivoCapabilityService, communityEvidenceService);

  AiConfig get aiConfig => _aiConfig;
  Color get primaryColor =>
      _skinVivo ? const Color(0xFF4470E8) : const Color(0xFF7040F2);
  bool get isUsingRealAi => _aiConfig.isEnabled;

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
    await _loadLocalDataFromStorage();
    final token = await _credentials.getAuthToken();
    _isLoggedIn = token != null && token.isNotEmpty;
    if (_isLoggedIn) {
      await ensureBackendAuth();
      try {
        await syncToCloud();
      } catch (_) {
        // 同步失败不阻断本地加载
      }
    }
    _isLoaded = true;
    notifyListeners();
    await NotificationService().rescheduleForTasks(_studyTasks);
    await NotificationService().setLearningAlertSettings(
      _learningAlertSettings,
      currentAlerts: learningAlerts,
    );
  }

  Future<void> _loadLocalDataFromStorage() async {
    // 并行加载所有独立的读操作，冷启动速度提升
    final results = await Future.wait([
      _storage.loadHistories(),
      _storage.loadTodos(),
      _storage.loadStudyTasks(),
      _storage.loadStudyLogs(),
      _storage.loadWeeklyReports(),
      _storage.loadDarkMode(),
      _storage.loadSkinVivo(),
      _storage.loadServerBaseUrl(),
      _credentials.getAuthToken(),
      _storage.loadAiConfig(),
      _storage.loadCourses(),
      _storage.loadUserProfile(),
      _storage.loadStudyNotes(),
      _storage.loadFlashCards(),
      _storage.loadTrashItems(),
      _storage.loadAiActionRecords(),
      _storage.loadGamificationState(),
      _storage.loadLearningMoments(),
      _storage.loadLearningAlertSettings(),
    ]);

    final loadedHistories = results[0] as List<HistoryItem>;
    final loadedTodos = results[1] as List<TodoItem>;
    final loadedTasks = results[2] as List<StudyTaskItem>;
    final loadedLogs = results[3] as List<StudyLogItem>;
    final loadedReports = results[4] as List<WeeklyReportItem>;
    _darkMode = results[5] as bool;
    _skinVivo = results[6] as bool;
    _apiBaseUrl = _defaultBaseUrl();
    final token = results[8] as String?;
    _isLoggedIn = token != null && token.isNotEmpty;
    _aiConfig = results[9] as AiConfig;
    final loadedCourses = results[10] as List<String>;
    _userProfile = results[11] as UserProfile;
    final loadedNotes = results[12] as List<StudyNote>;
    final loadedCards = results[13] as List<AiFlashCard>;
    final loadedTrash = results[14] as List<TrashItem>;
    final loadedRecords = results[15] as List<AiActionRecord>;
    _gamificationState = results[16] as GamificationState;
    final loadedMoments = results[17] as List<LearningMoment>;
    _learningAlertSettings = results[18] as LearningAlertSettings;
    await _credentials.clearLegacyAiKeys();

    if (_isLoggedIn && _isLoaded) {
      await ensureBackendAuth();
      try {
        await syncToCloud();
      } catch (_) {
        // 同步失败不阻断本地加载
      }
    }

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
    _studyNotes
      ..clear()
      ..addAll(loadedNotes);
    _flashCards
      ..clear()
      ..addAll(loadedCards);
    _trashItems
      ..clear()
      ..addAll(loadedTrash);
    _actionRecords
      ..clear()
      ..addAll(loadedRecords);
    _learningMoments
      ..clear()
      ..addAll(loadedMoments);
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
    await _refreshLearningAlertDigest();
    _queueSync();
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
      await _recordActivity(
        type: 'taskCompleted',
        title: _studyTasks[index].title,
        summary: _studyTasks[index].courseName,
        sourceType: 'study_task',
        sourceId: _studyTasks[index].id,
      );
    } else {
      await NotificationService().scheduleForTask(_studyTasks[index]);
    }
    await _refreshLearningAlertDigest();
    _queueSync();
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
    final nextSubTasks = subTasks ?? previous.subTasks;
    await NotificationService().cancelForTask(previous);
    _studyTasks[index] = StudyTaskItem(
      id: previous.id,
      title: title,
      type: type,
      courseName: courseName,
      deadline: deadline,
      status: status,
      note: note,
      subTasks: nextSubTasks,
      reminderTime: reminderTime,
      createdAt: previous.createdAt,
      updatedAt: DateTime.now(),
    );
    await _storage.saveStudyTasks(_studyTasks);
    notifyListeners();
    await NotificationService().scheduleForTask(_studyTasks[index]);
    await _recordCompletedSubTasks(previous, _studyTasks[index]);
    await _refreshLearningAlertDigest();
    _queueSync();
  }

  Future<void> _recordCompletedSubTasks(
    StudyTaskItem previous,
    StudyTaskItem current,
  ) async {
    final previousById = {
      for (final item in previous.subTasks) item.id: item,
    };
    for (final subTask in current.subTasks) {
      final old = previousById[subTask.id];
      if (old?.status == SubTaskStatus.completed ||
          subTask.status != SubTaskStatus.completed) {
        continue;
      }
      await _recordActivity(
        type: 'subTaskCompleted',
        title: subTask.title,
        summary: current.title,
        sourceType: 'study_sub_task',
        sourceId: subTask.id,
        payloadJson: {
          'taskId': current.id,
          'taskTitle': current.title,
          'courseName': current.courseName,
        },
      );
    }
  }

  Future<void> deleteStudyTask(String taskId) async {
    await _moveTaskToTrash(taskId);
  }

  Future<void> _moveTaskToTrash(String taskId) async {
    final task = _studyTasks.cast<StudyTaskItem?>().firstWhere(
          (t) => t?.id == taskId,
          orElse: () => null,
    );
    if (task == null) return;
    await NotificationService().cancelForTask(task);
    final trashItem = TrashItem(
      id: 'trash_${DateTime.now().microsecondsSinceEpoch}',
      entityType: TrashEntityType.task,
      entityId: task.id,
      title: task.title,
      payload: jsonEncode(task.toJson()),
      deletedAt: DateTime.now(),
    );
    _studyTasks.removeWhere((t) => t.id == taskId);
    _trashItems.add(trashItem);
    await _storage.saveStudyTasks(_studyTasks);
    await _storage.saveTrashItems(_trashItems);
    notifyListeners();
    await _refreshLearningAlertDigest();
    _queueSync();
    await _pushDeletedEntity(
      entityType: 'study_task',
      entityId: task.id,
      payloadJson: task.toJson(),
      deletedAt: trashItem.deletedAt,
    );
  }

  Future<void> _permanentlyDeleteTask(String taskId) async {
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
    await _refreshLearningAlertDigest();
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

  Future<void> saveLearningAlertSettings(
    LearningAlertSettings settings,
  ) async {
    _learningAlertSettings = settings;
    await _refreshLearningAlertDigest();
    notifyListeners();
  }

  Future<void> pushTopLearningAlertNow() async {
    final alerts = learningAlerts;
    if (alerts.isEmpty) return;
    await NotificationService().showLearningAlertNow(alerts.first);
  }

  Future<void> _refreshLearningAlertDigest() async {
    await NotificationService().setLearningAlertSettings(
      _learningAlertSettings,
      currentAlerts: learningAlerts,
    );
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
    await _recordActivity(
      type: 'studyLogCreated',
      title: courseName.isNotEmpty ? courseName : '学习记录',
      summary: content,
      sourceType: 'study_log',
      sourceId: log.id,
    );
    await _refreshLearningAlertDigest();
    _queueSync();
    return log;
  }

  Future<void> deleteStudyLog(String logId) async {
    await _moveLogToTrash(logId);
  }

  Future<void> _moveLogToTrash(String logId) async {
    final log = _studyLogs.cast<StudyLogItem?>().firstWhere(
          (l) => l?.id == logId,
          orElse: () => null,
    );
    if (log == null) return;
    final trashItem = TrashItem(
      id: 'trash_${DateTime.now().microsecondsSinceEpoch}',
      entityType: TrashEntityType.log,
      entityId: log.id,
      title: log.courseName.isNotEmpty ? log.courseName : '学习记录',
      payload: jsonEncode(log.toJson()),
      deletedAt: DateTime.now(),
    );
    _studyLogs.removeWhere((l) => l.id == logId);
    _trashItems.add(trashItem);
    await _storage.saveStudyLogs(_studyLogs);
    await _storage.saveTrashItems(_trashItems);
    notifyListeners();
    await _refreshLearningAlertDigest();
    _queueSync();
    await _pushDeletedEntity(
      entityType: 'study_log',
      entityId: log.id,
      payloadJson: log.toJson(),
      deletedAt: trashItem.deletedAt,
    );
  }

  Future<void> _permanentlyDeleteLog(String logId) async {
    _studyLogs.removeWhere((l) => l.id == logId);
    await _storage.saveStudyLogs(_studyLogs);
    notifyListeners();
    await _refreshLearningAlertDigest();
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
    _queueSync();
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
    _apiBaseUrl = _defaultBaseUrl();
    await _storage.saveServerBaseUrl(_apiBaseUrl);
    notifyListeners();
  }

  Future<void> logout() async {
    final refreshToken = await _credentials.getRefreshToken();
    if (_isLoggedIn && refreshToken != null && refreshToken.isNotEmpty) {
      try {
        final api = _ensureBackendClient();
        _authService.attach(api);
        await _authService.logout(refreshToken: refreshToken);
      } catch (_) {
        // 本地退出优先，不因网络失败阻塞。
      }
    }
    _isLoggedIn = false;
    _backendApi = null;
    _connectivity.stopMonitoring();
    _authService.attach(ApiClient(baseUrl: _apiBaseUrl, credentials: _credentials));
    await _credentials.clearAuthToken();
    await _credentials.clearRefreshToken();
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    if (!_isLoggedIn) return;
    try {
      final api = _ensureBackendClient();
      _authService.attach(api);
      await _authService.deleteAccount();
    } finally {
      await logout();
      await _clearLocalUserData();
    }
  }

  Future<void> _clearLocalUserData() async {
    _studyTasks.clear();
    _studyLogs.clear();
    _weeklyReports.clear();
    _studyNotes.clear();
    _flashCards.clear();
    _courses.clear();
    _trashItems.clear();
    _actionRecords.clear();
    _learningMoments.clear();
    _gamificationState = const GamificationState();
    await _storage.saveStudyTasks(_studyTasks);
    await _storage.saveStudyLogs(_studyLogs);
    await _storage.saveWeeklyReports(_weeklyReports);
    await _storage.saveStudyNotes(_studyNotes);
    await _storage.saveFlashCardBatch(_flashCards);
    await _storage.saveCourses(_courses);
    await _storage.saveTrashItems(_trashItems);
    await _storage.saveAiActionRecords(_actionRecords);
    await _storage.saveLearningMoments(_learningMoments);
    await _storage.saveGamificationState(_gamificationState);
    notifyListeners();
  }

  Future<SavedExportFile> exportAllUserData() async {
    final now = DateTime.now();
    final data = {
      'schema': 'studytrace.export.v1',
      'exportedAt': now.toIso8601String(),
      'profile': _userProfile.toJson(),
      'tasks': _studyTasks.map((item) => item.toJson()).toList(),
      'logs': _studyLogs.map((item) => item.toJson()).toList(),
      'notes': _studyNotes.map((item) => item.toJson()).toList(),
      'flashCards': _flashCards.map((item) => item.toJson()).toList(),
      'courses': _courses,
      'weeklyReports': _weeklyReports.map((item) => item.toJson()).toList(),
      'trashItems': _trashItems.map((item) => item.toJson()).toList(),
      'aiActionRecords': _actionRecords.map((item) => item.toJson()).toList(),
      'learningMoments': _learningMoments.map((item) => item.toJson()).toList(),
      'gamificationState': _gamificationState.toJson(),
    };
    return saveExportFile(
      fileName: 'studytrace_export_${_stampDateTime(now)}.json',
      mimeType: 'application/json;charset=utf-8',
      text: const JsonEncoder.withIndent('  ').convert(data),
    );
  }

  String _stampDateTime(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}_'
        '${date.hour.toString().padLeft(2, '0')}'
        '${date.minute.toString().padLeft(2, '0')}'
        '${date.second.toString().padLeft(2, '0')}';
  }

  Future<void> login(String token) async {
    _isLoggedIn = true;
    await _credentials.saveAuthToken(token);
    _backendApi ??= ApiClient(baseUrl: _apiBaseUrl, credentials: _credentials);
    _authService.attach(_backendApi!);
    notifyListeners();
  }

  Future<void> loginWithCredentials({
    required String identifier,
    required String password,
  }) async {
    final api = _ensureBackendClient();
    _authService.attach(api);
    final result = await _authService.login(
      identifier: identifier,
      password: password,
    );
    await _credentials.saveAuthToken(result.accessToken);
    await _credentials.saveRefreshToken(result.refreshToken);
    _backendApi = api;
    _isLoggedIn = true;
    if (!_isLoaded) {
      await _loadLocalDataAfterAuth();
      _isLoaded = true;
    }
    await ensureBackendAuth();
    notifyListeners();
    try {
      await syncToCloud();
    } catch (_) {
      // 登录成功但同步失败不阻断进入主界面
    }
  }

  Future<void> registerAccount({
    required String username,
    required String password,
    String? nickname,
  }) async {
    final api = _ensureBackendClient();
    _authService.attach(api);
    final result = await _authService.register(
      username: username,
      password: password,
      nickname: nickname,
    );
    await _credentials.saveAuthToken(result.accessToken);
    await _credentials.saveRefreshToken(result.refreshToken);
    _backendApi = api;
    _isLoggedIn = true;
    if (!_isLoaded) {
      await _loadLocalDataAfterAuth();
      _isLoaded = true;
    }
    await ensureBackendAuth();
    notifyListeners();
    try {
      await syncToCloud();
    } catch (_) {
      // 注册成功但同步失败不阻断进入主界面
    }
  }

  Future<void> _loadLocalDataAfterAuth() async {
    try {
      await _loadLocalDataFromStorage();
    } catch (_) {
      // Bad local cache should not turn successful cloud auth into login fail.
    } finally {
      _isLoggedIn = true;
    }
  }

  Future<void> ensureBackendAuth() async {
    final token = await _credentials.getAuthToken();
    if (token == null || token.isEmpty) return;
    final api = _ensureBackendClient();
    _backendApi = api;
    _authService.attach(api);
    _syncService.attach(api);
    _activityService.attach(api);
    _isLoggedIn = true;
    // 启动网络监控
    _connectivity.checkUrl = _apiBaseUrl;
    _connectivity.startMonitoring();
    // 监听网络恢复，自动同步
    _connectivity.statusStream.listen((status) {
      if (status == ConnectivityStatus.online && _isLoggedIn) {
        unawaited(syncToCloud());
      }
    });
  }

  ApiClient _ensureBackendClient() {
    final existing = _backendApi;
    if (existing != null) {
      existing.baseUrl = _apiBaseUrl;
      return existing;
    }
    final client = ApiClient(baseUrl: _apiBaseUrl, credentials: _credentials);
    _backendApi = client;
    return client;
  }

  Future<void> syncToCloud() async {
    if (!_isLoggedIn) return;
    final api = _ensureBackendClient();
    _syncService.attach(api);
    _activityService.attach(api);

    final localItems = _syncService.buildLocalPayloads(
      tasks: _studyTasks,
      logs: _studyLogs,
      notes: _studyNotes,
      cards: _flashCards,
      courses: _courses,
      reports: _weeklyReports,
      profile: _userProfile,
      trashItems: _trashItems,
      actionRecords: _actionRecords,
      moments: _learningMoments,
      gamificationState: _gamificationState,
    );
    await _syncService.push(localItems);

    final result = await _syncService.pull();
    _applyPullItems(result.items);
    await _persistSyncedData();
  }

  Future<void> _persistSyncedData() async {
    await _storage.saveStudyTasks(_studyTasks);
    await _storage.saveStudyLogs(_studyLogs);
    await _storage.saveStudyNotes(_studyNotes);
    await _storage.saveFlashCardBatch(_flashCards);
    await _storage.saveCourses(_courses);
    await _storage.saveWeeklyReports(_weeklyReports);
    await _storage.saveUserProfile(_userProfile);
    await _storage.saveTrashItems(_trashItems);
    await _storage.saveAiActionRecords(_actionRecords);
    await _storage.saveLearningMoments(_learningMoments);
    await _storage.saveGamificationState(_gamificationState);
  }

  void _queueSync() {
    if (!_isLoggedIn) return;
    unawaited(syncToCloud());
  }

  Future<void> _pushDeletedEntity({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> payloadJson,
    DateTime? deletedAt,
  }) async {
    if (!_isLoggedIn) return;
    try {
      final api = _ensureBackendClient();
      _syncService.attach(api);
      await _syncService.push([
        _syncService.buildDeletedPayload(
          entityType: entityType,
          entityId: entityId,
          payloadJson: payloadJson,
          deletedAt: deletedAt,
        ),
      ]);
    } catch (_) {
      // 离线或服务异常时保留本地回收站，后续全量同步会补齐。
    }
  }

  void _applyPullItems(List<SyncItemPayload> items) {
    for (final item in items) {
      final payload = _syncService.parsePayload(item);
      if (payload.isEmpty) continue;
      final isDeleted = item.deletedAt != null;
      switch (item.entityType) {
        case 'study_task':
          _applyTaskItem(item.entityId, payload, isDeleted);
        case 'study_log':
          _applyLogItem(item.entityId, payload, isDeleted);
        case 'study_note':
          _applyNoteItem(item.entityId, payload, isDeleted);
        case 'flash_card':
          _applyFlashCardItem(item.entityId, payload, isDeleted);
        case 'weekly_report':
          _applyWeeklyReportItem(item.entityId, payload, isDeleted);
        case 'course_catalog':
          _applyCourseCatalog(payload, isDeleted);
        case 'user_profile':
          _applyUserProfileItem(payload, isDeleted);
        case 'trash_item':
          _applyTrashItem(item.entityId, payload, isDeleted);
        case 'ai_action_record':
          _applyActionRecordItem(item.entityId, payload, isDeleted);
        case 'learning_moment':
          _applyLearningMomentItem(item.entityId, payload, isDeleted);
        case 'gamification_state':
          _applyGamificationState(payload, isDeleted);
      }
    }
    notifyListeners();
  }

  void _applyTaskItem(String entityId, Map<String, dynamic> payload, bool isDeleted) {
    final idx = _studyTasks.indexWhere((t) => t.id == entityId);
    if (isDeleted) {
      if (idx >= 0) _studyTasks.removeAt(idx);
      return;
    }
    final incoming = StudyTaskItem.fromJson(payload);
    if (idx >= 0) {
      final existing = _studyTasks[idx];
      if (incoming.updatedAt.isAfter(existing.updatedAt)) {
        _studyTasks[idx] = incoming;
      }
    } else {
      _studyTasks.add(incoming);
    }
  }

  void _applyLogItem(String entityId, Map<String, dynamic> payload, bool isDeleted) {
    final idx = _studyLogs.indexWhere((t) => t.id == entityId);
    if (isDeleted) {
      if (idx >= 0) _studyLogs.removeAt(idx);
      return;
    }
    final incoming = StudyLogItem.fromJson(payload);
    if (idx >= 0) {
      final existing = _studyLogs[idx];
      if (incoming.createdAt.isAfter(existing.createdAt)) {
        _studyLogs[idx] = incoming;
      }
    } else {
      _studyLogs.add(incoming);
    }
  }

  void _applyNoteItem(String entityId, Map<String, dynamic> payload, bool isDeleted) {
    final idx = _studyNotes.indexWhere((t) => t.id == entityId);
    if (isDeleted) {
      if (idx >= 0) _studyNotes.removeAt(idx);
      return;
    }
    final incoming = StudyNote.fromJson(payload);
    if (idx >= 0) {
      final existing = _studyNotes[idx];
      if (incoming.updatedAt.isAfter(existing.updatedAt)) {
        _studyNotes[idx] = incoming;
      }
    } else {
      _studyNotes.add(incoming);
    }
  }

  void _applyFlashCardItem(String entityId, Map<String, dynamic> payload, bool isDeleted) {
    final idx = _flashCards.indexWhere((t) => t.id == entityId);
    if (isDeleted) {
      if (idx >= 0) _flashCards.removeAt(idx);
      return;
    }
    final incoming = AiFlashCard.fromJson(payload);
    if (idx >= 0) {
      final existing = _flashCards[idx];
      if (incoming.createdAt.isAfter(existing.createdAt)) {
        _flashCards[idx] = incoming;
      }
    } else {
      _flashCards.add(incoming);
    }
  }

  void _applyWeeklyReportItem(
    String entityId,
    Map<String, dynamic> payload,
    bool isDeleted,
  ) {
    final idx = _weeklyReports.indexWhere((r) => r.id == entityId);
    if (isDeleted) {
      if (idx >= 0) _weeklyReports.removeAt(idx);
      return;
    }
    final incoming = WeeklyReportItem.fromJson(payload);
    if (idx >= 0) {
      if (incoming.createdAt.isAfter(_weeklyReports[idx].createdAt)) {
        _weeklyReports[idx] = incoming;
      }
    } else {
      _weeklyReports.add(incoming);
    }
  }

  void _applyCourseCatalog(Map<String, dynamic> payload, bool isDeleted) {
    if (isDeleted) return;
    final raw = payload['courses'];
    if (raw is! List) return;
    final incoming = raw.whereType<String>().where((e) => e.trim().isNotEmpty);
    _courses
      ..clear()
      ..addAll({...incoming})
      ..sort();
  }

  void _applyUserProfileItem(Map<String, dynamic> payload, bool isDeleted) {
    if (isDeleted) return;
    _userProfile = UserProfile.fromJson(payload);
  }

  void _applyTrashItem(String entityId, Map<String, dynamic> payload, bool isDeleted) {
    final idx = _trashItems.indexWhere((t) => t.id == entityId);
    if (isDeleted) {
      if (idx >= 0) _trashItems.removeAt(idx);
      return;
    }
    final incoming = TrashItem.fromJson(payload);
    if (idx >= 0) {
      if (incoming.deletedAt.isAfter(_trashItems[idx].deletedAt)) {
        _trashItems[idx] = incoming;
      }
    } else {
      _trashItems.add(incoming);
    }
  }

  void _applyActionRecordItem(
    String entityId,
    Map<String, dynamic> payload,
    bool isDeleted,
  ) {
    final idx = _actionRecords.indexWhere((r) => r.id == entityId);
    if (isDeleted) {
      if (idx >= 0) _actionRecords.removeAt(idx);
      return;
    }
    final incoming = AiActionRecord.fromJson(payload);
    if (idx >= 0) {
      if (incoming.createdAt.isAfter(_actionRecords[idx].createdAt)) {
        _actionRecords[idx] = incoming;
      }
    } else {
      _actionRecords.add(incoming);
    }
  }

  void _applyLearningMomentItem(
    String entityId,
    Map<String, dynamic> payload,
    bool isDeleted,
  ) {
    final idx = _learningMoments.indexWhere((m) => m.id == entityId);
    if (isDeleted) {
      if (idx >= 0) _learningMoments.removeAt(idx);
      return;
    }
    final incoming = LearningMoment.fromJson(payload);
    if (idx >= 0) {
      if (incoming.createdAt.isAfter(_learningMoments[idx].createdAt)) {
        _learningMoments[idx] = incoming;
      }
    } else {
      _learningMoments.add(incoming);
    }
  }

  void _applyGamificationState(Map<String, dynamic> payload, bool isDeleted) {
    if (isDeleted) return;
    final incoming = GamificationState.fromJson(payload);
    if (incoming.totalPoints >= _gamificationState.totalPoints) {
      _gamificationState = incoming;
    }
  }

  // --- AI Settings ---

  Future<void> saveAiSettings({
    required AiConfig config,
  }) async {
    _aiConfig = config;
    await _storage.saveAiConfig(config);
    notifyListeners();
  }

  // --- User Profile ---

  Future<void> updateUserProfile(UserProfile profile) async {
    _userProfile = profile;
    await _storage.saveUserProfile(profile);
    notifyListeners();
    _queueSync();
    if (_isLoggedIn) {
      try {
        final api = _ensureBackendClient();
        _authService.attach(api);
        await _authService.updateProfile(
          nickname: profile.nickname,
          avatarEmoji: profile.avatarEmoji,
          bio: profile.bio,
        );
      } catch (_) {
        // 后端更新失败不阻断本地保存
      }
    }
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
    await _recordActivity(
      type: 'noteCreated',
      title: isFolder ? '创建笔记文件夹' : '创建学习笔记',
      summary: title,
      sourceType: 'study_note',
      sourceId: note.id,
    );
    _queueSync();
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
    _queueSync();
  }

  Future<void> deleteStudyNote(String noteId) async {
    await _moveNoteToTrash(noteId);
  }

  Future<void> _moveNoteToTrash(String noteId) async {
    final note = _studyNotes.cast<StudyNote?>().firstWhere(
          (n) => n?.id == noteId,
          orElse: () => null,
    );
    if (note == null) return;
    final children = _studyNotes.where((n) => n.parentId == noteId).toList();
    final now = DateTime.now();
    final trashItem = TrashItem(
      id: 'trash_${now.microsecondsSinceEpoch}',
      entityType: TrashEntityType.note,
      entityId: note.id,
      title: note.title,
      payload: jsonEncode(note.toJson()),
      deletedAt: now,
    );
    _studyNotes.removeWhere((n) => n.id == noteId || n.parentId == noteId);
    _trashItems.add(trashItem);
    // Also trash children
    for (final child in children) {
      _trashItems.add(TrashItem(
        id: 'trash_${now.microsecondsSinceEpoch}_${children.indexOf(child)}',
        entityType: TrashEntityType.note,
        entityId: child.id,
        title: child.title,
        payload: jsonEncode(child.toJson()),
        deletedAt: now,
      ));
    }
    await _storage.saveStudyNotes(_studyNotes);
    await _storage.saveTrashItems(_trashItems);
    notifyListeners();
    _queueSync();
    await _pushDeletedEntity(
      entityType: 'study_note',
      entityId: note.id,
      payloadJson: note.toJson(),
      deletedAt: now,
    );
  }

  Future<void> _permanentlyDeleteNote(String noteId) async {
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
    await _refreshLearningAlertDigest();
    _queueSync();
  }

  Future<void> addFlashCards(List<AiFlashCard> cards) async {
    _flashCards.addAll(cards);
    await _storage.saveFlashCardBatch(_flashCards);
    notifyListeners();
    if (cards.isNotEmpty) {
      await _recordActivity(
        type: 'flashcardBatchCreated',
        title: '生成知识闪卡',
        summary: '新增 ${cards.length} 张闪卡',
        sourceType: 'flash_card_batch',
        sourceId: 'batch_${DateTime.now().microsecondsSinceEpoch}',
        payloadJson: {'cardCount': cards.length},
      );
    }
    await _refreshLearningAlertDigest();
    _queueSync();
  }

  Future<void> updateFlashCard(String cardId,
      {bool? isStarred, String? groupName}) async {
    final i = _flashCards.indexWhere((c) => c.id == cardId);
    if (i == -1) return;
    _flashCards[i] =
        _flashCards[i].copyWith(isStarred: isStarred, groupName: groupName);
    await _storage.saveFlashCardBatch(_flashCards);
    notifyListeners();
    await _refreshLearningAlertDigest();
    _queueSync();
  }

  Future<void> deleteFlashCard(String cardId) async {
    await _moveFlashCardToTrash(cardId);
  }

  Future<void> _moveFlashCardToTrash(String cardId) async {
    final card = _flashCards.cast<AiFlashCard?>().firstWhere(
          (c) => c?.id == cardId,
          orElse: () => null,
    );
    if (card == null) return;
    final trashItem = TrashItem(
      id: 'trash_${DateTime.now().microsecondsSinceEpoch}',
      entityType: TrashEntityType.flashCard,
      entityId: card.id,
      title: card.question,
      payload: jsonEncode(card.toJson()),
      deletedAt: DateTime.now(),
    );
    _flashCards.removeWhere((c) => c.id == cardId);
    _trashItems.add(trashItem);
    await _storage.saveFlashCardBatch(_flashCards);
    await _storage.saveTrashItems(_trashItems);
    notifyListeners();
    await _refreshLearningAlertDigest();
    _queueSync();
    await _pushDeletedEntity(
      entityType: 'flash_card',
      entityId: card.id,
      payloadJson: card.toJson(),
      deletedAt: trashItem.deletedAt,
    );
  }

  Future<void> _permanentlyDeleteFlashCard(String cardId) async {
    _flashCards.removeWhere((c) => c.id == cardId);
    await _storage.saveFlashCardBatch(_flashCards);
    notifyListeners();
    await _refreshLearningAlertDigest();
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
    _queueSync();
  }

  Future<void> deleteCourse(String name) async {
    _courses.remove(name);
    await _storage.saveCourses(_courses);
    notifyListeners();
    _queueSync();
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
    _queueSync();
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // --- 回收站管理 ---

  /// 恢复回收站中的条目到原列表
  Future<void> restoreFromTrash(String trashId) async {
    final index = _trashItems.indexWhere((t) => t.id == trashId);
    if (index < 0) return;
    final item = _trashItems.removeAt(index);
    try {
      final json = jsonDecode(item.payload) as Map<String, dynamic>;
      switch (item.entityType) {
        case TrashEntityType.task:
          final restoredTask =
              StudyTaskItem.fromJson({...json, 'id': item.entityId});
          _studyTasks.add(restoredTask);
          await _storage.saveStudyTasks(_studyTasks);
        case TrashEntityType.log:
          _studyLogs.add(StudyLogItem.fromJson(json));
          await _storage.saveStudyLogs(_studyLogs);
        case TrashEntityType.note:
          _studyNotes.add(StudyNote.fromJson(json));
          await _storage.saveStudyNotes(_studyNotes);
        case TrashEntityType.flashCard:
          _flashCards.add(AiFlashCard.fromJson(json));
          await _storage.saveFlashCardBatch(_flashCards);
      }
    } catch (_) {
      // 恢复失败，将 trash 条目放回
      _trashItems.insert(index, item);
    }
    await _storage.saveTrashItems(_trashItems);
    notifyListeners();
    _queueSync();
  }

  /// 从回收站永久删除单条
  Future<void> deleteTrashItemPermanently(String trashId) async {
    _trashItems.removeWhere((t) => t.id == trashId);
    await _storage.saveTrashItems(_trashItems);
    notifyListeners();
    _queueSync();
  }

  /// 清空回收站
  Future<void> emptyTrash() async {
    _trashItems.clear();
    await _storage.saveTrashItems(_trashItems);
    notifyListeners();
    _queueSync();
  }

  // --- AI 操作审计 ---

  Future<void> appendActionRecord(AiActionRecord record) async {
    _actionRecords.add(record);
    await _storage.saveAiActionRecords(_actionRecords);
    notifyListeners();
    _queueSync();
  }

  Future<void> updateActionRecord(
    String recordId, {
    AiActionStatus? status,
    String? resultMessage,
    String? errorMessage,
  }) async {
    final idx = _actionRecords.indexWhere((r) => r.id == recordId);
    if (idx < 0) return;
    _actionRecords[idx] = _actionRecords[idx].copyWith(
      status: status,
      resultMessage: resultMessage,
      errorMessage: errorMessage,
    );
    await _storage.saveAiActionRecords(_actionRecords);
    notifyListeners();
    _queueSync();
  }

  Future<void> clearActionRecords() async {
    _actionRecords.clear();
    await _storage.saveAiActionRecords(_actionRecords);
    notifyListeners();
    _queueSync();
  }

  // --- 学迹动态 ---

  Future<LearningMoment> publishLearningMoment({
    required String content,
    String courseName = '',
    List<String> imagePaths = const [],
    LearningMomentVisibility visibility = LearningMomentVisibility.private,
    String? groupId,
    String? sourceType,
    String? sourceId,
  }) async {
    final now = DateTime.now();
    final moment = LearningMoment(
      id: 'moment_${now.microsecondsSinceEpoch}',
      content: content.trim(),
      courseName: courseName.trim(),
      imagePaths: imagePaths.take(3).toList(growable: false),
      visibility: visibility,
      groupId: groupId,
      sourceType: sourceType,
      sourceId: sourceId,
      createdAt: now,
    );
    _learningMoments.insert(0, moment);
    await _storage.saveLearningMoments(_learningMoments);
    notifyListeners();
    _queueSync();
    if (visibility == LearningMomentVisibility.group &&
        groupId != null &&
        groupId.isNotEmpty) {
      await _recordActivity(
        type: 'momentShared',
        title: courseName.trim().isEmpty
            ? '分享了一条学迹动态'
            : '分享了 ${courseName.trim()} 的学习动态',
        summary: content.trim(),
        groupId: groupId,
        sourceType: sourceType ?? 'learning_moment',
        sourceId: sourceId ?? moment.id,
        payloadJson: {
          'courseName': courseName.trim(),
          'imageCount': moment.imagePaths.length,
          'visibility': visibility.name,
          if (moment.imagePaths.isNotEmpty) 'imagePaths': moment.imagePaths,
        },
      );
    }
    return moment;
  }

  Future<void> deleteLearningMoment(String momentId) async {
    final idx = _learningMoments.indexWhere((m) => m.id == momentId);
    if (idx < 0) return;
    final moment = _learningMoments.removeAt(idx);
    await _storage.saveLearningMoments(_learningMoments);
    notifyListeners();
    _queueSync();
    await _pushDeletedEntity(
      entityType: 'learning_moment',
      entityId: moment.id,
      payloadJson: moment.toJson(),
      deletedAt: DateTime.now(),
    );
  }

  Future<LearningMoment> shareTraceEvent(LearningTraceEvent event) {
    final text = [
      event.title,
      if (event.summary.trim().isNotEmpty) event.summary.trim(),
    ].join('\n');
    return publishLearningMoment(
      content: text,
      courseName: event.courseName,
      imagePaths: event.imagePaths,
      sourceType: event.type.name,
      sourceId: event.sourceId ?? event.id,
    );
  }

  Future<void> recordTimerCompleted({
    required int durationMinutes,
    String sourceId = '',
  }) async {
    await _recordActivity(
      type: 'timerCompleted',
      title: '完成专注计时',
      summary: '$durationMinutes 分钟',
      sourceType: 'timer',
      sourceId: sourceId.isNotEmpty
          ? sourceId
          : 'timer_${DateTime.now().microsecondsSinceEpoch}',
      payloadJson: {'durationMinutes': durationMinutes},
    );
  }

  Future<void> _recordActivity({
    required String type,
    required String title,
    String? summary,
    String? groupId,
    String? sourceType,
    String? sourceId,
    Map<String, dynamic>? payloadJson,
  }) async {
    if (!_isLoggedIn) return;
    try {
      final api = _ensureBackendClient();
      _activityService.attach(api);
      await _activityService.create(
        type: type,
        title: title,
        summary: summary,
        groupId: groupId,
        sourceType: sourceType,
        sourceId: sourceId,
        payloadJson: payloadJson,
      );
    } catch (_) {
      // 活动上报失败不影响本地学习流程。
    }
  }

  // --- 游戏化 ---

  /// 增加积分并保存
  Future<void> addPoints(int points) async {
    if (points <= 0) return;
    _gamificationState = _gamificationState.copyWith(
      totalPoints: _gamificationState.totalPoints + points,
    );
    await _storage.saveGamificationState(_gamificationState);
    notifyListeners();
    _queueSync();
    // 检查积分里程碑成就
    await _checkAndUnlockAchievements();
  }

  /// 解锁成就
  Future<void> _unlockAchievement(Achievement achievement) async {
    if (_gamificationState.isUnlocked(achievement.type)) return;
    final updated = List<UnlockedAchievement>.from(
      _gamificationState.unlockedAchievements,
    )..add(UnlockedAchievement(
        type: achievement.type,
        unlockedAt: DateTime.now(),
      ));
    _gamificationState = _gamificationState.copyWith(
      unlockedAchievements: updated,
      totalPoints: _gamificationState.totalPoints + achievement.points,
    );
    await _storage.saveGamificationState(_gamificationState);
    notifyListeners();
    _queueSync();
  }

  /// 检测并解锁新成就
  Future<List<Achievement>> _checkAndUnlockAchievements() async {
    final newAchievements = _gamificationService.checkAchievements(
      currentState: _gamificationState,
      tasks: _studyTasks,
      logs: _studyLogs,
      notes: _studyNotes,
      flashCards: _flashCards,
      reports: _weeklyReports,
      streakDays: studyStreak,
      aiUsageCount: _actionRecords.length,
    );
    for (final achievement in newAchievements) {
      await _unlockAchievement(achievement);
    }
    return newAchievements;
  }

  /// 记录学习操作并奖励积分（供外部调用）
  Future<List<Achievement>> onStudyAction({
    required String action,
    int? customPoints,
  }) async {
    int points = 0;
    switch (action) {
      case 'log':
        points = _gamificationService.pointsForLog();
        break;
      case 'task_completed':
        points = _gamificationService.pointsForTask(StudyTaskStatus.completed);
        break;
      case 'note':
        points = _gamificationService.pointsForNote();
        break;
      case 'flashcard':
        points = _gamificationService.pointsForFlashCard();
        break;
      case 'report':
        points = _gamificationService.pointsForReport();
        break;
    }
    if (customPoints != null) points = customPoints;
    if (points > 0) {
      _gamificationState = _gamificationState.copyWith(
        totalPoints: _gamificationState.totalPoints + points,
      );
      await _storage.saveGamificationState(_gamificationState);
      notifyListeners();
    }
    return _checkAndUnlockAchievements();
  }
}
