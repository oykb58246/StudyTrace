import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

enum PrimaryTab {
  assistant,
  scenarios,
  calendar,
  create,
  profile,
}

enum SecondaryTab {
  stats,
  timer,
}

enum AdminSection {
  overview,
  aiAssistant,
  aiSettings,
  notes,
  statistics,
  timer,
  flashCard,
  studyGroup,
  leaderboard,
  automations,
  analytics,
  settings,
}

extension PrimaryTabMeta on PrimaryTab {
  String get label {
    switch (this) {
      case PrimaryTab.assistant:
        return '首页';
      case PrimaryTab.scenarios:
        return '记录';
      case PrimaryTab.calendar:
        return '日历';
      case PrimaryTab.create:
        return '任务';
      case PrimaryTab.profile:
        return '归档';
    }
  }

  String get subtitle {
    switch (this) {
      case PrimaryTab.assistant:
        return '周报入口与学习概览';
      case PrimaryTab.scenarios:
        return '每日学习记录与反思';
      case PrimaryTab.calendar:
        return '日历视图与学习标记';
      case PrimaryTab.create:
        return '课程任务管理与状态跟踪';
      case PrimaryTab.profile:
        return '课程汇总与历史周报';
    }
  }

  IconData get icon {
    switch (this) {
      case PrimaryTab.assistant:
        return Icons.home_outlined;
      case PrimaryTab.scenarios:
        return Icons.article_outlined;
      case PrimaryTab.calendar:
        return Icons.calendar_month_outlined;
      case PrimaryTab.create:
        return Icons.task_alt_outlined;
      case PrimaryTab.profile:
        return Icons.folder_outlined;
    }
  }

  IconData get activeIcon {
    switch (this) {
      case PrimaryTab.assistant:
        return Icons.home_rounded;
      case PrimaryTab.scenarios:
        return Icons.article_rounded;
      case PrimaryTab.calendar:
        return Icons.calendar_month_rounded;
      case PrimaryTab.create:
        return Icons.task_alt_rounded;
      case PrimaryTab.profile:
        return Icons.folder_rounded;
    }
  }

  String get navLordiconAsset {
    switch (this) {
      case PrimaryTab.assistant:
        return 'assets/icons/lordicon/nav_home.json';
      case PrimaryTab.scenarios:
        return 'assets/icons/lordicon/nav_logs.json';
      case PrimaryTab.calendar:
        return 'assets/icons/lordicon/nav_calendar.json';
      case PrimaryTab.create:
        return 'assets/icons/lordicon/nav_task.json';
      case PrimaryTab.profile:
        return 'assets/icons/lordicon/nav_archive.json';
    }
  }

  String get riveArtboard {
    switch (this) {
      case PrimaryTab.assistant:
        return 'CHAT';
      case PrimaryTab.scenarios:
        return 'SEARCH';
      case PrimaryTab.calendar:
        return 'SEARCH';
      case PrimaryTab.create:
        return 'TIMER';
      case PrimaryTab.profile:
        return 'USER';
    }
  }

  String get riveStateMachine {
    switch (this) {
      case PrimaryTab.assistant:
        return 'CHAT_Interactivity';
      case PrimaryTab.scenarios:
        return 'SEARCH_Interactivity';
      case PrimaryTab.calendar:
        return 'SEARCH_Interactivity';
      case PrimaryTab.create:
        return 'TIMER_Interactivity';
      case PrimaryTab.profile:
        return 'USER_Interactivity';
    }
  }
}

extension AdminSectionMeta on AdminSection {
  String get label {
    switch (this) {
      case AdminSection.overview:
        return '作品总览';
      case AdminSection.aiAssistant:
        return 'AI 学习助手';
      case AdminSection.aiSettings:
        return 'AI 设置';
      case AdminSection.notes:
        return '学习笔记';
      case AdminSection.statistics:
        return '学习统计';
      case AdminSection.timer:
        return '专注计时';
      case AdminSection.flashCard:
        return '知识闪卡';
      case AdminSection.studyGroup:
        return '学习小组';
      case AdminSection.leaderboard:
        return '排行榜';
      case AdminSection.automations:
        return '任务编排';
      case AdminSection.analytics:
        return '数据看板';
      case AdminSection.settings:
        return '系统设置';
    }
  }

  String get subtitle {
    switch (this) {
      case AdminSection.overview:
        return '学习数据总览与周报入口。';
      case AdminSection.aiAssistant:
        return 'AI 学习日志生成、任务拆解、周报分析和风险提醒。';
      case AdminSection.aiSettings:
        return '模型、Key、推理参数与高级 AI 选项。';
      case AdminSection.notes:
        return '记录课堂笔记、学习心得与知识整理。';
      case AdminSection.statistics:
        return '学习数据统计图表与完成率分析。';
      case AdminSection.timer:
        return '番茄钟计时器，帮助保持专注学习节奏。';
      case AdminSection.flashCard:
        return 'AI 从学习记录生成知识闪卡，巩固复习。';
      case AdminSection.studyGroup:
        return '参与学习小组，与同伴交流讨论，共同进步。';
      case AdminSection.leaderboard:
        return '查看全站或好友学习榜单，激发学习动力。';
      case AdminSection.automations:
        return '编排自动任务流、触发条件与执行记录。';
      case AdminSection.analytics:
        return '追踪学习趋势、活跃度与完成情况。';
      case AdminSection.settings:
        return '管理通知、权限、隐私与系统偏好。';
    }
  }

  IconData get icon {
    switch (this) {
      case AdminSection.overview:
        return Icons.home_outlined;
      case AdminSection.aiAssistant:
        return Icons.auto_awesome_rounded;
      case AdminSection.aiSettings:
        return Icons.tune_rounded;
      case AdminSection.notes:
        return Icons.menu_book_rounded;
      case AdminSection.statistics:
        return Icons.bar_chart_rounded;
      case AdminSection.timer:
        return Icons.timer_rounded;
      case AdminSection.flashCard:
        return Icons.style_rounded;
      case AdminSection.studyGroup:
        return Icons.groups_rounded;
      case AdminSection.leaderboard:
        return Icons.leaderboard_rounded;
      case AdminSection.automations:
        return Icons.alt_route_rounded;
      case AdminSection.analytics:
        return Icons.trending_up_rounded;
      case AdminSection.settings:
        return Icons.settings_rounded;
    }
  }

  Color get accent {
    switch (this) {
      case AdminSection.overview:
        return const Color(0xFF7D9BFF);
      case AdminSection.aiAssistant:
        return const Color(0xFF4470E8);
      case AdminSection.aiSettings:
        return const Color(0xFF8C7CFF);
      case AdminSection.notes:
        return const Color(0xFF4CB9FF);
      case AdminSection.statistics:
        return const Color(0xFF4470E8);
      case AdminSection.timer:
        return const Color(0xFF4BC4A1);
      case AdminSection.flashCard:
        return const Color(0xFFF8AA5B);
      case AdminSection.studyGroup:
        return const Color(0xFFFF7C7C);
      case AdminSection.leaderboard:
        return const Color(0xFFFFC043);
      case AdminSection.automations:
        return const Color(0xFF4BC4A1);
      case AdminSection.analytics:
        return const Color(0xFFF8AA5B);
      case AdminSection.settings:
        return AppColors.accentDeep;
    }
  }
}
