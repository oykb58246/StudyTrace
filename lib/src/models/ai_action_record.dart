enum AiActionStatus { pending, confirmed, executed, cancelled, failed }

class AiActionRecord {
  const AiActionRecord({
    required this.id,
    this.sessionId,
    required this.toolId,
    this.targetId,
    this.targetTitle,
    required this.status,
    this.resultMessage,
    this.errorMessage,
    this.params,
    required this.createdAt,
  });

  final String id;
  final String? sessionId;
  final String toolId;
  final String? targetId;
  final String? targetTitle;
  final AiActionStatus status;
  final String? resultMessage;
  final String? errorMessage;
  final Map<String, dynamic>? params;
  final DateTime createdAt;

  String get statusLabel {
    return switch (status) {
      AiActionStatus.pending => '待执行',
      AiActionStatus.confirmed => '已确认',
      AiActionStatus.executed => '已完成',
      AiActionStatus.cancelled => '已取消',
      AiActionStatus.failed => '失败',
    };
  }

  AiActionRecord copyWith({
    String? id,
    String? sessionId,
    String? toolId,
    String? targetId,
    String? targetTitle,
    AiActionStatus? status,
    String? resultMessage,
    String? errorMessage,
    Map<String, dynamic>? params,
    DateTime? createdAt,
  }) {
    return AiActionRecord(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      toolId: toolId ?? this.toolId,
      targetId: targetId ?? this.targetId,
      targetTitle: targetTitle ?? this.targetTitle,
      status: status ?? this.status,
      resultMessage: resultMessage ?? this.resultMessage,
      errorMessage: errorMessage ?? this.errorMessage,
      params: params ?? this.params,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory AiActionRecord.fromJson(Map<String, dynamic> json) {
    return AiActionRecord(
      id: json['id'] as String? ?? '',
      sessionId: json['sessionId'] as String?,
      toolId: json['toolId'] as String? ?? '',
      targetId: json['targetId'] as String?,
      targetTitle: json['targetTitle'] as String?,
      status: _parseStatus(json['status'] as String? ?? ''),
      resultMessage: json['resultMessage'] as String?,
      errorMessage: json['errorMessage'] as String?,
      params: json['params'] != null
          ? Map<String, dynamic>.from(json['params'] as Map)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (sessionId != null) 'sessionId': sessionId,
      'toolId': toolId,
      if (targetId != null) 'targetId': targetId,
      if (targetTitle != null) 'targetTitle': targetTitle,
      'status': status.name,
      if (resultMessage != null) 'resultMessage': resultMessage,
      if (errorMessage != null) 'errorMessage': errorMessage,
      if (params != null) 'params': params,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static AiActionStatus _parseStatus(String value) {
    return switch (value) {
      'pending' => AiActionStatus.pending,
      'confirmed' => AiActionStatus.confirmed,
      'executed' => AiActionStatus.executed,
      'cancelled' => AiActionStatus.cancelled,
      'failed' => AiActionStatus.failed,
      _ => AiActionStatus.pending,
    };
  }
}
