import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'deepseek_client.dart';

/// 蓝心大模型客户端 - 支持 OpenAI 兼容的 Chat Completions 接口
class BlueHeartModelClient {
  BlueHeartModelClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const supportedModels = [
    'Volc-DeepSeek-V3.2',
    'Doubao-Seed-2.0-mini',
    'Doubao-Seed-2.0-lite',
    'Doubao-Seed-2.0-pro',
    'qwen3.5-plus',
  ];

  /// 消息条目，用于多轮对话
  static Map<String, String> msg(String role, String content) =>
      {'role': role, 'content': content};

  // ─── 同步聊天 ───

  /// 调用蓝心大模型进行文本生成
  Future<String> chatText({
    required String apiKey,
    String? systemPrompt,
    String? userPrompt,
    List<Map<String, dynamic>>? messages,
    String? imageBase64,
    String model = 'Volc-DeepSeek-V3.2',
    double temperature = 0.7,
    int maxTokens = 1200,
    double topP = 0.7,
    bool thinkingEnabled = false,
    bool includeJsonResponseFormat = false,
    double frequencyPenalty = 0,
    double presencePenalty = 0,
    String? reasoningEffort,
  }) async {
    final body = _buildPayload(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      messages: messages,
      imageBase64: imageBase64,
      model: model,
      temperature: temperature,
      maxTokens: maxTokens,
      topP: topP,
      thinkingEnabled: thinkingEnabled,
      includeJsonResponseFormat: includeJsonResponseFormat,
      frequencyPenalty: frequencyPenalty,
      presencePenalty: presencePenalty,
      reasoningEffort: reasoningEffort,
    );
    final decoded = await _post(body, apiKey: apiKey);
    return _extractContent(decoded);
  }

  /// 调用蓝心大模型进行 JSON 格式输出
  Future<Map<String, dynamic>> chatJson({
    required String apiKey,
    String? systemPrompt,
    String? userPrompt,
    String model = 'Volc-DeepSeek-V3.2',
    double temperature = 0.2,
    int maxTokens = 1800,
    double topP = 0.7,
    bool thinkingEnabled = false,
    double frequencyPenalty = 0,
    double presencePenalty = 0,
  }) async {
    final content = await chatText(
      apiKey: apiKey,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      model: model,
      temperature: temperature,
      maxTokens: maxTokens,
      topP: topP,
      thinkingEnabled: thinkingEnabled,
      frequencyPenalty: frequencyPenalty,
      presencePenalty: presencePenalty,
    );
    return _decodeJsonObject(content);
  }

  // ─── 流式聊天 ───

