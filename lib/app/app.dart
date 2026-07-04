import 'package:flutter/material.dart';

import '../src/config/ui_review_config.dart';
import '../src/controllers/app_data_controller.dart';
import '../src/services/notification_service.dart';
import '../src/theme/app_theme.dart';
import '../src/ui/login/login_screen.dart';
import '../src/ui/shared/global_route_observer.dart';
import '../src/ui/shell/app_shell.dart';
import '../src/ui/shell/navigation_models.dart';

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    this.initialController,
    this.controllerFactory,
  });

  final AppDataController? initialController;
  final AppDataController Function()? controllerFactory;

  @override
  Widget build(BuildContext context) {
    NotificationService().init();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'StudyTrace',
      theme: buildAppTheme(),
      routes: {
        '/login': (_) => WelcomeScreen(controllerFactory: controllerFactory),
      },
      navigatorObservers: [studyTraceNavigatorObserver],
      home: _StartupGate(
        initialController: initialController,
        controllerFactory: controllerFactory,
      ),
    );
  }
}

class _StartupGate extends StatefulWidget {
  const _StartupGate({
    this.initialController,
    this.controllerFactory,
  });

  final AppDataController? initialController;
  final AppDataController Function()? controllerFactory;

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  late final AppDataController _controller = widget.initialController ??
      widget.controllerFactory?.call() ??
      AppDataController();
  late final Future<void> _loadFuture = _controller.load();
  late final bool _ownsController = widget.initialController == null;
  bool _handedControllerToShell = false;

  @override
  void dispose() {
    if (_ownsController && !_handedControllerToShell) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _StartupLoadingPage();
        }
        if (_controller.isLoggedIn || UiReviewConfig.enabled) {
          _handedControllerToShell = true;
          return AppShell(
            initialController: _controller,
            debugMenuInitiallyOpen: _reviewMenuInitiallyOpen(),
            debugInitialPrimaryTab: _reviewInitialPrimaryTab(),
            debugInitialReviewTarget: _reviewInitialTarget(),
          );
        }
        return WelcomeScreen(controllerFactory: widget.controllerFactory);
      },
    );
  }

  PrimaryTab? _reviewInitialPrimaryTab() {
    if (!UiReviewConfig.enabled) return null;
    final target = UiReviewConfig.target.trim().toLowerCase();
    return switch (target) {
      'home' || 'assistant' || '首页' => PrimaryTab.assistant,
      'plan' ||
      'calendar' ||
      'task-planning' ||
      'tasks' ||
      'today-tasks' ||
      '计划' =>
        PrimaryTab.scenarios,
      'focus' || 'timer' || '专注' => PrimaryTab.calendar,
      'review' ||
      'flashcard' ||
      'flashcards' ||
      'flashcard-review' ||
      'flashcard-new-group' ||
      'flashcard-grade-result' ||
      'knowledge-flashcards' ||
      '知识闪卡' ||
      '复习' ||
      '复习页' =>
        PrimaryTab.create,
      'ai-assistant' ||
      'ai-cockpit' ||
      'ai-cockpit-saved-next-step' ||
      '学习助手' ||
      '学习座舱' =>
        PrimaryTab.assistant,
      'profile' ||
      'mine' ||
      '我的' ||
      'course-archive' ||
      '课程归档' =>
        PrimaryTab.profile,
      _ => null,
    };
  }

  bool _reviewMenuInitiallyOpen() {
    if (!UiReviewConfig.enabled) return false;
    final target = UiReviewConfig.target.trim().toLowerCase();
    return switch (target) {
      'side-menu' || 'menu' || 'sidebar' || '侧边栏' || '菜单' => true,
      _ => false,
    };
  }

  String? _reviewInitialTarget() {
    if (!UiReviewConfig.enabled) return null;
    final target = UiReviewConfig.target.trim();
    return _reviewMenuInitiallyOpen() || target.isEmpty ? null : target;
  }
}

class _StartupLoadingPage extends StatelessWidget {
  const _StartupLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.shell,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.ink),
      ),
    );
  }
}
