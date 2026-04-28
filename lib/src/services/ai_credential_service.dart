import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AiCredentialService {
  AiCredentialService({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const _deepSeekApiKey = 'studytrace_deepseek_api_key_v1';

  final FlutterSecureStorage _storage;

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
}
