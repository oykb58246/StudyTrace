import 'package:flutter/material.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/achievement.dart';
import '../../theme/app_theme.dart';
import '../shared/common_widgets.dart';

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
    final accent = controller.primaryColor;
    final unlockedByType = {
      for (final record in controller.unlockedAchievements) record.type: record,
    };
    final unlocked = Achievement.all
        .where((achievement) => unlockedByType.containsKey(achievement.type))
        .toList();
    final locked = Achievement.all
        .where((achievement) => !unlockedByType.containsKey(achievement.type))
        .toList();
    final total = Achievement.all.length;
    final level = _levelFor(controller.totalPoints);
    final nextLevel = _nextLevelPoints(controller.totalPoints);
    final levelStart = _levelStart(level);
    final levelProgress = nextLevel == null
        ? 1.0
        : ((controller.totalPoints - levelStart) / (nextLevel - levelStart))
            .clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        _PointsHero(
          accent: accent,
          totalPoints: controller.totalPoints,
          streakDays: controller.studyStreak,
          level: level,
          nextLevelPoints: nextLevel,
          levelProgress: levelProgress,
          unlockedCount: unlocked.length,
          totalCount: total,
        ),
        const SizedBox(height: 18),
        _BadgeWall(
          achievements: Achievement.all,
          unlockedByType: unlockedByType,
          accent: accent,
          isDarkMode: isDarkMode,
        ),
        const SizedBox(height: 22),
        _SectionTitle(
          title: '已解锁',
          subtitle: '${unlocked.length} 个徽章已收入你的学习档案',
          isDarkMode: isDarkMode,
        ),
        const SizedBox(height: 12),
        if (unlocked.isEmpty)
          _EmptyAchievementCard(isDarkMode: isDarkMode)
        else
          ...unlocked.map(
            (achievement) => _AchievementTile(
              achievement: achievement,
              isUnlocked: true,
              unlockedAt: unlockedByType[achievement.type]?.unlockedAt,
              accent: accent,
              isDarkMode: isDarkMode,
            ),
          ),
        const SizedBox(height: 18),
        _SectionTitle(
          title: '待解锁',
          subtitle: '继续记录、复盘和生成闪卡，慢慢点亮它们',
          isDarkMode: isDarkMode,
        ),
        const SizedBox(height: 12),
        ...locked.map(
          (achievement) => _AchievementTile(
            achievement: achievement,
            isUnlocked: false,
            accent: accent,
            isDarkMode: isDarkMode,
          ),
        ),
      ],
    );
  }
}

class _PointsHero extends StatelessWidget {
  const _PointsHero({
    required this.accent,
    required this.totalPoints,
    required this.streakDays,
    required this.level,
    required this.nextLevelPoints,
    required this.levelProgress,
    required this.unlockedCount,
    required this.totalCount,
  });

  final Color accent;
  final int totalPoints;
  final int streakDays;
  final int level;
  final int? nextLevelPoints;
  final double levelProgress;
  final int unlockedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: StudyUi.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    color: Colors.white, size: 32),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$totalPoints 积分',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Lv.$level · $unlockedCount/$totalCount 个成就',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: levelProgress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF4BC4A1)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            nextLevelPoints == null
                ? '已达到当前最高等级'
                : '距离 Lv.${level + 1} 还差 ${nextLevelPoints! - totalPoints} 积分',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _HeroMetric(label: '连续学习', value: '$streakDays 天'),
              const SizedBox(width: 10),
              _HeroMetric(
                label: '成就进度',
                value: '${totalCount == 0 ? 0 : (unlockedCount / totalCount * 100).round()}%',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _BadgeWall extends StatelessWidget {
  const _BadgeWall({
    required this.achievements,
    required this.unlockedByType,
    required this.accent,
    required this.isDarkMode,
  });

  final List<Achievement> achievements;
  final Map<AchievementType, UnlockedAchievement> unlockedByType;
  final Color accent;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: '徽章墙',
            subtitle: '把每一次学习行动沉淀成可见的成长痕迹',
            isDarkMode: isDarkMode,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: achievements
                .map(
                  (achievement) => _BadgeDot(
                    achievement: achievement,
                    unlocked:
                        unlockedByType.containsKey(achievement.type),
                    accent: accent,
                    isDarkMode: isDarkMode,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _BadgeDot extends StatelessWidget {
  const _BadgeDot({
    required this.achievement,
    required this.unlocked,
    required this.accent,
    required this.isDarkMode,
  });

  final Achievement achievement;
  final bool unlocked;
  final Color accent;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: achievement.title,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: unlocked
              ? StudyUi.chipBackground(accent, isDarkMode)
              : StudyUi.surfaceAlt(isDarkMode),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: unlocked
                ? accent.withValues(alpha: 0.28)
                : StudyUi.border(isDarkMode),
          ),
        ),
        child: Icon(
          _iconForAchievement(achievement.iconName),
          color: unlocked ? accent : StudyUi.muted(isDarkMode),
          size: 24,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
    required this.isDarkMode,
  });

  final String title;
  final String subtitle;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                color: StudyUi.title(isDarkMode),
                fontSize: 18,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(subtitle,
            style: TextStyle(
                color: StudyUi.body(isDarkMode), fontSize: 12, height: 1.4)),
      ],
    );
  }
}

