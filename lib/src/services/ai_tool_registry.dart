import 'dart:convert';

/// AI 动作风险等级
enum AiRiskLevel { safe, stateChanging, destructive }

/// 工具定义：描述一个 AI 可调用的工具
class AiToolDefinition {
  const AiToolDefinition({
    required this.toolId,
    required this.label,
    required this.description,
    required this.isNavigation,
    this.riskLevel = AiRiskLevel.safe,
    this.params = const {},
  });

  final String toolId;
  final String label;
  final String description;
  final AiRiskLevel riskLevel;
  final bool isNavigation;
  final Map<String, String> params;

  bool get needsConfirmation => riskLevel == AiRiskLevel.destructive;

  Map<String, dynamic> toAiPromptJson() {
    return {
      'toolId': toolId,
      'description': description,
      if (params.isNotEmpty) 'params': params,
    };
  }
}

/// AI 工具注册表（单例）
///
/// 所有供 AI 调用的工具在此注册，后续
/// system prompt 和上下文可由 registry 动态生成。
class AiToolRegistry {
  AiToolRegistry._();

  static final AiToolRegistry _instance = AiToolRegistry._();
  static AiToolRegistry get instance => _instance;

  final List<AiToolDefinition> _tools = [];

  void register(AiToolDefinition tool) {
    // 避免重复注册
    final existing = _tools.indexWhere((t) => t.toolId == tool.toolId);
    if (existing >= 0) {
      _tools[existing] = tool;
    } else {
      _tools.add(tool);
    }
  }

  AiToolDefinition? lookup(String toolId) {
    try {
      return _tools.firstWhere((t) => t.toolId == toolId);
    } catch (_) {
      return null;
    }
  }

  List<AiToolDefinition> get allTools => List.unmodifiable(_tools);

  List<AiToolDefinition> get safeTools =>
      _tools.where((t) => t.riskLevel == AiRiskLevel.safe).toList();

  List<AiToolDefinition> get dangerousTools =>
      _tools.where((t) => t.riskLevel == AiRiskLevel.destructive).toList();

  List<AiToolDefinition> get navigationTools =>
      _tools.where((t) => t.isNavigation).toList();

  bool isNavigationTool(String toolId) {
    return lookup(toolId)?.isNavigation ?? false;
  }

  /// 生成给 AI system prompt 的"可用动作"段落
  String buildToolListForPrompt() {
    final nav = navigationTools.map((t) => '- ${t.toolId}：${t.description}').toList();
    final data = _tools
        .where((t) => !t.isNavigation && t.riskLevel == AiRiskLevel.safe)
        .map((t) => '- ${t.toolId}：${t.description}')
        .toList();
    return [
      '导航动作：',
      ...nav,
      '数据动作（安全）：',
      ...data,
    ].join('\n');
  }

  /// 生成给 AiChatPage 上下文的"可打开页面"字符串
  String buildOpenablePagesString() {
    final navIds = navigationTools
        .where((t) => t.toolId.startsWith('navigation.open_') ||
            t.toolId == 'navigation.switch_tab')
        .map((t) => t.toolId.replaceFirst('navigation.', ''))
        .toList();
    return '可打开页面：${navIds.join('、')}';
  }

  /// 生成完整工具列表 JSON（给 AI 看）
  String buildToolJsonForPrompt() {
    return jsonEncode(_tools.map((t) => t.toAiPromptJson()).toList());
  }
}

/// 预定义工具 ID 常量
class AiToolIds {
  AiToolIds._();

  // navigation 工具
  static const switchTab = 'navigation.switch_tab';
  static const openTimer = 'navigation.open_timer';
  static const openFlashcard = 'navigation.open_flashcard';
  static const openNotes = 'navigation.open_notes';
  static const openAiSettings = 'navigation.open_ai_settings';
  static const openDashboard = 'navigation.open_dashboard';
  static const openTaskPlanning = 'navigation.open_task_planning';
  static const openAiAssistant = 'navigation.open_ai_assistant';
  static const openUserProfile = 'navigation.open_user_profile';
  static const openAbout = 'navigation.open_about';
  static const openStudyGroup = 'navigation.open_study_group';
  static const openLeaderboard = 'navigation.open_leaderboard';
  static const openWeeklyReport = 'navigation.open_weekly_report';
  static const openSystemSettings = 'navigation.open_system_settings';

