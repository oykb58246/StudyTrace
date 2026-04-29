import 'package:flutter/material.dart';

import '../src/services/notification_service.dart';
import '../src/theme/app_theme.dart';
import '../src/ui/login/login_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    NotificationService().init();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'StudyTrace',
      theme: buildAppTheme(),
      home: const WelcomeScreen(),
    );
  }
}
