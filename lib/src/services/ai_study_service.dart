import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_app_action.dart';
import '../models/ai_config.dart';
import '../models/ai_flash_card.dart';
import '../models/ai_generated_log.dart';
import '../models/ai_learning_loop.dart';
import '../models/ai_risk_warning.dart';
import '../models/ai_study_analysis.dart';
import '../models/ai_task_plan.dart';
import '../models/study_log_item.dart';
import '../models/study_task_item.dart';
import 'ai_credential_service.dart';
import 'ai_exceptions.dart';
import 'api_client.dart';
import 'local_storage_service.dart';

/// Study assistant service.
///
/// Production AI calls are proxied through the backend. The Flutter app does
/// not keep model provider keys or call provider APIs directly.
class AiStudyService {
  AiStudyService({
    LocalStorageService? storage,
    AiCredentialService? credentials,
    ApiClient? backendClient,
    AiConfig? config,
  })  : _storage = storage ?? LocalStorageService(),
        _credentials = credentials ?? AiCredentialService(),
        _backendClient = backendClient,
        _config = config ?? const AiConfig();

  final LocalStorageService _storage;
  final AiCredentialService _credentials;
  final ApiClient? _backendClient;
  final AiConfig _config;
  static const Duration _generationTimeout = Duration(seconds: 45);
  static const Duration _todayMissionTimeout = Duration(seconds: 75);

  Future<AiGeneratedLog> generateStudyLog(String input) =>
      _trackUsage(_doGenerateStudyLog(input));

  Future<AiTaskPlan> generateTaskPlan(String input) async {
    return _trackUsage(() async {
      final data = await _postBackend(
        '/ai/task-plan',
        _withThinking({'input': input}),
        timeout: _generationTimeout,
      );
      return AiTaskPlan.fromJson(data);
    }());
  }

  Future<List<DailyPlan>> generateWeeklyPlan({
    required List<StudyTaskItem> existingTasks,
    required List<StudyLogItem> recentLogs,
    required List<String> courses,
    int days = 7,
  }) async {
    final pendingTasks = existingTasks
        .where((task) => task.effectiveStatus != StudyTaskStatus.completed)
        .take(12)
        .map((task) => {
              'title': task.title,
              'courseName': task.courseName,
              'deadline': task.deadline.toIso8601String(),
              'status': task.status.name,
              'note': task.note,
            })
        .toList();
    final logsSummary = recentLogs
        .take(10)
        .map((log) => {
              'date': log.date.toIso8601String(),
              'courseName': log.courseName,
              'content': log.content,
              'nextPlan': log.nextPlan,
            })
        .toList();
    return _trackUsage(() async {
      final data = await _postBackend(
        '/ai/weekly-plan',
        _withThinking({
          'tasks': pendingTasks,
          'logs': logsSummary,
          'courses': courses,
          'days': days,
        }),
        timeout: _generationTimeout,
      );
      return _parseDailyPlans(data['plans']);
    }());
  }

  Future<AiLearningLoopPlan> generateLearningLoop({
    required String sourceText,
    String? imageBase64,
    String sourceKind = 'manual',
    String target = 'all',
    List<String> context = const [],
    Duration? timeout,
  }) async {
    return _trackUsage(() async {
      final data = await _postBackend(
        '/ai/learning-loop',
        _withThinking({
          'sourceText': sourceText,
          if (imageBase64 != null && imageBase64.isNotEmpty)
            'imageBase64': imageBase64,
          'sourceKind': sourceKind,
          'target': target,
          if (context.isNotEmpty) 'context': context,
        }),
        timeout: timeout ?? _generationTimeout,
      );
      return AiLearningLoopPlan.fromJson(data);
    }());
  }

  Future<AiLearningLoopPlan> generateTodayMission({
    required List<String> context,
  }) {
    return generateLearningLoop(
      sourceText: '请基于当前待办任务和近期学习日志，生成今天的学习安排。',
      sourceKind: 'manual',
      target: 'task',
      context: context,
      timeout: _todayMissionTimeout,
    );
  }