  // data 工具（安全）
  static const addTask = 'task.add';
  static const createLog = 'log.create';
  static const markTaskStatus = 'task.mark_status';
  static const saveNote = 'note.save';
  static const summarizeStarredCards = 'flashcard.summarize';

  // data 工具（危险）
  static const deleteTask = 'task.delete';
  static const deleteLog = 'log.delete';
  static const deleteNote = 'note.delete';
  static const deleteFlashcard = 'flashcard.delete';
  static const overwriteNote = 'note.overwrite';

  // 设置 / 账号
  static const setDarkMode = 'settings.set_dark_mode';
  static const setSkin = 'settings.set_skin';
  static const setDailyReminder = 'settings.set_daily_reminder';
  static const setServerUrl = 'settings.set_server_url';
  static const logout = 'auth.logout';

  // 课程管理
  static const addCourse = 'course.add';
  static const renameCourse = 'course.rename';
  static const deleteCourse = 'course.delete';

  // 闪卡管理
  static const toggleFlashcardStar = 'flashcard.toggle_star';
  static const addFlashcard = 'flashcard.add';
  static const generateTodayFlashcards = 'flashcard.generate_today';

  // 计时器
  static const startFocus = 'timer.start_focus';

  // 任务扩展
  static const addTaskDirect = 'task.add_direct';
  static const updateSubtask = 'task.update_subtask';

  // 回收站
  static const emptyTrash = 'trash.empty';

  // ── Phase 2 扩展 ──
  // 规划 / 笔记来源扩写
  static const generateWeeklyPlan = 'plan.generate_weekly';
  static const noteFromLog = 'note.from_log';

  // 比赛演示：AI 学习操作层
  static const createLoopFromSource = 'loop.create_from_source';
  static const generateTodayMission = 'mission.generate_today';
  static const searchMemory = 'memory.search';
  static const noteFromOcr = 'note.create_from_ocr';
  static const createFlashcardBatch = 'flashcard.create_batch';
  static const startFocusWithTask = 'timer.start_focus_with_task';
}

