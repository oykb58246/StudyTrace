import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../controllers/app_data_controller.dart';
import '../../models/ai_action_record.dart';
import '../../models/ai_app_action.dart';
import '../../models/analysis_item.dart';
import '../../models/trash_item.dart';
import '../../models/weekly_report_item.dart';
import '../../services/ai_action_executor.dart';
import '../../services/ai_tool_registry.dart';
import '../../services/report_export_service.dart';
import '../../theme/app_theme.dart';
import '../analysis/analysis_result_page.dart';
import '../study/about_page.dart';
import '../study/achievements_page.dart';
import '../shell/audit_log_page.dart';
import '../shell/trash_page.dart';
import '../study/ai_chat_page.dart';
import '../study/ai_assistant_page.dart';
import '../study/ai_learning_cockpit_page.dart';
import '../study/ai_settings_page.dart';
import '../study/evidence_package_page.dart';
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
import '../shared/common_widgets.dart';
import '../shared/global_route_observer.dart';
import '../shared/page_wrapper.dart';
import '../shared/rive_safe_widget.dart';
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
    this.debugInitialReviewTarget,
  });

  final AppDataController? initialController;
  final bool debugMenuInitiallyOpen;
  final PrimaryTab? debugInitialPrimaryTab;
  final AdminSection? debugInitialAdminSection;
  final String? debugInitialReviewTarget;

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
  bool _isAiChatOpen = false;
  Offset? _assistantOffset;
  OverlayEntry? _assistantOverlayEntry;
  double _menuWidth = 252;

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
    _menuController.addListener(_markAssistantOverlayNeedsBuild);
    _appDataController.addListener(_handleControllerChanged);
    studyTraceRouteTick.addListener(_bringAssistantOverlayToFront);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _ensureAssistantOverlay());
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _openInitialReviewTarget());
    unawaited(_loadData());
  }

  Future<void> _loadData() async {
    if (!_appDataController.isLoaded) {
      await _appDataController.load();
    }
    if (mounted) {
      setState(() => _isDarkMode = _appDataController.darkMode);
      _markAssistantOverlayNeedsBuild();
    }
    unawaited(_checkBackendReachable());
  }

  Future<void> _checkBackendReachable() async {
    if (!_appDataController.isLoggedIn) {
      if (mounted) setState(() => _backendReachable = 0);
      return;
    }
    try {
      final baseUrl =
          _appDataController.apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
      final response = await http.get(Uri.parse('$baseUrl/health')).timeout(
            const Duration(seconds: 4),
          );
      final reachable = response.statusCode >= 200 && response.statusCode < 300;
      if (mounted) setState(() => _backendReachable = reachable ? 1 : -1);
    } catch (_) {
      if (mounted) setState(() => _backendReachable = -1);
    }
  }

  @override
  void dispose() {
    _removeAssistantOverlay();
    studyTraceRouteTick.removeListener(_bringAssistantOverlayToFront);
    _menuController.removeListener(_markAssistantOverlayNeedsBuild);
    _appDataController.removeListener(_handleControllerChanged);
    _menuController.dispose();
    _appDataController.dispose();
    super.dispose();
  }

  @override
  void reassemble() {
    super.reassemble();
    _removeAssistantOverlay();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _ensureAssistantOverlay());
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

  Future<void> _openAiChat() async {
    if (_isAiChatOpen) return;
    setState(() => _isAiChatOpen = true);
    _markAssistantOverlayNeedsBuild();
    try {
      await _pushAnimatedPage(
        AiChatPage(
          isDarkMode: _isDarkMode,
          controller: _appDataController,
          onExecuteActions: _executeAssistantActions,
          onOpenTasks: () => _openTasksPage(),
          onOpenLogs: _openStudyLogsPage,
          onOpenNotes: _openStudyNotesPage,
          onOpenFlashCards: _openFlashCardLibrary,
          onStartFlashCardReview: (cardIds) => _openFlashCardReview(cardIds),
          currentLocation: _primaryTab.name,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isAiChatOpen = false);
        _markAssistantOverlayNeedsBuild();
      }
    }
  }

  void _ensureAssistantOverlay() {
    if (!mounted || _assistantOverlayEntry != null) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _assistantOverlayEntry = OverlayEntry(
      builder: (overlayContext) {
        if (!mounted || _isAiChatOpen) return const SizedBox.shrink();
        if (_activeAdminSection == null) {
          return const SizedBox.shrink();
        }
        final shellRoute = ModalRoute.of(context);
        if (shellRoute != null && !shellRoute.isCurrent) {
          return const SizedBox.shrink();
        }
        final media = MediaQuery.of(overlayContext);
        final menuProgress =
            Curves.fastOutSlowIn.transform(_menuController.value);
        return _DraggableAssistantButton(
          isDarkMode: _isDarkMode,
          accent: _appDataController.primaryColor,
          safeBottom: media.padding.bottom,
          menuProgress: menuProgress,
          offset: _assistantOffset,
          onOffsetChanged: _setAssistantOffset,
          onTap: () => unawaited(_openAiChat()),
        );
      },
    );
    overlay.insert(_assistantOverlayEntry!);
  }

  void _markAssistantOverlayNeedsBuild() {
    _assistantOverlayEntry?.markNeedsBuild();
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    final requestedTab =
        _primaryTabFromName(_appDataController.currentPrimaryTab);
    if (requestedTab != null && requestedTab != _primaryTab) {
      setState(() {
        _primaryTab = requestedTab;
        _activeAdminSection = null;
      });
    }
    _markAssistantOverlayNeedsBuild();
  }

  PrimaryTab? _primaryTabFromName(String name) {
    return switch (name.trim().toLowerCase()) {
      'assistant' || 'home' || '首页' || '主页' => PrimaryTab.assistant,
      'scenarios' || 'plan' || '计划' || '计划页' || '安排' => PrimaryTab.scenarios,
      'calendar' ||
      'focus' ||
      'timer' ||
      '专注' ||
      '专注页' ||
      '计时' ||
      '番茄钟' =>
        PrimaryTab.calendar,
      'create' ||
      'review' ||
      'flashcard' ||
      'flashcards' ||
      '复习' ||
      '闪卡' =>
        PrimaryTab.create,
      'profile' || 'mine' || '我的' || '我的页' || '个人' => PrimaryTab.profile,
      _ => null,
    };
  }

  void _removeAssistantOverlay() {
    _assistantOverlayEntry?.remove();
    _assistantOverlayEntry = null;
  }

  void _setAssistantOffset(Offset offset) {
    _assistantOffset = offset;
    _markAssistantOverlayNeedsBuild();
  }

  Widget _withStudyTheme(Widget child) {
    return Theme(
      data: _isDarkMode ? buildDarkAppTheme() : buildAppTheme(),
      child: child,
    );
  }

  Future<T?> _pushAnimatedPage<T>(Widget page) {
    _bringAssistantOverlayToFront();
    return Navigator.of(context).push<T>(
      PageRouteBuilder<T>(
        fullscreenDialog: false,
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (context, __, ___) => _withStudyTheme(page),
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

  void _openInitialReviewTarget() {
    if (!mounted) return;
    final target = widget.debugInitialReviewTarget?.trim().toLowerCase();
    if (target == null || target.isEmpty) return;
    switch (target) {
      case 'flashcards':
      case 'flashcard-library':
      case 'knowledge-flashcards':
      case '知识闪卡':
        _openFlashCardLibrary();
        return;
      case 'flashcard-new-group':
      case 'flashcard-group-dialog':
      case '闪卡分组':
        _openFlashCardNewGroupReview();
        return;
      case 'flashcard-grade-result':
      case 'flashcard-grade-dialog':
      case '闪卡评分':
        _openFlashCardGradeResultReview();
        return;
      case 'flashcard-review':
      case 'review':
      case '复习':
        _openFlashCardReview();
        return;
      case 'task-planning':
      case 'task-plan':
      case 'planning':
      case 'automations':
      case '任务编排':
        _openTaskPlanningPage();
        return;
      case 'tasks':
      case 'today-tasks':
      case 'today-plan':
      case '今日安排':
      case '学习任务':
        _openTasksPage();
        return;
      case 'notes':
      case 'study-notes':
      case '学习笔记':
      case '笔记':
        _openStudyNotesPage();
        return;
      case 'study-logs':
      case 'learning-logs':
      case 'logs':
      case '学习记录':
        _openStudyLogsPage();
        return;
      case 'learning-moments':
      case 'learning-moments-tools':
      case 'learning-moments-composer':
      case 'learning-moments-course-selector':
      case 'moments':
      case 'study-moments':
      case '学迹':
      case '学迹动态':
        _openLearningMomentsPage();
        return;
      case 'study-group':
      case 'group':
      case 'groups':
      case '学习小组':
      case '共学':
        _openStudyGroupPage();
        return;
      case 'leaderboard':
      case 'rank':
      case 'ranking':
      case '排行榜':
        _pushAnimatedPage(PageWithBackButton(
          title: '学习进度',
          isDarkMode: _isDarkMode,
          titleIcon: AdminSection.leaderboard.icon,
          accent: AdminSection.leaderboard.accent,
          compactHeader: true,
          child: LeaderboardPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
            onOpenStudyGroup: _openStudyGroupPage,
            onOpenLearningMoments: _openLearningMomentsPage,
          ),
        ));
        return;
      case 'achievements':
      case 'achievement':
      case 'badges':
      case '成就':
      case '成就殿堂':
        _pushAnimatedPage(PageWithBackButton(
          title: '成长记录',
          isDarkMode: _isDarkMode,
          titleIcon: AdminSection.achievements.icon,
          accent: AdminSection.achievements.accent,
          compactHeader: true,
          child: AchievementsPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
          ),
        ));
        return;
      case 'knowledge-graph':
      case 'knowledge':
      case 'graph':
      case '知识图谱':
      case '知识地图':
        _openKnowledgeMapPage();
        return;
      case 'learning-dashboard':
      case 'data-dashboard':
      case 'dashboard':
      case 'analytics':
      case 'statistics':
      case '学习数据':
      case '数据看板':
      case '学习统计':
        _pushAnimatedPage(PageWithBackButton(
          title: '数据看板',
          isDarkMode: _isDarkMode,
          titleIcon: AdminSection.analytics.icon,
          accent: AdminSection.analytics.accent,
          compactHeader: true,
          child: LearningDashboardPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
            onOpenTasks: () => _openTasksPage(),
            onOpenOverdueTasks: () =>
                _openTasksPage(initialOverdueFilter: true),
            onOpenLogs: _openStudyLogsPage,
            onOpenLearningMoments: _openLearningMomentsPage,
            onOpenTaskPlanning: _openTaskPlanningPage,
            onOpenKnowledgeMap: _openKnowledgeMapPage,
            onOpenWeeklyReview: _openWeeklyReviewPage,
          ),
        ));
        return;
      case 'analysis-result':
      case 'analysis':
      case '分析结果':
      case '分析页':
        _pushAnimatedPage(AnalysisResultPage(
          analysis: _reviewAnalysisItem(),
          controller: _appDataController,
          isDarkMode: _isDarkMode,
        ));
        return;
      case 'weekly-report':
      case 'report':
      case 'learning-report':
      case '每周回顾':
      case '周报':
      case '学习周报':
        _pushAnimatedPage(_WeeklyReportPage(
          controller: _appDataController,
          isDarkMode: _isDarkMode,
          autoGenerate: true,
        ));
        return;
      case 'evidence-package':
      case 'evidence':
      case 'learning-review':
      case '学习回顾':
      case '7天学习回顾':
        _pushAnimatedPage(PageWithBackButton(
          title: '7天学习回顾',
          isDarkMode: _isDarkMode,
          titleIcon: AdminSection.evidencePackage.icon,
          accent: AdminSection.evidencePackage.accent,
          child: _buildEvidencePackagePage(),
        ));
        return;
      case 'audit-log':
      case 'audit':
      case 'assistant-log':
      case '助手整理记录':
        _openAuditLogPage();
        return;
      case 'trash':
      case 'recycle-bin':
      case 'recovery':
      case '回收站':
        _pushAnimatedPage(PageWithBackButton(
          title: '回收站',
          isDarkMode: _isDarkMode,
          titleIcon: AdminSection.trash.icon,
          accent: AdminSection.trash.accent,
          compactHeader: true,
          child: TrashPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
            previewItems: _reviewTrashItems(),
          ),
        ));
        return;
      case 'timer':
      case 'focus':
      case 'focus-timer':
      case '专注':
      case '专注计时':
        _openTimerPage();
        return;
      case 'course-archive':
      case '课程归档':
        _openCourseArchivePage();
        return;
      case 'course-detail':
      case '课程详情':
        final courses = _appDataController.courseNames;
        if (courses.isNotEmpty) {
          _openCourseDetail(courses.first);
        }
        return;
      case 'ai-assistant':
      case '学习助手':
        _openAiAssistantTools();
        return;
      case 'ai-chat':
      case 'chat':
      case '学习对话':
        unawaited(_openAiChat());
        return;
      case 'ai-cockpit':
      case '学习座舱':
        _openLearningCockpit();
        return;
      case 'ai-cockpit-saved-next-step':
        _openLearningCockpitSavedNextStepReview();
        return;
      case 'ai-settings':
      case '助手设置':
        _openAssistantSettingsPage();
        return;
      case 'system-settings':
      case '系统设置':
        _openSystemSettingsPage();
        return;
      case 'about':
      case 'overview':
      case '应用介绍':
      case '作品总览':
      case '关于学迹':
        _openAboutPage();
        return;
    }
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

  /// 整理历史页"重试"按钮回调：把失败的 AiActionRecord 重建成 AiAppAction 再跑
  Future<void> _retryAuditRecord(AiActionRecord record) async {
    final type = _actionTypeFromToolId(record.toolId);
    if (type == null) {
      _showShellSnack('这条整理记录暂时无法重试');
      return;
    }
    final definition = AiToolRegistry.instance.lookup(record.toolId);
    if (definition?.needsConfirmation == true) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: StudyDialogSurface(
            isDarkMode: _isDarkMode,
            accent: StudyUi.warning,
            icon: Icons.warning_amber_rounded,
            title: '确认重新执行操作',
            actions: [
              Row(
                children: [
                  Expanded(
                    child: StudyActionPill(
                      icon: Icons.close_rounded,
                      label: '取消',
                      color: StudyUi.muted(_isDarkMode),
                      isDarkMode: _isDarkMode,
                      filled: false,
                      expand: true,
                      onPressed: () => Navigator.of(ctx).pop(false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StudyActionPill(
                      icon: Icons.refresh_rounded,
                      label: '继续重试',
                      color: StudyUi.warning,
                      isDarkMode: _isDarkMode,
                      expand: true,
                      onPressed: () => Navigator.of(ctx).pop(true),
                    ),
                  ),
                ],
              ),
            ],
            child: Text(
              '该动作会执行「${definition!.label}」，可能修改或删除数据。确定继续吗？',
              style: TextStyle(
                color: StudyUi.body(_isDarkMode),
                height: 1.5,
              ),
            ),
          ),
        ),
      );
      if (confirmed != true) return;
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
          ? '这次还没整理好，可以稍后再试'
          : (r.success ? '已重新整理好' : '这次还没整理好，可以稍后再试'),
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
          final directResult = _openDirectAssistantTarget(action);
          if (directResult != null) return directResult;
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
          _openTimerPage();
          return _navigationSuccess(action, '已打开专注计时器');
        case AiAppActionType.startFocus:
          final minutes = _parseFocusMinutes(action);
          _openTimerPage(
            initialMinutes: minutes,
            autoStart: true,
            focusTitle: action.title?.trim().isNotEmpty == true
                ? action.title!.trim()
                : null,
          );
          return _navigationSuccess(action, '已开始 $minutes 分钟专注');
        case AiAppActionType.startFocusWithTask:
          final minutes = _parseFocusMinutes(action);
          final task = _taskForFocusAction(action);
          _openTimerPage(
            initialMinutes: minutes,
            autoStart: true,
            focusTitle: task?.title,
          );
          return _navigationSuccess(
            action,
            task == null
                ? '已开始 $minutes 分钟专注'
                : '已围绕「${task.title}」开始 $minutes 分钟专注',
          );
        case AiAppActionType.openFlashcard:
          _openFlashCardPage();
          return _navigationSuccess(action, '已打开知识闪卡');
        case AiAppActionType.openNotes:
          _pushAnimatedPage(StudyNotesPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
          ));
          return _navigationSuccess(action, '已打开学习笔记');
        case AiAppActionType.openAiSettings:
          _openAssistantSettingsPage();
          return _navigationSuccess(action, '已打开助手设置');
        case AiAppActionType.openDashboard:
          _pushAnimatedPage(PageWithBackButton(
            title: '数据看板',
            isDarkMode: _isDarkMode,
            titleIcon: AdminSection.analytics.icon,
            accent: AdminSection.analytics.accent,
            compactHeader: true,
            child: LearningDashboardPage(
              isDarkMode: _isDarkMode,
              controller: _appDataController,
              onOpenTasks: () => _openTasksPage(),
              onOpenOverdueTasks: () =>
                  _openTasksPage(initialOverdueFilter: true),
              onOpenLogs: _openStudyLogsPage,
              onOpenLearningMoments: _openLearningMomentsPage,
              onOpenTaskPlanning: _openTaskPlanningPage,
              onOpenKnowledgeMap: _openKnowledgeMapPage,
              onOpenWeeklyReview: _openWeeklyReviewPage,
            ),
          ));
          return _navigationSuccess(action, '已打开数据看板');
        case AiAppActionType.openTaskPlanning:
          _pushAnimatedPage(PageWithBackButton(
            title: '学习流程',
            isDarkMode: _isDarkMode,
            titleIcon: AdminSection.automations.icon,
            accent: AdminSection.automations.accent,
            compactHeader: true,
            child: TaskPlanningPage(
              isDarkMode: _isDarkMode,
              controller: _appDataController,
              onOpenTasks: () => _openTasksPage(),
              onOpenOverdueTasks: () =>
                  _openTasksPage(initialOverdueFilter: true),
            ),
          ));
          return _navigationSuccess(action, '已打开学习流程');
        case AiAppActionType.openAiAssistant:
          _openLearningCockpit();
          return _navigationSuccess(action, '已打开学习助手');
        case AiAppActionType.openUserProfile:
          _openUserProfilePage();
          return _navigationSuccess(action, '已打开个人资料');
        case AiAppActionType.openAbout:
          _openAboutPage();
          return _navigationSuccess(action, '已打开应用介绍');
        case AiAppActionType.openStudyGroup:
          _openStudyGroupPage();
          return _navigationSuccess(action, '已打开学习小组');
        case AiAppActionType.openLeaderboard:
          _pushAnimatedPage(PageWithBackButton(
            title: '学习进度',
            isDarkMode: _isDarkMode,
            titleIcon: AdminSection.leaderboard.icon,
            accent: AdminSection.leaderboard.accent,
            compactHeader: true,
            child: LeaderboardPage(
              isDarkMode: _isDarkMode,
              controller: _appDataController,
              onOpenStudyGroup: _openStudyGroupPage,
              onOpenLearningMoments: _openLearningMomentsPage,
            ),
          ));
          return _navigationSuccess(action, '已打开学习进度');
        case AiAppActionType.openWeeklyReport:
          _pushAnimatedPage(_WeeklyReportPage(
            controller: _appDataController,
            isDarkMode: _isDarkMode,
            autoGenerate: true,
          ));
          return _navigationSuccess(action, '已打开每周回顾');
        case AiAppActionType.openSystemSettings:
          _openSystemSettingsPage();
          return _navigationSuccess(action, '已打开应用设置');
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
        message: '当前页面暂时打不开，可以稍后再试',
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
      titleIcon: tab.icon,
      accent: _appDataController.primaryColor,
      compactHeader: true,
      child: _primaryPageFor(tab),
    ));
  }

  void _openTimerPage({
    int? initialMinutes,
    String? focusTitle,
    bool autoStart = false,
  }) {
    _pushAnimatedPage(PageWithBackButton(
      title: '专注计时',
      isDarkMode: _isDarkMode,
      titleIcon: Icons.timer_rounded,
      accent: AdminSection.timer.accent,
      compactHeader: true,
      child: TimerPage(
        isDarkMode: _isDarkMode,
        controller: _appDataController,
        initialMinutes: initialMinutes,
        focusTitle: focusTitle,
        autoStart: autoStart,
        showAppBar: false,
      ),
    ));
  }

  void _openFlashCardPage({
    bool autoGenerate = true,
    bool startReviewOnOpen = false,
    List<String> initialReviewCardIds = const [],
    bool debugAutoOpenNewGroupDialog = false,
    bool debugAutoOpenGradeResultDialog = false,
  }) {
    _pushAnimatedPage(PageWithBackButton(
      title: '知识闪卡',
      isDarkMode: _isDarkMode,
      titleIcon: AdminSection.flashCard.icon,
      accent: AdminSection.flashCard.accent,
      compactHeader: true,
      child: FlashCardPage(
        isDarkMode: _isDarkMode,
        controller: _appDataController,
        autoGenerate: autoGenerate,
        startReviewOnOpen: startReviewOnOpen,
        initialReviewCardIds: initialReviewCardIds,
        debugAutoOpenNewGroupDialog: debugAutoOpenNewGroupDialog,
        debugAutoOpenGradeResultDialog: debugAutoOpenGradeResultDialog,
        onOpenNotes: _openStudyNotesPage,
        showAppBar: false,
      ),
    ));
  }

  void _openUserProfilePage() {
    _pushAnimatedPage(PageWithBackButton(
      title: '我的学迹',
      isDarkMode: _isDarkMode,
      titleIcon: Icons.person_outline_rounded,
      accent: StudyUi.pathViolet,
      compactHeader: true,
      child: UserProfilePage(
        isDarkMode: _isDarkMode,
        controller: _appDataController,
        onOpenAchievements: _openAchievementsPage,
        onOpenCourseArchive: _openCourseArchivePage,
        showAppBar: false,
      ),
    ));
  }

  void _bringAssistantOverlayToFront() {
    if (!mounted) return;
    final entry = _assistantOverlayEntry;
    if (entry == null) return;
    entry.remove();
    _assistantOverlayEntry = null;
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _ensureAssistantOverlay());
  }

  PrimaryTab? _tabFromAssistantAction(AiAppAction action) {
    final value = _assistantActionTargetValue(action);
    return switch (value) {
      'assistant' || 'home' || '首页' || '主页' => PrimaryTab.assistant,
      'scenarios' ||
      'calendar' ||
      '日历' ||
      '计划' ||
      '计划页' ||
      '安排' ||
      '今日安排' =>
        PrimaryTab.scenarios,
      'focus' ||
      'timer' ||
      '专注' ||
      '专注页' ||
      '计时' ||
      '番茄钟' ||
      '专注计时' =>
        PrimaryTab.calendar,
      'create' ||
      'flashcard' ||
      'flashcards' ||
      '复习' ||
      '复习页' ||
      '闪卡' ||
      '知识闪卡' =>
        PrimaryTab.create,
      'profile' ||
      'archive' ||
      '归档' ||
      '课程归档' ||
      '我的' ||
      '我的页' ||
      '个人' ||
      '个人资料' =>
        PrimaryTab.profile,
      _ => null,
    };
  }

  String _assistantActionTargetValue(AiAppAction action) {
    return (action.targetId ??
            action.targetTitle ??
            action.title ??
            action.content ??
            '')
        .trim()
        .toLowerCase();
  }

  AiActionResult? _openDirectAssistantTarget(AiAppAction action) {
    switch (_assistantActionTargetValue(action)) {
      case 'tasks':
      case 'task':
      case 'today-tasks':
      case 'today-plan':
      case '任务':
      case '今日安排':
      case '学习任务':
        _openTasksPage();
        return _navigationSuccess(action, '已打开今日安排');
      case 'logs':
      case 'study-logs':
      case 'learning-logs':
      case '记录':
      case '日志':
      case '学习记录':
        _openStudyLogsPage();
        return _navigationSuccess(action, '已打开学习记录');
    }
    return null;
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
      onOpenAiChat: () => unawaited(_openAiChat()),
      onOpenTasks: () => _openTasksPage(),
      onOpenFlashCards: _openFlashCardLibrary,
      onStartFlashCardReview: (cardIds) => _openFlashCardReview(cardIds),
      onOpenLearningMoments: _openLearningMomentsPage,
      onOpenEvidencePackage: () => _pushAnimatedPage(PageWithBackButton(
        title: '7天学习回顾',
        isDarkMode: _isDarkMode,
        titleIcon: AdminSection.evidencePackage.icon,
        accent: AdminSection.evidencePackage.accent,
        child: _buildEvidencePackagePage(),
      )),
    ));
  }

  void _openLearningCockpitSavedNextStepReview() {
    _pushAnimatedPage(AiLearningCockpitPage(
      isDarkMode: _isDarkMode,
      controller: _appDataController,
      debugAutoOpenSavedNextStepDialog: true,
      onOpenAiChat: () => unawaited(_openAiChat()),
      onOpenTasks: () => _openTasksPage(),
      onOpenFlashCards: _openFlashCardLibrary,
      onStartFlashCardReview: (cardIds) => _openFlashCardReview(cardIds),
      onOpenLearningMoments: _openLearningMomentsPage,
      onOpenEvidencePackage: () => _pushAnimatedPage(PageWithBackButton(
        title: '7天学习回顾',
        isDarkMode: _isDarkMode,
        titleIcon: AdminSection.evidencePackage.icon,
        accent: AdminSection.evidencePackage.accent,
        child: _buildEvidencePackagePage(),
      )),
    ));
  }

  void _openAiAssistantTools() {
    _pushAnimatedPage(PageWithBackButton(
      title: '学习助手',
      isDarkMode: _isDarkMode,
      titleIcon: Icons.auto_awesome_rounded,
      accent: StudyUi.pathViolet,
      compactHeader: true,
      child: AiAssistantPage(
        isDarkMode: _isDarkMode,
        controller: _appDataController,
        onOpenTasks: () => _openTasksPage(),
        onOpenLogs: _openStudyLogsPage,
        onOpenNotes: _openStudyNotesPage,
        onOpenFlashCards: _openFlashCardLibrary,
        onStartFlashCardReview: (cardIds) => _openFlashCardReview(cardIds),
        onOpenSettings: _openAssistantSettingsPage,
        onExecuteActions: _executeAssistantActions,
      ),
    ));
  }

  AnalysisItem _reviewAnalysisItem() {
    return AnalysisItem(
      id: 'review_analysis_path',
      contentType: '复盘材料',
      summary: '高数错题复盘已进入收尾，下一步要把洛必达适用条件讲清楚。',
      keyPoints: const [
        '已经完成极限未定式、求导步骤和错题标记。',
        '难点集中在 0/0 或 ∞/∞ 条件判断，以及化简后是否还能继续使用洛必达。',
        '最适合先重做一道同类极限题，再整理成 3 张闪卡。',
      ],
      suggestedActions: const [
        '今晚先把洛必达法则的使用条件写成判断清单。',
        '把未定式判断、求导步骤和易错点整理成 3 张闪卡。',
        '明天用 25 分钟复盘错题和下一步。',
      ],
      rawContent: '来自任务、笔记和复盘记录的学习材料：本周主要复习高数极限题和洛必达法则。'
          '当前已经完成知识点梳理，但适用条件判断还缺少一次完整复盘。',
      createdAt: DateTime.now().subtract(const Duration(minutes: 18)),
    );
  }

  List<TrashItem> _reviewTrashItems() {
    final now = DateTime.now();
    return [
      TrashItem(
        id: 'review_trash_task',
        entityType: TrashEntityType.task,
        entityId: 'review_task_archived',
        title: '高等数学错题复盘截图',
        payload: '{}',
        deletedAt: now.subtract(const Duration(hours: 3, minutes: 18)),
      ),
      TrashItem(
        id: 'review_trash_note',
        entityType: TrashEntityType.note,
        entityId: 'review_note_archived',
        title: '课程复盘材料摘要',
        payload: '{}',
        deletedAt: now.subtract(const Duration(days: 1, hours: 2)),
      ),
    ];
  }

  void _openFlashCardReview([List<String> cardIds = const []]) {
    _openFlashCardPage(
      startReviewOnOpen: true,
      initialReviewCardIds: cardIds,
    );
  }

  EvidencePackagePage _buildEvidencePackagePage() {
    return EvidencePackagePage(
      isDarkMode: _isDarkMode,
      controller: _appDataController,
      onOpenTasks: () => _openTasksPage(),
      onOpenFlashCards: _openFlashCardLibrary,
      onOpenLearningMoments: _openLearningMomentsPage,
      onOpenNotes: _openStudyNotesPage,
      onOpenCourse: _openCourseDetail,
      onStartReview: _openLearningCockpit,
    );
  }

  void _openWeeklyReviewPage() {
    _pushAnimatedPage(PageWithBackButton(
      title: '7天学习回顾',
      isDarkMode: _isDarkMode,
      titleIcon: AdminSection.evidencePackage.icon,
      accent: AdminSection.evidencePackage.accent,
      child: _buildEvidencePackagePage(),
    ));
  }

  void _openKnowledgeMapPage() {
    _pushAnimatedPage(PageWithBackButton(
      title: '知识地图',
      isDarkMode: _isDarkMode,
      titleIcon: AdminSection.knowledgeGraph.icon,
      accent: AdminSection.knowledgeGraph.accent,
      compactHeader: true,
      child: KnowledgeGraphPage(
        isDarkMode: _isDarkMode,
        controller: _appDataController,
      ),
    ));
  }

  void _openAssistantSettingsPage() {
    _pushAnimatedPage(PageWithBackButton(
      title: '助手设置',
      isDarkMode: _isDarkMode,
      titleIcon: AdminSection.aiSettings.icon,
      accent: AdminSection.aiSettings.accent,
      compactHeader: true,
      child: AiSettingsPage(
        isDarkMode: _isDarkMode,
        controller: _appDataController,
      ),
    ));
  }

  void _openSystemSettingsPage() {
    _pushAnimatedPage(PageWithBackButton(
      title: '应用设置',
      isDarkMode: _isDarkMode,
      titleIcon: AdminSection.settings.icon,
      accent: AdminSection.settings.accent,
      compactHeader: true,
      child: AiSettingsPage(
        isDarkMode: _isDarkMode,
        controller: _appDataController,
        mode: AiSettingsMode.system,
        onOpenAssistantSettings: _openAssistantSettingsPage,
        onOpenHistory: _openAuditLogPage,
        onOpenTrash: _openTrashPage,
        onOpenAbout: _openAboutPage,
      ),
    ));
  }

  void _openAuditLogPage() {
    _pushAnimatedPage(PageWithBackButton(
      title: '整理历史',
      isDarkMode: _isDarkMode,
      titleIcon: AdminSection.auditLog.icon,
      accent: AdminSection.auditLog.accent,
      compactHeader: true,
      child: AuditLogPage(
        isDarkMode: _isDarkMode,
        controller: _appDataController,
        onRetry: _retryAuditRecord,
      ),
    ));
  }

  void _openTrashPage() {
    _pushAnimatedPage(PageWithBackButton(
      title: '回收站',
      isDarkMode: _isDarkMode,
      titleIcon: AdminSection.trash.icon,
      accent: AdminSection.trash.accent,
      compactHeader: true,
      child: TrashPage(
        isDarkMode: _isDarkMode,
        controller: _appDataController,
      ),
    ));
  }

  void _openAboutPage() {
    _pushAnimatedPage(PageWithBackButton(
      title: '应用介绍',
      isDarkMode: _isDarkMode,
      titleIcon: AdminSection.overview.icon,
      accent: AdminSection.overview.accent,
      compactHeader: true,
      child: AboutPage(isDarkMode: _isDarkMode),
    ));
  }

  void _openStudyLogsPage() {
    _pushAnimatedPage(PageWithBackButton(
      title: '学习记录',
      isDarkMode: _isDarkMode,
      titleIcon: Icons.edit_note_rounded,
      accent: StudyUi.primary,
      compactHeader: true,
      child: StudyLogsPage(
        isDarkMode: _isDarkMode,
        controller: _appDataController,
      ),
    ));
  }

  void _openTasksPage({bool initialOverdueFilter = false}) {
    _pushAnimatedPage(PageWithBackButton(
      title: '任务清单',
      isDarkMode: _isDarkMode,
      titleIcon: Icons.flag_rounded,
      accent: StudyUi.primary,
      compactHeader: true,
      child: StudyTasksPage(
        isDarkMode: _isDarkMode,
        controller: _appDataController,
        initialOverdueFilter: initialOverdueFilter,
      ),
    ));
  }

  void _openTaskPlanningPage() {
    _pushAnimatedPage(PageWithBackButton(
      title: '学习流程',
      isDarkMode: _isDarkMode,
      titleIcon: AdminSection.automations.icon,
      accent: AdminSection.automations.accent,
      compactHeader: true,
      child: TaskPlanningPage(
        isDarkMode: _isDarkMode,
        controller: _appDataController,
        onOpenTasks: () => _openTasksPage(),
        onOpenOverdueTasks: () => _openTasksPage(initialOverdueFilter: true),
      ),
    ));
  }

  void _openFlashCardLibrary() {
    _openFlashCardPage();
  }

  void _openFlashCardNewGroupReview() {
    _openFlashCardPage(
      autoGenerate: false,
      debugAutoOpenNewGroupDialog: true,
    );
  }

  void _openFlashCardGradeResultReview() {
    _openFlashCardPage(
      autoGenerate: false,
      debugAutoOpenGradeResultDialog: true,
    );
  }

  void _openLearningMomentsPage() {
    _pushAnimatedPage(LearningMomentsPage(
      isDarkMode: _isDarkMode,
      controller: _appDataController,
      onOpenStudyGroup: _openStudyGroupPage,
    ));
  }

  void _openStudyGroupPage() {
    _pushAnimatedPage(PageWithBackButton(
      title: '学习小组',
      isDarkMode: _isDarkMode,
      titleIcon: AdminSection.studyGroup.icon,
      accent: AdminSection.studyGroup.accent,
      compactHeader: true,
      child: StudyGroupPage(
        isDarkMode: _isDarkMode,
        controller: _appDataController,
      ),
    ));
  }

  void _openStudyNotesPage() {
    _pushAnimatedPage(StudyNotesPage(
      isDarkMode: _isDarkMode,
      controller: _appDataController,
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
    StudyToast.show(context, message);
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
    _markAssistantOverlayNeedsBuild();
  }

  void _selectAdminSection(AdminSection section) {
    _closeMenu();
    switch (section) {
      case AdminSection.overview:
        _openAboutPage();
        return;
      case AdminSection.notes:
        _openStudyNotesPage();
        return;
      case AdminSection.flashCard:
        _openFlashCardLibrary();
        return;
      case AdminSection.learningMoments:
        _openLearningMomentsPage();
        return;
      case AdminSection.evidencePackage:
        _pushAnimatedPage(PageWithBackButton(
          title: '7天学习回顾',
          isDarkMode: _isDarkMode,
          titleIcon: AdminSection.evidencePackage.icon,
          accent: AdminSection.evidencePackage.accent,
          child: _buildEvidencePackagePage(),
        ));
        return;
      case AdminSection.timer:
        _openTimerPage();
        return;
      case AdminSection.studyGroup:
        _openStudyGroupPage();
        return;
      case AdminSection.leaderboard:
        _pushAnimatedPage(PageWithBackButton(
          title: '学习进度',
          isDarkMode: _isDarkMode,
          titleIcon: AdminSection.leaderboard.icon,
          accent: AdminSection.leaderboard.accent,
          compactHeader: true,
          child: LeaderboardPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
            onOpenStudyGroup: _openStudyGroupPage,
            onOpenLearningMoments: _openLearningMomentsPage,
          ),
        ));
        return;
      case AdminSection.achievements:
        _pushAnimatedPage(PageWithBackButton(
          title: '成长记录',
          isDarkMode: _isDarkMode,
          titleIcon: AdminSection.achievements.icon,
          accent: AdminSection.achievements.accent,
          compactHeader: true,
          child: AchievementsPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
          ),
        ));
        return;
      case AdminSection.knowledgeGraph:
        _openKnowledgeMapPage();
        return;
      case AdminSection.aiAssistant:
        _openLearningCockpit();
        return;
      case AdminSection.aiSettings:
        _openAssistantSettingsPage();
        return;
      case AdminSection.settings:
        _openSystemSettingsPage();
        return;
      case AdminSection.automations:
        _pushAnimatedPage(PageWithBackButton(
          title: '学习流程',
          isDarkMode: _isDarkMode,
          titleIcon: AdminSection.automations.icon,
          accent: AdminSection.automations.accent,
          compactHeader: true,
          child: TaskPlanningPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
            onOpenTasks: () => _openTasksPage(),
            onOpenOverdueTasks: () =>
                _openTasksPage(initialOverdueFilter: true),
          ),
        ));
        return;
      case AdminSection.analytics:
      case AdminSection.statistics:
        _pushAnimatedPage(PageWithBackButton(
          title: '数据看板',
          isDarkMode: _isDarkMode,
          titleIcon: section.icon,
          accent: section.accent,
          compactHeader: true,
          child: LearningDashboardPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
            onOpenTasks: () => _openTasksPage(),
            onOpenOverdueTasks: () =>
                _openTasksPage(initialOverdueFilter: true),
            onOpenLogs: _openStudyLogsPage,
            onOpenLearningMoments: _openLearningMomentsPage,
            onOpenTaskPlanning: _openTaskPlanningPage,
            onOpenKnowledgeMap: _openKnowledgeMapPage,
            onOpenWeeklyReview: _openWeeklyReviewPage,
          ),
        ));
        return;
      case AdminSection.auditLog:
        _openAuditLogPage();
        return;
      case AdminSection.trash:
        _openTrashPage();
        return;
    }
  }

  Future<void> _setDarkMode(bool value) async {
    setState(() => _isDarkMode = value);
    await _appDataController.setDarkMode(value);
  }

  void _openWeeklyReport() {
    _bringAssistantOverlayToFront();
    _pushAnimatedPage(_WeeklyReportPage(
      controller: _appDataController,
      isDarkMode: _isDarkMode,
    ));
  }

  void _openCourseDetail(String courseName) {
    _bringAssistantOverlayToFront();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _withStudyTheme(
          CourseDetailPage(
            courseName: courseName,
            isDarkMode: _isDarkMode,
            controller: _appDataController,
          ),
        ),
      ),
    );
  }

  void _openCourseArchivePage() {
    _pushAnimatedPage(PageWithBackButton(
      title: '课程归档',
      isDarkMode: _isDarkMode,
      titleIcon: Icons.inventory_2_rounded,
      accent: StudyUi.pathBlue,
      compactHeader: true,
      child: CourseArchivePage(
        isDarkMode: _isDarkMode,
        controller: _appDataController,
        onViewCourse: _openCourseDetail,
      ),
    ));
  }

  void _openUserProfile(BuildContext _) {
    _bringAssistantOverlayToFront();
    _openUserProfilePage();
  }

  void _openAchievementsPage() {
    _pushAnimatedPage(PageWithBackButton(
      title: '成长记录',
      isDarkMode: _isDarkMode,
      titleIcon: AdminSection.achievements.icon,
      accent: AdminSection.achievements.accent,
      compactHeader: true,
      child: AchievementsPage(
        isDarkMode: _isDarkMode,
        controller: _appDataController,
      ),
    ));
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
          onOpenLogs: _openStudyLogsPage,
          onOpenCalendar: () => _selectPrimaryTab(PrimaryTab.scenarios),
          onOpenTasks: () => _openTasksPage(),
          onOpenOverdueTasks: () =>
              _openTasksPage(initialOverdueFilter: true),
          onOpenNotes: _openStudyNotesPage,
          onOpenTimer: _openTimerPage,
          onOpenFlashCards: _openFlashCardLibrary,
          onStartFlashCardReview: () => _openFlashCardReview(),
          onOpenLearningMoments: _openLearningMomentsPage,
          onOpenEvidencePackage: () => _pushAnimatedPage(PageWithBackButton(
            title: '7天学习回顾',
            isDarkMode: _isDarkMode,
            titleIcon: AdminSection.evidencePackage.icon,
            accent: AdminSection.evidencePackage.accent,
            child: _buildEvidencePackagePage(),
          )),
          onOpenStudyGroup: _openStudyGroupPage,
          onOpenLeaderboard: () => _pushAnimatedPage(PageWithBackButton(
            title: '学习进度',
            isDarkMode: _isDarkMode,
            titleIcon: AdminSection.leaderboard.icon,
            accent: AdminSection.leaderboard.accent,
            compactHeader: true,
            child: LeaderboardPage(
              isDarkMode: _isDarkMode,
              controller: _appDataController,
              onOpenStudyGroup: _openStudyGroupPage,
              onOpenLearningMoments: _openLearningMomentsPage,
            ),
          )),
          onOpenSyncSettings: _openSystemSettingsPage,
          onOpenTaskPlanning: () => _pushAnimatedPage(PageWithBackButton(
            title: '学习流程',
            isDarkMode: _isDarkMode,
            titleIcon: AdminSection.automations.icon,
            accent: AdminSection.automations.accent,
            compactHeader: true,
            child: TaskPlanningPage(
              isDarkMode: _isDarkMode,
              controller: _appDataController,
              onOpenTasks: () => _openTasksPage(),
              onOpenOverdueTasks: () =>
                  _openTasksPage(initialOverdueFilter: true),
            ),
          )),
        );
      case PrimaryTab.scenarios:
        return _PrimaryTabSurface(
          isDarkMode: _isDarkMode,
          child: CalendarPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
            onOpenTasks: () => _openTasksPage(),
            onOpenLogs: _openLearningMomentsPage,
          ),
        );
      case PrimaryTab.calendar:
        return _PrimaryTabSurface(
          isDarkMode: _isDarkMode,
          child: TimerPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
            showAppBar: false,
          ),
        );
      case PrimaryTab.create:
        return _PrimaryTabSurface(
          isDarkMode: _isDarkMode,
          child: FlashCardPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
            onOpenNotes: _openStudyNotesPage,
            showAppBar: false,
          ),
        );
      case PrimaryTab.profile:
        return _PrimaryTabSurface(
          isDarkMode: _isDarkMode,
          child: UserProfilePage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
            onOpenAchievements: _openAchievementsPage,
            onOpenCourseArchive: _openCourseArchivePage,
            showAppBar: false,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final safeBottom = mediaQuery.padding.bottom;
    final screenWidth = mediaQuery.size.width;
    _menuWidth = math.min(screenWidth * 0.64, 252);

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
              ? _withStudyTheme(
                  AdminSectionPage(
                    section: _activeAdminSection!,
                    isDarkMode: _isDarkMode,
                    controller: _appDataController,
                    onOpenSettings: () =>
                        _selectAdminSection(AdminSection.aiSettings),
                    onOpenNotes: _openStudyNotesPage,
                    onExecuteActions: _executeAssistantActions,
                    onBack: () => setState(() => _activeAdminSection = null),
                  ),
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
                showMenuButton: _activeAdminSection != null ||
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
              if (_backendReachable == -1 &&
                  _appDataController.isLoggedIn &&
                  (_activeAdminSection != null || progress > 0.5))
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
                            color:
                                const Color(0xFFEF6850).withValues(alpha: 0.92),
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
                                '本机保存中',
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
    return Theme(
      data: isDarkMode ? buildDarkAppTheme() : buildAppTheme(),
      child: ColoredBox(
        color: isDarkMode ? const Color(0xFF101625) : const Color(0xFFF5F7FF),
        child: child,
      ),
    );
  }
}

