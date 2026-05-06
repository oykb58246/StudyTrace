import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';

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
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF4470E8), Color(0xFF8D5EFF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4470E8).withValues(alpha: 0.28),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 18),
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
            border: isDarkMode ? Border.all(color: Colors.white.withValues(alpha: 0.06)) : null,
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
                    child: const Icon(Icons.lightbulb_rounded, color: Color(0xFF4470E8), size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      '你的 AI 驱动学习成长伴侣',
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
                'StudyTrace 帮助大学生建立高效的学习习惯：AI 自动生成学习日志、智能拆解复杂任务、\\n定时生成复盘周报、通过知识闪卡巩固记忆。让每一分钟的学习都有迹可循。',
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
          icon: Icons.auto_awesome_rounded,
          color: const Color(0xFF4470E8),
          title: 'AI 学习助手',
          subtitle: '自然语言生成学习日志、拆解任务、\\n分析周报与风险提醒',
          isDarkMode: isDarkMode,
        ),
        _FeatureItem(
          icon: Icons.style_rounded,
          color: const Color(0xFFF8AA5B),
          title: '知识闪卡',
          subtitle: 'AI 从学习记录自动生成问答卡片，\\n翻转互动巩固记忆',
          isDarkMode: isDarkMode,
        ),
        _FeatureItem(
          icon: Icons.timer_rounded,
          color: const Color(0xFF4BC4A1),
          title: '专注计时',
          subtitle: '番茄工作法 + 学习记录关联，\\n让专注看得见',
          isDarkMode: isDarkMode,
        ),
        _FeatureItem(
          icon: Icons.menu_book_rounded,
          color: const Color(0xFF4CB9FF),
          title: 'Notion 风格笔记',
          subtitle: '图文混排、代码块、文件夹管理，\\n自由书写随心整理',
          isDarkMode: isDarkMode,
        ),
        _FeatureItem(
          icon: Icons.calendar_month_rounded,
          color: const Color(0xFFFF7C7C),
          title: '日历 + 周报',
          subtitle: '学习记录映射日历视图，\\nAI 自动生成每周复盘报告',
          isDarkMode: isDarkMode,
        ),
        _FeatureItem(
          icon: Icons.groups_rounded,
          color: const Color(0xFFFFC043),
          title: '学习小组 + 排行榜',
          subtitle: '和同伴交流讨论，\\n排行榜激发良性竞争',
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
            border: isDarkMode ? Border.all(color: Colors.white.withValues(alpha: 0.06)) : null,
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
                'Made with Flutter & AI',
                style: TextStyle(color: bodyColor, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                '2025 StudyTrace Team. All rights reserved.',
                style: TextStyle(color: bodyColor.withValues(alpha: 0.5), fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: 'StudyTrace - 你的 AI 学习成长伴侣'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('分享文案已复制到剪贴板')),
              );
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
        _TechChip('蓝心大模型', const Color(0xFF4470E8), cardBg, isDarkMode),
        _TechChip('DeepSeek', const Color(0xFF4D6BFE), cardBg, isDarkMode),
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
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.isDarkMode,
  });

  final IconData icon;
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
          border: isDarkMode ? Border.all(color: Colors.white.withValues(alpha: 0.06)) : null,
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
              child: Icon(icon, color: color, size: 22),
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
                      color: isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body,
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
        Text(label, style: const TextStyle(color: Color(0xFF8B93A7), fontSize: 10)),
      ],
    );
  }
}
