import 'dart:convert';
import 'dart:math';

import '../models/ai_config.dart';
import '../models/ai_flash_card.dart';
import '../models/ai_generated_log.dart';
import '../models/ai_risk_warning.dart';
import '../models/ai_study_analysis.dart';
import '../models/ai_task_plan.dart';
import '../models/study_log_item.dart';
import '../models/study_task_item.dart';
import 'ai_credential_service.dart';
import 'deepseek_client.dart';
import 'local_storage_service.dart';

/// AIGC 学习服务
///
/// 提供面向学习场景的四大 AI 能力：
/// 1. AI 生成学习日志
/// 2. AI 任务拆解
/// 3. AI 分析型周报
/// 4. AI 学习风险提醒
///
/// 未配置 DeepSeek API Key 时返回规则生成的模拟结果。
/// 配置并启用后，使用 DeepSeek Chat Completions + JSON Output。
class AiStudyService {
  AiStudyService({
    LocalStorageService? storage,
    AiCredentialService? credentials,
    DeepSeekClient? deepSeekClient,
  })  : _storage = storage ?? LocalStorageService(),
        _credentials = credentials ?? AiCredentialService(),
        _deepSeekClient = deepSeekClient ?? DeepSeekClient();

  final LocalStorageService _storage;
  final AiCredentialService _credentials;
  final DeepSeekClient _deepSeekClient;

  static const _courseKeywords = [
    '数据库',
    'Java',
    'Python',
    '高数',
    '数学',
    '英语',
    '操作系统',
    '网络',
    '数据结构',
    '算法',
    '编译原理',
    '软件工程',
    '人工智能',
    '机器学习',
    '深度学习',
    '计算机视觉',
    '嵌入式',
    '物联网',
    '区块链',
    '前端',
    '后端',
    '移动开发',
    '测试',
    '安全',
  ];

  /// AI 生成结构化学习日志
  ///
  /// 用户输入自然语言描述，返回结构化学习日志结果。
  Future<AiGeneratedLog> generateStudyLog(String input) async {
    final runtime = await _loadRuntime();
    if (runtime == null) return _mockGenerateStudyLog(input);
    return _deepSeekGenerateStudyLog(input, runtime);
  }

  /// AI 拆解复杂学习任务
  Future<AiTaskPlan> generateTaskPlan(String input) async {
    final runtime = await _loadRuntime();
    if (runtime == null) return _mockGenerateTaskPlan(input);
    return _deepSeekGenerateTaskPlan(input, runtime);
  }

