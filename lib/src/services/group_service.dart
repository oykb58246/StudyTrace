import 'api_client.dart';
import 'activity_service.dart';

class GroupInfo {
  const GroupInfo({
    required this.id,
    required this.name,
    this.description,
    this.inviteCode,
    this.memberCount = 0,
    this.role,
    this.joinedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;
  final String? inviteCode;
  final int memberCount;
  final String? role;
  final DateTime? joinedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory GroupInfo.fromJson(Map<String, dynamic> json) {
    return GroupInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      inviteCode: json['inviteCode'] as String?,
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      role: json['role'] as String?,
      joinedAt: _parseDate(json['joinedAt']),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}

class GroupMember {
  const GroupMember({
    required this.id,
    required this.username,
    this.role = 'member',
    this.joinedAt,
    this.profile,
  });

  final String id;
  final String username;
  final String role;
  final DateTime? joinedAt;
  final Map<String, dynamic>? profile;

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      role: json['role'] as String? ?? 'member',
      joinedAt: GroupInfo._parseDate(json['joinedAt']),
      profile: json['profile'] is Map<String, dynamic>
          ? json['profile'] as Map<String, dynamic>
          : null,
    );
  }
}

class GroupService {
  GroupService({ApiClient? apiClient}) : _api = apiClient;

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

  Future<GroupInfo> create({
    required String name,
    String? description,
  }) async {
    final data = await api.postJson('/groups', body: {
      'name': name,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
    });
    return GroupInfo.fromJson(data);
  }

  Future<GroupInfo> join({required String inviteCode}) async {
    final data = await api.postJson('/groups/join', body: {
      'inviteCode': inviteCode.trim(),
    });
    return GroupInfo.fromJson(data);
  }

  Future<List<GroupInfo>> listMine() async {
    final decoded = await api.getList('/groups');
    return decoded
        .map((e) => GroupInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<GroupInfo> getGroup(String groupId) async {
    final data = await api.getJson('/groups/$groupId');
    return GroupInfo.fromJson(data);
  }

  Future<List<GroupMember>> listMembers(String groupId) async {
    final decoded = await api.getList('/groups/$groupId/members');
    return decoded
        .map((e) => GroupMember.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> leave(String groupId) async {
    await api.deleteVoid('/groups/$groupId/membership');
  }

  Future<List<StudyActivity>> listActivities(String groupId) async {
    final decoded = await api.getList('/groups/$groupId/activities');
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(StudyActivity.fromJson)
        .toList();
  }
}
