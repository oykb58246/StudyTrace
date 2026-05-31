import 'package:flutter/material.dart';

import '../src/controllers/app_data_controller.dart';
import '../src/services/notification_service.dart';
import '../src/theme/app_theme.dart';
import '../src/ui/login/login_screen.dart';
import '../src/ui/shared/global_route_observer.dart';
import '../src/ui/shell/app_shell.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    NotificationService().init();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'StudyTrace',
      theme: buildAppTheme(),
      routes: {
        '/login': (_) => const WelcomeScreen(),
      },
      navigatorObservers: [studyTraceNavigatorObserver],
      home: const _StartupGate(),
    );
  }
}

class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  late final AppDataController _controller = AppDataController();
  late final Future<void> _loadFuture = _controller.load();
  bool _handedControllerToShell = false;

  @override
  void dispose() {
    if (!_handedControllerToShell) {
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
        if (_controller.isLoggedIn) {
          _handedControllerToShell = true;
          return AppShell(initialController: _controller);
        }
        return const WelcomeScreen();
      },
    );
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
