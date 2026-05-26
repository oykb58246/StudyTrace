import 'api_client.dart';

class StudyActivity {
  const StudyActivity({
    required this.id,
    required this.type,
    required this.title,
    this.summary,
    this.groupId,
    this.sourceType,
    this.sourceId,
    this.payloadJson,
    this.happenedAt,
    this.user,
  });

  final String id;
  final String type;
  final String title;
  final String? summary;
  final String? groupId;
  final String? sourceType;
  final String? sourceId;
  final Map<String, dynamic>? payloadJson;
  final DateTime? happenedAt;
  final Map<String, dynamic>? user;

  factory StudyActivity.fromJson(Map<String, dynamic> json) {
    return StudyActivity(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String?,
      groupId: json['groupId'] as String?,
      sourceType: json['sourceType'] as String?,
      sourceId: json['sourceId'] as String?,
      payloadJson: json['payloadJson'] is Map<String, dynamic>
          ? json['payloadJson'] as Map<String, dynamic>
          : null,
      happenedAt: DateTime.tryParse(json['happenedAt'] as String? ?? ''),
      user: json['user'] is Map<String, dynamic>
          ? json['user'] as Map<String, dynamic>
          : null,
    );
  }
}

class ActivityService {
  ActivityService({ApiClient? apiClient}) : _api = apiClient;

  ApiClient? _api;

  ApiClient get api {
    final client = _api;
    if (client == null) {
      throw const ApiException('尚未初始化后端连接');
    }
    return client;
  }

  void attach(ApiClient client) {
    _api = client;
  }

  Future<void> create({
    required String type,
    required String title,
    String? summary,
    String? groupId,
    String? sourceType,
    String? sourceId,
    Map<String, dynamic>? payloadJson,
    DateTime? happenedAt,
  }) async {
    await api.postJson('/activities', body: {
      'type': type,
      'title': title,
      if (summary != null && summary.trim().isNotEmpty)
        'summary': summary.trim(),
      if (groupId != null && groupId.isNotEmpty) 'groupId': groupId,
      if (sourceType != null && sourceType.isNotEmpty) 'sourceType': sourceType,
      if (sourceId != null && sourceId.isNotEmpty) 'sourceId': sourceId,
      if (payloadJson != null) 'payloadJson': payloadJson,
      if (happenedAt != null) 'happenedAt': happenedAt.toIso8601String(),
    });
  }

  Future<List<StudyActivity>> listMine() async {
    final decoded = await api.getList('/activities/mine');
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(StudyActivity.fromJson)
        .toList();
  }

  Future<List<StudyActivity>> listGroup(String groupId) async {
    final decoded = await api.getList('/groups/$groupId/activities');
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(StudyActivity.fromJson)
        .toList();
  }
}
