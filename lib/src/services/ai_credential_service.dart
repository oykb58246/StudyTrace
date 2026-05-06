import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AiCredentialService {
  AiCredentialService({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const _deepSeekApiKey = 'studytrace_deepseek_api_key_v1';
  static const _blueHeartAppKey = 'studytrace_blueheart_app_key_v1';
  static const _authTokenKey = 'studytrace_auth_token_v1';
  // 蓝心 AppKey - 已内置
  static const _embeddedBlueHeartAppKey = 'sk-xuanji-2026702831-aXhDYXVUY3lVSlZLZUhRcA==';

  final FlutterSecureStorage _storage;

  Future<String?> getAuthToken() async {
    try {
      return await _storage.read(key: _authTokenKey);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<void> saveAuthToken(String token) async {
    await _storage.write(key: _authTokenKey, value: token);
  }

  Future<void> clearAuthToken() async {
    await _storage.delete(key: _authTokenKey);
  }

  Future<String?> loadDeepSeekApiKey() async {
    try {
      final value = await _storage.read(key: _deepSeekApiKey);
      if (value == null || value.trim().isEmpty) return null;
      return value.trim();
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<bool> hasDeepSeekApiKey() async {
    final key = await loadDeepSeekApiKey();
    return key != null && key.isNotEmpty;
  }

  Future<void> saveDeepSeekApiKey(String apiKey) async {
    final cleaned = apiKey.trim();
    if (cleaned.isEmpty) return;
    try {
      await _storage.write(key: _deepSeekApiKey, value: cleaned);
    } on MissingPluginException {
      return;
    }
  }

  Future<void> deleteDeepSeekApiKey() async {
    try {
      await _storage.delete(key: _deepSeekApiKey);
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Future<String?> loadBlueHeartAppKey() async {
    try {
      final value = await _storage.read(key: _blueHeartAppKey);
      if (value == null || value.trim().isEmpty) {
        return _embeddedBlueHeartAppKey.trim().isNotEmpty
            ? _embeddedBlueHeartAppKey.trim()
            : null;
      }
      return value.trim();
    } on MissingPluginException {
      return _embeddedBlueHeartAppKey.trim().isNotEmpty
          ? _embeddedBlueHeartAppKey.trim()
          : null;
    } on PlatformException {
      return _embeddedBlueHeartAppKey.trim().isNotEmpty
          ? _embeddedBlueHeartAppKey.trim()
          : null;
    }
  }

  Future<bool> hasBlueHeartAppKey() async {
    final key = await loadBlueHeartAppKey();
    return key != null && key.isNotEmpty;
  }

  Future<void> saveBlueHeartAppKey(String appKey) async {
    final cleaned = appKey.trim();
    if (cleaned.isEmpty) return;
    try {
      await _storage.write(key: _blueHeartAppKey, value: cleaned);
    } on MissingPluginException {
      return;
    }
  }

  Future<void> deleteBlueHeartAppKey() async {
    try {
      await _storage.delete(key: _blueHeartAppKey);
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}
