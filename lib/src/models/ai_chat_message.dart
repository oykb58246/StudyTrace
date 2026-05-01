
enum ChatMessageRole { user, assistant }

class AiChatMessage {
  final String id;
  final ChatMessageRole role;
  final String content;
  final DateTime timestamp;

  const AiChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
  });

  /// 转换为 JSON 格式，用于持久化存储
  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role.name,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
  };

  /// 从 JSON 恢复
  factory AiChatMessage.fromJson(Map<String, dynamic> json) {
    return AiChatMessage(
      id: json['id'] as String,
      role: ChatMessageRole.values.byName(json['role'] as String),
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  @override
  String toString() =>
      'AiChatMessage(id: $id, role: ${role.name}, timestamp: $timestamp)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiChatMessage &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          role == other.role &&
          content == other.content &&
          timestamp == other.timestamp;

  @override
  int get hashCode =>
      id.hashCode ^ role.hashCode ^ content.hashCode ^ timestamp.hashCode;
}

/// 对话会话，包含多条消息
class AiChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<AiChatMessage> messages;

  AiChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });

  /// 转换为 JSON 格式
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'messages': messages.map((m) => m.toJson()).toList(),
  };

  /// 从 JSON 恢复
  factory AiChatSession.fromJson(Map<String, dynamic> json) {
    final rawTitle = json['title'];
    final title = rawTitle is String && rawTitle.isNotEmpty ? rawTitle : '新对话';
    return AiChatSession(
      id: json['id'] as String,
      title: title,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      messages: (json['messages'] as List<dynamic>?)
              ?.map((m) => AiChatMessage.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  @override
  String toString() =>
      'AiChatSession(id: $id, title: $title, messageCount: ${messages.length})';
}
