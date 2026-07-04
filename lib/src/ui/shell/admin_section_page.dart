import 'package:flutter/material.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/ai_app_action.dart';
import '../../theme/app_theme.dart';
import '../shared/common_widgets.dart';
import '../shared/page_wrapper.dart';
import '../study/ai_learning_cockpit_page.dart';
import '../study/ai_settings_page.dart';
import '../study/evidence_package_page.dart';
import '../study/flash_card_page.dart';
import '../study/learning_dashboard_page.dart';
import '../study/leaderboard_page.dart';
import '../study/learning_moments_page.dart';
import '../study/study_group_page.dart';
import '../study/task_planning_page.dart';
import '../study/timer_page.dart';
import 'audit_log_page.dart';
import 'navigation_models.dart';
import 'trash_page.dart';

class AdminSectionPage extends StatelessWidget {
  const AdminSectionPage({
    super.key,
    required this.section,
    required this.isDarkMode,
    this.controller,
    this.onOpenSettings,
    this.onOpenNotes,
    this.onExecuteActions,
    this.onBack,
  });

  final AdminSection section;
  final bool isDarkMode;
  final AppDataController? controller;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenNotes;
  final AiActionHandler? onExecuteActions;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (section == AdminSection.timer && controller != null) {
      return TimerPage(
        isDarkMode: isDarkMode,
        controller: controller!,
      );
    } else if (section == AdminSection.flashCard && controller != null) {
      return FlashCardPage(
        isDarkMode: isDarkMode,
        controller: controller!,
        onOpenNotes: onOpenNotes,
      );
    } else if (section == AdminSection.learningMoments && controller != null) {
      body = LearningMomentsPage(
        isDarkMode: isDarkMode,
        controller: controller!,
      );
    } else if (section == AdminSection.evidencePackage && controller != null) {
      body = EvidencePackagePage(
        isDarkMode: isDarkMode,
        controller: controller!,
      );
    } else if (section == AdminSection.studyGroup && controller != null) {
      body = StudyGroupPage(
        isDarkMode: isDarkMode,
        controller: controller!,
      );
    } else if (section == AdminSection.leaderboard && controller != null) {
      body = LeaderboardPage(
        isDarkMode: isDarkMode,
        controller: controller!,
      );
    } else if (section == AdminSection.aiAssistant && controller != null) {
      body = AiLearningCockpitPage(
        isDarkMode: isDarkMode,
        controller: controller!,
      );
    } else if (section == AdminSection.aiSettings && controller != null) {
      body = AiSettingsPage(
        isDarkMode: isDarkMode,
        controller: controller!,
      );
    } else if (section == AdminSection.settings && controller != null) {
      body = AiSettingsPage(
        isDarkMode: isDarkMode,
        controller: controller!,
        mode: AiSettingsMode.system,
      );
    } else if (section == AdminSection.automations && controller != null) {
      body = TaskPlanningPage(
        isDarkMode: isDarkMode,
        controller: controller!,
      );
    } else if (section == AdminSection.auditLog && controller != null) {
      body = AuditLogPage(
        isDarkMode: isDarkMode,
        controller: controller!,
      );
    } else if (section == AdminSection.trash && controller != null) {
      body = TrashPage(
        isDarkMode: isDarkMode,
        controller: controller!,
      );
    } else if ((section == AdminSection.analytics ||
            section == AdminSection.statistics) &&
        controller != null) {
      body = LearningDashboardPage(
        isDarkMode: isDarkMode,
        controller: controller!,
      );
    } else {
      final config = _configFor(section, controller: controller);
      body = ListView(
        key: Key('page_admin_${section.name}'),
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 124),
        children: [
          StudyPathHero(
            key: Key('admin_title_${section.name}'),
            isDarkMode: isDarkMode,
            accent: config.accent,
            badge: '学习模块',
            title: config.heroTitle,
            subtitle: config.heroSubtitle,
            icon: section.icon,
            steps: const ['查看', '整理', '行动', '回看'],
            child: Row(
              children: [
                Expanded(
                  child: StudyPathMetricPill(
                    label: section.label,
                    value: '当前',
                    icon: section.icon,
                    color: config.accent,
                    isDarkMode: isDarkMode,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StudyPathMetricPill(
                    label: '说明',
                    value: '已就绪',
                    icon: Icons.check_circle_rounded,
                    color: StudyUi.success,
                    isDarkMode: isDarkMode,
                  ),
                ),
              ],
            ),
          ),
          if (section == AdminSection.overview) ...[
            const SizedBox(height: 16),
            _AdminOverviewPathCard(isDarkMode: isDarkMode),
          ],
        ],
      );
    }

