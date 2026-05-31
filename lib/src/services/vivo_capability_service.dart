import '../models/ai_capability_trace.dart';
import '../models/vivo_capability.dart';
import 'api_client.dart';

class VivoCapabilityService {
  VivoCapabilityService({ApiClient? apiClient}) : _api = apiClient;

  ApiClient? _api;

  ApiClient get api {
    final client = _api;
    if (client == null) throw const ApiException('Backend connection is not initialized');
    return client;
  }

  void attach(ApiClient client) {
    _api = client;
  }

  Future<TranslatedTextResult> translate(
    String text, {
    String from = 'auto',
    String to = 'en',
  }) async {
    final data = await api.postJson('/ai/translate', body: {
      'text': text,
      'from': from,
      'to': to,
    });
    return TranslatedTextResult.fromJson(data);
  }

  Future<GeneratedImageTask> createCover({
    required String prompt,
    String purpose = 'evidence_cover',
  }) async {
    final data = await api.postJson('/ai/images/tasks', body: {
      'prompt': prompt,
      'purpose': purpose,
      'width': 768,
      'height': 1024,
    });
    return GeneratedImageTask.fromJson(data);
  }

  Future<GeneratedImageTask> refreshImageTask(String taskId) async {
    final data = await api.postJson(
      '/ai/images/tasks/status',
      body: {'taskId': taskId},
    );
    return GeneratedImageTask.fromJson(data);
  }

  Future<GeneratedVideoTask> createVideo({
    required String prompt,
    String? imageBase64,
    String? imageUrl,
    String purpose = 'chat_video',
  }) async {
    final data = await api.postJson('/ai/videos/tasks', body: {
      'prompt': prompt,
      'purpose': purpose,
      if (imageBase64 != null && imageBase64.isNotEmpty)
        'imageBase64': imageBase64,
      if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
    });
    return GeneratedVideoTask.fromJson(data);
  }

  Future<GeneratedVideoTask> refreshVideoTask(String taskId) async {
    final data = await api.postJson(
      '/ai/videos/tasks/status',
      body: {'taskId': taskId},
    );
    return GeneratedVideoTask.fromJson(data);
  }

  Future<Map<String, dynamic>> searchPoi(
    String query, {
    String city = '',
    String location = '',
  }) {
    return api.postJson('/ai/poi-search', body: {
      'query': query,
      if (city.isNotEmpty) 'city': city,
      if (location.isNotEmpty) 'location': location,
    });
  }

  Future<Map<String, dynamic>> reverseGeocode(String location) {
    return api.postJson('/ai/reverse-geocode', body: {'location': location});
  }

  Future<Map<String, dynamic>> transcribeAudio({
    required String audioBase64,
    String mimeType = 'audio/m4a',
    String mode = 'short',
  }) {
    return api.postJson('/ai/speech/transcribe', body: {
      'audioBase64': audioBase64,
      'mimeType': mimeType,
      'mode': mode,
    });
  }

  Future<Map<String, dynamic>> indexMemory(List<Map<String, dynamic>> items) {
    return api.postJson('/ai/memory/index', body: {'items': items});
  }

  Future<MemorySearchResult> searchMemory(String query, {int limit = 8}) async {
    final data = await api.postJson('/ai/memory/search', body: {
      'query': query,
      'limit': limit,
    });
    final rawHits = data['hits'];
    return MemorySearchResult(
      hits: rawHits is List
          ? rawHits
              .whereType<Map>()
              .map((item) => item.cast<String, dynamic>())
              .toList(growable: false)
          : const [],
      capabilityTraces: parseCapabilityTraces(data['capabilityTraces']),
    );
  }

  Future<List<Map<String, dynamic>>> capabilityBadges() async {
    final data = await api.getJson('/ai/capability-badges');
    final raw = data['badges'];
    return raw is List
        ? raw
            .whereType<Map>()
            .map((item) => item.cast<String, dynamic>())
            .toList(growable: false)
        : const [];
  }
}

class MemorySearchResult {
  const MemorySearchResult({
    required this.hits,
    required this.capabilityTraces,
  });

  final List<Map<String, dynamic>> hits;
  final List<AiCapabilityTrace> capabilityTraces;
}
