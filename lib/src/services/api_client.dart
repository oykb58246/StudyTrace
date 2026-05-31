import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_endpoint_config.dart';
import 'ai_credential_service.dart';

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.detail,
    this.isNetworkError = false,
    this.isUnauthorized = false,
  });

  final String message;
  final int? statusCode;
  final String? detail;
  final bool isNetworkError;
  final bool isUnauthorized;

  String get displayMessage {
    final cleanedDetail = detail?.trim();
    if (cleanedDetail != null && cleanedDetail.isNotEmpty) {
      return cleanedDetail;
    }
    return message;
  }

  @override
  String toString() {
    if (detail == null) return message;
    return '$message ($detail)';
  }
}

class ApiClient {
  ApiClient({
    required String baseUrl,
    AiCredentialService? credentials,
    http.Client? httpClient,
    Future<void> Function()? onUnauthorized,
  })  : _baseUrl = baseUrl,
        _credentials = credentials ?? AiCredentialService(),
        _httpClient = httpClient ?? http.Client(),
        _onUnauthorized = onUnauthorized;

  final AiCredentialService _credentials;
  final http.Client _httpClient;
  final Future<void> Function()? _onUnauthorized;
  final Duration _timeout = const Duration(seconds: 12);

  String _baseUrl;

  String get baseUrl => _baseUrl;

  set baseUrl(String value) {
    _baseUrl = value;
  }

  Future<http.Response> get(String path, {Map<String, String>? query}) {
    return _send(() async {
      final uri = _buildUri(path, query);
      final headers = await _buildHeaders();
      return _httpClient.get(uri, headers: headers);
    }, allowRefresh: !_isAuthPath(path));
  }

  Future<http.Response> post(
    String path, {
    Object? body,
    Map<String, String>? query,
    Duration? timeout,
  }) {
    return _send(() async {
      final uri = _buildUri(path, query);
      final headers = await _buildHeaders();
      return _httpClient.post(uri, headers: headers, body: _encodeBody(body));
    }, allowRefresh: !_isAuthPath(path), timeout: timeout);
  }

  Future<http.Response> patch(
    String path, {
    Object? body,
    Map<String, String>? query,
  }) {
    return _send(() async {
      final uri = _buildUri(path, query);
      final headers = await _buildHeaders();
      return _httpClient.patch(uri, headers: headers, body: _encodeBody(body));
    }, allowRefresh: !_isAuthPath(path));
  }