    return PageWithBackButton(
      title: section.label,
      isDarkMode: isDarkMode,
      onBack: onBack,
      titleIcon: section.icon,
      accent: section.accent,
      compactHeader: section != AdminSection.evidencePackage,
      child: body,
    );
  }
}

class _AdminConfig {
  const _AdminConfig({
    required this.accent,
    required this.subtitle,
    required this.heroTitle,
    required this.heroSubtitle,
  });

  final Color accent;
  final String subtitle;
  final String heroTitle;
  final String heroSubtitle;
}

class _AdminOverviewPathCard extends StatelessWidget {
  const _AdminOverviewPathCard({required this.isDarkMode});

  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      borderColor: StudyUi.pathBlue.withValues(alpha: isDarkMode ? 0.18 : 0.14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StudyGlassIconNode(
                icon: Icons.route_rounded,
                accent: StudyUi.pathBlue,
                size: 42,
                iconSize: 20,
                isDarkMode: isDarkMode,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '应用介绍',
                      style: TextStyle(
                        color: StudyUi.pathBlue,
                        fontSize: 12,
                        fontWeight: AppTypography.emphasis,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '把学习路径上的内容集中管理',
                      style: TextStyle(
                        color: StudyUi.title(isDarkMode),
                        fontSize: 16,
                        fontWeight: AppTypography.title,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _AdminOverviewItem(
                  icon: Icons.edit_note_rounded,
                  label: '记录',
                  color: StudyUi.pathBlue,
                  isDarkMode: isDarkMode,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AdminOverviewItem(
                  icon: Icons.psychology_rounded,
                  label: '复盘',
                  color: StudyUi.secondary,
                  isDarkMode: isDarkMode,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _AdminOverviewItem(
                  icon: Icons.timer_rounded,
                  label: '专注',
                  color: StudyUi.pathMint,
                  isDarkMode: isDarkMode,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AdminOverviewItem(
                  icon: Icons.summarize_rounded,
                  label: '回顾',
                  color: StudyUi.pathWarm,
                  isDarkMode: isDarkMode,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminOverviewItem extends StatelessWidget {
  const _AdminOverviewItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDarkMode,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: StudyUi.chipBackground(color, isDarkMode),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: StudyUi.title(isDarkMode),
                fontSize: 13,
                fontWeight: AppTypography.title,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

_AdminConfig _configFor(AdminSection section, {AppDataController? controller}) {
  switch (section) {
    case AdminSection.overview:
      return const _AdminConfig(
        accent: Color(0xFF4F7EE8),
        subtitle: '查看学习核心数据、任务进展与场景热度。',
        heroTitle: '学习总览',
        heroSubtitle: '集中查看今天的任务、记录、日程和课程归档，快速回到正在进行的学习。',
      );
    case AdminSection.aiAssistant:
      return _AdminConfig(
        accent: controller?.primaryColor ?? const Color(0xFF4470E8),
        subtitle: '2 分钟复盘，整理下一步、闪卡和学习回顾。',
        heroTitle: '学习助手',
        heroSubtitle: '把学习事实、难点和情绪整理成今天能开始的一步。',
      );
    case AdminSection.aiSettings:
      return const _AdminConfig(
        accent: Color(0xFF4F7EE8),
        subtitle: '助手开关、语音偏好与资料备份。',
        heroTitle: '助手设置',
        heroSubtitle: '管理学习助手开关、语音复盘、整理次数和资料备份。',
      );
    case AdminSection.notes:
      return const _AdminConfig(
        accent: Color(0xFF4CB9FF),
        subtitle: '记录课堂笔记、学习心得与知识整理。',
        heroTitle: '学习笔记',
        heroSubtitle: '自由书写课堂重点、代码片段、学习心得，按课程分类管理，支持搜索和回顾。',
      );
    case AdminSection.statistics:
      return _AdminConfig(
        accent: controller?.primaryColor ?? const Color(0xFF4470E8),
        subtitle: '回看学习节奏、课程时间和完成进展。',
        heroTitle: '学习统计看板',
        heroSubtitle: '看看这一周哪里学得稳、时间花在哪些课、哪些安排还要推进。',
      );
    case AdminSection.timer:
      return const _AdminConfig(
        accent: Color(0xFF4BC4A1),
        subtitle: '番茄钟计时器，帮助保持专注学习节奏。',
        heroTitle: '专注计时器',
        heroSubtitle: '采用番茄工作法，25分钟专注学习 + 5分钟休息循环，提高学习效率。',
      );
    case AdminSection.flashCard:
      return const _AdminConfig(
        accent: Color(0xFFF8AA5B),
        subtitle: '从学习记录整理知识闪卡，巩固复习。',
        heroTitle: '知识闪卡',
        heroSubtitle: '基于学习日志整理问答闪卡，点击翻转查看答案，帮助巩固和复习知识点。',
      );
    case AdminSection.learningMoments:
      return const _AdminConfig(
        accent: Color(0xFF19A974),
        subtitle: '记录学习图文，自动汇聚任务、日志、笔记、闪卡和整理历史。',
        heroTitle: '学迹动态',
        heroSubtitle: '默认先保存给自己看，需要时再选择分享范围，方便回看每次学习。',
      );
    case AdminSection.evidencePackage:
      return const _AdminConfig(
        accent: Color(0xFF2F7D78),
        subtitle: '汇总复盘、行动、复习和助手整理，形成 7天学习回顾。',
        heroTitle: '7天学习回顾',
        heroSubtitle: '用一页回看 StudyTrace 如何把学习事实变成行动、复习和成长变化。',
      );
    case AdminSection.automations:
      return const _AdminConfig(
        accent: Color(0xFF4BC4A1),
        subtitle: '整理可重复的学习提醒、复盘和资料整理动作。',
        heroTitle: '学习流程',
        heroSubtitle: '把常见学习动作做成清楚的步骤，减少反复设置和遗漏。',
      );
    case AdminSection.studyGroup:
      return const _AdminConfig(
        accent: Color(0xFFFF7C7C),
        subtitle: '和同伴一起安排计划、留下记录、回看进展。',
        heroTitle: '学习小组',
        heroSubtitle: '用小组计划和学习近况看见彼此的推进节奏。',
      );
    case AdminSection.leaderboard:
      return const _AdminConfig(
        accent: Color(0xFFFFC043),
        subtitle: '查看学习进展。',
        heroTitle: '学习进度',
        heroSubtitle: '看见自己和小组的前进节奏。',
      );
    case AdminSection.analytics:
      return const _AdminConfig(
        accent: Color(0xFFF8AA5B),
        subtitle: '追踪学习趋势、活跃度与完成情况。',
        heroTitle: '学习数据看板',
        heroSubtitle: '查看学习活跃趋势、课程完成情况和统计概览。',
      );
    case AdminSection.settings:
      return const _AdminConfig(
        accent: AppColors.accentDeep,
        subtitle: '管理通知、权限、隐私与应用偏好。',
        heroTitle: '应用设置',
        heroSubtitle: '管理通知、深色模式、隐私偏好与关于应用。',
      );
    case AdminSection.auditLog:
      return const _AdminConfig(
        accent: Color(0xFF7394F9),
        subtitle: '查看最近的整理历史与结果。',
        heroTitle: '整理历史',
        heroSubtitle: '记录每次整理的内容和完成时间。',
      );
    case AdminSection.trash:
      return const _AdminConfig(
        accent: Color(0xFFEF6850),
        subtitle: '已删除的学习数据，可恢复或永久删除。',
        heroTitle: '回收站',
        heroSubtitle: '管理已删除的任务、日志、笔记和闪卡。',
      );
    case AdminSection.achievements:
      return const _AdminConfig(
        accent: Color(0xFFFF9F43),
        subtitle: '成长点、记录徽章与连续学习，给每一次小进步留个标记。',
        heroTitle: '成就殿堂',
        heroSubtitle: '把学习记录、复盘和复习沉淀成徽章，见证成长变化。',
      );
    case AdminSection.knowledgeGraph:
      return const _AdminConfig(
        accent: Color(0xFF4CB9FF),
        subtitle: '把课程、笔记和复习卡串成学习线索。',
        heroTitle: '知识地图',
        heroSubtitle: '按课程整理难点、闪卡和相关笔记，帮你知道下一步先复习哪里。',
      );
  }
}
