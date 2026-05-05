import 'dart:convert';

import '../models/ai_config.dart';
import '../models/ai_flash_card.dart';
import '../models/ai_generated_log.dart';
import '../models/ai_risk_warning.dart';
import '../models/ai_study_analysis.dart';
import '../models/ai_task_plan.dart';
import '../models/study_log_item.dart';
import '../models/study_task_item.dart';
import 'ai_credential_service.dart';
import 'blueheart_model_client.dart';
import 'deepseek_client.dart';
import 'local_storage_service.dart';

/// AIGC 学习服务
///
/// 优先使用蓝心大模型（内置 AppKey），DeepSeek 作为备选。
/// 未配置任何 AI 服务时抛出错误提示用户配置。
class AiStudyService {
  AiStudyService({
    LocalStorageService? storage,
    AiCredentialService? credentials,
    DeepSeekClient? deepSeekClient,
    BlueHeartModelClient? blueHeartClient,
  })  : _storage = storage ?? LocalStorageService(),
        _credentials = credentials ?? AiCredentialService(),
        _deepSeekClient = deepSeekClient ?? DeepSeekClient(),
        _blueHeartClient = blueHeartClient ?? BlueHeartModelClient();

  final LocalStorageService _storage;
  final AiCredentialService _credentials;
  final DeepSeekClient _deepSeekClient;
  final BlueHeartModelClient _blueHeartClient;

  static const _systemPrompt = '''
你是 StudyTrace 的 AI 学习助手，StudyTrace 就是你正在运行的这个 App。
你内置在 App 中，用户正在跟你对话。App 本身就有以下功能，你只需要告诉用户怎么用，并直接帮他们执行操作。

当用户说"打开计时器""开专注模式"时，你直接回复【ACTION:OPEN_TIMER】，App 会自动跳转到计时器页面。
当用户说"查看闪卡""开始复习"时，回复【ACTION:OPEN_FLASHCARD】。
当用户说"添加任务""创建任务"时，回复【ACTION:ADD_TASK】。
当用户说"生成笔记""帮我总结"时，回复【ACTION:SUMMARY_NOTE】。

重要规则：
- 你运行在 StudyTrace App 内部，所有功能都在 App 里，不要建议用户去微信、浏览器或其他外部工具
- 当用户想使用某个功能（计时器、闪卡、笔记、任务），直接在回复末尾给出对应的 ACTION 标签
- 使用简单的 Markdown 格式：加粗用 **文字**，列表用 - 开头，代码用 `` 包裹
- 不要用 Markdown 表格，用简短清晰的段落和列表
- 回复要完整，不要省略，不超过500字

StudyTrace 功能介绍（你可以直接帮用户打开这些功能）：
1. 专注计时器 — 番茄钟倒计时，5/15/25/45/60 分钟可选
2. 知识闪卡 — AI 生成问答卡片，帮助巩固知识点
3. 学习笔记 — 多格式编辑器（标题/列表/待办/代码块）
4. 学习任务 — 管理作业、实验报告、论文、项目、考试复习
5. 学习日志 — 每日学习内容记录
6. 学习日历 — 查看每日学习安排
7. 周报分析 — AI 分析本周学习数据
8. 课程管理 — 按课程分类管理内容''';

  // ═══════════════════════════════════════════════════════════
  // Public API
  // ═══════════════════════════════════════════════════════════

  Future<AiGeneratedLog> generateStudyLog(String input) async {
    final blueHeartKey = await _credentials.loadBlueHeartAppKey();
    if (blueHeartKey != null && blueHeartKey.isNotEmpty) {
      try {
        return await _blueHeartGenerateStudyLog(input, blueHeartKey);
      } catch (_) {}
    }
    final runtime = await _loadDeepSeekRuntime();
    if (runtime != null) return _deepSeekGenerateStudyLog(input, runtime);
    throw const AiServiceException('请先在 AI 设置中配置蓝心或 DeepSeek');
  }

