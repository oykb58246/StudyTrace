class AiCapabilityTrace {
  const AiCapabilityTrace({
    required this.abilityName,
    required this.endpoint,
    required this.success,
    required this.durationMs,
    required this.requestId,
    this.model,
    this.fallback,
    this.detail,
  });

  final String abilityName;
  final String endpoint;
  final bool success;
  final int durationMs;
  final String requestId;
  final String? model;
  final String? fallback;
  final String? detail;

  factory AiCapabilityTrace.fromJson(Map<String, dynamic> json) {
    return AiCapabilityTrace(
      abilityName: json['abilityName'] as String? ?? '',
      endpoint: json['endpoint'] as String? ?? '',
      success: json['success'] as bool? ?? false,
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      requestId: json['requestId'] as String? ?? '',
      model: json['model'] as String?,
      fallback: json['fallback'] as String?,
      detail: json['detail'] as String?,
    );
  }
}

List<AiCapabilityTrace> parseCapabilityTraces(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((item) => AiCapabilityTrace.fromJson(item.cast<String, dynamic>()))
      .toList(growable: false);
}
