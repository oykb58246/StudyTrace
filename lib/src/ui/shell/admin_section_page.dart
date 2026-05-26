import 'package:flutter/material.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/ai_app_action.dart';
import '../../theme/app_theme.dart';
import '../shared/common_widgets.dart';
import '../shared/page_wrapper.dart';
import '../study/ai_assistant_page.dart';
import '../study/ai_settings_page.dart';
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
    this.onExecuteActions,
    this.onBack,
  });

  final AdminSection section;
  final bool isDarkMode;
  final AppDataController? controller;
  final VoidCallback? onOpenSettings;
  final AiActionHandler? onExecuteActions;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    Widget body;

    // For timer, render the Pomodoro timer page
    if (section == AdminSection.timer && controller != null) {
      body = TimerPage(
        isDarkMode: isDarkMode,
        controller: controller!,
      );
    } else if (section == AdminSection.flashCard && controller != null) {
      body = FlashCardPage(
        isDarkMode: isDarkMode,
        controller: controller!,
      );
    } else if (section == AdminSection.learningMoments && controller != null) {
      body = LearningMomentsPage(
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
      body = AiAssistantPage(
        isDarkMode: isDarkMode,
        controller: controller!,
        onOpenSettings: onOpenSettings,
        onExecuteActions: onExecuteActions,
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
        padding: const EdgeInsets.fromLTRB(22, 94, 22, 124),
        children: [
          Text(
            section.label,
            key: Key('admin_title_${section.name}'),
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            config.subtitle,
            key: Key('admin_subtitle_${section.name}'),
            style: TextStyle(
              color: isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  config.accent.withValues(alpha: 0.95),
                  Color.lerp(config.accent, AppColors.shell, 0.45)!,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BadgePill(
                  label: section == AdminSection.statistics ? '学习' : 'Admin',
                  background: Colors.white.withValues(alpha: 0.18),
                  foreground: Colors.white,
                ),
                const SizedBox(height: 16),
                Text(
                  config.heroTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  config.heroSubtitle,
                  style: const TextStyle(
                    color: Color(0xE6FFFFFF),
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return PageWithBackButton(
      title: section.label,
      isDarkMode: isDarkMode,
      onBack: onBack,
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

_AdminConfig _configFor(AdminSection section, {AppDataController? controller}) {
  switch (section) {
    case AdminSection.overview:
      return const _AdminConfig(
        accent: Color(0xFF7D9BFF),
        subtitle: '查看学习核心数据、任务进展与场景热度。',
        heroTitle: '学习总览',
        heroSubtitle: '欢迎页、底部导航到侧边管理菜单，快速了解学习状态与各功能入口。',
      );
    case AdminSection.aiAssistant:
      return _AdminConfig(
        accent: controller?.primaryColor ?? const Color(0xFF4470E8),
        subtitle: 'AI 学习助手、聊天、日志生成、任务拆解与周报分析。',
        heroTitle: 'AI 功能',
        heroSubtitle:
            'AI 聊天助手、结构化日志生成、复杂任务拆解、学习分析周报和风险提醒，形成"记录—执行—分析—复盘"的智能学习闭环。',
      );
    case AdminSection.aiSettings:
      return const _AdminConfig(
        accent: Color(0xFF8C7CFF),
        subtitle: 'AI 模型状态、参数调节与云服务配置。',
        heroTitle: 'AI 设置',
        heroSubtitle: '管理学迹 AI 配置、模型参数、云服务连接和系统偏好。',
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
        subtitle: '学习数据统计图表与完成率分析。',
        heroTitle: '学习统计看板',
        heroSubtitle: '课程分布饼图、近7天学习趋势、任务完成率一目了然。',
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
        subtitle: 'AI 从学习记录生成知识闪卡，巩固复习。',
        heroTitle: 'AI 知识闪卡',
        heroSubtitle: '基于学习日志自动生成问答闪卡，点击翻转查看答案，帮助巩固和复习知识点。',
      );
    case AdminSection.learningMoments:
      return const _AdminConfig(
        accent: Color(0xFF19A974),
        subtitle: '发布学习图文，自动汇聚任务、日志、笔记、闪卡和 AI 操作轨迹。',
        heroTitle: '学迹动态',
        heroSubtitle: '像朋友圈一样分享学习现场，同时把每次学习行为沉淀成可追溯的证据链。',
      );
    case AdminSection.automations:
      return const _AdminConfig(
        accent: Color(0xFF4BC4A1),
        subtitle: '编排自动任务流、触发条件与执行记录。',
        heroTitle: '自动任务编排',
        heroSubtitle: '把手机 AI 助手从一次性问答升级为持续工作的个人流转系统。',
      );
    case AdminSection.studyGroup:
      return const _AdminConfig(
        accent: Color(0xFFFF7C7C),
        subtitle: '学习小组讨论。',
        heroTitle: '学习小组',
        heroSubtitle: '与同伴交流讨论。',
      );
    case AdminSection.leaderboard:
      return const _AdminConfig(
        accent: Color(0xFFFFC043),
        subtitle: '查看积分排行。',
        heroTitle: '排行榜',
        heroSubtitle: '激励前行。',
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
        subtitle: '管理通知、权限、隐私与系统偏好。',
        heroTitle: '系统设置',
        heroSubtitle: '管理通知、深色模式、隐私偏好与关于应用。',
      );
    case AdminSection.auditLog:
      return const _AdminConfig(
        accent: Color(0xFF7394F9),
        subtitle: '查看 AI 操作历史与执行结果。',
        heroTitle: 'AI 操作记录',
        heroSubtitle: '记录每次 AI 操作的输入输出和执行时间。',
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
        subtitle: '积分、徽章与连续打卡，学习更有动力。',
        heroTitle: '成就殿堂',
        heroSubtitle: '解锁学习成就徽章，获取积分奖励，见证成长轨迹。',
      );
    case AdminSection.knowledgeGraph:
      return const _AdminConfig(
        accent: Color(0xFF4CB9FF),
        subtitle: '可视化知识点关联，直观展示学习结构。',
        heroTitle: '知识图谱',
        heroSubtitle: '从课程、笔记和闪卡中自动提取知识关联，一目了然。',
      );
  }
}
