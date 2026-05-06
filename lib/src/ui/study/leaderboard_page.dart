import 'package:flutter/material.dart';

import '../../controllers/app_data_controller.dart';
import '../../theme/app_theme.dart';

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({
    super.key,
    required this.isDarkMode,
    required this.controller,
  });

  final bool isDarkMode;
  final AppDataController controller;

  @override
  Widget build(BuildContext context) {
    final titleColor = isDarkMode ? Colors.white : Colors.black;
    final bodyColor = isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;
    final accent = controller.primaryColor;

    return ListView(
      key: const Key('page_leaderboard'),
      padding: const EdgeInsets.fromLTRB(22, 94, 22, 124),
      children: [
        Text(
          '排行榜',
          style: TextStyle(
            color: titleColor,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '查看全站或好友学习榜单，激发学习动力。（UI占位，待接入后端）',
          style: TextStyle(color: bodyColor, fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E2128) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              if (!isDarkMode)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Column(
            children: [
              Icon(Icons.leaderboard_rounded, size: 48, color: accent.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              Text(
                '谁是本周的卷王？',
                style: TextStyle(
                  color: titleColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '努力加载榜单数据中...',
                style: TextStyle(color: bodyColor, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