class _EmptyAchievementCard extends StatelessWidget {
  const _EmptyAchievementCard({required this.isDarkMode});

  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      child: Text(
        '暂时还没有解锁成就。完成第一条学习记录或第一个任务后，它会马上出现。',
        style: TextStyle(color: StudyUi.body(isDarkMode), height: 1.5),
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({
    required this.achievement,
    required this.isUnlocked,
    required this.accent,
    required this.isDarkMode,
    this.unlockedAt,
  });

  final Achievement achievement;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final Color accent;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: StudyCard(
        padding: const EdgeInsets.all(16),
        color: isUnlocked
            ? StudyUi.surface(isDarkMode)
            : StudyUi.surface(isDarkMode).withValues(alpha: isDarkMode ? 0.7 : 1),
        borderColor:
            isUnlocked ? accent.withValues(alpha: 0.25) : StudyUi.border(isDarkMode),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isUnlocked
                    ? StudyUi.chipBackground(accent, isDarkMode)
                    : StudyUi.surfaceAlt(isDarkMode),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _iconForAchievement(achievement.iconName),
                color: isUnlocked ? accent : StudyUi.muted(isDarkMode),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          achievement.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isUnlocked ? titleColor : bodyColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      BadgePill(
                        label: '+${achievement.points}分',
                        background:
                            StudyUi.chipBackground(accent, isDarkMode),
                        foreground: isUnlocked
                            ? accent
                            : StudyUi.muted(isDarkMode),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    achievement.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isUnlocked
                          ? bodyColor
                          : bodyColor.withValues(alpha: 0.62),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  if (isUnlocked && unlockedAt != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      '解锁于 ${_formatDate(unlockedAt!)}',
                      style: TextStyle(
                        color: accent.withValues(alpha: 0.76),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isUnlocked ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
              color: isUnlocked ? accent : StudyUi.muted(isDarkMode),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

int _levelFor(int points) {
  if (points >= 1000) return 5;
  if (points >= 500) return 4;
  if (points >= 200) return 3;
  if (points >= 80) return 2;
  return 1;
}

int _levelStart(int level) {
  switch (level) {
    case 5:
      return 1000;
    case 4:
      return 500;
    case 3:
      return 200;
    case 2:
      return 80;
    default:
      return 0;
  }
}

int? _nextLevelPoints(int points) {
  if (points < 80) return 80;
  if (points < 200) return 200;
  if (points < 500) return 500;
  if (points < 1000) return 1000;
  return null;
}

IconData _iconForAchievement(String name) {
  switch (name) {
    case 'edit_note':
      return Icons.edit_note_rounded;
    case 'task_alt':
      return Icons.task_alt_rounded;
    case 'emoji_events':
      return Icons.emoji_events_rounded;
    case 'military_tech':
      return Icons.military_tech_rounded;
    case 'local_fire_department':
    case 'whatshot':
      return Icons.local_fire_department_rounded;
    case 'stars':
      return Icons.stars_rounded;
    case 'summarize':
      return Icons.summarize_rounded;
    case 'style':
      return Icons.style_rounded;
    case 'menu_book':
      return Icons.menu_book_rounded;
    case 'toll':
      return Icons.toll_rounded;
    case 'workspace_premium':
      return Icons.workspace_premium_rounded;
    case 'diamond':
      return Icons.diamond_rounded;
    case 'smart_toy':
      return Icons.smart_toy_rounded;
    default:
      return Icons.emoji_events_rounded;
  }
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
