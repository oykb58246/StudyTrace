import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../shared/app_assets.dart';
import '../shared/common_widgets.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({
    super.key,
    required this.isDarkMode,
  });

  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 124),
      children: [
        StudyPathHero(
          isDarkMode: isDarkMode,
          accent: const Color(0xFF4470E8),
          badge: 'v1.2.0',
          title: 'StudyTrace 学迹',
          subtitle:
              '把学习记录、复盘、专注、闪卡和每周回顾整理成一条清楚的成长路径。',
          icon: Icons.auto_stories_rounded,
          steps: const ['记录', '复盘', '回顾', '成长'],
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: StudyPathMetricPill(
                      label: '学习路径',
                      value: '5 步',
                      icon: Icons.route_rounded,
                      color: const Color(0xFF4470E8),
                      isDarkMode: isDarkMode,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StudyPathMetricPill(
                      label: '本机可用',
                      value: '安心',
                      icon: Icons.verified_user_rounded,
                      color: StudyUi.success,
                      isDarkMode: isDarkMode,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '从一次记录开始，StudyTrace 会把复盘、专注、复习和每周回顾串成可回看的学习路径。',
                      style: TextStyle(
                        color: bodyColor,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        _sectionTitle('学习路径', titleColor),
        const SizedBox(height: 12),
        _LearningPathCard(isDarkMode: isDarkMode),
        const SizedBox(height: 18),

        // ── 核心亮点 ──
        _sectionTitle('核心亮点', titleColor),
        const SizedBox(height: 12),
        _FeatureItem(
          iconAsset: AppAssets.sideAiAssistantIcon,
          fallbackIcon: Icons.auto_awesome_rounded,
          color: const Color(0xFF4470E8),
          title: '学习助手',
          subtitle: '用文字、图片或语音复盘，整理难点和下一步',
          isDarkMode: isDarkMode,
        ),
        _FeatureItem(
          iconAsset: AppAssets.featureFlashcardIcon,
          fallbackIcon: Icons.style_rounded,
          color: const Color(0xFFF8AA5B),
          title: '知识闪卡',
          subtitle: '从学习记录整理问答卡片，翻转互动巩固记忆',
          isDarkMode: isDarkMode,
        ),
        _FeatureItem(
          iconAsset: AppAssets.featureTimerIcon,
          fallbackIcon: Icons.timer_rounded,
          color: const Color(0xFF4BC4A1),
          title: '专注计时',
          subtitle: '番茄工作法 + 学习记录关联，让专注看得见',
          isDarkMode: isDarkMode,
        ),
        _FeatureItem(
          iconAsset: AppAssets.featureNotesIcon,
          fallbackIcon: Icons.menu_book_rounded,
          color: const Color(0xFF4CB9FF),
          title: '学习笔记',
          subtitle: '文件夹、图文和代码块统一整理，复盘时随时回看',
          isDarkMode: isDarkMode,
        ),
        _FeatureItem(
          iconAsset: AppAssets.featureCalendarReportIcon,
          fallbackIcon: Icons.calendar_month_rounded,
          color: const Color(0xFFFF7C7C),
          title: '日历 + 每周回顾',
          subtitle: '按日期回看学习记录，整理每周收获和下周计划',
          isDarkMode: isDarkMode,
        ),
        _FeatureItem(
          iconAsset: AppAssets.featureGroupRankIcon,
          fallbackIcon: Icons.groups_rounded,
          color: const Color(0xFFFFC043),
          title: '学习小组 + 学习进度',
          subtitle: '和同伴交流讨论，互相看见进步',
          isDarkMode: isDarkMode,
        ),
        const SizedBox(height: 18),

        _sectionTitle('关于 StudyTrace', titleColor),
        const SizedBox(height: 12),
        _AppInfoCard(isDarkMode: isDarkMode),
        const SizedBox(height: 12),
        Center(
          child: StudyActionPill(
            icon: Icons.ios_share_rounded,
            label: '分享给朋友',
            color: const Color(0xFF4470E8),
            isDarkMode: isDarkMode,
            filled: false,
            onPressed: () {
              Clipboard.setData(
                  const ClipboardData(text: 'StudyTrace - 你的学习成长管理工具'));
              StudyToast.show(context, '分享文案已复制到剪贴板');
            },
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            '感谢你把学习过程交给 StudyTrace 陪伴。',
            style: TextStyle(
              color: bodyColor.withValues(alpha: 0.52),
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title, Color titleColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          color: titleColor,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

}

class _LearningPathCard extends StatelessWidget {
  const _LearningPathCard({required this.isDarkMode});

  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final nodes = [
      _LearningPathStep(
        icon: Icons.edit_rounded,
        title: '记录',
        subtitle: '捕捉学习瞬间',
        color: StudyUi.pathBlue,
      ),
      _LearningPathStep(
        icon: Icons.pie_chart_rounded,
        title: '复盘',
        subtitle: '整理与反思',
        color: StudyUi.pathMint,
      ),
      _LearningPathStep(
        icon: Icons.track_changes_rounded,
        title: '专注',
        subtitle: '沉浸高效学习',
        color: StudyUi.pathViolet,
      ),
      _LearningPathStep(
        icon: Icons.menu_book_rounded,
        title: '复习',
        subtitle: '巩固关键知识',
        color: StudyUi.secondary,
      ),
      _LearningPathStep(
        icon: Icons.autorenew_rounded,
        title: '回顾',
        subtitle: '形成长期记忆',
        color: StudyUi.pathWarm,
      ),
    ];

    return StudyCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      borderColor: StudyUi.pathBlue.withValues(alpha: isDarkMode ? 0.18 : 0.14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < nodes.length; i++) ...[
              _LearningPathNode(step: nodes[i], isDarkMode: isDarkMode),
              if (i != nodes.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: StudyUi.muted(isDarkMode),
                    size: 20,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LearningPathNode extends StatelessWidget {
  const _LearningPathNode({
    required this.step,
    required this.isDarkMode,
  });

  final _LearningPathStep step;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      child: Column(
        children: [
          StudyGlassIconNode(
            icon: step.icon,
            accent: step.color,
            size: 48,
            iconSize: 21,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(height: 8),
          Text(
            step.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: StudyUi.title(isDarkMode),
              fontSize: 14,
              fontWeight: AppTypography.title,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            step.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: StudyUi.body(isDarkMode),
              fontSize: 11,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _LearningPathStep {
  const _LearningPathStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
}

class _AppInfoCard extends StatelessWidget {
  const _AppInfoCard({required this.isDarkMode});

  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      borderColor: StudyUi.pathBlue.withValues(alpha: isDarkMode ? 0.18 : 0.14),
      child: Column(
        children: [
          _AppInfoRow(
            icon: Icons.layers_rounded,
            label: '版本',
            value: 'v1.2.0',
            color: StudyUi.pathBlue,
            isDarkMode: isDarkMode,
          ),
          _AppInfoRow(
            icon: Icons.groups_rounded,
            label: '出品团队',
            value: 'StudyTrace Team',
            color: StudyUi.secondary,
            isDarkMode: isDarkMode,
          ),
          _AppInfoRow(
            icon: Icons.public_rounded,
            label: '了解更多',
            value: 'www.studytrace.app',
            color: StudyUi.pathCyan,
            isDarkMode: isDarkMode,
          ),
          _AppInfoRow(
            icon: Icons.mail_rounded,
            label: '反馈邮箱',
            value: 'hello@studytrace.app',
            color: StudyUi.pathMint,
            isDarkMode: isDarkMode,
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _AppInfoRow extends StatelessWidget {
  const _AppInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDarkMode,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDarkMode;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: StudyUi.title(isDarkMode),
                  fontSize: 14,
                  fontWeight: AppTypography.title,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: StudyUi.body(isDarkMode),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: StudyUi.border(isDarkMode),
          ),
      ],
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.iconAsset,
    required this.fallbackIcon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.isDarkMode,
  });

  final String iconAsset;
  final IconData fallbackIcon;
  final Color color;
  final String title;
  final String subtitle;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: StudyCard(
        padding: const EdgeInsets.all(16),
        radius: 20,
        color: StudyUi.surface(isDarkMode),
        borderColor: StudyUi.border(isDarkMode),
        child: Row(
          children: [
            StudyGlassIconNode(
              asset: iconAsset,
              icon: fallbackIcon,
              accent: color,
              size: 46,
              iconSize: 24,
              isDarkMode: isDarkMode,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: StudyUi.title(isDarkMode),
                      fontSize: 15,
                      fontWeight: AppTypography.title,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: StudyUi.body(isDarkMode),
                      fontSize: 13,
                      height: 1.45,
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
