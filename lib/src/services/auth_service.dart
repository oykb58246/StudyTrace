import 'api_client.dart';

class AuthResult {
  const AuthResult({
    required this.accessToken,
    required this.refreshToken,
    this.user,
  });

  final String accessToken;
  final String refreshToken;
  final Map<String, dynamic>? user;
}

class AuthService {
  AuthService({ApiClient? apiClient}) : _api = apiClient;

  ApiClient? _api;

  ApiClient get api {
    final client = _api;
    if (client == null) {
      throw const ApiException('尚未初始化后端连接，请先配置服务地址');
    }
    return client;
  }

  void attach(ApiClient client) {
    _api = client;
  }

  Future<AuthResult> register({
    required String username,
    required String password,
    String? nickname,
  }) async {
    final data = await api.postJson('/auth/register', body: {
      'username': username,
      'password': password,
      if (nickname != null && nickname.trim().isNotEmpty)
        'nickname': nickname.trim(),
    });
    return _parseAuthResult(data);
  }

  Future<AuthResult> login({
    required String identifier,
    required String password,
  }) async {
    final data = await api.postJson('/auth/login', body: {
      'identifier': identifier,
      'password': password,
    });
    return _parseAuthResult(data);
  }

  Future<AuthResult> refreshToken(String refreshToken) async {
    final data = await api.postJson('/auth/refresh', body: {
      'refreshToken': refreshToken,
    });
    return _parseAuthResult(data);
  }

  Future<Map<String, dynamic>> getProfile() async {
    return api.getJson('/me');
  }

  Future<Map<String, dynamic>> updateProfile({
    String? nickname,
    String? avatarEmoji,
    String? avatarImageUrl,
    String? bio,
  }) async {
    final body = <String, dynamic>{};
    if (nickname != null) body['nickname'] = nickname;
    if (avatarEmoji != null) body['avatarEmoji'] = avatarEmoji;
    if (avatarImageUrl != null) body['avatarImageUrl'] = avatarImageUrl;
    if (bio != null) body['bio'] = bio;
    return api.patchJson('/me/profile', body: body);
  }

  Future<void> logout({String? refreshToken}) async {
    await api.postJson('/auth/logout', body: {
      if (refreshToken != null && refreshToken.isNotEmpty)
        'refreshToken': refreshToken,
    });
  }

  Future<void> deleteAccount() async {
    await api.postJson('/auth/delete-account');
  }

  AuthResult _parseAuthResult(Map<String, dynamic> data) {
    final accessToken = data['accessToken'] as String?;
    final refreshToken = data['refreshToken'] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw const ApiException('服务器未返回登录凭据');
    }
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const ApiException('服务器未返回刷新凭据');
    }
    return AuthResult(
      accessToken: accessToken,
      refreshToken: refreshToken,
      user: data['user'] is Map<String, dynamic>
          ? data['user'] as Map<String, dynamic>
          : null,
    );
  }
}