  Future<AiStudyAnalysis> generateWeeklyAnalysis({
    required List<StudyLogItem> logs,
    required List<StudyTaskItem> tasks,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return _trackUsage(() async {
      final data = await _postBackend('/ai/weekly-analysis', _withThinking({
        'logs': logs.map((log) => log.toJson()).toList(),
        'tasks': tasks.map((task) => task.toJson()).toList(),
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
      }));
      return AiStudyAnalysis.fromJson(data);
    }());
  }

  Future<List<AiRiskWarning>> generateRiskWarnings({
    required List<StudyLogItem> logs,
    required List<StudyTaskItem> tasks,
  }) async {
    return _trackUsage(() async {
      final data = await _postBackend('/ai/risk-warnings', _withThinking({
        'logs': logs.map((log) => log.toJson()).toList(),
        'tasks': tasks.map((task) => task.toJson()).toList(),
      }));
      final warnings = data['warnings'];
      if (warnings is! List) return <AiRiskWarning>[];
      return warnings
          .whereType<Map<String, dynamic>>()
          .map(AiRiskWarning.fromJson)
          .toList();
    }());
  }

  Future<List<AiFlashCard>> generateFlashCards({
    required List<StudyLogItem> logs,
    int count = 5,
  }) async {
    if (logs.isEmpty) return [];
    return _trackUsage(() async {
      final data = await _postBackend('/ai/flash-cards', _withThinking({
        'logs': logs.map((log) => log.toJson()).toList(),
        'count': count,
      }));
      final cards = data['cards'];
      if (cards is! List) return <AiFlashCard>[];
      return cards
          .whereType<Map<String, dynamic>>()
          .map(AiFlashCard.fromJson)
          .where((card) => card.question.trim().isNotEmpty)
          .toList();
    }());
  }

  Future<String> rewriteOrExpand({
    required String text,
    required String intent,
  }) async {
    final source = text.trim();
    if (source.isEmpty) return '';
    return _trackUsage(() async {
      final data = await _postBackend('/ai/rewrite', _withThinking({
        'text': source,
        'intent': intent,
      }));
      return (data['text'] as String?)?.trim() ?? '';
    }());
  }

  Future<FlashCardGrade> gradeFlashcard({
    required String question,
    required String correctAnswer,
    required String userAnswer,
    String courseName = '',
  }) async {
    return _trackUsage(() async {
      final data = await _postBackend('/ai/grade-flashcard', _withThinking({
        'question': question,
        'correctAnswer': correctAnswer,
        'userAnswer': userAnswer,
        if (courseName.isNotEmpty) 'courseName': courseName,
      }));
      final score = (data['score'] as num?)?.toInt() ?? 3;
      final feedback = (data['feedback'] as String?)?.trim() ?? '';
      return FlashCardGrade(
        score: score.clamp(1, 5),
        feedback: feedback.isEmpty ? '暂时没有给出反馈' : feedback,
      );
    }());
  }

  Future<AiAssistantTurn> generateAssistantTurn({
    required String input,
    List<String> appContext = const [],
    List<Map<String, dynamic>> messages = const [],
    String? imageBase64,
    bool? thinkingEnabled,
  }) {
    return _trackUsage(_doGenerateAssistantTurn(
      input: input,
      appContext: appContext,
      messages: messages,
      imageBase64: imageBase64,
      thinkingEnabled: thinkingEnabled,
    ));
  }

  Future<String> generateAssistantReply({
    required String input,
    List<String> context = const [],
    List<Map<String, dynamic>> messages = const [],
    String? imageBase64,
    String purpose = 'chat',
    bool? thinkingEnabled,
  }) async {
    return _trackUsage(() async {
      final data = await _postBackend('/ai/chat', {
        'input': input,
        if (context.isNotEmpty) 'context': context,
        if (messages.isNotEmpty) 'messages': messages,
        if (imageBase64 != null && imageBase64.isNotEmpty)
          'imageBase64': imageBase64,
        'purpose': purpose,
        'thinkingEnabled': _resolveThinkingEnabled(thinkingEnabled),
        'options': await _aiOptions(),
      });
      final content = data['content'];
      if (content is String && content.trim().isNotEmpty) return content.trim();
      throw const AiServiceException('AI学习助手返回格式异常');
    }());
  }

  Stream<String> generateAssistantReplyStream({
    required String input,
    List<String> context = const [],
    List<Map<String, dynamic>> messages = const [],
    String? imageBase64,
    String purpose = 'chat',
    bool? thinkingEnabled,
  }) async* {
    final backend = _requireBackend();
    final body = {
      'input': input,
      if (context.isNotEmpty) 'context': context,
      if (messages.isNotEmpty) 'messages': messages,
      if (imageBase64 != null && imageBase64.isNotEmpty)
        'imageBase64': imageBase64,
      'purpose': purpose,
      'thinkingEnabled': _resolveThinkingEnabled(thinkingEnabled),
      'options': await _aiOptions(minMaxTokens: 2000),
    };
    final request = http.Request(
      'POST',
      Uri.parse('${backend.baseUrl}/ai/chat/stream'),
    )
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'text/event-stream'
      ..headers['Cache-Control'] = 'no-cache'
      ..body = jsonEncode(body);
    final token = await _credentials.getAuthToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    try {
      final response = await http.Client().send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final errorBody = await response.stream.bytesToString();
        throw AiServiceException('AI学习助手请求失败', detail: errorBody);
      }
      final stream =
          response.stream.transform(utf8.decoder).transform(const LineSplitter());
      var event = 'message';
      await for (final line in stream) {
        if (line.startsWith('event:')) {
          event = line.substring(6).trim();
          continue;
        }
        if (!line.startsWith('data:')) continue;
        final data = line.substring(5).trim();
        if (data.isEmpty || data == '[DONE]') continue;
        final decoded = jsonDecode(data);
        if (event == 'error') {
          final message = decoded is Map
              ? (decoded['message']?.toString().trim() ?? '')
              : '';
          throw AiServiceException(
            message.isEmpty ? 'AI学习助手流式回复失败' : message,
            detail: data,
          );
        }
        if (decoded is Map && decoded['delta'] is String) {
          final delta = decoded['delta'] as String;
          if (delta.isNotEmpty) yield delta;
        } else if (decoded is Map && decoded['message'] is String) {
          throw AiServiceException(
            (decoded['message'] as String).trim(),
            detail: data,
          );
        }
        event = 'message';
      }
    } on AiServiceException {
      rethrow;
    } catch (error) {
      throw AiServiceException('AI学习助手暂时不可用，请稍后重试', detail: '$error');
    }
  }

