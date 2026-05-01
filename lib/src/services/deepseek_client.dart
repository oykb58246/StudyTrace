import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_config.dart';

class AiServiceException implements Exception {
  const AiServiceException(this.message, {this.detail});

  final String message;
  final String? detail;

  @override
  String toString() => detail == null ? message : '$message ($detail)';
}

class DeepSeekClient {
  DeepSeekClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<String> chatText({
    required AiConfig config,
    required String apiKey,
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.7,
    int maxTokens = 1200,
    bool includeJsonResponseFormat = false,
  }) async {
    final uri = Uri.parse(_joinUrl(config.baseUrl, '/chat/completions'));
    final payload = <String, dynamic>{
      'model': config.model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      'temperature': temperature,
      'max_tokens': maxTokens,
    };
    if (includeJsonResponseFormat) {
      payload['response_format'] = {'type': 'json_object'};
    }

    final response = await _httpClient.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiServiceException(
        _messageForStatusCode(response.statusCode),
        detail: _extractErrorDetail(response.body),
      );
    }

    final decoded = _decodeJsonObject(response.body);
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const AiServiceException('AI 返回格式异常');
    }
    final first = choices.first;
    if (first is! Map) {
      throw const AiServiceException('AI 返回格式异常');
    }
    final message = first['message'];
    if (message is! Map) {
      throw const AiServiceException('AI 返回格式异常');
    }
    final content = message['content'];
    if (content is! String || content.trim().isEmpty) {
      throw const AiServiceException('AI 返回格式异常');
    }
    return content.trim();
  }

  Future<Map<String, dynamic>> chatJson({
    required AiConfig config,
    required String apiKey,
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.2,
    int maxTokens = 1800,
  }) async {
    final content = await chatText(
      config: config,
      apiKey: apiKey,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      temperature: temperature,
      maxTokens: maxTokens,
      includeJsonResponseFormat: true,
    );
    return _decodeJsonObject(content);
  }

  Future<bool> testConnection({
    required AiConfig config,
    required String apiKey,
  }) async {
    final result = await chatJson(
      config: config,
      apiKey: apiKey,
      systemPrompt: '你是连接测试助手。只返回 JSON，不要返回 Markdown。',
      userPrompt: '请返回 {"ok": true, "message": "connected"}',
      maxTokens: 80,
    );
    return result['ok'] == true;
  }

  Map<String, dynamic> _decodeJsonObject(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } on FormatException {
      throw const AiServiceException('AI 返回格式异常');
    }
    throw const AiServiceException('AI 返回格式异常');
  }

  String _joinUrl(String baseUrl, String path) {
    final cleanedBase = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return '$cleanedBase$path';
  }

  String _extractErrorDetail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map && error['message'] is String) {
          return error['message'] as String;
        }
        if (decoded['message'] is String) return decoded['message'] as String;
      }
    } catch (_) {
      return body;
    }
    return body;
  }

  String _messageForStatusCode(int statusCode) {
    switch (statusCode) {
      case 401:
        return 'DeepSeek API Key 无效或未授权';
      case 402:
        return 'DeepSeek 账户余额不足';
      case 422:
        return 'DeepSeek 请求参数不正确';
      case 429:
        return 'DeepSeek 请求过于频繁，请稍后重试';
      case 500:
        return 'DeepSeek 服务内部错误';
      case 503:
        return 'DeepSeek 服务繁忙，请稍后重试';
      default:
        return 'DeepSeek 请求失败（HTTP $statusCode）';
    }
  }
}