  /// 流式调用蓝心大模型，返回 SSE 事件流
  /// [onChunk] 每收到一个 token 调用一次
  /// [onDone] 流结束时调用，传入完整文本
  Stream<String> chatStream({
    required String apiKey,
    String? systemPrompt,
    String? userPrompt,
    List<Map<String, dynamic>>? messages,
    String? imageBase64,
    String model = 'Volc-DeepSeek-V3.2',
    double temperature = 0.7,
    int maxTokens = 1200,
    double topP = 0.7,
    bool thinkingEnabled = false,
    double frequencyPenalty = 0,
    double presencePenalty = 0,
    String? reasoningEffort,
  }) async* {
    final body = _buildPayload(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      messages: messages,
      imageBase64: imageBase64,
      model: model,
      temperature: temperature,
      maxTokens: maxTokens,
      topP: topP,
      thinkingEnabled: thinkingEnabled,
      frequencyPenalty: frequencyPenalty,
      presencePenalty: presencePenalty,
      reasoningEffort: reasoningEffort,
      stream: true,
    );

    final requestId = _generateUuid();
    final uri = Uri.parse('https://api-ai.vivo.com.cn/v1/chat/completions')
        .replace(queryParameters: {'requestId': requestId});

    final request = http.StreamedRequest('POST', uri);
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    });
    request.sink.add(utf8.encode(jsonEncode(body)));
    request.sink.close();

    final response = await _httpClient.send(request);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final bodyBytes = await response.stream.bytesToString();
      throw AiServiceException(
        _messageForStatusCode(response.statusCode),
        detail: _extractErrorDetail(bodyBytes),
      );
    }

    var lineBuffer = '';
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      lineBuffer += chunk;
      final lines = lineBuffer.split('\n');
      // 最后一行可能不完整，保留到下次
      lineBuffer = lines.removeLast();
      for (final raw in lines) {
        final trimmed = raw.trim();
        if (!trimmed.startsWith('data:')) continue;
        final data = trimmed.substring(5).trim();
        if (data == '[DONE]') return;
        try {
          final json = jsonDecode(data);
          final delta = json['choices']?[0]?['delta'];
          if (delta == null) continue;
          final content = delta['content'];
          if (content is String && content.isNotEmpty) {
            yield content;
          }
        } catch (_) {}
      }
    }
  }

  // ─── 测试连接 ───

  Future<bool> testConnection({required String apiKey}) async {
    try {
      final result = await chatJson(
        apiKey: apiKey,
        systemPrompt: 'You are a helpful assistant.',
        userPrompt: '说一个数字',
      );
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // ─── 内部方法 ───

  Map<String, dynamic> _buildPayload({
    String? systemPrompt,
    String? userPrompt,
    List<Map<String, dynamic>>? messages,
    String? imageBase64,
    required String model,
    required double temperature,
    required int maxTokens,
    required double topP,
    required bool thinkingEnabled,
    bool includeJsonResponseFormat = false,
    double frequencyPenalty = 0,
    double presencePenalty = 0,
    String? reasoningEffort,
    bool stream = false,
  }) {
    // 构建 messages 数组
    List<Map<String, dynamic>> msgs;
    if (messages != null && messages.isNotEmpty) {
      msgs = messages;
    } else {
      msgs = [];
      if (systemPrompt != null && systemPrompt.isNotEmpty) {
        msgs.add({'role': 'system', 'content': systemPrompt});
      }
      if (userPrompt != null && userPrompt.isNotEmpty) {
        if (imageBase64 != null && imageBase64.isNotEmpty) {
          // 多模态 Vision 模式
          msgs.add({
            'role': 'user',
            'content': [
              {'type': 'text', 'text': userPrompt},
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,$imageBase64'},
              },
            ],
          });
        } else {
          msgs.add({'role': 'user', 'content': userPrompt});
        }
      }
    }

    final payload = <String, dynamic>{
      'model': model,
      'messages': msgs,
      'temperature': temperature,
      'max_tokens': maxTokens,
      'top_p': topP,
      'stream': stream,
    };

    if (includeJsonResponseFormat) {
      payload['response_format'] = {'type': 'json_object'};
    }
    if (thinkingEnabled) {
      if (model.startsWith('qwen')) {
        payload['enable_thinking'] = true;
      } else {
        payload['thinking'] = {'type': 'enabled'};
      }
    }
    if (frequencyPenalty != 0) payload['frequency_penalty'] = frequencyPenalty;
    if (presencePenalty != 0) payload['presence_penalty'] = presencePenalty;
    if (reasoningEffort != null && reasoningEffort.isNotEmpty) {
      payload['reasoning_effort'] = reasoningEffort;
    }

    return payload;
  }

  Future<Map<String, dynamic>> _post(
      Map<String, dynamic> body, {
    required String apiKey,
  }) async {
    final requestId = _generateUuid();
    final uri = Uri.parse('https://api-ai.vivo.com.cn/v1/chat/completions')
        .replace(queryParameters: {'requestId': requestId});

    final response = await _httpClient.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode(body),
    );

    // 先检查 HTTP 状态码
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiServiceException(
        _messageForStatusCode(response.statusCode),
        detail: _extractErrorDetail(response.body),
      );
    }

    final decoded = _decodeJsonObject(response.body);

    // 检查 API 业务错误码（即使 HTTP 200 也可能有错误）
    _checkApiError(decoded);

    return decoded;
  }

  /// 检查蓝心 API 特有的业务错误码
  void _checkApiError(Map<String, dynamic> decoded) {
    final errorCode = decoded['code'];
    if (errorCode == null || errorCode == 0) return;

    final errorMsg = decoded['msg']?.toString() ?? '';
    final message = _messageForErrorCode(errorCode, errorMsg);
    throw AiServiceException(message, detail: errorMsg);
  }

  String _extractContent(Map<String, dynamic> decoded) {
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const AiServiceException('蓝心模型返回格式异常');
    }
    final first = choices.first;
    if (first is! Map) {
      throw const AiServiceException('蓝心模型返回格式异常');
    }
    final message = first['message'];
    if (message is! Map) {
      throw const AiServiceException('蓝心模型返回格式异常');
    }
    final content = message['content'];
    if (content is! String || content.trim().isEmpty) {
      throw const AiServiceException('蓝心模型返回空内容');
    }
    return content.trim();
  }

  String _messageForStatusCode(int code) {
    return switch (code) {
      400 => '请求参数错误',
      401 => '认证失败（AppKey 无效）',
      402 => '配额已用尽',
      422 => '请求参数不可处理',
      429 => '请求过于频繁，请稍后重试',
      500 => '蓝心服务器错误',
      503 => '蓝心服务不可用',
      _ => 'HTTP 错误 ($code)',
    };
  }

  /// 映射蓝心 API 业务错误码
  String _messageForErrorCode(dynamic code, String detail) {
    final codeInt = code is int ? code : int.tryParse(code.toString()) ?? 0;
    return switch (codeInt) {
      1001 => '请求参数不完整或格式错误',
      1007 => '内容触发审核，请修改后重试',
      2003 => '今日使用额度已用完，请明天再试',
      30001 when detail.contains('rate') =>
        '请求过于频繁，已触发限流，请稍后重试',
      30001 when detail.contains('permission') =>
        '模型访问权限不足或已过期，请联系客服',
      30001 => '模型访问受限（权限或频率限制）',
      _ => 'API 错误 ($codeInt)',
    };
  }

  String? _extractErrorDetail(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map) {
        return json['message']?.toString() ??
            json['error']?.toString() ??
            json['msg']?.toString();
      }
    } catch (_) {}
    return null;
  }

  Map<String, dynamic> _decodeJsonObject(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.cast<String, dynamic>();
    throw const AiServiceException('蓝心模型返回格式异常');
  }

  String _generateUuid() {
    final r = Random();
    final hex = List<String>.generate(
      32,
      (_) => r.nextInt(16).toRadixString(16),
    ).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-4${hex.substring(13, 16)}-${_uuidVariant()}${hex.substring(17, 20)}-${hex.substring(20, 32)}';
  }

  String _uuidVariant() {
    final v = Random().nextInt(4) + 8;
    return v.toRadixString(16);
  }
}
