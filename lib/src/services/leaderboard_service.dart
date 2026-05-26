import 'api_client.dart';

class MyScore {
  const MyScore({
    this.totalPoints = 0,
    this.todayPoints = 0,
    this.weekPoints = 0,
    this.monthPoints = 0,
  });

  final int totalPoints;
  final int todayPoints;
  final int weekPoints;
  final int monthPoints;

  factory MyScore.fromJson(Map<String, dynamic> json) {
    return MyScore(
      totalPoints: (json['totalPoints'] as num?)?.toInt() ?? 0,
      todayPoints: (json['todayPoints'] as num?)?.toInt() ?? 0,
      weekPoints: (json['weekPoints'] as num?)?.toInt() ?? 0,
      monthPoints: (json['monthPoints'] as num?)?.toInt() ?? 0,
    );
  }
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.points,
    this.username,
    this.profile,
  });

  final int rank;
  final String userId;
  final int points;
  final String? username;
  final Map<String, dynamic>? profile;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      userId: json['userId'] as String? ?? '',
      points: (json['points'] as num?)?.toInt() ?? 0,
      username: json['username'] as String?,
      profile: json['profile'] is Map<String, dynamic>
          ? json['profile'] as Map<String, dynamic>
          : null,
    );
  }
}

class LeaderboardService {
  LeaderboardService({ApiClient? apiClient}) : _api = apiClient;

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

  Future<MyScore> getMine() async {
    final data = await api.getJson('/leaderboards/me');
    return MyScore.fromJson(data);
  }

  Future<List<LeaderboardEntry>> getGroupLeaderboard(
    String groupId, {
    String range = 'week',
    String metric = 'points',
  }) async {
    final decoded = await api.getList(
      '/leaderboards/groups/$groupId',
      query: {'range': range, 'metric': metric},
    );
    return decoded
        .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
