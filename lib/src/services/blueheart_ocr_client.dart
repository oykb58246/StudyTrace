import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_config.dart';
import 'deepseek_client.dart';

class BlueHeartOcrClient {
  BlueHeartOcrClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<String> recognizeTextFromBase64({
    required AiConfig config,
    required String apiKey,
    required String imageBase64,
    String? requestId,
    int pos = 2,
  }) async {
    final appId = config.appId.trim();
    if (appId.isEmpty) {
      throw const AiServiceException('请先配置蓝心 AppId');
    }

    final uri = Uri.parse(
      'https://api-ai.vivo.com.cn/ocr/general_recognition',
    ).replace(
      queryParameters: {
        'requestId': requestId ?? DateTime.now().microsecondsSinceEpoch.toString(),
      },
    );

    final response = await _httpClient.post(
      uri,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'image': imageBase64,
        'pos': pos.toString(),
        'businessid': 'aigc$appId',
        'sessid': requestId ?? DateTime.now().microsecondsSinceEpoch.toString(),
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiServiceException(
        'OCR 请求失败（HTTP ${response.statusCode}）',
        detail: response.body,
      );
    }

    final decoded = _decodeJsonObject(response.body);
    final errorCode = decoded['error_code'];
    if (errorCode is int && errorCode != 0) {
      throw AiServiceException(
        'OCR 识别失败',
        detail: decoded['error_msg']?.toString(),
      );
    }

    final result = decoded['result'];
    final words = <String>[];
    _collectWords(result, words);
    return words.join('\n').trim();
  }

  Map<String, dynamic> _decodeJsonObject(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.cast<String, dynamic>();
    throw const AiServiceException('OCR 返回格式异常');
  }

  void _collectWords(Object? node, List<String> words) {
    if (node == null) return;
    if (node is String) {
      final trimmed = node.trim();
      if (trimmed.isNotEmpty) words.add(trimmed);
      return;
    }
    if (node is Map) {
      final map = node.cast<String, dynamic>();
      final direct = map['words'];
      if (direct is String && direct.trim().isNotEmpty) {
        words.add(direct.trim());
      }
      for (final value in map.values) {
        _collectWords(value, words);
      }
      return;
    }
    if (node is Iterable) {
      for (final item in node) {
        _collectWords(item, words);
      }
    }
  }
}