
enum ChatMessageRole { user, assistant }

enum AiChatAttachmentType { image, video, link, apiResult }

class AiChatAttachment {
  const AiChatAttachment({
    required this.id,
    required this.type,
    this.url,
    this.title,
    this.description,
    this.metadata = const {},
  });

  final String id;
  final AiChatAttachmentType type;
  final String? url;
  final String? title;
  final String? description;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        if (url != null) 'url': url,
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (metadata.isNotEmpty) 'metadata': metadata,
      };

  factory AiChatAttachment.fromJson(Map<String, dynamic> json) {
    final rawType = json['type']?.toString();
    final type = AiChatAttachmentType.values.firstWhere(
      (item) => item.name == rawType,
      orElse: () => AiChatAttachmentType.link,
    );
    final rawMetadata = json['metadata'];
    return AiChatAttachment(
      id: json['id']?.toString() ??
          'att_${DateTime.now().microsecondsSinceEpoch}',
      type: type,
      url: json['url']?.toString(),
      title: json['title']?.toString(),
      description: json['description']?.toString(),
      metadata: rawMetadata is Map
          ? rawMetadata.cast<String, dynamic>()
          : const {},
    );
  }
}

class AiChatMessage {
  final String id;
  final ChatMessageRole role;
  final String content;
  final DateTime timestamp;
  final List<AiChatAttachment> attachments;

  const AiChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.attachments = const [],
  });

  /// 转换为 JSON 格式，用于持久化存储
  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role.name,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    if (attachments.isNotEmpty)
      'attachments': attachments.map((item) => item.toJson()).toList(),
  };

  /// 从 JSON 恢复
  factory AiChatMessage.fromJson(Map<String, dynamic> json) {
    final rawRole = json['role']?.toString();
    final rawTimestamp = json['timestamp']?.toString();
    final timestamp = rawTimestamp == null
        ? DateTime.now()
        : DateTime.tryParse(rawTimestamp) ?? DateTime.now();
    return AiChatMessage(
      id: json['id']?.toString() ?? 'message_${timestamp.millisecondsSinceEpoch}',
      role: rawRole == ChatMessageRole.user.name
          ? ChatMessageRole.user
          : ChatMessageRole.assistant,
      content: json['content']?.toString() ?? '',
      timestamp: timestamp,
      attachments: _parseAttachments(json['attachments']),
    );
  }

  static List<AiChatAttachment> _parseAttachments(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => AiChatAttachment.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
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
          timestamp == other.timestamp &&
          attachments == other.attachments;

  @override
  int get hashCode =>
      id.hashCode ^
      role.hashCode ^
      content.hashCode ^
      timestamp.hashCode ^
      attachments.hashCode;
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
    final createdAt =
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now();
    final updatedAt =
        DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? createdAt;
    final rawMessages = json['messages'];
    return AiChatSession(
      id: json['id']?.toString() ?? 'chat_${createdAt.millisecondsSinceEpoch}',
      title: title,
      createdAt: createdAt,
      updatedAt: updatedAt,
      messages: rawMessages is List
          ? rawMessages
              .whereType<Map>()
              .map((message) => AiChatMessage.fromJson(
                    message.cast<String, dynamic>(),
                  ))
              .toList()
          : [],
    );
  }

  @override
  String toString() =>
      'AiChatSession(id: $id, title: $title, messageCount: ${messages.length})';
}