class _DraggableAssistantButton extends StatelessWidget {
  const _DraggableAssistantButton({
    required this.isDarkMode,
    required this.accent,
    required this.safeBottom,
    required this.menuProgress,
    required this.offset,
    required this.onOffsetChanged,
    required this.onTap,
  });

  final bool isDarkMode;
  final Color accent;
  final double safeBottom;
  final double menuProgress;
  final Offset? offset;
  final ValueChanged<Offset> onOffsetChanged;
  final VoidCallback onTap;

  static const _size = 54.0;
  static const _margin = 10.0;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bounds = media.size;
    final defaultOffset = Offset(
      bounds.width - _size - 12,
      bounds.height - safeBottom - media.viewInsets.bottom - 116,
    );
    final current = _clampOffset(offset ?? defaultOffset, bounds, media);

    return Positioned(
      left: current.dx,
      top: current.dy,
      child: IgnorePointer(
        ignoring: menuProgress > 0.55,
        child: AnimatedOpacity(
          opacity: menuProgress > 0.55 ? 0 : 1,
          duration: const Duration(milliseconds: 160),
          child: _GlobalAssistantButton(
            isDarkMode: isDarkMode,
            accent: accent,
            onTap: onTap,
            onPanUpdate: (details) {
              onOffsetChanged(
                _clampOffset(current + details.delta, bounds, media),
              );
            },
          ),
        ),
      ),
    );
  }

  Offset _clampOffset(Offset value, Size bounds, MediaQueryData media) {
    final minX = _margin;
    final maxX = math.max(_margin, bounds.width - _size - _margin);
    final minY = media.padding.top + _margin;
    final maxY = math.max(
      minY,
      bounds.height - _size - safeBottom - media.viewInsets.bottom - 86,
    );
    return Offset(
      value.dx.clamp(minX, maxX).toDouble(),
      value.dy.clamp(minY, maxY).toDouble(),
    );
  }
}

