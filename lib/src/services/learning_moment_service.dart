import '../models/learning_moment.dart';
import 'api_client.dart';

class LearningMomentService {
  LearningMomentService({ApiClient? apiClient}) : _api = apiClient;

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

  Future<List<LearningMoment>> feed() async {
    final decoded = await api.getList('/moments/feed');
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(LearningMoment.fromJson)
        .toList(growable: false);
  }

  Future<LearningMoment> create({
    required String content,
    String courseName = '',
    List<String> imagePaths = const [],
    required LearningMomentVisibility visibility,
    List<String> allowedGroupIds = const [],
    List<String> deniedGroupIds = const [],
    String? sourceType,
    String? sourceId,
  }) async {
    final data = await api.postJson('/moments', body: {
      'content': content,
      if (courseName.trim().isNotEmpty) 'courseName': courseName.trim(),
      if (imagePaths.isNotEmpty) 'imagePaths': imagePaths,
      'visibility': visibility.name,
      if (allowedGroupIds.isNotEmpty) 'allowedGroupIds': allowedGroupIds,
      if (deniedGroupIds.isNotEmpty) 'deniedGroupIds': deniedGroupIds,
      if (sourceType != null && sourceType.trim().isNotEmpty)
        'sourceType': sourceType.trim(),
      if (sourceId != null && sourceId.trim().isNotEmpty)
        'sourceId': sourceId.trim(),
    });
    return LearningMoment.fromJson(data);
  }

  Future<LearningMoment> updateVisibility({
    required String momentId,
    required LearningMomentVisibility visibility,
    List<String> allowedGroupIds = const [],
    List<String> deniedGroupIds = const [],
  }) async {
    final data = await api.patchJson('/moments/$momentId/visibility', body: {
      'visibility': visibility.name,
      if (allowedGroupIds.isNotEmpty) 'allowedGroupIds': allowedGroupIds,
      if (deniedGroupIds.isNotEmpty) 'deniedGroupIds': deniedGroupIds,
    });
    return LearningMoment.fromJson(data);
  }

  Future<void> delete(String momentId) async {
    await api.deleteVoid('/moments/$momentId');
  }

  Future<LearningMoment> like(String momentId) async {
    final data = await api.postJson('/moments/$momentId/likes/me');
    return LearningMoment.fromJson(data);
  }

  Future<LearningMoment> unlike(String momentId) async {
    final data = await api.deleteJson('/moments/$momentId/likes/me');
    return LearningMoment.fromJson(data);
  }

  Future<LearningMoment> comment(String momentId, String content) async {
    final data = await api.postJson('/moments/$momentId/comments', body: {
      'content': content,
    });
    return LearningMoment.fromJson(data);
  }

  Future<LearningMoment> deleteComment(String momentId, String commentId) async {
    final data = await api.deleteJson('/moments/$momentId/comments/$commentId');
    return LearningMoment.fromJson(data);
  }
}
