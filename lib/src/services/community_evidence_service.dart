import '../models/community_evidence.dart';
import 'api_client.dart';

class CommunityEvidenceService {
  CommunityEvidenceService({ApiClient? apiClient}) : _api = apiClient;

  ApiClient? _api;

  ApiClient get api {
    final client = _api;
    if (client == null) throw const ApiException('Backend connection is not initialized');
    return client;
  }

  void attach(ApiClient client) {
    _api = client;
  }

  Future<String> draftChallenge(String groupId, {List<String> context = const []}) async {
    final data = await api.postJson(
      '/groups/$groupId/challenges/ai-draft',
      body: {'context': context},
    );
    return data['draftText'] as String? ?? '';
  }

  Future<GroupChallenge> createChallenge({
    required String groupId,
    required String title,
    required String description,
    required Map<String, dynamic> planJson,
    Map<String, dynamic> scoringJson = const {},
    String? coverImageUrl,
  }) async {
    final data = await api.postJson('/groups/$groupId/challenges', body: {
      'title': title,
      'description': description,
      'planJson': planJson,
      'scoringJson': scoringJson,
      if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
    });
    return GroupChallenge.fromJson(data);
  }

  Future<List<GroupChallenge>> listChallenges(String groupId) async {
    final list = await api.getList('/groups/$groupId/challenges');
    return list
        .whereType<Map>()
        .map((item) => GroupChallenge.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  Future<void> joinChallenge(String groupId, String challengeId) async {
    await api.postJson('/groups/$groupId/challenges/$challengeId/join');
  }

  Future<ChallengeEvidence> submitEvidence({
    required String groupId,
    required String challengeId,
    required String evidenceType,
    required String title,
    String summary = '',
    String? sourceType,
    String? sourceId,
    Map<String, dynamic> payloadJson = const {},
  }) async {
    final data = await api.postJson(
      '/groups/$groupId/challenges/$challengeId/evidence',
      body: {
        'evidenceType': evidenceType,
        'title': title,
        if (summary.isNotEmpty) 'summary': summary,
        if (sourceType != null) 'sourceType': sourceType,
        if (sourceId != null) 'sourceId': sourceId,
        if (payloadJson.isNotEmpty) 'payloadJson': payloadJson,
      },
    );
    return ChallengeEvidence.fromJson(data);
  }

  Future<EvidencePackage> createPackage({
    required String title,
    required String courseName,
    required String description,
    required List<Map<String, dynamic>> sourceRefs,
    required Map<String, dynamic> metrics,
    String? groupId,
    String visibility = 'private',
    bool featured = false,
    String? coverImageUrl,
  }) async {
    final data = await api.postJson('/evidence-packages', body: {
      'title': title,
      'courseName': courseName,
      'description': description,
      'sourceRefsJson': sourceRefs,
      'metricsJson': metrics,
      'visibility': visibility,
      'featured': featured,
      if (groupId != null) 'groupId': groupId,
      if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
    });
    return EvidencePackage.fromJson(data);
  }

  Future<List<EvidencePackage>> listMyPackages() async {
    final list = await api.getList('/evidence-packages/mine');
    return list
        .whereType<Map>()
        .map((item) => EvidencePackage.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  Future<List<EvidencePackage>> listGroupPackages(String groupId) async {
    final list = await api.getList('/groups/$groupId/evidence-packages');
    return list
        .whereType<Map>()
        .map((item) => EvidencePackage.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  Future<EvidencePackage> updatePackage(
    String id, {
    String? visibility,
    String? groupId,
    bool? featured,
    String? coverImageUrl,
  }) async {
    final data = await api.patchJson('/evidence-packages/$id', body: {
      if (visibility != null) 'visibility': visibility,
      if (groupId != null) 'groupId': groupId,
      if (featured != null) 'featured': featured,
      if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
    });
    return EvidencePackage.fromJson(data);
  }

  Future<LocationCheckIn> createLocationCheckIn({
    required String title,
    String address = '',
    double? latitude,
    double? longitude,
    String? groupId,
    String visibility = 'private',
    Map<String, dynamic> poiPayloadJson = const {},
  }) async {
    final data = await api.postJson('/locations/check-ins', body: {
      'title': title,
      if (address.isNotEmpty) 'address': address,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (groupId != null) 'groupId': groupId,
      'visibility': visibility,
      if (poiPayloadJson.isNotEmpty) 'poiPayloadJson': poiPayloadJson,
    });
    return LocationCheckIn.fromJson(data);
  }

  Future<List<LocationCheckIn>> listMyLocationCheckIns() async {
    final list = await api.getList('/locations/check-ins/mine');
    return list
        .whereType<Map>()
        .map((item) => LocationCheckIn.fromJson(item.cast<String, dynamic>()))
        .toList();
  }
}
