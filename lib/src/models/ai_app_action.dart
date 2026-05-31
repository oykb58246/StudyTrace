import 'dart:convert';

enum AiAppActionType {
  switchTab,
  openTimer,
  openFlashcard,
  openNotes,
  openAiSettings,
  addTask,
  createLog,
  markTaskStatus,
  saveNote,
  summarizeStarredCards,
  openDashboard,
  openTaskPlanning,
  openAiAssistant,
  openUserProfile,
  openAbout,
  openStudyGroup,
  openLeaderboard,
  openWeeklyReport,
  openSystemSettings,
  deleteTask,
  deleteLog,
  deleteNote,
  deleteFlashcard,
  overwriteNote,
  // ── 扩展动作 ──
  setDarkMode,
  setSkin,
  setDailyReminder,
  setServerUrl,
  logout,
  addCourse,
  renameCourse,
  deleteCourse,
  toggleFlashcardStar,
  addFlashcard,
  generateTodayFlashcards,
  startFocus,
  addTaskDirect,
  updateSubtask,
  emptyTrash,
  // Phase 2
  generateWeeklyPlan,
  noteFromLog,
  // 学习工具扩展
  createLoopFromSource,
  generateTodayMission,
  searchMemory,
  noteFromOcr,
  createFlashcardBatch,
  startFocusWithTask,
  generateImage,
  refreshImage,
  generateVideo,
  refreshVideo,
  translateText,
  searchPoi,
  reverseGeocode,
}

typedef AiActionHandler = Future<List<AiActionResult>> Function({
  required List<AiAppAction> actions,
  required String input,
  required String assistantReply,
});

class AiAssistantTurn {
  const AiAssistantTurn({
    required this.reply,
    this.actions = const [],
    this.schemaVersion = 1,
  });

  final String reply;
  final List<AiAppAction> actions;
  final int schemaVersion;

  factory AiAssistantTurn.fromJson(Map<String, dynamic> json) {
    final rawActions = json['actions'];
    final actions = <AiAppAction>[];
    if (rawActions is List) {
      for (final item in rawActions) {
        if (item is Map) {
          final action =
              AiAppAction.tryParse(item.cast<String, dynamic>());
          if (action != null) actions.add(action);
        }
      }
    }
    return AiAssistantTurn(
      reply: _stringValue(json['reply'] ?? json['message']),
      actions: actions,
      schemaVersion:
          _intValue(json['schemaVersion'] ?? json['schema_version']) ?? 1,
    );
  }
}

class AiAppAction {
  const AiAppAction({
    required this.type,
    this.targetId,
    this.targetTitle,
    this.status,
    this.title,
    this.content,
    this.sourceText,
    this.actionId,
  });

  final AiAppActionType type;
  final String? targetId;
  final String? targetTitle;
  final String? status;
  final String? title;
  final String? content;
  final String? sourceText;
  final String? actionId;

  static AiAppAction? tryParse(Map<String, dynamic> json) {
    final rawType = _stringValue(json['type'] ?? json['toolId'] ?? json['action']);
    final type = aiAppActionTypeFromWire(
      rawType,
    );
    if (type == null) return null;
    final normalizedType = rawType
        .trim()
        .replaceAll('-', '_')
        .replaceAll(' ', '_')
        .toLowerCase();
    final inferredStatus = switch (normalizedType) {
      'mark_completed' => 'completed',
      'mark_in_progress' => 'in_progress',
      _ => null,
    };
    // 把模型可能自造的额外字段（如 time / minutes / count / course）合并到 sourceText，
    // 方便下游 handler 用正则兜底解析。
    const standardKeys = {
      'type', 'toolId', 'action', 'targetId', 'target_id',
      'targetTitle', 'target_title', 'status', 'title', 'content',
      'sourceText', 'source_text', 'actionId', 'action_id',
    };
    final extras = <String>[];
    for (final entry in json.entries) {
      if (standardKeys.contains(entry.key)) continue;
      final v = entry.value;
      if (v == null) continue;
      String text;
      if (v is String) {
        text = v;
      } else if (v is num || v is bool) {
        text = v.toString();
      } else if (v is List || v is Map) {
        try {
          text = jsonEncode(v);
        } catch (_) {
          text = v.toString();
        }
      } else {
        text = v.toString();
      }
      if (text.trim().isEmpty) continue;
      extras.add('${entry.key}: $text');
    }
    final explicitSource =
        _nullableString(json['sourceText'] ?? json['source_text']);
    final mergedSource = extras.isEmpty
        ? explicitSource
        : (explicitSource == null || explicitSource.isEmpty
            ? extras.join(' | ')
            : '$explicitSource | ${extras.join(' | ')}');
    return AiAppAction(
      type: type,
      targetId: _nullableString(json['targetId'] ?? json['target_id']),
      targetTitle:
          _nullableString(json['targetTitle'] ?? json['target_title']),
      status: _nullableString(json['status']) ?? inferredStatus,
      title: _nullableString(json['title']),
      content: _nullableString(json['content']),
      sourceText: mergedSource,
      actionId: _nullableString(json['actionId'] ?? json['action_id']),
    );
  }
}