class _GlobalAssistantButton extends StatefulWidget {
  const _GlobalAssistantButton({
    required this.isDarkMode,
    required this.accent,
    required this.onTap,
    required this.onPanUpdate,
  });

  final bool isDarkMode;
  final Color accent;
  final VoidCallback onTap;
  final GestureDragUpdateCallback onPanUpdate;

  @override
  State<_GlobalAssistantButton> createState() => _GlobalAssistantButtonState();
}

class _GlobalAssistantButtonState extends State<_GlobalAssistantButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motionController;

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _motionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '全局学习助手',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onPanUpdate: widget.onPanUpdate,
          child: AnimatedBuilder(
            animation: _motionController,
            builder: (context, child) {
              final t = Curves.easeInOut.transform(_motionController.value);
              final lift = math.sin(t * math.pi) * 5;
              final turn = math.sin(t * math.pi * 2) * 0.04;
              final scale = 1 + math.sin(t * math.pi) * 0.035;
              return Transform.translate(
                offset: Offset(0, -lift),
                child: Transform.rotate(
                  angle: turn,
                  child: Transform.scale(scale: scale, child: child),
                ),
              );
            },
            child: Container(
              width: 54,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.accent.withValues(alpha: 0.22),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: widget.isDarkMode ? 0.28 : 0.10,
                    ),
                    blurRadius: 14,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: const StudyAssetIcon(
                asset: AppAssets.aiFloatingAssistantIcon,
                preserveColor: true,
                fallbackIcon: Icons.smart_toy_rounded,
                size: 50,
              ),
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
  bool _isSaving = false;

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

  Future<void> _pickDate({required bool isStart}) async {
    final current = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (context, child) {
        final theme = widget.isDarkMode ? buildDarkAppTheme() : buildAppTheme();
        return Theme(data: theme, child: child ?? const SizedBox.shrink());
      },
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_startDate.isAfter(_endDate)) _endDate = picked;
      } else {
        _endDate = picked;
        if (_endDate.isBefore(_startDate)) _startDate = picked;
      }
    });
  }

  void _copyReport() {
    final content = _reportContent;
    if (content == null) return;
    Clipboard.setData(ClipboardData(text: content));
    StudyToast.show(context, '已复制到剪贴板');
  }

  Future<void> _saveReport() async {
    final content = _reportContent;
    if (content == null || _isSaving) return;
    setState(() => _isSaving = true);
    await widget.controller.saveWeeklyReport(
      content,
      startDate: _startDate,
      endDate: _endDate,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    StudyToast.show(context, '每周回顾已保存');
  }

  @override
  Widget build(BuildContext context) {
    const accent = StudyUi.primary;
    final bodyColor = StudyUi.body(widget.isDarkMode);
    final logsInRange = widget.controller.studyLogs
        .where((item) =>
            !item.date.isBefore(_startDate) && !item.date.isAfter(_endDate))
        .length;
    final tasksInRange = widget.controller.studyTasks
        .where((item) =>
            !item.deadline.isBefore(_startDate) &&
            !item.deadline.isAfter(_endDate))
        .length;
    final savedReportCount = widget.controller.weeklyReports.length;

    return Scaffold(
      backgroundColor: StudyUi.background(widget.isDarkMode),
      body: StudyScreenBackground(
        isDarkMode: widget.isDarkMode,
        accent: accent,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 34),
            children: [
              _WeeklyReportTopBar(
                isDarkMode: widget.isDarkMode,
                accent: accent,
              ),
              const SizedBox(height: 14),
              StudyPathHero(
                isDarkMode: widget.isDarkMode,
                accent: accent,
                badge: '每周回顾',
                title: _reportContent == null ? '整理这 7 天的学习轨迹' : '本周学习轨迹已整理好',
                subtitle: _reportContent == null
                    ? '把日志、任务和复盘材料整理成一份可以保存的每周回顾。'
                    : '可以复制、保存为文档，或留到每周回顾里。',
                icon: Icons.summarize_rounded,
                steps: const ['范围', '整理', '文档', '保存'],
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: StudyPathMetricPill(
                            label: '学习日志',
                            value: '$logsInRange',
                            icon: Icons.menu_book_rounded,
                            color: StudyUi.pathBlue,
                            isDarkMode: widget.isDarkMode,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StudyPathMetricPill(
                            label: '相关任务',
                            value: '$tasksInRange',
                            icon: Icons.task_alt_rounded,
                            color: StudyUi.success,
                            isDarkMode: widget.isDarkMode,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    StudyPathMetricPill(
                      label: '时间范围',
                      value:
                          '${_shortDate(_startDate)} - ${_shortDate(_endDate)}',
                      icon: Icons.date_range_rounded,
                      color: StudyUi.pathWarm,
                      isDarkMode: widget.isDarkMode,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _WeeklyReportInsightStrip(
                isDarkMode: widget.isDarkMode,
                goodText: logsInRange > 0
                    ? '本周沉淀了 $logsInRange 条学习记录，可以继续保留这个复盘节奏。'
                    : '先记录一次学习现场，每周回顾会更有抓手。',
                adjustText: tasksInRange > 0
                    ? '把 $tasksInRange 个相关任务再拆小，避免集中到最后一天。'
                    : '本周任务还没有进入回顾范围，可以先补一个下一步。',
                nextText: _reportContent == null
                    ? '整理后保存到每周回顾，方便下周接着复盘。'
                    : '每周回顾已经生成，可以保存为文档或留到回顾里。',
                routeText:
                    '已保存 $savedReportCount 份回顾 · ${_shortDate(_startDate)} - ${_shortDate(_endDate)}',
              ),
              const SizedBox(height: 16),
              StudyCard(
                color: StudyUi.surface(widget.isDarkMode)
                    .withValues(alpha: widget.isDarkMode ? 0.82 : 0.88),
                borderColor: Colors.white
                    .withValues(alpha: widget.isDarkMode ? 0.10 : 0.70),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StudyGlassIconNode(
                          icon: Icons.event_note_rounded,
                          accent: accent,
                          size: 42,
                          iconSize: 20,
                          isDarkMode: widget.isDarkMode,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '回顾范围',
                                style: TextStyle(
                                  color: StudyUi.title(widget.isDarkMode),
                                  fontSize: 16,
                                  fontWeight: AppTypography.title,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '选择要整理的学习记录时间段。',
                                style: TextStyle(
                                  color: bodyColor,
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _DateButton(
                            label: '开始',
                            date: _startDate,
                            isDarkMode: widget.isDarkMode,
                            onTap: () => _pickDate(isStart: true),
                            accentColor: accent,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: StudyUi.muted(widget.isDarkMode),
                            size: 18,
                          ),
                        ),
                        Expanded(
                          child: _DateButton(
                            label: '结束',
                            date: _endDate,
                            isDarkMode: widget.isDarkMode,
                            onTap: () => _pickDate(isStart: false),
                            accentColor: StudyUi.pathWarm,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _ReportPrimaryButton(
                      key: const Key('do_generate_report_button'),
                      label: _isGenerating ? '整理中...' : '整理每周回顾',
                      icon: Icons.auto_awesome_rounded,
                      color: accent,
                      isDarkMode: widget.isDarkMode,
                      onTap: _isGenerating ? null : _generate,
                    ),
                  ],
                ),
              ),
              if (_reportContent != null) ...[
                const SizedBox(height: 16),
                StudyCard(
                  color: StudyUi.surface(widget.isDarkMode)
                      .withValues(alpha: widget.isDarkMode ? 0.84 : 0.90),
                  borderColor: Colors.white
                      .withValues(alpha: widget.isDarkMode ? 0.10 : 0.70),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StudyGlassIconNode(
                            icon: Icons.description_rounded,
                            accent: StudyUi.secondary,
                            size: 42,
                            iconSize: 20,
                            isDarkMode: widget.isDarkMode,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '回顾内容',
                                  style: TextStyle(
                                    color: StudyUi.title(widget.isDarkMode),
                                    fontSize: 16,
                                    fontWeight: AppTypography.title,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '整理完成后可以复制、保存为文档或留到每周回顾。',
                                  style: TextStyle(
                                    color: bodyColor,
                                    fontSize: 12,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _ReportActionPill(
                            label: '复制',
                            icon: Icons.copy_rounded,
                            color: StudyUi.pathBlue,
                            isDarkMode: widget.isDarkMode,
                            onTap: _copyReport,
                          ),
                          _ReportActionPill(
                            label: _isExporting ? '保存中' : '保存为文档',
                            icon: Icons.description_rounded,
                            color: StudyUi.secondary,
                            isDarkMode: widget.isDarkMode,
                            onTap: _isExporting
                                ? null
                                : () => _exportReport(asPdf: false),
                          ),
                          _ReportActionPill(
                            label: _isExporting ? '保存中' : '保存为 PDF',
                            icon: Icons.picture_as_pdf_rounded,
                            color: StudyUi.pathWarm,
                            isDarkMode: widget.isDarkMode,
                            onTap: _isExporting
                                ? null
                                : () => _exportReport(asPdf: true),
                          ),
                          _ReportActionPill(
                            label: _isSaving ? '保存中' : '保存',
                            icon: Icons.save_rounded,
                            color: StudyUi.success,
                            filled: true,
                            isDarkMode: widget.isDarkMode,
                            onTap: _isSaving ? null : _saveReport,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: StudyUi.surfaceAlt(widget.isDarkMode)
                              .withValues(
                                  alpha: widget.isDarkMode ? 0.78 : 0.84),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: StudyUi.border(widget.isDarkMode),
                          ),
                        ),
                        child: Text(
                          _reportContent!,
                          style: TextStyle(
                            color: bodyColor,
                            height: 1.62,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _shortDate(DateTime date) {
    return '${date.month}/${date.day}';
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
      StudyToast.show(context, '已保存${asPdf ? ' PDF' : '文档'}，文件位置已复制');
    } catch (error) {
      if (!mounted) return;
      StudyToast.dialog(
        context,
        title: '保存失败',
        message: '这次没有保存成功，请稍后再试。',
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}

class _WeeklyReportInsightStrip extends StatelessWidget {
  const _WeeklyReportInsightStrip({
    required this.isDarkMode,
    required this.goodText,
    required this.adjustText,
    required this.nextText,
    required this.routeText,
  });

  final bool isDarkMode;
  final String goodText;
  final String adjustText;
  final String nextText;
  final String routeText;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      color: StudyUi.surface(isDarkMode)
          .withValues(alpha: isDarkMode ? 0.82 : 0.90),
      borderColor: Colors.white.withValues(alpha: isDarkMode ? 0.10 : 0.72),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WeeklyReportInsightTile(
            isDarkMode: isDarkMode,
            icon: Icons.thumb_up_alt_rounded,
            accent: StudyUi.pathMint,
            title: '做得好的',
            text: goodText,
          ),
          const SizedBox(height: 10),
          _WeeklyReportInsightTile(
            isDarkMode: isDarkMode,
            icon: Icons.tune_rounded,
            accent: StudyUi.pathWarm,
            title: '需要调整',
            text: adjustText,
          ),
          const SizedBox(height: 10),
          _WeeklyReportInsightTile(
            isDarkMode: isDarkMode,
            icon: Icons.near_me_rounded,
            accent: StudyUi.secondary,
            title: '下一步建议',
            text: nextText,
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: StudyUi.surfaceAlt(isDarkMode)
                  .withValues(alpha: isDarkMode ? 0.72 : 0.86),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: StudyUi.border(isDarkMode)),
            ),
            child: Row(
              children: [
                StudyGlassIconNode(
                  icon: Icons.timeline_rounded,
                  accent: StudyUi.pathCyan,
                  size: 36,
                  iconSize: 17,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '本周学习路线回顾',
                        style: TextStyle(
                          color: StudyUi.title(isDarkMode),
                          fontSize: 14,
                          fontWeight: AppTypography.title,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        routeText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: StudyUi.body(isDarkMode),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyReportInsightTile extends StatelessWidget {
  const _WeeklyReportInsightTile({
    required this.isDarkMode,
    required this.icon,
    required this.accent,
    required this.title,
    required this.text,
  });

  final bool isDarkMode;
  final IconData icon;
  final Color accent;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: StudyUi.chipBackground(accent, isDarkMode),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accent.withValues(alpha: isDarkMode ? 0.24 : 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StudyGlassIconNode(
            icon: icon,
            accent: accent,
            size: 36,
            iconSize: 17,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: StudyUi.title(isDarkMode),
                    fontSize: 14,
                    fontWeight: AppTypography.title,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: StudyUi.body(isDarkMode),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyReportTopBar extends StatelessWidget {
  const _WeeklyReportTopBar({
    required this.isDarkMode,
    required this.accent,
  });

  final bool isDarkMode;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      color: StudyUi.surface(isDarkMode)
          .withValues(alpha: isDarkMode ? 0.78 : 0.86),
      borderColor: Colors.white.withValues(alpha: isDarkMode ? 0.10 : 0.72),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: StudyUi.chipBackground(accent, isDarkMode),
                border: Border.all(
                  color: accent.withValues(alpha: isDarkMode ? 0.28 : 0.18),
                ),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: StudyUi.title(isDarkMode),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          StudyGlassIconNode(
            icon: Icons.summarize_rounded,
            accent: accent,
            size: 42,
            iconSize: 20,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '每周回顾',
                  style: TextStyle(
                    color: StudyUi.title(isDarkMode),
                    fontSize: 18,
                    fontWeight: AppTypography.title,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '把一周学习整理成可回看的轨迹。',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: StudyUi.body(isDarkMode),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.date,
    required this.isDarkMode,
    required this.onTap,
    required this.accentColor,
  });

  final String label;
  final DateTime date;
  final bool isDarkMode;
  final VoidCallback onTap;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: StudyUi.chipBackground(accentColor, isDarkMode),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: accentColor.withValues(alpha: isDarkMode ? 0.24 : 0.18),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_month_rounded,
              color: accentColor,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: StudyUi.body(isDarkMode),
                      fontSize: 11,
                      fontWeight: AppTypography.title,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: StudyUi.title(isDarkMode),
                      fontSize: 13,
                      fontWeight: AppTypography.hero,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportPrimaryButton extends StatelessWidget {
  const _ReportPrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.isDarkMode,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool isDarkMode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.56 : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                color,
                Color.alphaBlend(
                  Colors.white.withValues(alpha: isDarkMode ? 0.08 : 0.16),
                  color,
                ),
              ],
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDarkMode ? 0.16 : 0.50),
            ),
            boxShadow: [
              if (!disabled)
                BoxShadow(
                  color: color.withValues(alpha: isDarkMode ? 0.16 : 0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 9),
                ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: AppTypography.title,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportActionPill extends StatelessWidget {
  const _ReportActionPill({
    required this.label,
    required this.icon,
    required this.color,
    required this.isDarkMode,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool isDarkMode;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final foreground = filled ? Colors.white : color;
    return Opacity(
      opacity: disabled ? 0.50 : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: filled ? color : StudyUi.chipBackground(color, isDarkMode),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: filled
                  ? Colors.white.withValues(alpha: isDarkMode ? 0.12 : 0.36)
                  : color.withValues(alpha: isDarkMode ? 0.24 : 0.18),
            ),
            boxShadow: filled && !disabled
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: isDarkMode ? 0.18 : 0.24),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foreground, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: AppTypography.title,
                ),
              ),
            ],
          ),
        ),
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
    required this.showMenuButton,
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
  final bool showMenuButton;
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
    final scale = lerpDouble(1, 0.84, progress)!;
    final rotateY = lerpDouble(0, 18 * math.pi / 180, progress)!;
    final radius = lerpDouble(0, 24, progress)!;
    final revealedMenuEdge = menuWidth * progress;
    final scaledInset = screenWidth * (1 - scale) / 2;
    final seamOverlap = progress;
    final translateX = math.max(
      0.0,
      revealedMenuEdge - scaledInset - seamOverlap,
    );

    final transform = Matrix4.identity()
      ..setEntry(3, 2, 0.0009)
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
            : DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white70,
                      StudyUi.background(false),
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
                    transitionBuilder: (child, animation, secondaryAnimation) {
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
                if (showMenuButton)
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
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: safeBottom + 118,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: isDarkMode
                              ? [
                                  Colors.transparent,
                                  const Color(0xFF0A1020)
                                      .withValues(alpha: 0.78),
                                ]
                              : [
                                  Colors.transparent,
                                  Colors.white.withValues(alpha: 0.9),
                                ],
                        ),
                      ),
                    ),
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? const Color(0xFF111726).withValues(alpha: 0.94)
                    : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.8),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF17203A).withValues(alpha: 0.18),
                    offset: const Offset(0, 18),
                    blurRadius: 28,
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
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final activeColor = const Color(0xFF4470E8);
    final inactiveColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.62)
        : const Color(0xFF6E7687);
    final labelColor = isActive ? activeColor : inactiveColor;
    final iconColor = isActive ? activeColor : inactiveColor;
    return Semantics(
      button: true,
      selected: isActive,
      label: tab.label,
      child: GestureDetector(
        key: Key('bottom_nav_${tab.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              margin: const EdgeInsets.only(bottom: 2),
              duration: const Duration(milliseconds: 200),
              curve: Curves.fastOutSlowIn,
              height: 4,
              width: isActive ? 20 : 0,
              decoration: BoxDecoration(
                color: const Color(0xFF81B4FF),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              height: 34,
              width: 44,
              decoration: BoxDecoration(
                color: isActive
                    ? activeColor.withValues(alpha: isDarkMode ? 0.18 : 0.10)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive
                      ? activeColor.withValues(alpha: isDarkMode ? 0.26 : 0.18)
                      : Colors.transparent,
                ),
              ),
              child: Icon(
                tab.icon,
                color: iconColor,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              tab.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: labelColor,
                fontSize: 10,
                height: 1,
                fontWeight: isActive ? AppTypography.title : FontWeight.w600,
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
                            StudyUserAvatar(
                              avatarImagePath:
                                  widget.controller.userProfile.avatarImagePath,
                              avatarEmoji:
                                  widget.controller.userProfile.avatarEmoji,
                              size: 42,
                              accent: accent,
                              isDarkMode: true,
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
                      label: '学习助手',
                      asset: AppAssets.sideAiAssistantIcon,
                      accent: AdminSection.aiAssistant.accent,
                      fallbackIcon: Icons.smart_toy_rounded,
                      selected:
                          widget.currentSection == AdminSection.aiAssistant,
                      onTap: () => widget.onSelected(AdminSection.aiAssistant),
                    ),
                    const SizedBox(height: 10),
                    _SideMenuActionItem(
                      label: '学习笔记',
                      asset: AppAssets.featureNotesIcon,
                      accent: AdminSection.notes.accent,
                      fallbackIcon: Icons.menu_book_rounded,
                      selected: widget.currentSection == AdminSection.notes,
                      onTap: () => widget.onSelected(AdminSection.notes),
                    ),
                    const SizedBox(height: 10),
                    _SideMenuActionItem(
                      label: '学迹动态',
                      asset: AppAssets.sideMomentsIcon,
                      accent: AdminSection.learningMoments.accent,
                      fallbackIcon: Icons.dynamic_feed_rounded,
                      selected:
                          widget.currentSection == AdminSection.learningMoments,
                      onTap: () =>
                          widget.onSelected(AdminSection.learningMoments),
                    ),
                    const SizedBox(height: 10),
                    _SideMenuActionItem(
                      label: '数据看板',
                      asset: AppAssets.sideDashboardIcon,
                      accent: AdminSection.analytics.accent,
                      fallbackIcon: Icons.insights_rounded,
                      selected: widget.currentSection == AdminSection.analytics,
                      onTap: () => widget.onSelected(AdminSection.analytics),
                    ),
                    const SizedBox(height: 10),
                    _SideMenuActionItem(
                      label: '设置',
                      asset: AppAssets.sideSettingsIcon,
                      accent: AdminSection.settings.accent,
                      fallbackIcon: Icons.settings_rounded,
                      selected: widget.currentSection == AdminSection.settings,
                      onTap: () => widget.onSelected(AdminSection.settings),
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

class _SideMenuActionItem extends StatefulWidget {
  const _SideMenuActionItem({
    required this.label,
    required this.asset,
    required this.accent,
    required this.fallbackIcon,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final String asset;
  final Color accent;
  final IconData fallbackIcon;
  final VoidCallback onTap;
  final bool selected;

  @override
  State<_SideMenuActionItem> createState() => _SideMenuActionItemState();
}

class _SideMenuActionItemState extends State<_SideMenuActionItem> {
  bool _hovered = false;
  bool _pressed = false;

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.selected || _hovered || _pressed;
    return LayoutBuilder(
      builder: (context, constraints) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => _setHovered(true),
          onExit: (_) {
            _setHovered(false);
            _setPressed(false);
          },
          child: GestureDetector(
            onTap: widget.onTap,
            onTapDown: (_) => _setPressed(true),
            onTapCancel: () => _setPressed(false),
            onTapUp: (_) => _setPressed(false),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              scale: _pressed ? 0.985 : 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  height: 58,
                  child: Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.fastOutSlowIn,
                        width: widget.selected ? constraints.maxWidth : 0,
                        height: 58,
                        left: 0,
                        top: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                widget.accent.withValues(alpha: 0.80),
                                widget.accent.withValues(alpha: 0.46),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: widget.accent.withValues(alpha: 0.24),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          decoration: BoxDecoration(
                            color: widget.selected
                                ? Colors.transparent
                                : Colors.white.withValues(
                                    alpha: active ? 0.08 : 0.045,
                                  ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(
                                alpha: widget.selected ? 0.20 : 0.06,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                StudyGlassIconNode(
                                  asset: widget.asset,
                                  icon: widget.fallbackIcon,
                                  accent: widget.selected
                                      ? Colors.white
                                      : widget.accent,
                                  size: 38,
                                  iconSize: 27,
                                  isDarkMode: true,
                                  preserveColor: true,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    widget.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: widget.selected ? 1 : 0.88,
                                      ),
                                      fontSize: 15,
                                      fontWeight: widget.selected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ),
                                AnimatedOpacity(
                                  duration: const Duration(milliseconds: 160),
                                  opacity: widget.selected ? 1 : 0,
                                  child: Icon(
                                    Icons.chevron_right_rounded,
                                    color: Colors.white.withValues(alpha: 0.78),
                                    size: 18,
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
