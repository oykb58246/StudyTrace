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
    final titleColor = isDarkMode ? Colors.white : Colors.black;
    final bodyColor = isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;
    final cardBg = isDarkMode ? const Color(0xFF1E2430) : Colors.white;

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 124),
      children: [
        // ── 品牌区 ──
        const SizedBox(height: 24),
        Center(
          child: Column(
            children: [
              const Image(
                image: AssetImage('logo/app_icon_v2.png'),
                width: 112,
                height: 112,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 16),
              Image.asset(
                isDarkMode ? 'logo/logo白透明.png' : 'logo/logo黑透明.png',
                height: 34,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Text(
                  'StudyTrace 学迹',
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'StudyTrace 学迹',
                style: TextStyle(
                  color: titleColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'v1.2.0',
                style: TextStyle(
                  color: bodyColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // ── 一句话介绍 ──
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: isDarkMode
                ? Border.all(color: Colors.white.withValues(alpha: 0.06))
                : null,
            boxShadow: isDarkMode
                ? null
                : const [
                    BoxShadow(
                      color: Color(0x0C123C78),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFF4470E8).withValues(alpha: 0.12),
                    ),
                    child: const StudyAssetIcon(
                      asset: AppAssets.aiSuggestionIcon,
                      preserveColor: true,
                      size: 22,
                      fallbackIcon: Icons.lightbulb_rounded,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      '你的学习成长管理工具',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'StudyTrace 帮助大学生建立高效的学习习惯：整理学习日志、拆解复杂任务、定时生成复盘周报、通过知识闪卡巩固记忆。让每一分钟的学习都有迹可循。',
                style: TextStyle(
                  color: bodyColor,
                  fontSize: 14,
                  height: 1.65,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // ── 核心亮点 ──
        _sectionTitle('核心亮点', titleColor),
        const SizedBox(height: 12),
        _FeatureItem(
          iconAsset: AppAssets.sideAiAssistantIcon,
          fallbackIcon: Icons.auto_awesome_rounded,
          color: const Color(0xFF4470E8),
          title: 'AI学习助手',
          subtitle: '自然语言生成学习日志、拆解任务、分析周报与风险提醒',
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
          title: 'Notion 风格笔记',
          subtitle: '图文混排、代码块、文件夹管理，自由书写随心整理',
          isDarkMode: isDarkMode,
        ),
        _FeatureItem(
          iconAsset: AppAssets.featureCalendarReportIcon,
          fallbackIcon: Icons.calendar_month_rounded,
          color: const Color(0xFFFF7C7C),
          title: '日历 + 周报',
          subtitle: '学习记录映射日历视图，生成每周复盘报告',
          isDarkMode: isDarkMode,
        ),
        _FeatureItem(
          iconAsset: AppAssets.featureGroupRankIcon,
          fallbackIcon: Icons.groups_rounded,
          color: const Color(0xFFFFC043),
          title: '学习小组 + 排行榜',
          subtitle: '和同伴交流讨论，排行榜激发良性竞争',
          isDarkMode: isDarkMode,
        ),
        const SizedBox(height: 18),

        // ── 技术栈 ──
        _sectionTitle('技术栈', titleColor),
        const SizedBox(height: 12),
        _techStack(isDarkMode, bodyColor),
        const SizedBox(height: 18),

        // ── 底部 ──
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: isDarkMode
                ? Border.all(color: Colors.white.withValues(alpha: 0.06))
                : null,
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SocialIcon(Icons.language, 'lordicon.com'),
                  const SizedBox(width: 24),
                  _SocialIcon(Icons.code, 'GitHub'),
                  const SizedBox(width: 24),
                  _SocialIcon(Icons.email_outlined, 'support@studytrace.app'),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Made with Flutter',
                style: TextStyle(color: bodyColor, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                '2025 StudyTrace Team. All rights reserved.',
                style: TextStyle(
                    color: bodyColor.withValues(alpha: 0.5), fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () {
              Clipboard.setData(
                  const ClipboardData(text: 'StudyTrace - 你的学习成长管理工具'));
              StudyToast.show(context, '分享文案已复制到剪贴板');
            },
            child: Text(
              '分享 StudyTrace 给朋友',
              style: TextStyle(
                color: const Color(0xFF4470E8),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
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

  Widget _techStack(bool isDarkMode, Color bodyColor) {
    final cardBg = isDarkMode ? const Color(0xFF1E2430) : Colors.white;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _TechChip('Flutter', const Color(0xFF02569B), cardBg, isDarkMode),
        _TechChip('Dart', const Color(0xFF0175C2), cardBg, isDarkMode),
        _TechChip('云端服务', const Color(0xFF4470E8), cardBg, isDarkMode),
        _TechChip('云端能力', const Color(0xFF4D6BFE), cardBg, isDarkMode),
        _TechChip('Lottie', const Color(0xFF00DDB3), cardBg, isDarkMode),
        _TechChip('Rive', const Color(0xFFFF4D6A), cardBg, isDarkMode),
        _TechChip('ML Kit', const Color(0xFF34A853), cardBg, isDarkMode),
        _TechChip('语音识别', const Color(0xFFF77D8E), cardBg, isDarkMode),
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
    final cardBg = isDarkMode ? const Color(0xFF1E2430) : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: isDarkMode
              ? Border.all(color: Colors.white.withValues(alpha: 0.06))
              : null,
          boxShadow: isDarkMode
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x080E2A6A),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: color.withValues(alpha: 0.12),
              ),
              child: Center(
                child: StudyAssetIcon(
                  asset: iconAsset,
                  color: color,
                  size: 24,
                  fallbackIcon: fallbackIcon,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color:
                          isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body,
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

class _TechChip extends StatelessWidget {
  const _TechChip(this.label, this.color, this.cardBg, this.isDarkMode);
  final String label;
  final Color color;
  final Color cardBg;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SocialIcon extends StatelessWidget {
  const _SocialIcon(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF8B93A7), size: 20),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: Color(0xFF8B93A7), fontSize: 10)),
      ],
    );
  }
}