  /// AI 分析型周报生成
  Future<AiStudyAnalysis> generateWeeklyAnalysis({
    required List<StudyLogItem> logs,
    required List<StudyTaskItem> tasks,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final runtime = await _loadRuntime();
    if (runtime == null) {
      return _mockGenerateWeeklyAnalysis(
        logs: logs,
        tasks: tasks,
        startDate: startDate,
        endDate: endDate,
      );
    }
    return _deepSeekGenerateWeeklyAnalysis(
      logs: logs,
      tasks: tasks,
      startDate: startDate,
      endDate: endDate,
      runtime: runtime,
    );
  }

  /// AI 学习风险提醒
  Future<List<AiRiskWarning>> generateRiskWarnings({
    required List<StudyLogItem> logs,
    required List<StudyTaskItem> tasks,
  }) async {
    final runtime = await _loadRuntime();
    if (runtime == null) {
      return _mockGenerateRiskWarnings(logs: logs, tasks: tasks);
    }
    return _deepSeekGenerateRiskWarnings(
      logs: logs,
      tasks: tasks,
      runtime: runtime,
    );
  }

  /// AI 生成知识闪卡
  ///
  /// 基于近期学习日志自动生成问答闪卡，帮助巩固知识点。
  Future<List<AiFlashCard>> generateFlashCards({
    required List<StudyLogItem> logs,
    int count = 5,
  }) async {
    final runtime = await _loadRuntime();
    if (runtime == null) return _mockGenerateFlashCards(logs: logs, count: count);
    return _deepSeekGenerateFlashCards(logs: logs, count: count, runtime: runtime);
  }

  Future<_AiRuntime?> _loadRuntime() async {
    final config = await _storage.loadAiConfig();
    if (!config.isEnabled || config.provider != 'deepseek') return null;
    final apiKey = await _credentials.loadDeepSeekApiKey();
    if (apiKey == null || apiKey.isEmpty) return null;
    return _AiRuntime(config: config, apiKey: apiKey);
  }

  Future<AiGeneratedLog> _deepSeekGenerateStudyLog(
    String input,
    _AiRuntime runtime,
  ) async {
    if (input.trim().isEmpty) return const AiGeneratedLog();
    final result = await _deepSeekClient.chatJson(
      config: runtime.config,
      apiKey: runtime.apiKey,
      systemPrompt: _systemPrompt(
        '你需要把大学生的自然语言学习描述整理成结构化学习日志。',
      ),
      userPrompt: '''
请根据输入生成 JSON，字段必须为：
{
  "courseName": "课程名或未归类",
  "content": "今日学习内容，完整中文句子",
  "problems": "遇到的问题",
  "thoughts": "思考与收获",
  "nextPlan": "下一步计划"
}

输入：
$input
''',
    );
    return AiGeneratedLog(
      courseName: _requiredString(result, 'courseName'),
      content: _requiredString(result, 'content'),
      problems: _asString(result['problems']),
      thoughts: _asString(result['thoughts']),
      nextPlan: _asString(result['nextPlan']),
    );
  }

  Future<AiTaskPlan> _deepSeekGenerateTaskPlan(
    String input,
    _AiRuntime runtime,
  ) async {
    if (input.trim().isEmpty) {
      return AiTaskPlan(
        mainTitle: '',
        taskType: StudyTaskType.other,
        courseName: '',
        deadline: DateTime.now().add(const Duration(days: 7)),
        subTasks: const [],
        schedule: '',
      );
    }
    final result = await _deepSeekClient.chatJson(
      config: runtime.config,
      apiKey: runtime.apiKey,
      systemPrompt: _systemPrompt(
        '你需要把复杂学习任务拆成可执行计划。',
      ),
      userPrompt: '''
今天日期和时间：${DateTime.now().toIso8601String()}
请根据输入生成 JSON，字段必须为：
{
  "mainTitle": "主任务标题",
  "taskType": "classHomework | paperReading | programmingHomework | labReport | projectDev | examReview | readingNotes | other",
  "courseName": "课程名或未归类",
  "deadline": "yyyy-MM-ddTHH:mm:ss（ISO 8601 本地时间）",
  "difficulty": "较轻松 | 中等 | 困难",
  "subTasks": ["子任务1", "子任务2"],
  "plannedSubTasks": [
    {
      "title": "子任务标题",
      "startAt": "yyyy-MM-ddTHH:mm:ss（开始时间，可选）",
      "deadline": "yyyy-MM-ddTHH:mm:ss（截止时间）",
      "note": "备注"
    }
  ],
  "schedule": "按天安排，中文多行文本"
}
要求：plannedSubTasks 中每个子任务的 deadline 必须早于或等于主任务 deadline。
      ''',
    );
    final rawPlanned = result['plannedSubTasks'];
    final List<AiPlannedSubTask> planned = [];
    if (rawPlanned is List) {
      for (final item in rawPlanned) {
        if (item is Map<String, dynamic>) {
          planned.add(AiPlannedSubTask.fromJson(item));
        }
      }
    }
    return AiTaskPlan.fromJson({
      ...result,
      'plannedSubTasks': rawPlanned ?? planned,
    });
  }

  Future<AiStudyAnalysis> _deepSeekGenerateWeeklyAnalysis({
    required List<StudyLogItem> logs,
    required List<StudyTaskItem> tasks,
    required DateTime startDate,
    required DateTime endDate,
    required _AiRuntime runtime,
  }) async {
    final result = await _deepSeekClient.chatJson(
      config: runtime.config,
      apiKey: runtime.apiKey,
      systemPrompt: _systemPrompt(
        '你需要根据学习日志和任务数据生成分析型学习周报。',
      ),
      userPrompt: '''
分析周期：${_fmtDate(startDate)} 至 ${_fmtDate(endDate)}
学习日志 JSON：
${_logsJson(logs)}

任务 JSON：
${_tasksJson(tasks)}

请生成 JSON，字段必须为：
{
  "mainTopics": "本周主要学习主题",
  "courseDistribution": "各课程投入情况，允许多行",
  "frequentProblems": "高频问题分析，允许多行",
  "completedTasks": "任务完成情况，允许多行",
  "riskTasks": "延期风险，允许多行",
  "statusEvaluation": "学习状态评价",
  "nextWeekPriority": "下周优先级建议，允许多行"
}
''',
      maxTokens: 2200,
    );
    return AiStudyAnalysis(
      mainTopics: _asString(result['mainTopics']),
      courseDistribution: _asString(result['courseDistribution']),
      frequentProblems: _asString(result['frequentProblems']),
      completedTasks: _asString(result['completedTasks']),
      riskTasks: _asString(result['riskTasks']),
      statusEvaluation: _asString(result['statusEvaluation']),
      nextWeekPriority: _asString(result['nextWeekPriority']),
    );
  }

  Future<List<AiRiskWarning>> _deepSeekGenerateRiskWarnings({
    required List<StudyLogItem> logs,
    required List<StudyTaskItem> tasks,
    required _AiRuntime runtime,
  }) async {
    final result = await _deepSeekClient.chatJson(
      config: runtime.config,
      apiKey: runtime.apiKey,
      systemPrompt: _systemPrompt(
        '你需要识别大学生学习计划中的风险，只输出明确可执行的提醒。',
      ),
      userPrompt: '''
今天日期：${_fmtDate(DateTime.now())}
学习日志 JSON：
${_logsJson(logs)}

任务 JSON：
${_tasksJson(tasks)}

请生成 JSON，字段必须为：
{
  "warnings": [
    {
      "title": "风险标题",
      "description": "风险说明和建议",
      "level": "low | medium | high",
      "category": "deadline | gap | completionRate | logFrequency | repeatedProblem"
    }
  ]
}
没有风险时返回 {"warnings": []}。
''',
      maxTokens: 1800,
    );
    final rawWarnings = result['warnings'];
    if (rawWarnings is! List) {
      throw const AiServiceException('AI 返回格式异常');
    }
    return rawWarnings.map((item) {
      if (item is! Map) throw const AiServiceException('AI 返回格式异常');
      final map = item.cast<String, dynamic>();
      return AiRiskWarning(
        title: _requiredString(map, 'title'),
        description: _requiredString(map, 'description'),
        level: _riskLevelFromName(_asString(map['level'], fallback: 'medium')),
        category: _asString(map['category'], fallback: 'deadline'),
      );
    }).toList();
  }

  Future<List<AiFlashCard>> _deepSeekGenerateFlashCards({
    required List<StudyLogItem> logs,
    required int count,
    required _AiRuntime runtime,
  }) async {
    if (logs.isEmpty) return [];
    final result = await _deepSeekClient.chatJson(
      config: runtime.config,
      apiKey: runtime.apiKey,
      systemPrompt: _systemPrompt(
        '你需要根据学习日志生成问答闪卡，帮助巩固知识点。',
      ),
      userPrompt: '''
近期学习日志 JSON：
${_logsJson(logs)}

请生成 JSON，字段必须为：
{
  "cards": [
    {
      "question": "问题",
      "answer": "答案（简洁清晰）",
      "courseName": "所属课程",
      "hint": "提示（可选）"
    }
  ]
}
生成 $count 张闪卡，涵盖日志中不同课程的知识点。
问题基于日志内容，答案简明扼要。
''',
      maxTokens: 2000,
    );
    final rawCards = result['cards'];
    if (rawCards is! List) return [];
    return rawCards.map((item) {
      if (item is! Map) return null;
      final map = item.cast<String, dynamic>();
      return AiFlashCard(
        question: _asString(map['question'], fallback: ''),
        answer: _asString(map['answer'], fallback: ''),
        courseName: _asString(map['courseName'], fallback: ''),
        hint: _asString(map['hint']),
      );
    }).whereType<AiFlashCard>().where((c) => c.question.isNotEmpty).toList();
  }

  String _systemPrompt(String task) {
    return '''
你是 StudyTrace 的 AI 学习助手。$task
只返回合法 JSON，不要返回 Markdown、注释或额外解释。
字段内容使用简洁中文，适合大学生日常学习记录。
''';
  }

  Future<AiGeneratedLog> _mockGenerateStudyLog(String input) async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (input.trim().isEmpty) return const AiGeneratedLog();

    final courseName = _extractCourse(input);

    final content = '学习了 $input。'
        '通过本次学习，对相关内容有了初步的理解和掌握。';

    final problems = _mockProblems(input);

    final thoughts = '通过今天的学习，认识到理论知识需要结合具体场景来理解。'
        '对${courseName.isNotEmpty ? courseName : '该领域'}的核心概念有了更深入的认识。';

    final nextPlan = '明天继续深入学习${courseName.isNotEmpty ? courseName : '相关知识'}，'
        '重点关注${_extractNextFocus(input)}。';

    return AiGeneratedLog(
      courseName: courseName,
      content: content,
      problems: problems,
      thoughts: thoughts,
      nextPlan: nextPlan,
    );
  }

