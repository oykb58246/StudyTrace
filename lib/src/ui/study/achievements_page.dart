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

    return StudyScreenBackground(
      isDarkMode: isDarkMode,
      accent: accent,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          _PointsHero(
            accent: accent,
            isDarkMode: isDarkMode,
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
          if (locked.isNotEmpty) ...[
            const SizedBox(height: 18),
            _NextBadgeCard(
              achievement: locked.first,
              accent: accent,
              isDarkMode: isDarkMode,
            ),
          ],
          const SizedBox(height: 22),
          _SectionTitle(
            title: '已记录',
            subtitle: '${unlocked.length} 条成长记录已收入你的学习档案',
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
            title: '待记录',
            subtitle: '继续记录、复盘和整理闪卡，慢慢留下更多痕迹',
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
      ),
    );
  }
}

class _PointsHero extends StatelessWidget {
  const _PointsHero({
    required this.accent,
    required this.isDarkMode,
    required this.totalPoints,
    required this.streakDays,
    required this.level,
    required this.nextLevelPoints,
    required this.levelProgress,
    required this.unlockedCount,
    required this.totalCount,
  });

  final Color accent;
  final bool isDarkMode;
  final int totalPoints;
  final int streakDays;
  final int level;
  final int? nextLevelPoints;
  final double levelProgress;
  final int unlockedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final progressLabel = totalCount == 0
        ? '0%'
        : '${(unlockedCount / totalCount * 100).round()}%';
    return StudyPathHero(
      isDarkMode: isDarkMode,
      accent: accent,
      badge: '成长阶段',
      title: '成长记录',
      subtitle: nextLevelPoints == null
          ? '阶段 $level · 已达到当前最高阶段'
          : '阶段 $level · 距离阶段 ${level + 1} 还差 ${nextLevelPoints! - totalPoints} 成长点',
      icon: Icons.workspace_premium_rounded,
      steps: const ['记录', '复盘', '闪卡', '沉淀'],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: levelProgress,
              minHeight: 7,
              backgroundColor: StudyUi.surfaceAlt(isDarkMode),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF4BC4A1)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StudyPathMetricPill(
                  label: '连续学习',
                  value: '$streakDays 天',
                  icon: Icons.local_fire_department_rounded,
                  color: StudyUi.warning,
                  isDarkMode: isDarkMode,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StudyPathMetricPill(
                  label: '记录进度',
                  value: progressLabel,
                  icon: Icons.auto_awesome_rounded,
                  color: StudyUi.success,
                  isDarkMode: isDarkMode,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StudyPathMetricPill(
            label: '成长点',
            value: '$totalPoints',
            icon: Icons.emoji_events_rounded,
            color: accent,
            isDarkMode: isDarkMode,
          ),
        ],
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
            title: '成长记录',
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

class _NextBadgeCard extends StatelessWidget {
  const _NextBadgeCard({
    required this.achievement,
    required this.accent,
    required this.isDarkMode,
  });

  final Achievement achievement;
  final Color accent;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    const previewProgress = 0.58;
    final nextStep = _nextStepFor(achievement.type);
    return StudyCard(
      padding: const EdgeInsets.all(18),
      borderColor: accent.withValues(alpha: isDarkMode ? 0.20 : 0.14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '下一条成长记录',
                style: TextStyle(
                  color: titleColor,
                  fontSize: 18,
                  fontWeight: AppTypography.hero,
                ),
              ),
              const Spacer(),
              BadgePill(
                label: '待记录',
                background: StudyUi.chipBackground(accent, isDarkMode),
                foreground: accent,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StudyGlassIconNode(
                icon: _iconForAchievement(achievement.iconName),
                accent: StudyUi.muted(isDarkMode),
                size: 76,
                iconSize: 30,
                isDarkMode: isDarkMode,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      achievement.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 18,
                        fontWeight: AppTypography.hero,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      nextStep,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: bodyColor,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: previewProgress,
                        minHeight: 6,
                        backgroundColor: isDarkMode
                            ? Colors.white.withValues(alpha: 0.10)
                            : const Color(0xFFE7ECFF),
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '小贴士：保持记录、复盘和复习，成长痕迹会自然留下。',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: bodyColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _nextStepFor(AchievementType type) {
    return switch (type) {
      AchievementType.firstLog => '先写一条今天的学习记录，留下难点和下一步。',
      AchievementType.firstTask => '先完成一个最小学习任务，后面再慢慢补细节。',
      AchievementType.task10 ||
      AchievementType.task50 => '继续推进任务列表里的小行动，完成后会自动记录。',
      AchievementType.streak3 ||
      AchievementType.streak7 ||
      AchievementType.streak30 => '连续几天保留学习记录，形成稳定节奏。',
      AchievementType.firstReport => '整理一次本周回顾，看清这周学过来的路径。',
      AchievementType.flashCard10 => '把容易忘的概念整理成闪卡，睡前答一轮。',
      AchievementType.firstNote => '保存一条课堂重点或错题笔记，方便之后回看。',
      AchievementType.points100 ||
      AchievementType.points500 ||
      AchievementType.points1000 => '继续记录、复习和完成任务，成长点会自然累积。',
      AchievementType.aiUsage10 => '用学习整理台拆一次任务、复盘或闪卡。',
    };
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
      child: StudyGlassIconNode(
        icon: _iconForAchievement(achievement.iconName),
        accent: unlocked ? accent : StudyUi.muted(isDarkMode),
        size: 48,
        iconSize: 22,
        isDarkMode: isDarkMode,
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
                fontWeight: AppTypography.title)),
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
        '暂时还没有成长记录。完成第一条学习记录或第一个任务后，它会马上出现。',
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
            StudyGlassIconNode(
              icon: _iconForAchievement(achievement.iconName),
              accent: isUnlocked ? accent : StudyUi.muted(isDarkMode),
              size: 48,
              iconSize: 22,
              isDarkMode: isDarkMode,
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
                            fontWeight: AppTypography.title,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      BadgePill(
                        label: '+${achievement.points} 点',
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
                        '记录于 ${_formatDate(unlockedAt!)}',
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
