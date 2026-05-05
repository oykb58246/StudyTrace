import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:studytrace/src/models/ai_config.dart';
import 'package:studytrace/src/services/ai_credential_service.dart';
import 'package:studytrace/src/services/ai_study_service.dart';
import 'package:studytrace/src/services/deepseek_client.dart';
import 'package:studytrace/src/services/local_storage_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('DeepSeekClient decodes JSON content from chat response', () async {
    final client = DeepSeekClient(
      httpClient: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer test-key');
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({'ok': true}),
                },
              },
            ],
          }),
          200,
        );
      }),
    );

    final result = await client.chatJson(
      config: const AiConfig(isEnabled: true),
      apiKey: 'test-key',
      systemPrompt: 'system',
      userPrompt: 'user',
    );

    expect(result['ok'], isTrue);
  });

  test('DeepSeekClient maps authorization errors to readable failures',
      () async {
    final client = DeepSeekClient(
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {'message': 'bad key'},
          }),
          401,
        );
      }),
    );

    expect(
      () => client.chatJson(
        config: const AiConfig(isEnabled: true),
        apiKey: 'bad-key',
        systemPrompt: 'system',
        userPrompt: 'user',
      ),
      throwsA(isA<AiServiceException>()),
    );
  });

  test('AiStudyService maps DeepSeek study log JSON to model', () async {
    final storage = LocalStorageService();
    await storage.saveAiConfig(const AiConfig(isEnabled: true));
    final credentials = _FakeCredentials('test-key');
    final deepSeekClient = DeepSeekClient(
      httpClient: MockClient((request) async {
        final body = jsonEncode({
          'choices': [
            {
              'message': {
                'content': jsonEncode({
                  'courseName': '数据库',
                  'content': '学习了索引结构。',
                  'problems': 'B+树分裂过程还不熟。',
                  'thoughts': '需要结合例题理解。',
                  'nextPlan': '复习查询优化。',
                }),
              },
            },
          ],
        });
        return http.Response.bytes(
          utf8.encode(body),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final service = AiStudyService(
      storage: storage,
      credentials: credentials,
      deepSeekClient: deepSeekClient,
    );

    final result = await service.generateStudyLog('今天学了数据库索引');

    expect(result.courseName, '数据库');
    expect(result.content, contains('索引'));
    expect(result.nextPlan, contains('查询优化'));
  });
}

class _FakeCredentials extends AiCredentialService {
  _FakeCredentials(this.key);

  final String? key;

  @override
  Future<String?> loadDeepSeekApiKey() async => key;

  @override
  Future<bool> hasDeepSeekApiKey() async => key != null && key!.isNotEmpty;

  @override
  Future<void> saveDeepSeekApiKey(String apiKey) async {}

  @override
  Future<void> deleteDeepSeekApiKey() async {}

  @override
  Future<String?> loadBlueHeartAppKey() async => null;

  @override
  Future<bool> hasBlueHeartAppKey() async => false;

  @override
  Future<void> saveBlueHeartAppKey(String appKey) async {}

  @override
  Future<void> deleteBlueHeartAppKey() async {}
}