  Future<AiTaskPlan> _mockGenerateTaskPlan(String input) async {
    await Future.delayed(const Duration(milliseconds: 1000));

    if (input.trim().isEmpty) {
      return AiTaskPlan(
        mainTitle: '',
        taskType: StudyTaskType.other,
        courseName: '',
        deadline: DateTime.now().add(const Duration(days: 7)),
        subTasks: [],
        schedule: '',
      );
    }

    final courseName = _extractCourse(input);
    final taskType = _extractTaskType(input);
    final deadline = _extractDeadline(input);
    final now = DateTime.now();
    final daysUntilDeadline = deadline.difference(now).inDays.clamp(1, 30);
    final subTasks = _mockSubTasks(taskType, daysUntilDeadline);
    final schedule = _mockSchedule(daysUntilDeadline, subTasks);
    final difficulty = daysUntilDeadline <= 3
        ? '困难'
        : daysUntilDeadline <= 7
            ? '中等'
            : '较轻松';

    // Generate timed sub-tasks
    final totalSubs = subTasks.length;
    final plannedSubTasks = <AiPlannedSubTask>[];
    for (var i = 0; i < totalSubs; i++) {
      final offsetDays = (daysUntilDeadline * i / totalSubs).round();
      final subDeadline = now.add(Duration(days: offsetDays + 1));
      plannedSubTasks.add(AiPlannedSubTask(
        title: subTasks[i],
        deadline: DateTime(subDeadline.year, subDeadline.month,
            subDeadline.day, 22, 0),
        note: '第 ${offsetDays + 1} 天完成',
      ));
    }

    return AiTaskPlan(
      mainTitle: input,
      taskType: taskType,
      courseName: courseName,
      deadline: deadline,
      difficulty: difficulty,
      subTasks: subTasks,
      plannedSubTasks: plannedSubTasks,
      schedule: schedule,
    );
  }