  Future<AiTaskPlan> generateTaskPlan(String input) async {
    final blueHeartKey = await _credentials.loadBlueHeartAppKey();
    if (blueHeartKey != null && blueHeartKey.isNotEmpty) {
      try {
        return await _blueHeartGenerateTaskPlan(input, blueHeartKey);
      } catch (_) {}
    }
    final runtime = await _loadDeepSeekRuntime();
    if (runtime != null) return _deepSeekGenerateTaskPlan(input, runtime);
    throw const AiServiceException('请先在 AI 设置中配置蓝心或 DeepSeek');
  }

  Future<AiStudyAnalysis> generateWeeklyAnalysis({
    required List<StudyLogItem> logs,
    required List<StudyTaskItem> tasks,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final blueHeartKey = await _credentials.loadBlueHeartAppKey();
    if (blueHeartKey != null && blueHeartKey.isNotEmpty) {
      try {
        return await _blueHeartGenerateWeeklyAnalysis(
            logs: logs, tasks: tasks,
            startDate: startDate, endDate: endDate, apiKey: blueHeartKey);
      } catch (_) {}
    }
    final runtime = await _loadDeepSeekRuntime();
    if (runtime != null) {
      return _deepSeekGenerateWeeklyAnalysis(
          logs: logs, tasks: tasks,
          startDate: startDate, endDate: endDate, runtime: runtime);
    }
    throw const AiServiceException('请先在 AI 设置中配置蓝心或 DeepSeek');
  }

  Future<List<AiRiskWarning>> generateRiskWarnings({
    required List<StudyLogItem> logs,
    required List<StudyTaskItem> tasks,
  }) async {
    final blueHeartKey = await _credentials.loadBlueHeartAppKey();
    if (blueHeartKey != null && blueHeartKey.isNotEmpty) {
      try {
        return await _blueHeartGenerateRiskWarnings(
            logs: logs, tasks: tasks, apiKey: blueHeartKey);
      } catch (_) {}
    }
    final runtime = await _loadDeepSeekRuntime();
    if (runtime != null) {
      return _deepSeekGenerateRiskWarnings(
          logs: logs, tasks: tasks, runtime: runtime);
    }
    throw const AiServiceException('请先在 AI 设置中配置蓝心或 DeepSeek');
  }

  Future<List<AiFlashCard>> generateFlashCards({
    required List<StudyLogItem> logs,
    int count = 5,
  }) async {
    final blueHeartKey = await _credentials.loadBlueHeartAppKey();
    if (blueHeartKey != null && blueHeartKey.isNotEmpty) {
      try {
        return await _blueHeartGenerateFlashCards(
            logs: logs, count: count, apiKey: blueHeartKey);
      } catch (_) {}
    }
    final runtime = await _loadDeepSeekRuntime();
    if (runtime != null) {
      return _deepSeekGenerateFlashCards(
          logs: logs, count: count, runtime: runtime);
    }
    throw const AiServiceException('请先在 AI 设置中配置蓝心或 DeepSeek');
  }

  Future<String> generateAssistantReply({
    required String input,
    List<String> context = const [],
    List<Map<String, dynamic>> messages = const [],
    String? imageBase64,
    String purpose = 'chat',
  }) async {
    final blueHeartKey = await _credentials.loadBlueHeartAppKey();
    if (blueHeartKey != null && blueHeartKey.isNotEmpty) {
      try {
        return await _blueHeartGenerateAssistantReply(
            input: input, context: context, messages: messages,
            imageBase64: imageBase64, purpose: purpose, apiKey: blueHeartKey);
      } catch (_) {}
    }
    final runtime = await _loadDeepSeekRuntime();
    if (runtime != null) {
      return _deepSeekGenerateAssistantReply(
          input: input, context: context, purpose: purpose, runtime: runtime);
    }
    throw const AiServiceException('请先在 AI 设置中配置蓝心或 DeepSeek');
  }

  Stream<String> generateAssistantReplyStream({
    required String input,
    List<String> context = const [],
    List<Map<String, dynamic>> messages = const [],
    String? imageBase64,
    String purpose = 'chat',
    bool thinkingEnabled = false,
  }) async* {
    final blueHeartKey = await _credentials.loadBlueHeartAppKey();
    if (blueHeartKey == null || blueHeartKey.isEmpty) {
      throw const AiServiceException('请先在 AI 设置中配置蓝心或 DeepSeek');
    }
    try {
      final config = await _storage.loadAiConfig();
      final systemPrompt = switch (purpose) {
        'note' => '你是 StudyTrace 的学习笔记整理助手。根据用户的收藏、对话和学习记录，生成可直接保存的学习笔记。',
        'task' => '你是 StudyTrace 的任务编排助手。根据学习目标和上下文，给出可执行建议，并在需要时用【ACTION:OPEN_TIMER】、【ACTION:ADD_TASK】或【ACTION:SUMMARY_NOTE】标注动作。',
        _ => _systemPrompt,
      };
      yield* _blueHeartClient.chatStream(
        apiKey: blueHeartKey,
        systemPrompt: systemPrompt,
        userPrompt: messages.isEmpty ? input : null,
        messages: messages.isEmpty ? null : [...messages, {'role': 'user', 'content': input}],
        imageBase64: imageBase64,
        model: config.blueHeartModel,
        temperature: config.temperature,
        maxTokens: config.maxTokens < 2000 ? 2000 : config.maxTokens,
        topP: config.topP,
        thinkingEnabled: thinkingEnabled || config.thinkingEnabled,
        frequencyPenalty: config.frequencyPenalty,
        presencePenalty: config.presencePenalty,
        reasoningEffort: config.reasoningEffort,
      );
    } catch (e) {
      yield 'AI 回复失败：$e';
    }
  }

  // ═══════════════════════════════════════════════════════════
  // DeepSeek 实现
  // ═══════════════════════════════════════════════════════════

  Future<_AiRuntime?> _loadDeepSeekRuntime() async {
    final config = await _storage.loadAiConfig();
    if (!config.isEnabled || config.provider != 'deepseek') return null;
    final apiKey = await _credentials.loadDeepSeekApiKey();
    if (apiKey == null || apiKey.isEmpty) return null;
    return _AiRuntime(config: config, apiKey: apiKey);
  }

  Future<AiGeneratedLog> _deepSeekGenerateStudyLog(String input, _AiRuntime runtime) async {
    if (input.trim().isEmpty) return const AiGeneratedLog();
    final result = await _deepSeekClient.chatJson(
      config: runtime.config, apiKey: runtime.apiKey,
      systemPrompt: _sys('你需要把大学生的自然语言学习描述整理成结构化学习日志。'),
      userPrompt: '请根据输入生成 JSON，字段必须为：\n{"courseName":"课程名或未归类","content":"今日学习内容","problems":"遇到的问题","thoughts":"思考与收获","nextPlan":"下一步计划"}\n\n输入：\n$input',
    );
    return AiGeneratedLog(
      courseName: _req(result, 'courseName'), content: _req(result, 'content'),
      problems: _str(result['problems']), thoughts: _str(result['thoughts']),
      nextPlan: _str(result['nextPlan']),
    );
  }

  Future<AiTaskPlan> _deepSeekGenerateTaskPlan(String input, _AiRuntime runtime) async {
    if (input.trim().isEmpty) {
      return AiTaskPlan(mainTitle: '', taskType: StudyTaskType.other,
          courseName: '', deadline: DateTime.now().add(const Duration(days: 7)),
          subTasks: const [], schedule: '');
    }
    final result = await _deepSeekClient.chatJson(
      config: runtime.config, apiKey: runtime.apiKey,
      systemPrompt: _sys('你需要把复杂学习任务拆成可执行计划。'),
      userPrompt: '今天：${DateTime.now().toIso8601String()}\n请生成 JSON：{"mainTitle":"","taskType":"classHomework|paperReading|programmingHomework|labReport|projectDev|examReview|readingNotes|other","courseName":"","deadline":"ISO8601","difficulty":"较轻松|中等|困难","subTasks":[""],"plannedSubTasks":[{"title":"","deadline":"ISO8601","note":""}],"schedule":""}\n输入：$input',
    );
    final raw = result['plannedSubTasks'];
    final planned = raw is List ? raw.whereType<Map<String, dynamic>>().map((j) => AiPlannedSubTask.fromJson(j)).toList() : <AiPlannedSubTask>[];
    return AiTaskPlan.fromJson({...result, 'plannedSubTasks': raw ?? planned});
  }

  Future<AiStudyAnalysis> _deepSeekGenerateWeeklyAnalysis({
    required List<StudyLogItem> logs, required List<StudyTaskItem> tasks,
    required DateTime startDate, required DateTime endDate, required _AiRuntime runtime,
  }) async {
    final result = await _deepSeekClient.chatJson(
      config: runtime.config, apiKey: runtime.apiKey,
      systemPrompt: _sys('你需要根据学习日志和任务数据生成分析型学习周报。'),
      userPrompt: '分析周期：${_fmt(startDate)} 至 ${_fmt(endDate)}\n学习日志：${_logs(logs)}\n任务：${_tasks(tasks)}\n请生成 JSON：{"mainTopics":"","courseDistribution":"","frequentProblems":"","completedTasks":"","riskTasks":"","statusEvaluation":"","nextWeekPriority":""}',
      maxTokens: 2200,
    );
    return AiStudyAnalysis(
      mainTopics: _str(result['mainTopics']), courseDistribution: _str(result['courseDistribution']),
      frequentProblems: _str(result['frequentProblems']), completedTasks: _str(result['completedTasks']),
      riskTasks: _str(result['riskTasks']), statusEvaluation: _str(result['statusEvaluation']),
      nextWeekPriority: _str(result['nextWeekPriority']),
    );
  }

  Future<List<AiRiskWarning>> _deepSeekGenerateRiskWarnings({
    required List<StudyLogItem> logs, required List<StudyTaskItem> tasks, required _AiRuntime runtime,
  }) async {
    final result = await _deepSeekClient.chatJson(
      config: runtime.config, apiKey: runtime.apiKey,
      systemPrompt: _sys('你需要识别大学生学习计划中的风险，只输出明确可执行的提醒。'),
      userPrompt: '今天：${_fmt(DateTime.now())}\n日志：${_logs(logs)}\n任务：${_tasks(tasks)}\n请生成 JSON：{"warnings":[{"title":"","description":"","level":"low|medium|high","category":"deadline|gap|completionRate|logFrequency|repeatedProblem"}]}\n没有风险返回 {"warnings":[]}',
      maxTokens: 1800,
    );
    final raw = result['warnings'];
    if (raw is! List) throw const AiServiceException('AI 返回格式异常');
    return raw.map((item) {
      if (item is! Map) throw const AiServiceException('AI 返回格式异常');
      final m = item.cast<String, dynamic>();
      return AiRiskWarning(
        title: _req(m, 'title'), description: _req(m, 'description'),
        level: _riskLevel(_str(m['level'], fallback: 'medium')),
        category: _str(m['category'], fallback: 'deadline'),
      );
    }).toList();
  }

  Future<List<AiFlashCard>> _deepSeekGenerateFlashCards({
    required List<StudyLogItem> logs, required int count, required _AiRuntime runtime,
  }) async {
    if (logs.isEmpty) return [];
    final result = await _deepSeekClient.chatJson(
      config: runtime.config, apiKey: runtime.apiKey,
      systemPrompt: _sys('你需要根据学习日志生成问答闪卡，帮助巩固知识点。'),
      userPrompt: '日志：${_logs(logs)}\n生成 $count 张闪卡，JSON：{"cards":[{"question":"","answer":"","courseName":"","hint":""}]}',
      maxTokens: 2000,
    );
    final raw = result['cards'];
    if (raw is! List) return [];
    return raw.whereType<Map>().map((item) {
      final m = item.cast<String, dynamic>();
      final now = DateTime.now();
      return AiFlashCard(
        id: 'fc_ds_${now.microsecondsSinceEpoch}_${now.millisecondsSinceEpoch}',
        question: _str(m['question'], fallback: ''),
        answer: _str(m['answer'], fallback: ''),
        courseName: _str(m['courseName'], fallback: ''),
        hint: _str(m['hint']),
        createdAt: now,
      );
    }).where((c) => c.question.isNotEmpty).toList();
  }

  Future<String> _deepSeekGenerateAssistantReply({
    required String input, required List<String> context,
    required String purpose, required _AiRuntime runtime,
  }) async {
    final sp = switch (purpose) {
      'note' => '你是 StudyTrace 的学习笔记整理助手。',
      'task' => '你是 StudyTrace 的任务编排助手。',
      _ => '你是 StudyTrace 的 AI 学习助手。在需要时用【ACTION:OPEN_TIMER】、【ACTION:ADD_TASK】、【ACTION:SUMMARY_NOTE】标注动作。',
    };
    return _deepSeekClient.chatText(
      config: runtime.config, apiKey: runtime.apiKey, systemPrompt: sp,
      userPrompt: [if (context.isNotEmpty) '上下文：\n${context.join('\n')}', '用户输入：$input',
        if (purpose == 'note') '请输出简洁的学习笔记正文' else '请优先给出明确、可执行、简洁的回答。'].join('\n\n'),
      maxTokens: purpose == 'note' ? 1800 : 1200,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 蓝心大模型实现
  // ═══════════════════════════════════════════════════════════

  Future<AiGeneratedLog> _blueHeartGenerateStudyLog(String input, String apiKey) async {
    if (input.trim().isEmpty) return const AiGeneratedLog();
    final cfg = await _storage.loadAiConfig();
    final result = await _blueHeartClient.chatJson(
      apiKey: apiKey, model: cfg.blueHeartModel,
      temperature: cfg.temperature, maxTokens: cfg.maxTokens,
      topP: cfg.topP, thinkingEnabled: cfg.thinkingEnabled,
      systemPrompt: _sys('你需要把大学生的自然语言学习描述整理成结构化学习日志。'),
      userPrompt: '请根据输入生成 JSON：{"courseName":"","content":"","problems":"","thoughts":"","nextPlan":""}\n输入：$input',
    );
    return AiGeneratedLog(
      courseName: _req(result, 'courseName'), content: _req(result, 'content'),
      problems: _str(result['problems']), thoughts: _str(result['thoughts']),
      nextPlan: _str(result['nextPlan']),
    );
  }

  Future<AiTaskPlan> _blueHeartGenerateTaskPlan(String input, String apiKey) async {
    if (input.trim().isEmpty) {
      return AiTaskPlan(mainTitle: '', taskType: StudyTaskType.other,
          courseName: '', deadline: DateTime.now().add(const Duration(days: 7)),
          subTasks: const [], schedule: '');
    }
    final cfg = await _storage.loadAiConfig();
    final result = await _blueHeartClient.chatJson(
      apiKey: apiKey, model: cfg.blueHeartModel,
      temperature: cfg.temperature, maxTokens: cfg.maxTokens,
      topP: cfg.topP, thinkingEnabled: cfg.thinkingEnabled,
      systemPrompt: _sys('你需要把复杂学习任务拆成可执行计划。'),
      userPrompt: '今天：${DateTime.now().toIso8601String()}\n请生成：{"mainTitle":"","taskType":"classHomework|...|other","courseName":"","deadline":"ISO8601","subTasks":[""],"schedule":""}\n输入：$input',
    );
    final raw = result['plannedSubTasks'];
    final planned = raw is List ? raw.whereType<Map<String, dynamic>>().map((j) => AiPlannedSubTask.fromJson(j)).toList() : <AiPlannedSubTask>[];
    return AiTaskPlan.fromJson({...result, 'plannedSubTasks': raw ?? planned});
  }

  Future<AiStudyAnalysis> _blueHeartGenerateWeeklyAnalysis({
    required List<StudyLogItem> logs, required List<StudyTaskItem> tasks,
    required DateTime startDate, required DateTime endDate, required String apiKey,
  }) async {
    final cfg = await _storage.loadAiConfig();
    final result = await _blueHeartClient.chatJson(
      apiKey: apiKey, model: cfg.blueHeartModel,
      temperature: cfg.temperature, topP: cfg.topP,
      thinkingEnabled: cfg.thinkingEnabled,
      systemPrompt: _sys('你需要根据学习日志和任务数据生成分析型学习周报。'),
      userPrompt: '分析：${_fmt(startDate)}~${_fmt(endDate)}\n日志：${_logs(logs)}\n任务：${_tasks(tasks)}\nJSON：{"mainTopics":"","courseDistribution":"","frequentProblems":"","completedTasks":"","riskTasks":"","statusEvaluation":"","nextWeekPriority":""}',
      maxTokens: 2200,
    );
    return AiStudyAnalysis(
      mainTopics: _str(result['mainTopics']), courseDistribution: _str(result['courseDistribution']),
      frequentProblems: _str(result['frequentProblems']), completedTasks: _str(result['completedTasks']),
      riskTasks: _str(result['riskTasks']), statusEvaluation: _str(result['statusEvaluation']),
      nextWeekPriority: _str(result['nextWeekPriority']),
    );
  }

  Future<List<AiRiskWarning>> _blueHeartGenerateRiskWarnings({
    required List<StudyLogItem> logs, required List<StudyTaskItem> tasks, required String apiKey,
  }) async {
    final cfg = await _storage.loadAiConfig();
    final result = await _blueHeartClient.chatJson(
      apiKey: apiKey, model: cfg.blueHeartModel,
      temperature: cfg.temperature, topP: cfg.topP,
      thinkingEnabled: cfg.thinkingEnabled,
      systemPrompt: _sys('你需要识别大学生学习计划中的风险，只输出明确可执行的提醒。'),
      userPrompt: '今天：${_fmt(DateTime.now())}\n日志：${_logs(logs)}\n任务：${_tasks(tasks)}\nJSON：{"warnings":[{"title":"","description":"","level":"low|medium|high","category":"deadline|gap|completionRate|logFrequency|repeatedProblem"}]}',
      maxTokens: 1800,
    );
    final raw = result['warnings'];
    if (raw is! List) throw const AiServiceException('AI 返回格式异常');
    return raw.map((item) {
      if (item is! Map) throw const AiServiceException('AI 返回格式异常');
      final m = item.cast<String, dynamic>();
      return AiRiskWarning(
        title: _req(m, 'title'), description: _req(m, 'description'),
        level: _riskLevel(_str(m['level'], fallback: 'medium')),
        category: _str(m['category'], fallback: 'deadline'),
      );
    }).toList();
  }

  Future<List<AiFlashCard>> _blueHeartGenerateFlashCards({
    required List<StudyLogItem> logs, required int count, required String apiKey,
  }) async {
    if (logs.isEmpty) return [];
    final cfg = await _storage.loadAiConfig();
    final result = await _blueHeartClient.chatJson(
      apiKey: apiKey, model: cfg.blueHeartModel,
      temperature: cfg.temperature, topP: cfg.topP,
      thinkingEnabled: cfg.thinkingEnabled,
      systemPrompt: _sys('你需要根据学习日志生成问答闪卡，帮助巩固知识点。'),
      userPrompt: '日志：${_logs(logs)}\n生成 $count 张闪卡：{"cards":[{"question":"","answer":"","courseName":"","hint":""}]}',
      maxTokens: 2000,
    );
    final raw = result['cards'];
    if (raw is! List) return [];
    return raw.whereType<Map>().map((item) {
      final m = item.cast<String, dynamic>();
      final now = DateTime.now();
      return AiFlashCard(
        id: 'fc_ds_${now.microsecondsSinceEpoch}_${now.millisecondsSinceEpoch}',
        question: _str(m['question'], fallback: ''),
        answer: _str(m['answer'], fallback: ''),
        courseName: _str(m['courseName'], fallback: ''),
        hint: _str(m['hint']),
        createdAt: now,
      );
    }).where((c) => c.question.isNotEmpty).toList();
  }

  Future<String> _blueHeartGenerateAssistantReply({
    required String input, required List<String> context,
    List<Map<String, dynamic>> messages = const [],
    String? imageBase64, required String purpose, required String apiKey,
  }) async {
    final sp = switch (purpose) {
      'note' => '你是 StudyTrace 的学习笔记整理助手。根据用户输入生成可直接保存的学习笔记。',
      'task' => '你是 StudyTrace 的任务编排助手。',
      _ => _systemPrompt,
    };
    final cfg = await _storage.loadAiConfig();
    return _blueHeartClient.chatText(
      apiKey: apiKey, model: cfg.blueHeartModel,
      temperature: cfg.temperature, topP: cfg.topP,
      thinkingEnabled: cfg.thinkingEnabled,
      frequencyPenalty: cfg.frequencyPenalty,
      presencePenalty: cfg.presencePenalty,
      reasoningEffort: cfg.reasoningEffort,
      systemPrompt: messages.isEmpty ? sp : null,
      userPrompt: messages.isEmpty
          ? [if (context.isNotEmpty) '上下文：\n${context.join('\n')}', '用户输入：$input',
              if (purpose == 'note') '请输出简洁的学习笔记正文' else '请优先给出明确、可执行、简洁的回答。'].join('\n\n')
          : null,
      messages: messages.isEmpty ? null : [...messages, {'role': 'user', 'content': input}],
      imageBase64: imageBase64,
      maxTokens: purpose == 'note' ? 1800 : 1200,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════

  String _sys(String task) => '你是 StudyTrace 的 AI 学习助手。$task\n只返回合法 JSON，不要返回 Markdown、注释或额外解释。\n字段内容使用简洁中文，适合大学生日常学习记录。';

  String _req(Map<String, dynamic> json, String key) {
    final v = json[key];
    if (v is String && v.trim().isNotEmpty) return v.trim();
    throw const AiServiceException('AI 返回格式异常');
  }

  String _str(Object? value, {String fallback = ''}) {
    if (value == null) return fallback;
    if (value is String) return value.trim();
    return value.toString().trim();
  }

  RiskLevel _riskLevel(String value) => switch (value.trim()) {
    'low' => RiskLevel.low, 'medium' => RiskLevel.medium,
    'high' => RiskLevel.high,
    _ => throw const AiServiceException('AI 返回格式异常'),
  };

  String _fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _logs(List<StudyLogItem> logs) => jsonEncode(logs.map((l) => {
    'date': _fmt(l.date), 'courseName': l.courseName,
    'content': l.content, 'problems': l.problems,
    'thoughts': l.thoughts, 'nextPlan': l.nextPlan,
  }).toList());

  String _tasks(List<StudyTaskItem> tasks) => jsonEncode(tasks.map((t) => {
    'title': t.title, 'type': t.type.name, 'typeLabel': t.type.label,
    'courseName': t.courseName, 'deadline': _fmt(t.deadline),
    'status': t.status.name, 'statusLabel': t.status.label, 'note': t.note,
  }).toList());
}

class _AiRuntime {
  const _AiRuntime({required this.config, required this.apiKey});
  final AiConfig config;
  final String apiKey;
}