class AiActionResult {
  const AiActionResult({
    required this.action,
    required this.success,
    required this.message,
    this.createdId,
    this.candidates = const [],
  });

  final AiAppAction action;
  final bool success;
  final String message;
  final String? createdId;
  final List<String> candidates;
}

AiAppActionType? aiAppActionTypeFromWire(String value) {
  final raw = value
      .trim()
      .replaceAll('-', '_')
      .replaceAll(' ', '_')
      .toLowerCase();

  // 1) 优先按"命名空间 + 动作"做精确匹配，避免 course.add 被误当成 task.add
  final nsExact = switch (raw) {
    // 导航
    'navigation.switch_tab' => AiAppActionType.switchTab,
    'navigation.open_timer' => AiAppActionType.openTimer,
    'navigation.open_flashcard' => AiAppActionType.openFlashcard,
    'navigation.open_notes' => AiAppActionType.openNotes,
    'navigation.open_ai_settings' => AiAppActionType.openAiSettings,
    'navigation.open_dashboard' => AiAppActionType.openDashboard,
    'navigation.open_task_planning' => AiAppActionType.openTaskPlanning,
    'navigation.open_ai_assistant' => AiAppActionType.openAiAssistant,
    'navigation.open_user_profile' => AiAppActionType.openUserProfile,
    'navigation.open_about' => AiAppActionType.openAbout,
    'navigation.open_study_group' => AiAppActionType.openStudyGroup,
    'navigation.open_leaderboard' => AiAppActionType.openLeaderboard,
    'navigation.open_weekly_report' => AiAppActionType.openWeeklyReport,
    'navigation.open_system_settings' => AiAppActionType.openSystemSettings,
    // 任务
    'task.add' => AiAppActionType.addTask,
    'task.mark_status' => AiAppActionType.markTaskStatus,
    'task.delete' => AiAppActionType.deleteTask,
    'task.add_direct' => AiAppActionType.addTaskDirect,
    'task.update_subtask' => AiAppActionType.updateSubtask,
    // 日志
    'log.create' => AiAppActionType.createLog,
    'log.delete' => AiAppActionType.deleteLog,
    // 笔记
    'note.save' => AiAppActionType.saveNote,
    'note.delete' => AiAppActionType.deleteNote,
    'note.overwrite' => AiAppActionType.overwriteNote,
    // 闪卡
    'flashcard.summarize' => AiAppActionType.summarizeStarredCards,
    'flashcard.delete' => AiAppActionType.deleteFlashcard,
    'flashcard.toggle_star' => AiAppActionType.toggleFlashcardStar,
    'flashcard.add' => AiAppActionType.addFlashcard,
    'flashcard.generate_today' => AiAppActionType.generateTodayFlashcards,
    // 设置
    'settings.set_dark_mode' => AiAppActionType.setDarkMode,
    'settings.set_skin' => AiAppActionType.setSkin,
    'settings.set_daily_reminder' => AiAppActionType.setDailyReminder,
    'settings.set_server_url' => AiAppActionType.setServerUrl,
    // 账号
    'auth.logout' => AiAppActionType.logout,
    // 课程
    'course.add' => AiAppActionType.addCourse,
    'course.rename' => AiAppActionType.renameCourse,
    'course.delete' => AiAppActionType.deleteCourse,
    // 计时器
    'timer.start_focus' => AiAppActionType.startFocus,
    // 回收站
    'trash.empty' => AiAppActionType.emptyTrash,
    // Phase 2
    'plan.generate_weekly' => AiAppActionType.generateWeeklyPlan,
    'note.from_log' => AiAppActionType.noteFromLog,
    'loop.create_from_source' => AiAppActionType.createLoopFromSource,
    'mission.generate_today' => AiAppActionType.generateTodayMission,
    'memory.search' => AiAppActionType.searchMemory,
    'note.create_from_ocr' => AiAppActionType.noteFromOcr,
    'flashcard.create_batch' => AiAppActionType.createFlashcardBatch,
    'timer.start_focus_with_task' => AiAppActionType.startFocusWithTask,
    'media.generate_image' => AiAppActionType.generateImage,
    'media.refresh_image' => AiAppActionType.refreshImage,
    'media.generate_video' => AiAppActionType.generateVideo,
    'media.refresh_video' => AiAppActionType.refreshVideo,
    'api.translate_text' => AiAppActionType.translateText,
    'api.search_poi' => AiAppActionType.searchPoi,
    'api.reverse_geocode' => AiAppActionType.reverseGeocode,
    _ => null,
  };
  if (nsExact != null) return nsExact;

  // 2) 如果不是带点的命名空间，按无命名空间的 wire 做别名匹配
  final normalized = raw
      .replaceAll('navigation.', '')
      .replaceAll('task.', '')
      .replaceAll('log.', '')
      .replaceAll('note.', '')
      .replaceAll('flashcard.', '')
      .replaceAll('settings.', '')
      .replaceAll('auth.', '')
      .replaceAll('course.', '')
      .replaceAll('timer.', '')
      .replaceAll('trash.', '')
      .replaceAll('plan.', '')
      .replaceAll('loop.', '')
      .replaceAll('mission.', '')
      .replaceAll('memory.', '')
      .replaceAll('media.', '')
      .replaceAll('api.', '');
  // 同时提供带命名空间的几条常见别名，覆盖 normalize 之后拼写
  final aliased = switch (normalized) {
    'mark_status' => 'mark_task_status',
    'summarize' => 'summarize_starred_cards',
    _ => normalized,
  };
  return switch (aliased) {
    'switch_tab' => AiAppActionType.switchTab,
    'open_timer' => AiAppActionType.openTimer,
    'open_flashcard' || 'open_flashcards' => AiAppActionType.openFlashcard,
    'open_notes' || 'open_note' => AiAppActionType.openNotes,
    'open_ai_settings' || 'open_settings' => AiAppActionType.openAiSettings,
    'add_task' || 'create_task' => AiAppActionType.addTask,
    'create_log' || 'add_log' => AiAppActionType.createLog,
    'mark_task_status' || 'mark_completed' || 'mark_in_progress' =>
      AiAppActionType.markTaskStatus,
    'save_note' => AiAppActionType.saveNote,
    'summarize_starred_cards' || 'summary_note' =>
      AiAppActionType.summarizeStarredCards,
    'open_dashboard' || 'open_dashboards' || '看板' || '数据看板' =>
      AiAppActionType.openDashboard,
    'open_task_planning' || 'open_task_plannings' || '任务编排' || '编排' =>
      AiAppActionType.openTaskPlanning,
    'open_ai_assistant' ||
    'open_ai_assistants' ||
    'ai助手' ||
    '学习助手' ||
    'AI学习助手' =>
      AiAppActionType.openAiAssistant,
    'open_user_profile' || 'open_users_profile' || '个人资料' || 'profile' =>
      AiAppActionType.openUserProfile,
    'open_about' || 'about' || '关于' || '应用介绍' =>
      AiAppActionType.openAbout,
    'open_study_group' || 'open_study_groups' || '学习小组' || '小组' =>
      AiAppActionType.openStudyGroup,
    'open_leaderboard' || 'open_leaderboards' || '排行榜' || '排名' =>
      AiAppActionType.openLeaderboard,
    'open_weekly_report' || 'open_weekly_reports' || '周报' || '生成周报' =>
      AiAppActionType.openWeeklyReport,
    'open_system_settings' || 'open_system_setting' || '系统设置' || '设置' =>
      AiAppActionType.openSystemSettings,
    'delete_task' || 'remove_task' => AiAppActionType.deleteTask,
    'delete_log' || 'remove_log' => AiAppActionType.deleteLog,
    'delete_note' || 'remove_note' => AiAppActionType.deleteNote,
    'delete_flashcard' || 'delete_flash_card' || 'remove_flashcard' =>
      AiAppActionType.deleteFlashcard,
    'overwrite_note' || 'update_note' || 'replace_note' =>
      AiAppActionType.overwriteNote,
    // ── 系统设置 ──
    'set_dark_mode' || 'toggle_dark_mode' || '深色模式' =>
      AiAppActionType.setDarkMode,
    'set_skin' || 'change_skin' || '切换皮肤' || '皮肤' =>
      AiAppActionType.setSkin,
    'set_daily_reminder' || 'daily_reminder' || '每日提醒' || '学习提醒' =>
      AiAppActionType.setDailyReminder,
    'set_server_url' || 'set_backend_url' || 'set_api_base_url' =>
      AiAppActionType.setServerUrl,
    'logout' || 'sign_out' || '退出登录' || '注销' => AiAppActionType.logout,
    // ── 课程 ──
    'add_course' || 'create_course' || '新增课程' => AiAppActionType.addCourse,
    'rename_course' || 'update_course' || '重命名课程' =>
      AiAppActionType.renameCourse,
    'delete_course' || 'remove_course' || '删除课程' =>
      AiAppActionType.deleteCourse,
    // ── 闪卡扩展 ──
    'toggle_star' || 'toggle_flashcard_star' || 'star_flashcard' =>
      AiAppActionType.toggleFlashcardStar,
    'add_flashcard' || 'add_flash_card' || 'create_flashcard' =>
      AiAppActionType.addFlashcard,
    'generate_today' || 'generate_today_flashcards' ||
          'generate_daily_flashcards' =>
      AiAppActionType.generateTodayFlashcards,
    // ── 计时器 ──
    'start_focus' || 'start_focus_timer' || 'start_pomodoro' ||
          '开始专注' || '开专注' =>
      AiAppActionType.startFocus,
    // ── 任务扩展 ──
    'add_task_direct' || 'create_task_direct' ||
          'quick_add_task' =>
      AiAppActionType.addTaskDirect,
    'update_subtask' || 'mark_subtask' || 'subtask_status' =>
      AiAppActionType.updateSubtask,
    // ── 回收站 ──
    'empty_trash' || 'clear_trash' || '清空回收站' =>
      AiAppActionType.emptyTrash,
    // ── 学习规划扩展 ──
    'generate_weekly_plan' || 'generate_weekly' || 'plan_weekly' ||
          'weekly_plan' || '生成周计划' || '生成学习计划' =>
      AiAppActionType.generateWeeklyPlan,
    'from_log' || 'expand_log' || 'note_from_log' || '扩写日志' ||
          '日志扩写' =>
      AiAppActionType.noteFromLog,
    // ── 学习操作层 ──
    'create_from_source' || 'create_loop_from_source' ||
          'learning_loop' || '学习安排' || '学习闭环' =>
      AiAppActionType.createLoopFromSource,
    'generate_today_mission' || 'generate_today_path' ||
          'today_mission' || '今日安排' || '今日路径' =>
      AiAppActionType.generateTodayMission,
    'search' || 'search_memory' || 'memory_search' || '学习记忆' =>
      AiAppActionType.searchMemory,
    'create_from_ocr' || 'note_from_ocr' || 'ocr_note' =>
      AiAppActionType.noteFromOcr,
    'create_batch' || 'create_flashcard_batch' || 'flashcard_batch' =>
      AiAppActionType.createFlashcardBatch,
    'start_focus_with_task' || 'focus_with_task' =>
      AiAppActionType.startFocusWithTask,
    'generate_image' || 'create_image' || 'image_generation' ||
          'text_to_image' || 'draw_image' || '生成图片' || '画图' =>
      AiAppActionType.generateImage,
    'refresh_image' || 'query_image' || 'image_status' =>
      AiAppActionType.refreshImage,
    'generate_video' || 'create_video' || 'video_generation' ||
          'text_to_video' || '生成视频' || '文生视频' =>
      AiAppActionType.generateVideo,
    'refresh_video' || 'query_video' || 'video_status' =>
      AiAppActionType.refreshVideo,
    'translate_text' || 'translate' => AiAppActionType.translateText,
    'search_poi' || 'poi_search' || 'search_place' || 'search_location' =>
      AiAppActionType.searchPoi,
    'reverse_geocode' || 'geocode_reverse' || 'address_from_location' =>
      AiAppActionType.reverseGeocode,
    _ => null,
  };
}