  Future<int> todayUsageCount() => _storage.getTodayAiUsageCount();

  Future<AiUsageToday> todayUsage() async {
    final backend = _requireBackend();
    try {
      final data = await backend.getJson('/ai/usage/today');
      return AiUsageToday.fromJson(data);
    } on ApiException catch (error) {
      throw AiServiceException(error.displayMessage, detail: error.detail);
    }
  }

  Future<AiGeneratedLog> _doGenerateStudyLog(String input) async {
    final data = await _postBackend(
      '/ai/study-log',
      _withThinking({'input': input}),
    );
    return AiGeneratedLog.fromJson(data);
  }

  Future<AiAssistantTurn> _doGenerateAssistantTurn({
    required String input,
    List<String> appContext = const [],
    List<Map<String, dynamic>> messages = const [],
    String? imageBase64,
    bool? thinkingEnabled,
  }) async {
    final data = await _postBackend('/ai/chat', {
      'input': input,
      if (appContext.isNotEmpty) 'context': appContext,
      if (messages.isNotEmpty) 'messages': messages,
      if (imageBase64 != null && imageBase64.isNotEmpty)
        'imageBase64': imageBase64,
      'purpose': 'assistant_turn',
      'thinkingEnabled': _resolveThinkingEnabled(thinkingEnabled),
      'options': await _aiOptions(minMaxTokens: 2200),
    });
    final content = data['content'];
    if (content is String && content.trim().isNotEmpty) {
      try {
        final parsed = jsonDecode(_extractJsonObject(content.trim()));
        if (parsed is Map<String, dynamic>) {
          return AiAssistantTurn.fromJson(parsed);
        }
        if (parsed is Map) {
          return AiAssistantTurn.fromJson(parsed.cast<String, dynamic>());
        }
      } catch (_) {
        return AiAssistantTurn(reply: content.trim());
      }
    }
    throw const AiServiceException('AI学习助手返回格式异常');
  }

