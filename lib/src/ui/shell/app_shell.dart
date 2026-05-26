import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import '../../controllers/app_data_controller.dart';
import '../../models/ai_action_record.dart';
import '../../models/ai_app_action.dart';
import '../../models/weekly_report_item.dart';
import '../../services/ai_action_executor.dart';
import '../../services/ai_study_service.dart';
import '../../services/report_export_service.dart';
import '../../theme/app_theme.dart';
import '../study/about_page.dart';
import '../study/achievements_page.dart';
import '../shell/audit_log_page.dart';
import '../shell/trash_page.dart';
import '../study/ai_assistant_page.dart';
import '../study/ai_chat_page.dart';
import '../study/ai_learning_cockpit_page.dart';
import '../study/ai_settings_page.dart';
import '../study/calendar_page.dart';
import '../study/flash_card_page.dart';
import '../study/knowledge_graph_page.dart';
import '../study/leaderboard_page.dart';
import '../study/learning_moments_page.dart';
import '../study/learning_dashboard_page.dart';
import '../study/study_group_page.dart';
import '../study/study_notes_page.dart';
import '../study/task_planning_page.dart';
import '../study/timer_page.dart';
import '../study/user_profile_page.dart';
import '../shared/app_assets.dart';
import '../shared/local_image.dart';
import '../shared/page_wrapper.dart';
import '../shared/rive_safe_widget.dart';
import '../shared/snackbar_queue.dart';
import 'admin_section_page.dart';
import 'create_page.dart';
import 'extension_page.dart';
import 'navigation_models.dart';
import 'tool_home_page.dart';
import 'user_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.initialController,
    this.debugMenuInitiallyOpen = false,
    this.debugInitialPrimaryTab,
    this.debugInitialAdminSection,
  });

  final AppDataController? initialController;
  final bool debugMenuInitiallyOpen;
  final PrimaryTab? debugInitialPrimaryTab;
  final AdminSection? debugInitialAdminSection;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _menuController;
  late final AppDataController _appDataController;

  late PrimaryTab _primaryTab;
  AdminSection? _activeAdminSection;
  bool _isDarkMode = false;
  bool _allowDrag = false;
  double _menuWidth = 300;

  /// 0 = 未知, 1 = 在线, -1 = 离线
  int _backendReachable = 0;

  @override
  void initState() {
    super.initState();
    _appDataController = widget.initialController ?? AppDataController();
    _primaryTab = widget.debugInitialPrimaryTab ?? PrimaryTab.assistant;
    _appDataController.setCurrentPrimaryTab(_primaryTab.name);
    _activeAdminSection = widget.debugInitialAdminSection;
    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 200),
      animationBehavior: AnimationBehavior.preserve,
      value: widget.debugMenuInitiallyOpen ? 1 : 0,
    );
    unawaited(_loadData());
  }

  Future<void> _loadData() async {
    if (!_appDataController.isLoaded) {
      await _appDataController.load();
    }
    if (mounted) {
      setState(() => _isDarkMode = _appDataController.darkMode);
    }
    unawaited(_checkBackendReachable());
  }

  Future<void> _checkBackendReachable() async {
    if (!_appDataController.isLoggedIn) {
      if (mounted) setState(() => _backendReachable = 0);
      return;
    }
    try {
      final url = _appDataController.apiBaseUrl;
      final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 4),
          );
      final reachable = response.statusCode < 500;
      if (mounted) setState(() => _backendReachable = reachable ? 1 : -1);
    } catch (_) {
      if (mounted) setState(() => _backendReachable = -1);
    }
  }

  @override
  void dispose() {
    _menuController.dispose();
    _appDataController.dispose();
    super.dispose();
  }

  void _openMenu() => _menuController.forward();

  void _closeMenu() {
    _menuController.reverse();
  }

  void _toggleMenu() {
    if (_menuController.value > 0.5) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  void _openAiChat() {
    _pushAnimatedPage(
      AiChatPage(
        isDarkMode: _isDarkMode,
        controller: _appDataController,
        onExecuteActions: _executeAssistantActions,
        currentLocation: _primaryTab.name,
      ),
    );
  }

  void _pushAnimatedPage(Widget page) {
    Navigator.of(context).push(
      PageRouteBuilder(
        fullscreenDialog: false,
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (context, __, ___) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SharedAxisTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            transitionType: SharedAxisTransitionType.scaled,
            child: child,
          );
        },
      ),
    );
  }

  Future<List<AiActionResult>> _executeAssistantActions({
    required List<AiAppAction> actions,
    required String input,
    required String assistantReply,
  }) {
    final executor = AiActionExecutor(
      controller: _appDataController,
      aiService: _appDataController.aiStudyService,
      onNavigationAction: _executeNavigationAction,
    );
    return executor.execute(
      actions: actions,
      input: input,
      assistantReply: assistantReply,
    );
  }

  /// 审计页"重试"按钮回调：把失败的 AiActionRecord 重建成 AiAppAction 再跑
  Future<void> _retryAuditRecord(AiActionRecord record) async {
    final type = _actionTypeFromToolId(record.toolId);
    if (type == null) {
      _showShellSnack('该动作无法重试（未识别 toolId）');
      return;
    }
    final params = record.params ?? <String, dynamic>{};
    final action = AiAppAction(
      type: type,
      targetId: record.targetId,
      targetTitle: record.targetTitle,
      status: params['status'] as String?,
      title: params['title'] as String?,
      content: params['content'] as String?,
      sourceText: params['sourceText'] as String?,
    );
    final results = await _executeAssistantActions(
      actions: [action],
      input: params['sourceText'] as String? ?? '',
      assistantReply: '',
    );
    if (!mounted) return;
    final r = results.isNotEmpty ? results.first : null;
    _showShellSnack(
      r == null
          ? '重试失败'
          : (r.success ? '重试成功：${r.message}' : '重试失败：${r.message}'),
    );
  }

  /// 从 toolId（命名空间格式）解析出 AiAppActionType
  AiAppActionType? _actionTypeFromToolId(String toolId) {
    return aiAppActionTypeFromWire(toolId);
  }

  Future<AiActionResult> _executeNavigationAction(AiAppAction action) async {
    try {
      _closeMenu();
      switch (action.type) {
        case AiAppActionType.switchTab:
          final tab = _tabFromAssistantAction(action);
          if (tab == null) {
            return AiActionResult(
              action: action,
              success: false,
              message: '没有识别到要切换的页面',
            );
          }
          _openPrimaryTabFromAssistant(tab);
          _showShellSnack('已打开${tab.label}');
          return AiActionResult(
            action: action,
            success: true,
            message: '已打开${tab.label}，返回可回到对话',
          );
        case AiAppActionType.openTimer:
          _pushAnimatedPage(TimerPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
          ));
          return _navigationSuccess(action, '已打开专注计时器');
        case AiAppActionType.startFocus:
          final minutes = _parseFocusMinutes(action);
          _pushAnimatedPage(TimerPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
            initialMinutes: minutes,
            autoStart: true,
          ));
          return _navigationSuccess(action, '已开始 $minutes 分钟专注');
        case AiAppActionType.startFocusWithTask:
          final minutes = _parseFocusMinutes(action);
          final task = _taskForFocusAction(action);
          _pushAnimatedPage(TimerPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
            initialMinutes: minutes,
            autoStart: true,
          ));
          return _navigationSuccess(
            action,
            task == null
                ? '已开始 $minutes 分钟专注'
                : '已围绕「${task.title}」开始 $minutes 分钟专注',
          );
        case AiAppActionType.openFlashcard:
          _pushAnimatedPage(FlashCardPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
          ));
          return _navigationSuccess(action, '已打开知识闪卡');
        case AiAppActionType.openNotes:
          _pushAnimatedPage(StudyNotesPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
          ));
          return _navigationSuccess(action, '已打开学习笔记');
        case AiAppActionType.openAiSettings:
          _pushAnimatedPage(PageWithBackButton(
            title: 'AI 设置',
            isDarkMode: _isDarkMode,
            child: AiSettingsPage(
              isDarkMode: _isDarkMode,
              controller: _appDataController,
            ),
          ));
          return _navigationSuccess(action, '已打开 AI 设置');
        case AiAppActionType.openDashboard:
          _pushAnimatedPage(PageWithBackButton(
            title: '数据看板',
            isDarkMode: _isDarkMode,
            child: LearningDashboardPage(
              isDarkMode: _isDarkMode,
              controller: _appDataController,
            ),
          ));
          return _navigationSuccess(action, '已打开数据看板');
        case AiAppActionType.openTaskPlanning:
          _pushAnimatedPage(PageWithBackButton(
            title: '任务编排',
            isDarkMode: _isDarkMode,
            child: TaskPlanningPage(
              isDarkMode: _isDarkMode,
              controller: _appDataController,
            ),
          ));
          return _navigationSuccess(action, '已打开任务编排');
        case AiAppActionType.openAiAssistant:
          _pushAnimatedPage(PageWithBackButton(
            title: 'AI 功能',
            isDarkMode: _isDarkMode,
            child: AiAssistantPage(
              isDarkMode: _isDarkMode,
              controller: _appDataController,
              onExecuteActions: _executeAssistantActions,
              onOpenSettings: () => _pushAnimatedPage(PageWithBackButton(
                title: 'AI 设置',
                isDarkMode: _isDarkMode,
                child: AiSettingsPage(
                  isDarkMode: _isDarkMode,
                  controller: _appDataController,
                ),
              )),
            ),
          ));
          return _navigationSuccess(action, '已打开 AI 功能');
        case AiAppActionType.openUserProfile:
          _pushAnimatedPage(PageWithBackButton(
            title: '个人资料',
            isDarkMode: _isDarkMode,
            child: UserProfilePage(
              isDarkMode: _isDarkMode,
              controller: _appDataController,
            ),
          ));
          return _navigationSuccess(action, '已打开个人资料');
        case AiAppActionType.openAbout:
          _pushAnimatedPage(PageWithBackButton(
            title: '应用介绍',
            isDarkMode: _isDarkMode,
            child: AboutPage(isDarkMode: _isDarkMode),
          ));
          return _navigationSuccess(action, '已打开应用介绍');
        case AiAppActionType.openStudyGroup:
          _pushAnimatedPage(PageWithBackButton(
            title: '学习小组',
            isDarkMode: _isDarkMode,
            child: StudyGroupPage(
              isDarkMode: _isDarkMode,
              controller: _appDataController,
            ),
          ));
          return _navigationSuccess(action, '已打开学习小组');
        case AiAppActionType.openLeaderboard:
          _pushAnimatedPage(PageWithBackButton(
            title: '排行榜',
            isDarkMode: _isDarkMode,
            child: LeaderboardPage(
              isDarkMode: _isDarkMode,
              controller: _appDataController,
            ),
          ));
          return _navigationSuccess(action, '已打开排行榜');
        case AiAppActionType.openWeeklyReport:
          _pushAnimatedPage(PageWithBackButton(
            title: '学习周报',
            isDarkMode: _isDarkMode,
            child: _WeeklyReportPage(
              controller: _appDataController,
              isDarkMode: _isDarkMode,
              autoGenerate: true,
            ),
          ));
          return _navigationSuccess(action, '已打开学习周报');
        case AiAppActionType.openSystemSettings:
          _pushAnimatedPage(PageWithBackButton(
            title: '系统设置',
            isDarkMode: _isDarkMode,
            child: AiSettingsPage(
              isDarkMode: _isDarkMode,
              controller: _appDataController,
              mode: AiSettingsMode.system,
            ),
          ));
          return _navigationSuccess(action, '已打开系统设置');
        default:
          return AiActionResult(
            action: action,
            success: false,
            message: '这个操作不是导航动作',
          );
      }
    } catch (error) {
      return AiActionResult(
        action: action,
        success: false,
        message: '导航失败：$error',
      );
    }
  }

  AiActionResult _navigationSuccess(AiAppAction action, String message) {
    _showShellSnack(message);
    return AiActionResult(action: action, success: true, message: message);
  }

  void _openPrimaryTabFromAssistant(PrimaryTab tab) {
    _pushAnimatedPage(PageWithBackButton(
      title: tab.label,
      isDarkMode: _isDarkMode,
      child: _primaryPageFor(tab),
    ));
  }

  PrimaryTab? _tabFromAssistantAction(AiAppAction action) {
    final value = (action.targetId ??
            action.targetTitle ??
            action.title ??
            action.content ??
            '')
        .trim()
        .toLowerCase();
    return switch (value) {
      'assistant' || 'home' || '首页' || '主页' => PrimaryTab.assistant,
      'scenarios' || 'logs' || 'log' || '记录' || '日志' || '学习记录' =>
        PrimaryTab.scenarios,
      'calendar' || '日历' => PrimaryTab.calendar,
      'create' || 'tasks' || 'task' || '任务' || '任务页' =>
        PrimaryTab.create,
      'profile' || 'archive' || '归档' || '课程归档' => PrimaryTab.profile,
      _ => null,
    };
  }

  int _parseFocusMinutes(AiAppAction action) {
    final raw = (action.status ??
            action.content ??
            action.title ??
            action.sourceText ??
            '')
        .trim();
    if (raw.isEmpty) return 25;
    final match = RegExp(r'(\d+)').firstMatch(raw);
    if (match == null) return 25;
    final n = int.tryParse(match.group(1) ?? '') ?? 25;
    return n.clamp(1, 180);
  }

  void _openLearningCockpit() {
    _pushAnimatedPage(AiLearningCockpitPage(
      isDarkMode: _isDarkMode,
      controller: _appDataController,
      onOpenAiChat: _openAiChat,
    ));
  }

  dynamic _taskForFocusAction(AiAppAction action) {
    final targetId = action.targetId?.trim();
    if (targetId == null || targetId.isEmpty) return null;
    for (final task in _appDataController.studyTasks) {
      if (task.id == targetId) return task;
    }
    return null;
  }

  void _showShellSnack(String message) {
    if (!mounted) return;
    SnackBarQueue.instance.enqueue(
      message,
      duration: const Duration(seconds: 2),
      messenger: ScaffoldMessenger.of(context),
    );
  }

  void _handleDragStart(DragStartDetails details) {
    _allowDrag = _menuController.value > 0 || details.globalPosition.dx < 28;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_allowDrag) return;
    _menuController.value = (_menuController.value +
            (details.primaryDelta ?? 0) / math.max(_menuWidth, 1))
        .clamp(0.0, 1.0);
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_allowDrag) return;
    _allowDrag = false;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity > 240) {
      _openMenu();
    } else if (velocity < -240) {
      _closeMenu();
    } else if (_menuController.value > 0.5) {
      _openMenu();
    } else {
      _closeMenu();
    }
  }

  void _selectPrimaryTab(PrimaryTab tab) {
    setState(() {
      _primaryTab = tab;
      _activeAdminSection = null;
    });
    _appDataController.setCurrentPrimaryTab(tab.name);
    _closeMenu();
  }

  void _selectAdminSection(AdminSection section) {
    _closeMenu();
    switch (section) {
      case AdminSection.overview:
        _pushAnimatedPage(PageWithBackButton(
          title: '应用介绍',
          isDarkMode: _isDarkMode,
          child: AboutPage(isDarkMode: _isDarkMode),
        ));
        return;
      case AdminSection.notes:
        _pushAnimatedPage(StudyNotesPage(
          isDarkMode: _isDarkMode,
          controller: _appDataController,
        ));
        return;
      case AdminSection.flashCard:
        _pushAnimatedPage(FlashCardPage(
          isDarkMode: _isDarkMode,
          controller: _appDataController,
        ));
        return;
      case AdminSection.learningMoments:
        _pushAnimatedPage(LearningMomentsPage(
          isDarkMode: _isDarkMode,
          controller: _appDataController,
        ));
        return;
      case AdminSection.timer:
        _pushAnimatedPage(TimerPage(
          isDarkMode: _isDarkMode,
          controller: _appDataController,
        ));
        return;
      case AdminSection.studyGroup:
        _pushAnimatedPage(PageWithBackButton(
          title: '学习小组',
          isDarkMode: _isDarkMode,
          child: StudyGroupPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
          ),
        ));
        return;
      case AdminSection.leaderboard:
        _pushAnimatedPage(PageWithBackButton(
          title: '排行榜',
          isDarkMode: _isDarkMode,
          child: LeaderboardPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
          ),
        ));
        return;
      case AdminSection.achievements:
        _pushAnimatedPage(PageWithBackButton(
          title: '成就殿堂',
          isDarkMode: _isDarkMode,
          child: AchievementsPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
          ),
        ));
        return;
      case AdminSection.knowledgeGraph:
        _pushAnimatedPage(PageWithBackButton(
          title: '知识图谱',
          isDarkMode: _isDarkMode,
          child: KnowledgeGraphPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
          ),
        ));
        return;
      case AdminSection.aiAssistant:
        _pushAnimatedPage(PageWithBackButton(
          title: 'AI 学习助手',
          isDarkMode: _isDarkMode,
          child: AiAssistantPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
            onExecuteActions: _executeAssistantActions,
            onOpenSettings: () => _pushAnimatedPage(PageWithBackButton(
              title: 'AI 设置',
              isDarkMode: _isDarkMode,
              child: AiSettingsPage(
                isDarkMode: _isDarkMode,
                controller: _appDataController,
              ),
            )),
          ),
        ));
        return;
      case AdminSection.aiSettings:
        _pushAnimatedPage(PageWithBackButton(
          title: 'AI 设置',
          isDarkMode: _isDarkMode,
          child: AiSettingsPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
          ),
        ));
        return;
      case AdminSection.settings:
        _pushAnimatedPage(PageWithBackButton(
          title: '系统设置',
          isDarkMode: _isDarkMode,
          child: AiSettingsPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
            mode: AiSettingsMode.system,
          ),
        ));
        return;
      case AdminSection.automations:
        _pushAnimatedPage(PageWithBackButton(
          title: '任务编排',
          isDarkMode: _isDarkMode,
          child: TaskPlanningPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
          ),
        ));
        return;
      case AdminSection.analytics:
      case AdminSection.statistics:
        _pushAnimatedPage(PageWithBackButton(
          title: '数据看板',
          isDarkMode: _isDarkMode,
          child: LearningDashboardPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
          ),
        ));
        return;
      case AdminSection.auditLog:
        _pushAnimatedPage(PageWithBackButton(
          title: 'AI 操作记录',
          isDarkMode: _isDarkMode,
          child: AuditLogPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
            onRetry: _retryAuditRecord,
          ),
        ));
        return;
      case AdminSection.trash:
        _pushAnimatedPage(PageWithBackButton(
          title: '回收站',
          isDarkMode: _isDarkMode,
          child: TrashPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
          ),
        ));
        return;
    }
  }

  Future<void> _setDarkMode(bool value) async {
    setState(() => _isDarkMode = value);
    await _appDataController.setDarkMode(value);
  }

  void _openWeeklyReport() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _WeeklyReportPage(
          controller: _appDataController,
          isDarkMode: _isDarkMode,
        ),
      ),
    );
  }

  void _openCourseDetail(String courseName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CourseDetailPage(
          courseName: courseName,
          isDarkMode: _isDarkMode,
          controller: _appDataController,
        ),
      ),
    );
  }

  void _openUserProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfilePage(
          isDarkMode: _isDarkMode,
          controller: _appDataController,
        ),
      ),
    );
  }

  Widget _primaryPageFor(PrimaryTab tab) {
    switch (tab) {
      case PrimaryTab.assistant:
        return HomePage(
          isDarkMode: _isDarkMode,
          controller: _appDataController,
          onGenerateReport: _openWeeklyReport,
          onOpenAiAssistant: () {
            _openLearningCockpit();
          },
          onOpenAiChat: _openAiChat,
          onOpenLogs: () => _selectPrimaryTab(PrimaryTab.scenarios),
          onOpenCalendar: () => _selectPrimaryTab(PrimaryTab.calendar),
          onOpenTasks: () => _selectPrimaryTab(PrimaryTab.create),
          onOpenNotes: () => _pushAnimatedPage(StudyNotesPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
          )),
          onOpenTimer: () => _pushAnimatedPage(TimerPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
          )),
          onOpenFlashCards: () => _pushAnimatedPage(FlashCardPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
          )),
          onOpenLearningMoments: () => _pushAnimatedPage(LearningMomentsPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
          )),
          onOpenDashboard: () => _pushAnimatedPage(PageWithBackButton(
            title: '数据看板',
            isDarkMode: _isDarkMode,
            child: LearningDashboardPage(
              isDarkMode: _isDarkMode,
              controller: _appDataController,
            ),
          )),
          onOpenStudyGroup: () => _pushAnimatedPage(PageWithBackButton(
            title: '学习小组',
            isDarkMode: _isDarkMode,
            child: StudyGroupPage(
              isDarkMode: _isDarkMode,
              controller: _appDataController,
            ),
          )),
          onOpenLeaderboard: () => _pushAnimatedPage(PageWithBackButton(
            title: '排行榜',
            isDarkMode: _isDarkMode,
            child: LeaderboardPage(
              isDarkMode: _isDarkMode,
              controller: _appDataController,
            ),
          )),
          onOpenSyncSettings: () => _pushAnimatedPage(AiSettingsPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
            mode: AiSettingsMode.system,
          )),
          onOpenTaskPlanning: () => _pushAnimatedPage(PageWithBackButton(
            title: '任务编排',
            isDarkMode: _isDarkMode,
            child: TaskPlanningPage(
              isDarkMode: _isDarkMode,
              controller: _appDataController,
            ),
          )),
        );
      case PrimaryTab.scenarios:
        return _PrimaryTabSurface(
          isDarkMode: _isDarkMode,
          child: StudyLogsPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
          ),
        );
      case PrimaryTab.calendar:
        return _PrimaryTabSurface(
          isDarkMode: _isDarkMode,
          child: CalendarPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
          ),
        );
      case PrimaryTab.create:
        return _PrimaryTabSurface(
          isDarkMode: _isDarkMode,
          child: StudyTasksPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
          ),
        );
      case PrimaryTab.profile:
        return _PrimaryTabSurface(
          isDarkMode: _isDarkMode,
          child: CourseArchivePage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
            onViewCourse: _openCourseDetail,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final safeBottom = mediaQuery.padding.bottom;
    final screenWidth = mediaQuery.size.width;
    _menuWidth = math.min(screenWidth * 0.74, 288);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor:
          _isDarkMode ? const Color(0xFF05070D) : const Color(0xFF182146),
      body: ListenableBuilder(
        listenable: Listenable.merge([_menuController, _appDataController]),
        builder: (context, _) {
          final progress =
              Curves.fastOutSlowIn.transform(_menuController.value);
          final page = _activeAdminSection != null
              ? AdminSectionPage(
                  section: _activeAdminSection!,
                  isDarkMode: _isDarkMode,
                  controller: _appDataController,
                  onOpenSettings: () =>
                      _selectAdminSection(AdminSection.aiSettings),
                  onExecuteActions: _executeAssistantActions,
                  onBack: () => setState(() => _activeAdminSection = null),
                )
              : _primaryPageFor(_primaryTab);

          return Stack(
            children: [
              Positioned(
                top: 0,
                bottom: 0,
                left: lerpDouble(-_menuWidth, 0, progress)!,
                width: _menuWidth,
                child: _SideMenu(
                  currentSection: _activeAdminSection,
                  progress: progress,
                  isDarkMode: _isDarkMode,
                  controller: _appDataController,
                  onDarkModeChanged: _setDarkMode,
                  onSelected: _selectAdminSection,
                  onOpenProfile: () {
                    _closeMenu();
                    _openUserProfile(context);
                  },
                ),
              ),
              _ForegroundSurface(
                isDarkMode: _isDarkMode,
                isMenuOpen: _menuController.value > 0.5,
                useHomeBackground: _activeAdminSection == null &&
                    _primaryTab == PrimaryTab.assistant,
                menuWidth: _menuWidth,
                screenWidth: screenWidth,
                progress: progress,
                safeBottom: safeBottom,
                pageKey: ValueKey<String>(
                  _activeAdminSection?.name ?? _primaryTab.name,
                ),
                currentTab: _primaryTab,
                onMenuTap: _toggleMenu,
                onTabSelected: _selectPrimaryTab,
                onHorizontalDragStart: _handleDragStart,
                onHorizontalDragUpdate: _handleDragUpdate,
                onHorizontalDragEnd: _handleDragEnd,
                child: page,
              ),
              if (_backendReachable == -1 && _appDataController.isLoggedIn)
                Positioned(
                  bottom: safeBottom + 72,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _backendReachable = 0);
                        unawaited(_checkBackendReachable());
                      },
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          key: const ValueKey('offline_chip'),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF6850)
                                .withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEF6850)
                                    .withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.cloud_off_rounded,
                                  color: Colors.white, size: 14),
                              SizedBox(width: 6),
                              Text(
                                '离线模式',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.refresh_rounded,
                                  color: Colors.white70, size: 12),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 18,
                bottom: safeBottom + 96,
                child: IgnorePointer(
                  ignoring: progress > 0.55,
                  child: AnimatedOpacity(
                    opacity: progress > 0.55 ? 0 : 1,
                    duration: const Duration(milliseconds: 160),
                    child: _GlobalAssistantButton(
                      isDarkMode: _isDarkMode,
                      accent: _appDataController.primaryColor,
                      onTap: _openAiChat,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PrimaryTabSurface extends StatelessWidget {
  const _PrimaryTabSurface({
    required this.isDarkMode,
    required this.child,
  });

  final bool isDarkMode;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: isDarkMode ? const Color(0xFF101625) : const Color(0xFFF5F7FF),
      child: child,
    );
  }
}

class _GlobalAssistantButton extends StatelessWidget {
  const _GlobalAssistantButton({
    required this.isDarkMode,
    required this.accent,
    required this.onTap,
  });

  final bool isDarkMode;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'AI 全局助手',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent,
                  const Color(0xFF4BC4A1),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDarkMode ? 0.18 : 0.7),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.24),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

class _WeeklyReportPage extends StatefulWidget {
  const _WeeklyReportPage({
    required this.controller,
    required this.isDarkMode,
    this.autoGenerate = false,
  });

  final AppDataController controller;
  final bool isDarkMode;
  final bool autoGenerate;

  @override
  State<_WeeklyReportPage> createState() => _WeeklyReportPageState();
}

class _WeeklyReportPageState extends State<_WeeklyReportPage> {
  final ReportExportService _exportService = const ReportExportService();
  late DateTime _startDate;
  late DateTime _endDate;
  String? _reportContent;
  bool _isGenerating = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _endDate = now;
    _startDate = now.subtract(const Duration(days: 7));
    if (widget.autoGenerate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _generate();
      });
    }
  }

  void _generate() {
    setState(() => _isGenerating = true);
    final content = widget.controller.generateWeeklyReportContent(
      startDate: _startDate,
      endDate: _endDate,
    );
    setState(() {
      _reportContent = content;
      _isGenerating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.controller.primaryColor;
    final textColor = widget.isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor =
        widget.isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;

    return Scaffold(
      backgroundColor:
          widget.isDarkMode ? const Color(0xFF141923) : const Color(0xFFF5F7FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        title: const Text(
          '生成学习周报',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (_reportContent != null)
            IconButton(
              icon: const Icon(Icons.copy_rounded),
              tooltip: '复制到剪贴板',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _reportContent!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已复制到剪贴板')),
                );
              },
            ),
          if (_reportContent != null)
            IconButton(
              icon: const Icon(Icons.description_rounded),
              tooltip: '导出 Markdown',
              onPressed:
                  _isExporting ? null : () => _exportReport(asPdf: false),
            ),
          if (_reportContent != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              tooltip: '导出 PDF',
              onPressed: _isExporting ? null : () => _exportReport(asPdf: true),
            ),
          if (_reportContent != null)
            IconButton(
              icon: const Icon(Icons.save_rounded),
              tooltip: '保存为历史周报',
              onPressed: () async {
                await widget.controller.saveWeeklyReport(
                  _reportContent!,
                  startDate: _startDate,
                  endDate: _endDate,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('周报已保存')),
                  );
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 40),
        children: [
          // Date range selector
          Row(
            children: [
              Expanded(
                child: _DateButton(
                  label: '开始日期',
                  date: _startDate,
                  isDarkMode: widget.isDarkMode,
                  onPick: (picked) => setState(() => _startDate = picked),
                  accentColor: accent,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.arrow_forward_rounded,
                    color:
                        widget.isDarkMode ? Colors.white54 : AppColors.muted),
              ),
              Expanded(
                child: _DateButton(
                  label: '结束日期',
                  date: _endDate,
                  isDarkMode: widget.isDarkMode,
                  onPick: (picked) => setState(() => _endDate = picked),
                  accentColor: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              key: const Key('do_generate_report_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 0,
              ),
              onPressed: _isGenerating ? null : _generate,
              child: Text(
                _isGenerating ? '生成中...' : '生成周报',
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
          if (_reportContent != null) ...[
            const SizedBox(height: 20),
            Text(
              '周报内容',
              style: TextStyle(
                color: widget.isDarkMode ? Colors.white : Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: widget.isDarkMode
                    ? const Color(0xFF242B37).withValues(alpha: 0.92)
                    : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: widget.isDarkMode
                        ? Colors.black.withValues(alpha: 0.2)
                        : const Color(0x10121A36),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Text(
                _reportContent!,
                style: TextStyle(
                  color: bodyColor,
                  height: 1.65,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  WeeklyReportItem _previewReportItem() {
    final now = DateTime.now();
    return WeeklyReportItem(
      id: 'preview_${now.microsecondsSinceEpoch}',
      startDate: _startDate,
      endDate: _endDate,
      content: _reportContent ?? '',
      sourceLogIds: const [],
      createdAt: now,
    );
  }

  Future<void> _exportReport({required bool asPdf}) async {
    if (_reportContent == null) return;
    setState(() => _isExporting = true);
    try {
      final report = _previewReportItem();
      final file = asPdf
          ? await _exportService.exportWeeklyReportPdf(report)
          : await _exportService.exportWeeklyReportMarkdown(report);
      await Clipboard.setData(ClipboardData(text: file.path));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已导出${asPdf ? ' PDF' : ' Markdown'}，文件路径已复制：${file.path}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败：$error')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.date,
    required this.isDarkMode,
    required this.onPick,
    required this.accentColor,
  });

  final String label;
  final DateTime date;
  final bool isDarkMode;
  final ValueChanged<DateTime> onPick;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: isDarkMode ? Colors.white : accentColor,
        side: BorderSide(
          color:
              isDarkMode ? Colors.white24 : accentColor.withValues(alpha: 0.2),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2024),
          lastDate: DateTime(2030),
        );
        if (picked != null) onPick(picked);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 11)),
          const SizedBox(height: 2),
          Text(
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// --- Below: all existing private widgets (unchanged) ---

class _ForegroundSurface extends StatelessWidget {
  const _ForegroundSurface({
    required this.isDarkMode,
    required this.isMenuOpen,
    required this.useHomeBackground,
    required this.menuWidth,
    required this.screenWidth,
    required this.progress,
    required this.safeBottom,
    required this.pageKey,
    required this.currentTab,
    required this.onMenuTap,
    required this.onTabSelected,
    required this.onHorizontalDragStart,
    required this.onHorizontalDragUpdate,
    required this.onHorizontalDragEnd,
    required this.child,
  });

  final bool isDarkMode;
  final bool isMenuOpen;
  final bool useHomeBackground;
  final double menuWidth;
  final double screenWidth;
  final double progress;
  final double safeBottom;
  final Key pageKey;
  final PrimaryTab currentTab;
  final VoidCallback onMenuTap;
  final ValueChanged<PrimaryTab> onTabSelected;
  final GestureDragStartCallback onHorizontalDragStart;
  final GestureDragUpdateCallback onHorizontalDragUpdate;
  final GestureDragEndCallback onHorizontalDragEnd;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final translateY = lerpDouble(0, 0, progress)!;
    final scale = lerpDouble(1, 0.8, progress)!;
    final rotateY = lerpDouble(0, 1 - 30 * math.pi / 180, progress)!;
    final radius = lerpDouble(0, 24, progress)!;
    final revealedMenuEdge = menuWidth * progress;
    final scaledInset = screenWidth * (1 - scale) / 2;
    final seamOverlap = progress;
    final translateX = math.max(
      0.0,
      revealedMenuEdge - scaledInset - seamOverlap,
    );

    final transform = Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..translateByDouble(translateX, translateY, 0, 1)
      ..rotateY(rotateY)
      ..scaleByDouble(scale, scale, 1, 1);
    final backgroundLayer = useHomeBackground
        ? _LightShellBackground(isDarkMode: isDarkMode)
        : isDarkMode
            ? const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF1E2430),
                      Color(0xFF141923),
                    ],
                  ),
                ),
              )
            : const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white70,
                      Color(0xFFF2F5FC),
                    ],
                  ),
                ),
              );

    return Transform(
      key: const Key('shell_front_transform'),
      alignment: Alignment.center,
      transform: transform,
      child: GestureDetector(
        onHorizontalDragStart: onHorizontalDragStart,
        onHorizontalDragUpdate: onHorizontalDragUpdate,
        onHorizontalDragEnd: onHorizontalDragEnd,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isDarkMode
                  ? const Color(0xFF151A24)
                  : const Color(0xFFF5F7FF),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08 + progress * 0.16),
                  blurRadius: 26,
                  offset: const Offset(-6, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: backgroundLayer,
                ),
                Positioned.fill(
                  child: PageTransitionSwitcher(
                    duration: const Duration(milliseconds: 280),
                    reverse: false,
                    transitionBuilder:
                        (child, animation, secondaryAnimation) {
                      return FadeThroughTransition(
                        animation: animation,
                        secondaryAnimation: secondaryAnimation,
                        child: child,
                      );
                    },
                    child: KeyedSubtree(
                      key: pageKey,
                      child: child,
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  top: 38,
                  child: _MenuButton(
                    isDarkMode: isDarkMode,
                    isMenuOpen: isMenuOpen,
                    progress: progress,
                    onTap: onMenuTap,
                  ),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: safeBottom + 16,
                  child: RepaintBoundary(
                    child: _BottomNav(
                      isDarkMode: isDarkMode,
                      currentTab: currentTab,
                      progress: progress,
                      onSelected: onTabSelected,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LightShellBackground extends StatelessWidget {
  const _LightShellBackground({required this.isDarkMode});

  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color:
                isDarkMode ? const Color(0xFF121827) : const Color(0xFFEFF5FF),
          ),
        ),
        Positioned(
          width: screenSize.width * 2.18,
          left: -screenSize.width * 0.56,
          top: -screenSize.height * 0.08,
          child: IgnorePointer(
            child: Image.asset(
              AppAssets.spline,
              fit: BoxFit.fitWidth,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        const Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: SafeRiveAsset(
                asset: AppAssets.shapes,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDarkMode
                      ? [
                          const Color(0xFF121827).withValues(alpha: 0.28),
                          const Color(0xFF101521).withValues(alpha: 0.56),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.04),
                          const Color(0xFFF6F8FF).withValues(alpha: 0.18),
                        ],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.78),
                  radius: 1.02,
                  colors: [
                    Colors.white.withValues(alpha: isDarkMode ? 0.03 : 0.02),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuButton extends StatefulWidget {
  const _MenuButton({
    required this.isDarkMode,
    required this.isMenuOpen,
    required this.progress,
    required this.onTap,
  });
  final bool isDarkMode;
  final bool isMenuOpen;
  final double progress;
  final VoidCallback onTap;

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _iconController;

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      animationBehavior: AnimationBehavior.preserve,
      value: widget.isMenuOpen ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(covariant _MenuButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _iconController.animateTo(
      widget.progress,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.isDarkMode
          ? const Color(0xFF242B37).withValues(alpha: 0.96)
          : Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(18),
      elevation: 4,
      shadowColor:
          widget.isDarkMode ? const Color(0x66000000) : const Color(0x2217203A),
      child: InkWell(
        key: const Key('app_shell_menu_button'),
        borderRadius: BorderRadius.circular(18),
        onTap: widget.onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: AnimatedIcon(
              icon: AnimatedIcons.menu_close,
              progress: _iconController,
              color: widget.isDarkMode ? Colors.white : AppColors.ink,
              size: 30,
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.isDarkMode,
    required this.currentTab,
    required this.progress,
    required this.onSelected,
  });
  final bool isDarkMode;
  final PrimaryTab currentTab;
  final double progress;
  final ValueChanged<PrimaryTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, 100 * progress),
      child: IgnorePointer(
        ignoring: progress > 0.55,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: isDarkMode ? 0.18 : 0.68),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDarkMode ? 0.16 : 0.48),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF17203A).withValues(alpha: 0.16),
                offset: const Offset(0, 20),
                blurRadius: 20,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final tab in PrimaryTab.values)
                _BottomNavItem(
                  tab: tab,
                  isActive: currentTab == tab,
                  isDarkMode: isDarkMode,
                  onTap: () => onSelected(tab),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatefulWidget {
  const _BottomNavItem({
    required this.tab,
    required this.isActive,
    required this.isDarkMode,
    required this.onTap,
  });
  final PrimaryTab tab;
  final bool isActive;
  final bool isDarkMode;
  final VoidCallback onTap;

  @override
  State<_BottomNavItem> createState() => _BottomNavItemState();
}

class _BottomNavItemState extends State<_BottomNavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _iconController;

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      value: widget.isActive ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(covariant _BottomNavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _iconController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _iconController.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: widget.isActive,
      label: widget.tab.label,
      child: GestureDetector(
        key: Key('bottom_nav_${widget.tab.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              margin: const EdgeInsets.only(bottom: 2),
              duration: const Duration(milliseconds: 200),
              curve: Curves.fastOutSlowIn,
              height: 4,
              width: widget.isActive ? 20 : 0,
              decoration: BoxDecoration(
                color: const Color(0xFF81B4FF),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            SizedBox(
              height: 36,
              width: 36,
              child: Opacity(
                opacity: widget.isActive ? 1 : 0.5,
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    widget.isDarkMode ? Colors.white : Colors.transparent,
                    widget.isDarkMode ? BlendMode.srcATop : BlendMode.dst,
                  ),
                  child: Lottie.asset(
                    widget.tab.navLordiconAsset,
                    controller: _iconController,
                    repeat: false,
                    onLoaded: (composition) {
                      _iconController.duration = composition.duration;
                      if (widget.isActive && _iconController.value == 0) {
                        _iconController.value = 1;
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideMenu extends StatefulWidget {
  const _SideMenu({
    required this.currentSection,
    required this.progress,
    required this.isDarkMode,
    required this.controller,
    required this.onDarkModeChanged,
    required this.onSelected,
    required this.onOpenProfile,
  });
  final AdminSection? currentSection;
  final double progress;
  final bool isDarkMode;
  final AppDataController controller;
  final ValueChanged<bool> onDarkModeChanged;
  final ValueChanged<AdminSection> onSelected;
  final VoidCallback onOpenProfile;

  @override
  State<_SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends State<_SideMenu> {
  @override
  Widget build(BuildContext context) {
    final accent = widget.controller.primaryColor;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: (widget.isDarkMode
                    ? const Color(0xFF070A11)
                    : const Color(0xFF1C2442))
                .withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Opacity(
            opacity: lerpDouble(0.15, 1, widget.progress)!,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Image.asset(
                          'logo/logo白透明.png',
                          height: 32,
                          fit: BoxFit.fitHeight,
                        ),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: widget.onOpenProfile,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 4, horizontal: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  gradient: widget.controller.userProfile
                                              .avatarImagePath ==
                                          null
                                      ? LinearGradient(
                                          colors: [
                                            accent,
                                            const Color(0xFF8D5EFF)
                                          ],
                                        )
                                      : null,
                                  shape: BoxShape.circle,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: widget.controller.userProfile
                                            .avatarImagePath !=
                                        null
                                    ? localImageFromPath(
                                        widget.controller.userProfile
                                            .avatarImagePath!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Center(
                                          child: Text(
                                              widget.controller.userProfile
                                                  .avatarEmoji,
                                              style: const TextStyle(
                                                  fontSize: 22)),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          widget.controller.userProfile
                                              .avatarEmoji,
                                          style: const TextStyle(fontSize: 22),
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.controller.userProfile.nickname,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.controller.userProfile.bio,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xB3FFFFFF),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white.withValues(alpha: 0.4),
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      _SideMenuActionItem(
                        label: '个人资料',
                        icon: Icons.account_circle_outlined,
                        onTap: widget.onOpenProfile,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '更多',
                        style: TextStyle(
                          color: Color(0x99FFFFFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _SideMenuActionItem(
                        label: 'AI 功能',
                        icon: Icons.smart_toy_outlined,
                        selected:
                            widget.currentSection == AdminSection.aiAssistant,
                        onTap: () =>
                            widget.onSelected(AdminSection.aiAssistant),
                      ),
                      const SizedBox(height: 10),
                      _SideMenuActionItem(
                        label: 'AI 设置',
                        icon: Icons.tune_rounded,
                        selected:
                            widget.currentSection == AdminSection.aiSettings,
                        onTap: () =>
                            widget.onSelected(AdminSection.aiSettings),
                      ),
                      const SizedBox(height: 10),
                      _SideMenuActionItem(
                        label: '学迹动态',
                        icon: Icons.dynamic_feed_outlined,
                        selected: widget.currentSection ==
                            AdminSection.learningMoments,
                        onTap: () =>
                            widget.onSelected(AdminSection.learningMoments),
                      ),
                      const SizedBox(height: 10),
                      _SideMenuActionItem(
                        label: '系统设置',
                        icon: Icons.settings_outlined,
                        selected:
                            widget.currentSection == AdminSection.settings,
                        onTap: () => widget.onSelected(AdminSection.settings),
                      ),
                      const SizedBox(height: 10),
                      _SideMenuActionItem(
                        label: '成就殿堂',
                        icon: Icons.emoji_events_outlined,
                        selected:
                            widget.currentSection == AdminSection.achievements,
                        onTap: () =>
                            widget.onSelected(AdminSection.achievements),
                      ),
                      const SizedBox(height: 10),
                      _SideMenuActionItem(
                        label: '知识图谱',
                        icon: Icons.account_tree_outlined,
                        selected:
                            widget.currentSection ==
                                AdminSection.knowledgeGraph,
                        onTap: () =>
                            widget.onSelected(AdminSection.knowledgeGraph),
                      ),
                      const SizedBox(height: 10),
                      _SideMenuActionItem(
                        label: 'AI 操作记录',
                        icon: Icons.history_rounded,
                        selected:
                            widget.currentSection == AdminSection.auditLog,
                        onTap: () => widget.onSelected(AdminSection.auditLog),
                      ),
                      const SizedBox(height: 10),
                      _SideMenuActionItem(
                        label: '回收站',
                        icon: Icons.delete_outline_rounded,
                        selected:
                            widget.currentSection == AdminSection.trash,
                        onTap: () => widget.onSelected(AdminSection.trash),
                      ),
                      const SizedBox(height: 10),
                      _SideMenuActionItem(
                        label: '应用介绍',
                        icon: Icons.info_outline_rounded,
                        selected:
                            widget.currentSection == AdminSection.overview,
                        onTap: () => widget.onSelected(AdminSection.overview),
                      ),
                      const SizedBox(height: 16),
                      _ThemeModeButton(
                        value: widget.isDarkMode,
                        onChanged: widget.onDarkModeChanged,
                      ),
                    ],
                  ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SideMenuActionItem extends StatelessWidget {
  const _SideMenuActionItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 56,
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.fastOutSlowIn,
                    width: selected ? constraints.maxWidth : 0,
                    height: 56,
                    left: 0,
                    top: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF6792FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.transparent
                            : Colors.white.withValues(alpha: 0.04),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            Icon(
                              icon,
                              color: Colors.white
                                  .withValues(alpha: selected ? 1 : 0.88),
                              size: 20,
                            ),
                            const SizedBox(width: 14),
                            Text(
                              label,
                              style: TextStyle(
                                color: Colors.white
                                    .withValues(alpha: selected ? 1 : 0.86),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ThemeModeButton extends StatelessWidget {
  const _ThemeModeButton({
    required this.value,
    required this.onChanged,
  });
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = value ? '夜间' : '日间';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onChanged(!value),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: value ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Icon(
                value ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xCCFFFFFF),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
