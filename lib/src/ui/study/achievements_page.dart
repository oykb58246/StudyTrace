import 'package:flutter/material.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/achievement.dart';
import '../../theme/app_theme.dart';

class AchievementsPage extends StatelessWidget {
  const AchievementsPage({
    super.key,
    required this.isDarkMode,
    required this.controller,
  });

  final bool isDarkMode;
  final AppDataController controller;

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor = isDarkMode ? AppColors.darkBody : AppColors.body;
    final cardColor = isDarkMode ? const Color(0xFF1E2430) : Colors.white;
    final accent = controller.primaryColor;

    final unlockedTypes = controller.unlockedAchievements
        .map((u) => u.type)
        .toSet();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        // 积分概览
        _PointsSummaryCard(
          totalPoints: controller.totalPoints,
          streakDays: controller.studyStreak,
          unlockedCount: controller.unlockedAchievements.length,
          totalCount: Achievement.all.length,
          accent: accent,
          isDarkMode: isDarkMode,
        ),
        const SizedBox(height: 24),
        Text(
          '全部成就',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        // 成就列表
        ...Achievement.all.map((achievement) {
          final isUnlocked = unlockedTypes.contains(achievement.type);
          final unlockedRecord = controller.unlockedAchievements
              .where((u) => u.type == achievement.type)
              .firstOrNull;
          return _AchievementTile(
            achievement: achievement,
            isUnlocked: isUnlocked,
            unlockedAt: unlockedRecord?.unlockedAt,
            cardColor: cardColor,
            textColor: textColor,
            bodyColor: bodyColor,
            accent: accent,
            isDarkMode: isDarkMode,
          );
        }),
      ],
    );
  }
}

class _PointsSummaryCard extends StatelessWidget {
  const _PointsSummaryCard({
    required this.totalPoints,
    required this.streakDays,
    required this.unlockedCount,
    required this.totalCount,
    required this.accent,
    required this.isDarkMode,
  });

  final int totalPoints;
  final int streakDays;
  final int unlockedCount;
  final int totalCount;
  final Color accent;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, accent.withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                value: totalPoints.toString(),
                label: '总积分',
                icon: Icons.toll_rounded,
              ),
              _StatItem(
                value: streakDays.toString(),
                label: '连续天数',
                icon: Icons.local_fire_department_rounded,
              ),
              _StatItem(
                value: '$unlockedCount/$totalCount',
                label: '已解锁',
                icon: Icons.emoji_events_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({
    required this.achievement,
    required this.isUnlocked,
    this.unlockedAt,
    required this.cardColor,
    required this.textColor,
    required this.bodyColor,
    required this.accent,
    required this.isDarkMode,
  });

  final Achievement achievement;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final Color cardColor;
  final Color textColor;
  final Color bodyColor;
  final Color accent;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnlocked
            ? cardColor
            : cardColor.withValues(alpha: isDarkMode ? 0.5 : 0.7),
        borderRadius: BorderRadius.circular(16),
        border: isUnlocked
            ? Border.all(color: accent.withValues(alpha: 0.3), width: 1)
            : null,
      ),
      child: Row(
        children: [
          // 图标
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isUnlocked
                  ? accent.withValues(alpha: 0.15)
                  : (isDarkMode
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFF0F0F5)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                _iconEmoji(achievement.iconName),
                style: TextStyle(
                  fontSize: 22,
                  color: isUnlocked ? null : Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // 文字
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      achievement.title,
                      style: TextStyle(
                        color: isUnlocked ? textColor : bodyColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+${achievement.points}分',
                      style: TextStyle(
                        color: isUnlocked ? accent : bodyColor.withValues(alpha: 0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  achievement.description,
                  style: TextStyle(
                    color: isUnlocked ? bodyColor : bodyColor.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
                if (isUnlocked && unlockedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '解锁于 ${_formatDate(unlockedAt!)}',
                    style: TextStyle(
                      color: accent.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // 状态
          if (isUnlocked)
            Icon(Icons.check_circle_rounded, color: accent, size: 22)
          else
            Icon(
              Icons.lock_outline_rounded,
              color: bodyColor.withValues(alpha: 0.3),
              size: 22,
            ),
        ],
      ),
    );
  }

  String _iconEmoji(String name) {
    switch (name) {
      case 'edit_note':
        return '📝';
      case 'task_alt':
        return '✅';
      case 'emoji_events':
        return '🏆';
      case 'military_tech':
        return '🎖️';
      case 'local_fire_department':
        return '🔥';
      case 'whatshot':
        return '🔥';
      case 'stars':
        return '⭐';
      case 'summarize':
        return '📊';
      case 'style':
        return '🃏';
      case 'menu_book':
        return '📖';
      case 'toll':
        return '🎯';
      case 'workspace_premium':
        return '🏅';
      case 'diamond':
        return '💎';
      case 'smart_toy':
        return '🤖';
      default:
        return '🏅';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