  String _extractJsonObject(String content) {
    final trimmed = content.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) return trimmed;
    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return trimmed.substring(start, end + 1);
    }
    return trimmed;
  }

  Future<Map<String, dynamic>> _postBackend(
    String path,
    Map<String, dynamic> body, {
    Duration? timeout,
  }) async {
    final backend = _requireBackend();
    try {
      return await backend.postJson(path, body: body, timeout: timeout);
    } on ApiException catch (error) {
      if (error.isNetworkError && error.displayMessage.contains('超时')) {
        throw AiServiceException(
          'AI 生成耗时较长，请稍后重试或减少上下文',
          detail: error.detail,
        );
      }
      throw AiServiceException(error.displayMessage, detail: error.detail);
    }
  }

  ApiClient _requireBackend() {
    final backend = _backendClient;
    if (backend == null) {
      throw const AiServiceException('请先登录并连接云端AI学习助手');
    }
    return backend;
  }

  Future<Map<String, dynamic>> _aiOptions({int minMaxTokens = 1200}) async {
    final defaults = _config;
    return {
      'temperature': defaults.temperature,
      'maxTokens': defaults.maxTokens < minMaxTokens
          ? minMaxTokens
          : defaults.maxTokens,
      'topP': defaults.topP,
      'frequencyPenalty': defaults.frequencyPenalty,
      'presencePenalty': defaults.presencePenalty,
      'reasoningEffort': defaults.reasoningEffort,
    };
  }

  bool _resolveThinkingEnabled(bool? override) {
    return override ?? _config.thinkingEnabled;
  }

  Map<String, dynamic> _withThinking(Map<String, dynamic> body) {
    return {
      ...body,
      'thinkingEnabled': _config.thinkingEnabled,
    };
  }

  List<DailyPlan> _parseDailyPlans(Object? raw) {
    if (raw is! List) return [];
    final plans = <DailyPlan>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = item.cast<String, dynamic>();
      final date = DateTime.tryParse((map['date'] as String?) ?? '');
      if (date == null) continue;
      final rawTasks = map['tasks'];
      final tasks = <PlannedTaskItem>[];
      if (rawTasks is List) {
        for (final task in rawTasks) {
          if (task is! Map) continue;
          final taskMap = task.cast<String, dynamic>();
          final title = (taskMap['title'] as String?)?.trim() ?? '';
          if (title.isEmpty) continue;
          tasks.add(PlannedTaskItem(
            title: title,
            courseName: (taskMap['courseName'] as String?)?.trim() ?? '',
            note: (taskMap['note'] as String?)?.trim() ?? '',
          ));
        }
      }
      if (tasks.isNotEmpty) plans.add(DailyPlan(date: date, tasks: tasks));
    }
    return plans;
  }

  Future<T> _trackUsage<T>(Future<T> future) async {
    final value = await future;
    unawaited(_storage.incrementAiUsage().catchError((_) => 0));
    return value;
  }
}

class DailyPlan {
  const DailyPlan({required this.date, required this.tasks});
  final DateTime date;
  final List<PlannedTaskItem> tasks;
}

class PlannedTaskItem {
  const PlannedTaskItem({
    required this.title,
    this.courseName = '',
    this.note = '',
  });

  final String title;
  final String courseName;
  final String note;
}

class FlashCardGrade {
  const FlashCardGrade({required this.score, required this.feedback});

  final int score;
  final String feedback;

  String get label => switch (score) {
        1 => '完全错误',
        2 => '主要错误',
        3 => '部分正确',
        4 => '基本正确',
        5 => '完全正确',
        _ => '未知',
      };
}

class AiUsageToday {
  const AiUsageToday({
    required this.used,
    required this.limit,
    required this.remaining,
  });

  final int used;
  final int limit;
  final int remaining;

  factory AiUsageToday.fromJson(Map<String, dynamic> json) {
    return AiUsageToday(
      used: (json['used'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 0,
      remaining: (json['remaining'] as num?)?.toInt() ?? 0,
    );
  }
}