  Future<AiStudyAnalysis> _mockGenerateWeeklyAnalysis({
    required List<StudyLogItem> logs,
    required List<StudyTaskItem> tasks,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1200));

    final periodLogs = logs
        .where((l) => !l.date.isBefore(startDate) && !l.date.isAfter(endDate))
        .toList();
    final periodTasks = tasks
        .where((t) =>
            !t.deadline.isBefore(startDate) && !t.deadline.isAfter(endDate))
        .toList();

    final courseCount = <String, int>{};
    for (final log in periodLogs) {
      final course = log.courseName.isEmpty ? '未归类' : log.courseName;
      courseCount[course] = (courseCount[course] ?? 0) + 1;
    }
    final sortedCourses = courseCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalLogs = periodLogs.length;

    final completed =
        periodTasks.where((t) => t.status == StudyTaskStatus.completed).length;
    final total = periodTasks.length;
    final rate = total > 0 ? (completed / total * 100).toInt() : 0;

    final riskTasks = periodTasks
        .where((t) =>
            t.status != StudyTaskStatus.completed &&
            t.deadline.isBefore(DateTime.now().add(const Duration(days: 3))))
        .toList();

    return AiStudyAnalysis(
      mainTopics: _mockMainTopics(sortedCourses, totalLogs),
      courseDistribution: _mockCourseDistribution(sortedCourses),
      frequentProblems: _mockFrequentProblems(periodLogs),
      completedTasks: _mockCompletedTasks(total, completed, rate, periodTasks),
      riskTasks: _mockRiskTasksText(riskTasks),
      statusEvaluation:
          _mockStatusEvaluation(rate, totalLogs, riskTasks.length),
      nextWeekPriority: _mockNextWeekPriority(riskTasks, sortedCourses),
    );
  }

  Future<List<AiRiskWarning>> _mockGenerateRiskWarnings({
    required List<StudyLogItem> logs,
    required List<StudyTaskItem> tasks,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));

    final warnings = <AiRiskWarning>[];
    final now = DateTime.now();

    // 1. 临近截止但未开始
    for (final task
        in tasks.where((t) => t.status == StudyTaskStatus.notStarted)) {
      final daysLeft = task.deadline.difference(now).inDays;
      if (daysLeft >= 0 && daysLeft <= 2) {
        warnings.add(AiRiskWarning(
          title: '任务即将截止：「${task.title}」',
          description: '还有 $daysLeft 天截止，当前仍为"未开始"。'
              '建议今天至少完成初步准备。',
          level: daysLeft <= 1 ? RiskLevel.high : RiskLevel.medium,
          category: 'deadline',
        ));
      }
    }

    // 2. 临近截止但进度较低
    for (final task
        in tasks.where((t) => t.status == StudyTaskStatus.inProgress)) {
      final daysLeft = task.deadline.difference(now).inDays;
      if (daysLeft >= 0 && daysLeft <= 1) {
        warnings.add(AiRiskWarning(
          title: '进度偏低：「${task.title}」',
          description: '还剩 $daysLeft 天，仍在进行中，建议集中时间尽快完成。',
          level: RiskLevel.high,
          category: 'deadline',
        ));
      }
    }

    // 3. 某门课程多日无记录
    final courseLastDate = <String, DateTime>{};
    for (final log in logs) {
      if (log.courseName.isNotEmpty) {
        final existing = courseLastDate[log.courseName];
        if (existing == null || log.date.isAfter(existing)) {
          courseLastDate[log.courseName] = log.date;
        }
      }
    }
    for (final entry in courseLastDate.entries) {
      final daysSince = now.difference(entry.value).inDays;
      if (daysSince >= 5) {
        warnings.add(AiRiskWarning(
          title: '学习断档：「${entry.key}」',
          description: '已 $daysSince 天没有学习「${entry.key}」。'
              '如有相关任务，建议安排一次复习。',
          level: daysSince >= 7 ? RiskLevel.high : RiskLevel.medium,
          category: 'gap',
        ));
      }
    }

    // 4. 本周完成率偏低
    final weekAgo = now.subtract(const Duration(days: 7));
    final weekTasks =
        tasks.where((t) => !t.deadline.isBefore(weekAgo)).toList();
    if (weekTasks.length >= 3) {
      final weekDone =
          weekTasks.where((t) => t.status == StudyTaskStatus.completed).length;
      final weekRate = weekDone / weekTasks.length;
      if (weekRate < 0.3) {
        warnings.add(AiRiskWarning(
          title: '本周任务完成率偏低',
          description:
              '本周 $weekDone/${weekTasks.length} 已完成（${(weekRate * 100).toInt()}%），'
              '建议重新评估任务量。',
          level: RiskLevel.medium,
          category: 'completionRate',
        ));
      }
    }

    // 5. 学习记录过少
    final weekLogCount = logs.where((l) => !l.date.isBefore(weekAgo)).length;
    if (weekLogCount == 0) {
      warnings.add(AiRiskWarning(
        title: '本周无学习记录',
        description: '过去 7 天没有学习记录，即使少量学习也值得记录。',
        level: RiskLevel.medium,
        category: 'logFrequency',
      ));
    }

    return warnings;
  }

  Future<List<AiFlashCard>> _mockGenerateFlashCards({
    required List<StudyLogItem> logs,
    required int count,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (logs.isEmpty) return [];

    final cards = <AiFlashCard>[];
    final courseCards = <String, List<String>>{};

    for (final log in logs) {
      final course = log.courseName.isEmpty ? '未归类' : log.courseName;
      courseCards.putIfAbsent(course, () => []).add(log.content);
    }

    for (final entry in courseCards.entries) {
      if (cards.length >= count) break;
      final contents = entry.value;
      for (var i = 0; i < contents.length && cards.length < count; i++) {
        final content = contents[i];
        if (content.length < 6) continue;
        cards.add(AiFlashCard(
          question: '关于「${entry.key}」，今天学习了什么内容？',
          answer: content.length > 60
              ? '${content.substring(0, 60)}...'
              : content,
          courseName: entry.key,
          hint: '回顾 ${entry.key} 的核心知识点',
        ));
        if (cards.length < count) {
          cards.add(AiFlashCard(
            question: '学习「${entry.key}」时遇到了哪些问题？',
            answer: '回顾学习过程中遇到的关键难点和思考。',
            courseName: entry.key,
            hint: '关注不理解的概念',
          ));
        }
      }
    }

    if (cards.isEmpty) {
      cards.add(const AiFlashCard(
        question: '今天学习了什么？',
        answer: '记录一些学习内容，AI 会自动生成闪卡帮助你复习。',
        courseName: '提示',
        hint: '先去记录学习日志吧',
      ));
    }

    return cards.take(count).toList(growable: false);
  }

  // ========== Private helpers ==========

  String _extractCourse(String input) {
    for (final kw in _courseKeywords) {
      if (input.contains(kw)) return kw;
    }
    return '未归类';
  }

  String _mockProblems(String input) {
    if (input.contains('不理解') || input.contains('不太理解')) {
      return '对相关概念的理解还不够深入，停留在理论层面，需要结合实际应用场景进一步学习。';
    }
    if (input.contains('难') || input.contains('困难')) {
      return '学习过程中遇到一些难点，需要结合更多实例和练习来加深理解。';
    }
    return '学习中遇到一些需要进一步消化的概念，目前理解还处于表面层次。';
  }

  String _extractNextFocus(String input) {
    if (input.contains('索引') || input.contains('B+树')) return '查询优化和索引原理';
    if (input.contains('算法') || input.contains('排序')) return '算法复杂度分析';
    if (input.contains('编程') || input.contains('代码')) return '代码实践和调试技巧';
    if (input.contains('实验')) return '实验报告的完整性和结果分析';
    return '核心概念的深入理解和应用';
  }

  StudyTaskType _extractTaskType(String input) {
    if (input.contains('实验报告') || input.contains('lab')) {
      return StudyTaskType.labReport;
    }
    if (input.contains('PPT') || input.contains('项目') || input.contains('开发')) {
      return StudyTaskType.projectDev;
    }
    if (input.contains('编程') || input.contains('代码') || input.contains('程序')) {
      return StudyTaskType.programmingHomework;
    }
    if (input.contains('论文') || input.contains('阅读') || input.contains('文献')) {
      return StudyTaskType.paperReading;
    }
    if (input.contains('复习') || input.contains('考试') || input.contains('期末')) {
      return StudyTaskType.examReview;
    }
    if (input.contains('笔记') || input.contains('读书')) {
      return StudyTaskType.readingNotes;
    }
    if (input.contains('视频') || input.contains('作业')) {
      return StudyTaskType.classHomework;
    }
    return StudyTaskType.other;
  }

  DateTime _extractDeadline(String input) {
    final now = DateTime.now();
    if (input.contains('今天')) return now;
    if (input.contains('明天')) return now.add(const Duration(days: 1));
    if (input.contains('后天')) return now.add(const Duration(days: 2));
    if (input.contains('下周五')) {
      final daysUntilFriday = (DateTime.friday - now.weekday + 7) % 7;
      return now
          .add(Duration(days: daysUntilFriday == 0 ? 7 : daysUntilFriday));
    }
    if (input.contains('月底') || input.contains('月末')) {
      return DateTime(now.year, now.month + 1, 0);
    }
    return now.add(const Duration(days: 7));
  }

  List<String> _mockSubTasks(StudyTaskType type, int days) {
    final base = <String>[
      '阅读任务要求和评分标准',
      '整理所需参考资料',
    ];

    switch (type) {
      case StudyTaskType.labReport:
        base.addAll([
          '搭建实验环境并完成配置',
          '运行实验并记录数据',
          '截图保存关键过程',
          '撰写实验报告正文',
          '总结问题与解决方法',
          '检查格式并提交',
        ]);
      case StudyTaskType.projectDev:
        base.addAll([
          '确定技术方案',
          '搭建项目框架',
          '实现核心功能',
          '编写测试用例',
          '调试修复 Bug',
          '撰写项目文档',
          '准备答辩材料',
        ]);
      case StudyTaskType.programmingHomework:
        base.addAll([
          '理解题目要求',
          '设计算法方案',
          '编写代码实现',
          '本地测试验证',
          '优化代码性能',
          '提交并确认',
        ]);
      case StudyTaskType.paperReading:
        base.addAll([
          '浏览全文了解结构',
          '精读引言和背景',
          '精读方法与实验',
          '整理论文核心观点',
          '撰写阅读笔记',
        ]);
      case StudyTaskType.classHomework:
        base.addAll([
          '明确作业要求',
          '整理相关资料',
          '完成作业内容',
          '检查并修改',
          '按时提交',
        ]);
      case StudyTaskType.examReview:
        base.addAll([
          '整理课程知识框架',
          '复习重点章节',
          '做历年真题',
          '总结常见考点',
          '模拟考试练习',
          '查漏补缺',
        ]);
      case StudyTaskType.readingNotes:
        base.addAll([
          '浏览全书/全文了解结构',
          '精读重点章节',
          '提炼核心观点',
          '摘抄关键段落',
          '撰写个人感悟',
        ]);
      case StudyTaskType.other:
        base.addAll([
          '明确交付标准',
          '制定执行计划',
          '按计划执行',
          '定期检查进度',
          '复核交付物',
        ]);
    }
    return base;
  }

  String _mockSchedule(int days, List<String> subTasks) {
    final buffer = StringBuffer();
    final chunkSize = (subTasks.length / days).ceil().clamp(1, subTasks.length);
    for (var d = 0; d < days && d * chunkSize < subTasks.length; d++) {
      final start = d * chunkSize;
      final end = (start + chunkSize).clamp(0, subTasks.length);
      buffer
          .writeln('- 第 ${d + 1} 天：${subTasks.sublist(start, end).join('、')}');
    }
    return buffer.toString();
  }

  String _mockMainTopics(List<MapEntry<String, int>> sorted, int total) {
    if (sorted.isEmpty) return '本周暂无学习记录。';
    final names = sorted.map((e) => e.key).join('、');
    final top = sorted.first;
    return '本周学习内容主要集中在 $names 方向，'
        '其中「${top.key}」相关记录最多（${top.value} 条），'
        '显示本周学习重心偏向该方向。';
  }

  String _mockCourseDistribution(List<MapEntry<String, int>> sorted) {
    if (sorted.isEmpty) return '暂无数据。';
    return sorted.map((e) => '- ${e.key}：${e.value} 条记录').join('\n');
  }

  String _mockFrequentProblems(List<StudyLogItem> logs) {
    final problems = logs
        .where((l) => l.problems.isNotEmpty)
        .map((l) => l.problems)
        .toList();
    if (problems.isEmpty) return '本周记录中未发现高频问题。';
    return problems.take(3).map((p) => '- $p').join('\n');
  }

  String _mockCompletedTasks(
      int total, int completed, int rate, List<StudyTaskItem> tasks) {
    if (total == 0) return '本周暂无学习任务。';
    final eval = rate >= 80
        ? '整体推进顺利。'
        : rate >= 50
            ? '部分任务有进展，仍有提升空间。'
            : '完成度偏低，建议重新评估任务量。';
    final sb = StringBuffer('本周完成 $completed/$total 项任务（完成率 $rate%）。$eval');
    for (final t in tasks) {
      final mark = t.status == StudyTaskStatus.completed ? '✓' : ' ';
      sb.writeln('\n- [$mark] ${t.title}（${t.type.label}）');
    }
    return sb.toString();
  }

  String _mockRiskTasksText(List<StudyTaskItem> riskTasks) {
    if (riskTasks.isEmpty) return '本周暂无临近截止的未完成任务。';
    return riskTasks
        .map((t) =>
            '- 「${t.title}」距截止还有 ${t.deadline.difference(DateTime.now()).inDays} 天，当前状态「${t.status.label}」。')
        .join('\n');
  }

  String _mockStatusEvaluation(int rate, int totalLogs, int riskCount) {
    final parts = <String>[
      if (totalLogs >= 5)
        '本周保持了较好的学习节奏。'
      else if (totalLogs >= 3)
        '有基本的学习记录，建议每天坚持。'
      else
        '学习记录偏少，建议养成每日记录习惯。',
      if (rate >= 80)
        '任务完成情况良好，执行力较强。'
      else if (rate >= 50)
        '任务完成情况一般，需抓紧推进。'
      else
        '任务完成率偏低，建议优先处理未完成任务。',
      if (riskCount > 0) '有 $riskCount 项任务存在延期风险。',
    ];
    if (Random().nextBool()) {
      parts.add('从记录来看，你开始从完成任务转向理解知识背后的原理，这是积极的变化。');
    }
    return parts.join('');
  }

  String _mockNextWeekPriority(
    List<StudyTaskItem> riskTasks,
    List<MapEntry<String, int>> sortedCourses,
  ) {
    final parts = <String>[];
    if (riskTasks.isNotEmpty) {
      parts.add('优先处理存在延期风险的任务：');
      parts.addAll(riskTasks.map((t) => '- 「${t.title}」'));
    }
    if (sortedCourses.isNotEmpty) {
      parts.add('建议对「${sortedCourses.first.key}」进行复盘巩固。');
    }
    parts.add('将大任务拆解到每天执行，避免集中赶工。');
    return parts.join('\n');
  }

  String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    throw const AiServiceException('AI 返回格式异常');
  }

  String _asString(Object? value, {String fallback = ''}) {
    if (value == null) return fallback;
    if (value is String) return value.trim();
    return value.toString().trim();
  }

  RiskLevel _riskLevelFromName(String value) {
    switch (value.trim()) {
      case 'low':
        return RiskLevel.low;
      case 'medium':
        return RiskLevel.medium;
      case 'high':
        return RiskLevel.high;
      default:
        throw const AiServiceException('AI 返回格式异常');
    }
  }

  String _fmtDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _logsJson(List<StudyLogItem> logs) {
    return jsonEncode(logs.map((log) {
      return {
        'date': _fmtDate(log.date),
        'courseName': log.courseName,
        'content': log.content,
        'problems': log.problems,
        'thoughts': log.thoughts,
        'nextPlan': log.nextPlan,
      };
    }).toList());
  }

  String _tasksJson(List<StudyTaskItem> tasks) {
    return jsonEncode(tasks.map((task) {
      return {
        'title': task.title,
        'type': task.type.name,
        'typeLabel': task.type.label,
        'courseName': task.courseName,
        'deadline': _fmtDate(task.deadline),
        'status': task.status.name,
        'statusLabel': task.status.label,
        'note': task.note,
      };
    }).toList());
  }
}

class _AiRuntime {
  const _AiRuntime({
    required this.config,
    required this.apiKey,
  });

  final AiConfig config;
  final String apiKey;
}
