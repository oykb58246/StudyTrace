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
  learningMoments,
  evidencePackage,
  studyGroup,
  leaderboard,
  achievements,
  knowledgeGraph,
  automations,
  analytics,
  settings,
  auditLog,
  trash,
}

extension PrimaryTabMeta on PrimaryTab {
  String get label {
    switch (this) {
      case PrimaryTab.assistant:
        return '首页';
      case PrimaryTab.scenarios:
        return '计划';
      case PrimaryTab.calendar:
        return '专注';
      case PrimaryTab.create:
        return '复习';
      case PrimaryTab.profile:
        return '我的';
    }
  }

  String get subtitle {
    switch (this) {
      case PrimaryTab.assistant:
        return '今日学习路径与学习概览';
      case PrimaryTab.scenarios:
        return '课程安排、截止时间与学习标记';
      case PrimaryTab.calendar:
        return '番茄钟专注与学习记录';
      case PrimaryTab.create:
        return '知识闪卡与今日复习';
      case PrimaryTab.profile:
        return '个人资料、成就与学习偏好';
    }
  }

  IconData get icon {
    switch (this) {
      case PrimaryTab.assistant:
        return Icons.home_outlined;
      case PrimaryTab.scenarios:
        return Icons.calendar_month_outlined;
      case PrimaryTab.calendar:
        return Icons.timer_outlined;
      case PrimaryTab.create:
        return Icons.style_outlined;
      case PrimaryTab.profile:
        return Icons.person_outline_rounded;
    }
  }

  String get riveArtboard {
    switch (this) {
      case PrimaryTab.assistant:
        return 'CHAT';
      case PrimaryTab.scenarios:
        return 'SEARCH';
      case PrimaryTab.calendar:
        return 'TIMER';
      case PrimaryTab.create:
        return 'SEARCH';
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
        return 'TIMER_Interactivity';
      case PrimaryTab.create:
        return 'SEARCH_Interactivity';
      case PrimaryTab.profile:
        return 'USER_Interactivity';
    }
  }
}

extension AdminSectionMeta on AdminSection {
  String get label {
    switch (this) {
      case AdminSection.overview:
        return '关于学迹';
      case AdminSection.aiAssistant:
        return '学习助手';
      case AdminSection.aiSettings:
        return '助手设置';
      case AdminSection.notes:
        return '学习笔记';
      case AdminSection.statistics:
        return '学习统计';
      case AdminSection.timer:
        return '专注计时';
      case AdminSection.flashCard:
        return '知识闪卡';
      case AdminSection.learningMoments:
        return '学迹动态';
      case AdminSection.evidencePackage:
        return '学习回顾';
      case AdminSection.studyGroup:
        return '学习小组';
      case AdminSection.leaderboard:
        return '学习进度';
      case AdminSection.achievements:
        return '成长记录';
      case AdminSection.knowledgeGraph:
        return '知识地图';
      case AdminSection.automations:
        return '学习流程';
      case AdminSection.analytics:
        return '数据看板';
      case AdminSection.settings:
        return '应用设置';
      case AdminSection.auditLog:
        return '整理历史';
      case AdminSection.trash:
        return '回收站';
    }
  }

  String get subtitle {
    switch (this) {
      case AdminSection.overview:
        return '今日安排、最近学习和每周回顾入口。';
      case AdminSection.aiAssistant:
        return '2 分钟复盘，整理下一步、闪卡和学习回顾。';
      case AdminSection.aiSettings:
        return '助手开关、语音偏好与资料备份。';
      case AdminSection.notes:
        return '记录课堂笔记、学习心得与知识整理。';
      case AdminSection.statistics:
        return '回看学习节奏、课程时间和完成进展。';
      case AdminSection.timer:
        return '番茄钟计时器，帮助保持专注学习节奏。';
      case AdminSection.flashCard:
        return '从学习记录整理知识闪卡，巩固复习。';
      case AdminSection.learningMoments:
        return '记录学习图文，并把任务、日志、笔记和助手整理汇成可回看的时间线。';
      case AdminSection.evidencePackage:
        return '汇总复盘、行动、复习和助手整理，形成7天学习回顾。';
      case AdminSection.studyGroup:
        return '参与学习小组，与同伴交流讨论，共同进步。';
      case AdminSection.leaderboard:
        return '查看自己和小组的学习进展，互相给一点继续向前的反馈。';
      case AdminSection.achievements:
        return '成长点、记录徽章与连续学习，给每一次小进步留个标记。';
      case AdminSection.knowledgeGraph:
        return '把课程、笔记和复习卡串成学习线索。';
      case AdminSection.automations:
        return '整理常用学习提醒、复盘和资料整理步骤。';
      case AdminSection.analytics:
        return '回看学习趋势、活跃度与完成情况。';
      case AdminSection.settings:
        return '管理通知、权限、隐私与应用偏好。';
      case AdminSection.auditLog:
        return '查看助手整理历史与结果。';
      case AdminSection.trash:
        return '回收站中已删除的数据，可恢复或永久删除。';
    }
  }

  IconData get icon {
    switch (this) {
      case AdminSection.overview:
        return Icons.home_outlined;
      case AdminSection.aiAssistant:
        return Icons.tips_and_updates_rounded;
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
      case AdminSection.learningMoments:
        return Icons.dynamic_feed_rounded;
      case AdminSection.evidencePackage:
        return Icons.inventory_2_rounded;
      case AdminSection.studyGroup:
        return Icons.groups_rounded;
      case AdminSection.leaderboard:
        return Icons.auto_graph_rounded;
      case AdminSection.achievements:
        return Icons.bookmarks_rounded;
      case AdminSection.knowledgeGraph:
        return Icons.account_tree_rounded;
      case AdminSection.automations:
        return Icons.alt_route_rounded;
      case AdminSection.analytics:
        return Icons.trending_up_rounded;
      case AdminSection.settings:
        return Icons.settings_rounded;
      case AdminSection.auditLog:
        return Icons.history_rounded;
      case AdminSection.trash:
        return Icons.delete_outline_rounded;
    }
  }

  Color get accent {
    switch (this) {
      case AdminSection.overview:
        return const Color(0xFF4F7EE8);
      case AdminSection.aiAssistant:
        return const Color(0xFF4470E8);
      case AdminSection.aiSettings:
        return const Color(0xFF4F7EE8);
      case AdminSection.notes:
        return const Color(0xFF4CB9FF);
      case AdminSection.statistics:
        return const Color(0xFF4470E8);
      case AdminSection.timer:
        return const Color(0xFF4BC4A1);
      case AdminSection.flashCard:
        return const Color(0xFFF8AA5B);
      case AdminSection.learningMoments:
        return const Color(0xFF19A974);
      case AdminSection.evidencePackage:
        return const Color(0xFF2F7D78);
      case AdminSection.studyGroup:
        return const Color(0xFFFF7C7C);
      case AdminSection.leaderboard:
        return const Color(0xFFFFC043);
      case AdminSection.achievements:
        return const Color(0xFFFF9F43);
      case AdminSection.knowledgeGraph:
        return const Color(0xFF4CB9FF);
      case AdminSection.automations:
        return const Color(0xFF4BC4A1);
      case AdminSection.analytics:
        return const Color(0xFFF8AA5B);
      case AdminSection.settings:
        return AppColors.accentDeep;
      case AdminSection.auditLog:
        return const Color(0xFF7394F9);
      case AdminSection.trash:
        return const Color(0xFFEF6850);
    }
  }
}