String aiAppActionTypeToWire(AiAppActionType type) {
  return switch (type) {
    AiAppActionType.switchTab => 'switch_tab',
    AiAppActionType.openTimer => 'open_timer',
    AiAppActionType.openFlashcard => 'open_flashcard',
    AiAppActionType.openNotes => 'open_notes',
    AiAppActionType.openAiSettings => 'open_ai_settings',
    AiAppActionType.addTask => 'add_task',
    AiAppActionType.createLog => 'create_log',
    AiAppActionType.markTaskStatus => 'mark_task_status',
    AiAppActionType.saveNote => 'save_note',
    AiAppActionType.summarizeStarredCards => 'summarize_starred_cards',
    AiAppActionType.openDashboard => 'open_dashboard',
    AiAppActionType.openTaskPlanning => 'open_task_planning',
    AiAppActionType.openAiAssistant => 'open_ai_assistant',
    AiAppActionType.openUserProfile => 'open_user_profile',
    AiAppActionType.openAbout => 'open_about',
    AiAppActionType.openStudyGroup => 'open_study_group',
    AiAppActionType.openLeaderboard => 'open_leaderboard',
    AiAppActionType.openWeeklyReport => 'open_weekly_report',
    AiAppActionType.openSystemSettings => 'open_system_settings',
    AiAppActionType.deleteTask => 'delete_task',
    AiAppActionType.deleteLog => 'delete_log',
    AiAppActionType.deleteNote => 'delete_note',
    AiAppActionType.deleteFlashcard => 'delete_flashcard',
    AiAppActionType.overwriteNote => 'overwrite_note',
    AiAppActionType.setDarkMode => 'set_dark_mode',
    AiAppActionType.setSkin => 'set_skin',
    AiAppActionType.setDailyReminder => 'set_daily_reminder',
    AiAppActionType.setServerUrl => 'set_server_url',
    AiAppActionType.logout => 'logout',
    AiAppActionType.addCourse => 'add_course',
    AiAppActionType.renameCourse => 'rename_course',
    AiAppActionType.deleteCourse => 'delete_course',
    AiAppActionType.toggleFlashcardStar => 'toggle_flashcard_star',
    AiAppActionType.addFlashcard => 'add_flashcard',
    AiAppActionType.generateTodayFlashcards => 'generate_today_flashcards',
    AiAppActionType.startFocus => 'start_focus',
    AiAppActionType.addTaskDirect => 'add_task_direct',
    AiAppActionType.updateSubtask => 'update_subtask',
    AiAppActionType.emptyTrash => 'empty_trash',
    AiAppActionType.generateWeeklyPlan => 'generate_weekly_plan',
    AiAppActionType.noteFromLog => 'note_from_log',
    AiAppActionType.createLoopFromSource => 'create_loop_from_source',
    AiAppActionType.generateTodayMission => 'generate_today_mission',
    AiAppActionType.searchMemory => 'search_memory',
    AiAppActionType.noteFromOcr => 'note_from_ocr',
    AiAppActionType.createFlashcardBatch => 'create_flashcard_batch',
    AiAppActionType.startFocusWithTask => 'start_focus_with_task',
    AiAppActionType.generateImage => 'generate_image',
    AiAppActionType.refreshImage => 'refresh_image',
    AiAppActionType.generateVideo => 'generate_video',
    AiAppActionType.refreshVideo => 'refresh_video',
    AiAppActionType.translateText => 'translate_text',
    AiAppActionType.searchPoi => 'search_poi',
    AiAppActionType.reverseGeocode => 'reverse_geocode',
  };
}

String _stringValue(Object? value) {
  if (value == null) return '';
  return value.toString().trim();
}

String? _nullableString(Object? value) {
  final text = _stringValue(value);
  return text.isEmpty ? null : text;
}

int? _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(_stringValue(value));
}