  Future<http.Response> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
  }) {
    return _send(() async {
      final uri = _buildUri(path, query);
      final headers = await _buildHeaders();
      return _httpClient.delete(uri, headers: headers, body: _encodeBody(body));
    }, allowRefresh: !_isAuthPath(path));
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
  }) async {
    final response = await get(path, query: query);
    return _decodeJson(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Object? body,
    Map<String, String>? query,
    Duration? timeout,
  }) async {
    final response = await post(path, body: body, query: query, timeout: timeout);
    return _decodeJson(response);
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    Object? body,
    Map<String, String>? query,
  }) async {
    final response = await patch(path, body: body, query: query);
    return _decodeJson(response);
  }

  Future<void> deleteVoid(
    String path, {
    Object? body,
    Map<String, String>? query,
  }) async {
    final response = await delete(path, body: body, query: query);
    _throwIfNotSuccess(response);
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    Object? body,
    Map<String, String>? query,
  }) async {
    final response = await delete(path, body: body, query: query);
    return _decodeJson(response);
  }

  Future<List<dynamic>> getList(
    String path, {
    Map<String, String>? query,
  }) async {
    final response = await get(path, query: query);
    return _decodeList(response);
  }

  List<dynamic> _decodeList(http.Response response) {
    _throwIfNotSuccess(response);
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is List) return decoded;
    } catch (_) {
      throw const ApiException('服务器返回格式异常');
    }
    throw const ApiException('服务器返回格式异常');
  }

  Future<http.Response> _send(
    Future<http.Response> Function() request, {
    bool allowRefresh = true,
    Duration? timeout,
  }) async {
    final effectiveTimeout = timeout ?? _timeout;
    try {
      final response = await request().timeout(effectiveTimeout);

      if (response.statusCode == 401) {
        if (!allowRefresh) {
          return response;
        }
        final retried = await _retryWithRefresh(
          request,
          timeout: effectiveTimeout,
        );
        if (retried != null) {
          if (retried.statusCode == 401) {
            await _notifyUnauthorized();
            throw const ApiException(
              '登录已过期，请重新登录',
              statusCode: 401,
              isUnauthorized: true,
            );
          }
          return retried;
        }
        await _notifyUnauthorized();
        throw const ApiException(
          '登录已过期，请重新登录',
          statusCode: 401,
          isUnauthorized: true,
        );
      }

      return response;
    } on TimeoutException {
      throw const ApiException(
        '请求超时，请检查网络',
        isNetworkError: true,
      );
    } on http.ClientException {
      throw const ApiException(
        '无法连接到服务器，请检查网络或服务地址',
        isNetworkError: true,
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        '网络异常，请稍后重试',
        isNetworkError: true,
      );
    }
  }

  Future<http.Response?> _retryWithRefresh(
    Future<http.Response> Function() request, {
    Duration? timeout,
  }) async {
    final refreshToken = await _credentials.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return null;
    final effectiveTimeout = timeout ?? _timeout;

    final refreshUri = _buildUri('/auth/refresh', null);
    try {
      final refreshResponse = await _httpClient
          .post(
            refreshUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(_timeout);

      if (refreshResponse.statusCode >= 200 &&
          refreshResponse.statusCode < 300) {
        final data = _decodeRawJson(refreshResponse.body);
        final newAccessToken = data['accessToken'] as String?;
        final newRefreshToken = data['refreshToken'] as String?;
        if (newAccessToken != null && newAccessToken.isNotEmpty) {
          await _credentials.saveAuthToken(newAccessToken);
        }
        if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
          await _credentials.saveRefreshToken(newRefreshToken);
        }
        return await request().timeout(effectiveTimeout);
      }
    } catch (_) {
      // refresh 失败，交给上层按 401 处理
    }

    return null;
  }

  Future<void> _notifyUnauthorized() async {
    final callback = _onUnauthorized;
    if (callback == null) return;
    try {
      await callback();
    } catch (_) {
      // Auth-state cleanup must not mask the original 401 error.
    }
  }

  Future<Map<String, String>> _buildHeaders() async {
    final token = await _credentials.getAuthToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Uri _buildUri(String path, Map<String, String>? query) {
    final base = ApiEndpointConfig.normalizeBaseUrl(_baseUrl);
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$base$normalizedPath');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      ...query,
    });
  }

  String? _encodeBody(Object? body) {
    if (body == null) return null;
    if (body is String) return body;
    return jsonEncode(body);
  }

  bool _isAuthPath(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return normalizedPath.startsWith('/auth/');
  }

  Map<String, dynamic> _decodeJson(http.Response response) {
    _throwIfNotSuccess(response);
    return _decodeRawJson(response.body);
  }

  void _throwIfNotSuccess(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _messageForStatusCode(response.statusCode),
        statusCode: response.statusCode,
        detail: _extractErrorMessage(response.body),
        isUnauthorized: response.statusCode == 401,
      );
    }
  }

  Map<String, dynamic> _decodeRawJson(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {
      throw const ApiException('服务器返回格式异常');
    }
    throw const ApiException('服务器返回格式异常');
  }

  String _extractErrorMessage(String body) {
    final normalizedBody = body.trim();
    final lowerBody = normalizedBody.toLowerCase();
    if (lowerBody.startsWith('<!doctype html') ||
        lowerBody.startsWith('<html') ||
        lowerBody.contains('<center><h1>404 not found</h1></center>') ||
        lowerBody.contains('openresty') ||
        lowerBody.contains('nginx')) {
      return '';
    }
    try {
      final decoded = jsonDecode(normalizedBody);
      if (decoded is Map) {
        final message = decoded['message'];
        if (message is String) return _humanizeErrorDetail(message);
        if (message is List && message.isNotEmpty) {
          return _humanizeErrorDetail(message.join('；'));
        }
        final error = decoded['error'];
        if (error is String) return _humanizeErrorDetail(error);
        if (error is Map && error['message'] is String) {
          return _humanizeErrorDetail(error['message'] as String);
        }
      }
      if (decoded is List && decoded.isNotEmpty) {
        final first = decoded.first;
        if (first is Map) {
          final constraints = first['constraints'];
          if (constraints is Map && constraints.isNotEmpty) {
            return _humanizeErrorDetail(constraints.values.first.toString());
          }
        }
      }
    } catch (_) {
      return _humanizeErrorDetail(normalizedBody);
    }
    return _humanizeErrorDetail(normalizedBody);
  }

  String _humanizeErrorDetail(String detail) {
    if (detail.contains('identifier') && detail.contains('string')) {
      return '请输入用户名或邮箱';
    }
    if (detail.contains('username')) {
      if (detail.contains('longer than or equal to 3') ||
          detail.contains('shorter than or equal to 32') ||
          detail.contains('Length')) {
        return '用户名需要 3-32 位';
      }
      return '请输入有效的用户名';
    }
    if (detail.contains('password')) {
      if (detail.contains('8') || detail.contains('MinLength')) {
        return '密码至少需要 8 位';
      }
      return '请输入有效的密码';
    }
    if (detail.contains('email')) {
      return '请输入有效的邮箱地址';
    }
    return detail;
  }

  String _messageForStatusCode(int statusCode) {
    switch (statusCode) {
      case 400:
        return '请求参数不正确（用户名3-32位，密码至少8位）';
      case 401:
        return '登录已过期，请重新登录';
      case 403:
        return '没有权限执行此操作';
      case 404:
        return '请求的资源不存在';
      case 409:
        return '数据已存在或发生冲突';
      case 422:
        return '请求参数校验失败';
      case 429:
        return '请求过于频繁，请稍后重试';
      case 500:
        return '服务器内部错误';
      case 502:
        return '服务器网关异常';
      case 503:
        return '服务暂不可用，请稍后重试';
      default:
        return '请求失败（HTTP $statusCode）';
    }
  }
}