/// 注册所有工具的便捷方法
void registerAllTools() {
  final r = AiToolRegistry.instance;

  // ── 导航工具 ──
  r.register(const AiToolDefinition(
    toolId: AiToolIds.switchTab,
    label: '切换页面',
    description: '切换底部主页面。targetId 只能是 assistant/scenarios/calendar/create/profile。',
    isNavigation: true,
    riskLevel: AiRiskLevel.safe,
    params: {'targetId': 'assistant|scenarios|calendar|create|profile'},
  ));
  r.register(const AiToolDefinition(
    toolId: AiToolIds.openTimer,
    label: '专注计时器',
    description: '打开专注计时器。',
    isNavigation: true,
  ));
  r.register(const AiToolDefinition(
    toolId: AiToolIds.openFlashcard,
    label: '知识闪卡',
    description: '打开知识闪卡。',
    isNavigation: true,
  ));
  r.register(const AiToolDefinition(
    toolId: AiToolIds.openNotes,
    label: '学习笔记',
    description: '打开学习笔记。',
    isNavigation: true,
  ));
  r.register(const AiToolDefinition(
    toolId: AiToolIds.openAiSettings,
    label: 'AI 设置',
    description: '打开 AI 设置。',
    isNavigation: true,
  ));
  r.register(const AiToolDefinition(
    toolId: AiToolIds.openDashboard,
    label: '数据看板',
    description: '打开数据看板。',
    isNavigation: true,
  ));
  r.register(const AiToolDefinition(
    toolId: AiToolIds.openTaskPlanning,
    label: '任务编排',
    description: '打开任务编排。',
    isNavigation: true,
  ));
  r.register(const AiToolDefinition(
    toolId: AiToolIds.openAiAssistant,
    label: 'AI 学习助手',
    description: '打开 AI 学习助手。',
    isNavigation: true,
  ));
  r.register(const AiToolDefinition(
    toolId: AiToolIds.openUserProfile,
    label: '个人资料',
    description: '打开个人资料。',
    isNavigation: true,
  ));
  r.register(const AiToolDefinition(
    toolId: AiToolIds.openAbout,
    label: '应用介绍',
    description: '打开应用介绍。',
    isNavigation: true,
  ));
  r.register(const AiToolDefinition(
    toolId: AiToolIds.openStudyGroup,
    label: '学习小组',
    description: '打开学习小组。',
    isNavigation: true,
  ));
  r.register(const AiToolDefinition(
    toolId: AiToolIds.openLeaderboard,
    label: '排行榜',
    description: '打开排行榜。',
    isNavigation: true,
  ));
  r.register(const AiToolDefinition(
    toolId: AiToolIds.openWeeklyReport,
    label: '学习周报',
    description: '生成学习周报。',
    isNavigation: true,
  ));
  r.register(const AiToolDefinition(
    toolId: AiToolIds.openSystemSettings,
    label: '系统设置',
    description: '打开系统设置。',
    isNavigation: true,
  ));
  r.register(const AiToolDefinition(
    toolId: AiToolIds.startFocusWithTask,
    label: '围绕任务专注',
    description: '围绕某个任务启动专注计时。targetId 可指定任务 id，content 可写分钟数。',
    isNavigation: true,
    params: {'targetId': 'task id', 'content': 'minutes'},
  ));

  // ── 安全数据动作 ──
  r.register(const AiToolDefinition(
    toolId: AiToolIds.addTask,
    label: '创建任务',
    description: '创建学习任务。sourceText 写清完整任务需求。',
    isNavigation: false,
    riskLevel: AiRiskLevel.safe,
    params: {'sourceText': '任务需求描述'},
  ));
  r.register(const AiToolDefinition(
    toolId: AiToolIds.createLog,
    label: '创建日志',
    description: '创建学习日志。sourceText 写清学习内容。',
    isNavigation: false,
    riskLevel: AiRiskLevel.safe,
    params: {'sourceText': '学习内容描述'},
  ));
  r.register(const AiToolDefinition(
    toolId: AiToolIds.markTaskStatus,
    label: '标记任务状态',
    description: '标记任务状态。必须尽量使用上下文里的任务 id 作为 targetId；status 只能是 completed 或 in_progress。',
    isNavigation: false,
    riskLevel: AiRiskLevel.safe,
    params: {'targetId': '任务 id', 'status': 'completed|in_progress'},
  ));
  r.register(const AiToolDefinition(
    toolId: AiToolIds.saveNote,
    label: '保存笔记',
    description: '新建学习笔记。title 写笔记标题，content 写整理后的笔记正文。',
    isNavigation: false,
    riskLevel: AiRiskLevel.safe,
    params: {'title': '笔记标题', 'content': '笔记正文'},
  ));
  r.register(const AiToolDefinition(
    toolId: AiToolIds.summarizeStarredCards,
    label: '整理闪卡',
    description: '把收藏闪卡整理成学习笔记。',
    isNavigation: false,
    riskLevel: AiRiskLevel.safe,
  ));

  // ── 危险数据动作 ──
  r.register(const AiToolDefinition(
    toolId: AiToolIds.deleteTask,
    label: '删除任务',
    description: '删除指定的学习任务（会移入回收站，可恢复）。targetId 必须指定任务 id。',
    isNavigation: false,
    riskLevel: AiRiskLevel.destructive,
    params: {'targetId': '任务 id'},
  ));
  r.register(const AiToolDefinition(
    toolId: AiToolIds.deleteLog,
    label: '删除日志',
    description: '删除指定的学习日志（会移入回收站，可恢复）。targetId 必须指定日志 id。',
    isNavigation: false,
    riskLevel: AiRiskLevel.destructive,
    params: {'targetId': '日志 id'},
  ));
  r.register(const AiToolDefinition(
    toolId: AiToolIds.deleteNote,
    label: '删除笔记',
    description: '删除指定的学习笔记（会移入回收站，可恢复）。targetId 必须指定笔记 id。',
    isNavigation: false,
    riskLevel: AiRiskLevel.destructive,
    params: {'targetId': '笔记 id'},
  ));
  r.register(const AiToolDefinition(
    toolId: AiToolIds.deleteFlashcard,
    label: '删除闪卡',
    description: '删除指定的知识闪卡（会移入回收站，可恢复）。targetId 必须指定闪卡 id。',
    isNavigation: false,
    riskLevel: AiRiskLevel.destructive,
    params: {'targetId': '闪卡 id'},
  ));
  r.register(const AiToolDefinition(
    toolId: AiToolIds.overwriteNote,
    label: '覆盖笔记',
    description: '覆盖更新已有笔记的内容。targetId 指定笔记 id，content 写新内容。',
    isNavigation: false,
    riskLevel: AiRiskLevel.destructive,
    params: {'targetId': '笔记 id', 'content': '新内容'},
  ));

  // ── 系统设置（安全） ──
  r.register(const AiToolDefinition(
    toolId: AiToolIds.setDarkMode,
    label: '切换深色模式',
    description: '切换深色/浅色主题。status 填 on/off/toggle。',
    isNavigation: false,
    riskLevel: AiRiskLevel.safe,
    params: {'status': 'on|off|toggle'},
  ));
  r.register(const AiToolDefinition(
    toolId: AiToolIds.setSkin,
    label: '切换皮肤',
    description: '切换应用皮肤。status 填 vivo/classic/toggle，vivo 为蓝色，classic 为紫色。',
    isNavigation: false,
    riskLevel: AiRiskLevel.safe,
    params: {'status': 'vivo|classic|toggle'},
  ));
  r.register(const AiToolDefinition(
    toolId: AiToolIds.setDailyReminder,
    label: '每日学习提醒',
    description: '开/关每日学习提醒，可选带时间。status 填 on/off，time 可选（HH:mm，例如 "20:00"）。',
    isNavigation: false,
    riskLevel: AiRiskLevel.safe,
    params: {'status': 'on|off', 'time': 'HH:mm（可选）'},
  ));
  // ── 账号（危险） ──
  r.register(const AiToolDefinition(
    toolId: AiToolIds.logout,
    label: '退出登录',
    description: '退出当前账号，返回登录页。建议在用户明确要求时才执行。',
    isNavigation: false,
    riskLevel: AiRiskLevel.destructive,
  ));

  // ── 课程管理 ──
  r.register(const AiToolDefinition(
    toolId: AiToolIds.addCourse,
    label: '新增课程',
    description: '新增课程。title 填课程名。',
    isNavigation: false,
    riskLevel: AiRiskLevel.safe,
    params: {'title': '课程名'},
  ));
  r.register(const AiToolDefinition(
    toolId: AiToolIds.renameCourse,
    label: '重命名课程',
    description: '重命名课程。targetTitle 填旧课程名，title 填新课程名。',
    isNavigation: false,
    riskLevel: AiRiskLevel.safe,
    params: {'targetTitle': '旧课程名', 'title': '新课程名'},
  ));
  r.register(const AiToolDefinition(
    toolId: AiToolIds.deleteCourse,
    label: '删除课程',
    description: '删除课程。targetTitle 填课程名。此操作不可撤销。',
    isNavigation: false,
    riskLevel: AiRiskLevel.destructive,
    params: {'targetTitle': '课程名'},
  ));

  // ── 闪卡管理 ──
  r.register(const AiToolDefinition(
    toolId: AiToolIds.toggleFlashcardStar,
    label: '切换闪卡收藏',
    description: '收藏/取消收藏闪卡。targetId 填闪卡 id，status 填 starred/unstarred/toggle。',
    isNavigation: false,
    riskLevel: AiRiskLevel.safe,
    params: {'targetId': '闪卡 id', 'status': 'starred|unstarred|toggle'},
  ));
  r.register(const AiToolDefinition(
    toolId: AiToolIds.addFlashcard,
    label: '手动新增闪卡',
    description: '手动新增一张知识闪卡。title 填题面，content 填答案，targetTitle 填课程（可选）。',
    isNavigation: false,
    riskLevel: AiRiskLevel.safe,
    params: {'title': '题面', 'content': '答案', 'targetTitle': '课程（可选）'},
  ));
  r.register(const AiToolDefinition(
    toolId: AiToolIds.generateTodayFlashcards,
    label: '生成今日闪卡',
    description: '从今天的学习日志生成闪卡。status 可选指定张数（默认 5）。',
    isNavigation: false,
    riskLevel: AiRiskLevel.safe,
    params: {'status': '闪卡张数（可选，默认 5）'},
  ));

  // ── 计时器 ──
  r.register(const AiToolDefinition(
    toolId: AiToolIds.startFocus,
    label: '开始专注',
    description: '打开计时器并直接开始专注。status/title 里可指定分钟数（1~180），默认 25。',
    isNavigation: true,
    riskLevel: AiRiskLevel.safe,
    params: {'status': '分钟数（可选，默认 25）'},
  ));

  // ── 任务扩展 ──
  r.register(const AiToolDefinition(
    toolId: AiToolIds.addTaskDirect,
    label: '直接创建任务',
    description: '跳过 AI 拆解直接创建任务。title 任务名，content 备注（可选），targetTitle 课程（可选），status 填 ISO 截止日期（可选）。',
    isNavigation: false,
    riskLevel: AiRiskLevel.safe,
    params: {
      'title': '任务名',
      'content': '备注（可选）',
      'targetTitle': '课程（可选）',
      'status': '截止 ISO8601（可选）',
    },
  ));
  r.register(const AiToolDefinition(
    toolId: AiToolIds.updateSubtask,
    label: '标记子任务状态',
    description: '标记指定任务的单个子任务状态。targetId 填父任务 id，targetTitle 填子任务标题，status 填 completed/in_progress/not_started。',
    isNavigation: false,
    riskLevel: AiRiskLevel.safe,
    params: {
      'targetId': '父任务 id',
      'targetTitle': '子任务标题',
      'status': 'completed|in_progress|not_started',
    },
  ));

  // ── 回收站（危险） ──
  r.register(const AiToolDefinition(
    toolId: AiToolIds.emptyTrash,
    label: '清空回收站',
    description: '永久清空回收站。此操作不可撤销。',
    isNavigation: false,
    riskLevel: AiRiskLevel.destructive,
  ));

  // ── Phase 2 扩展：AI 规划 / 日志扩写 ──
  r.register(const AiToolDefinition(
    toolId: AiToolIds.generateWeeklyPlan,
    label: '生成周学习计划',
    description: '结合未完成任务与最近学习日志生成未来一周的学习计划并落入任务列表。status 可选 "7" 表示天数。',
    isNavigation: false,
    riskLevel: AiRiskLevel.safe,
    params: {'status': '天数（可选，默认 7）'},
  ));
  r.register(const AiToolDefinition(
    toolId: AiToolIds.noteFromLog,
    label: '日志扩写成笔记',
    description: '把指定学习日志扩写成结构化学习笔记。targetId 填日志 id（优先），否则 targetTitle 填课程或关键词。',
    isNavigation: false,
    riskLevel: AiRiskLevel.safe,
    params: {'targetId': '日志 id', 'targetTitle': '课程名或关键词'},
  ));

  // ── 比赛演示：AI 学习操作层 ──
  r.register(const AiToolDefinition(
    toolId: AiToolIds.createLoopFromSource,
    label: '生成学习闭环',
    description: '从用户给出的材料生成学习记录、任务、笔记、闪卡和复习计划草稿。sourceText 放材料正文。',
    isNavigation: false,
    riskLevel: AiRiskLevel.safe,
    params: {'sourceText': '学习材料正文'},
  ));
  r.register(const AiToolDefinition(
    toolId: AiToolIds.generateTodayMission,
    label: '生成今日路径',
    description: '结合当前任务、日志、闪卡和学习状态，生成今天的最优学习路径。',
    isNavigation: false,
    riskLevel: AiRiskLevel.safe,
  ));
  r.register(const AiToolDefinition(
    toolId: AiToolIds.searchMemory,
    label: '检索学习记忆',
    description: '语义检索用户过往任务、日志、笔记和闪卡。sourceText 或 title 填查询词。',
    isNavigation: false,
    riskLevel: AiRiskLevel.safe,
    params: {'sourceText': '查询词'},
  ));
  r.register(const AiToolDefinition(
    toolId: AiToolIds.noteFromOcr,
    label: 'OCR 成笔记',
    description: '把 OCR 文本保存为学习笔记。title 可选，content/sourceText 放 OCR 文本。',
    isNavigation: false,
    riskLevel: AiRiskLevel.safe,
    params: {'title': '笔记标题', 'content': 'OCR 文本'},
  ));
  r.register(const AiToolDefinition(
    toolId: AiToolIds.createFlashcardBatch,
    label: '批量生成闪卡',
    description: '从材料批量生成知识闪卡。sourceText 放材料正文，status 可写数量。',
    isNavigation: false,
    riskLevel: AiRiskLevel.safe,
    params: {'sourceText': '学习材料正文', 'status': '数量'},
  ));
}
