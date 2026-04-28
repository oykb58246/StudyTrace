import 'package:flutter/material.dart';

import '../src/theme/app_theme.dart';
import '../src/ui/login/login_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '灵析 AI 助手',
      theme: buildAppTheme(),
      home: const WelcomeScreen(),
    );
  }
}
