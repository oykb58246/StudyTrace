import 'ai_capability_trace.dart';

class GeneratedImageTask {
  const GeneratedImageTask({
    required this.taskId,
    required this.status,
    this.imagesUrl = const [],
    this.auditStatus,
    this.capabilityTraces = const [],
  });

  final String taskId;
  final String status;
  final List<String> imagesUrl;
  final String? auditStatus;
  final List<AiCapabilityTrace> capabilityTraces;

  factory GeneratedImageTask.fromJson(Map<String, dynamic> json) {
    return GeneratedImageTask(
      taskId: json['taskId'] as String? ?? '',
      status: json['status']?.toString() ?? 'submitted',
      imagesUrl: (json['imagesUrl'] as List?)
              ?.map((item) => item.toString())
              .where((item) => item.isNotEmpty)
              .toList() ??
          const [],
      auditStatus: json['auditStatus']?.toString(),
      capabilityTraces: parseCapabilityTraces(json['capabilityTraces']),
    );
  }
}

class GeneratedVideoTask {
  const GeneratedVideoTask({
    required this.taskId,
    required this.status,
    this.videosUrl = const [],
    this.coverUrl,
    this.auditStatus,
    this.capabilityTraces = const [],
  });

  final String taskId;
  final String status;
  final List<String> videosUrl;
  final String? coverUrl;
  final String? auditStatus;
  final List<AiCapabilityTrace> capabilityTraces;

  factory GeneratedVideoTask.fromJson(Map<String, dynamic> json) {
    return GeneratedVideoTask(
      taskId: json['taskId'] as String? ?? '',
      status: json['status']?.toString() ?? 'submitted',
      videosUrl: (json['videosUrl'] as List?)
              ?.map((item) => item.toString())
              .where((item) => item.isNotEmpty)
              .toList() ??
          const [],
      coverUrl: json['coverUrl']?.toString(),
      auditStatus: json['auditStatus']?.toString(),
      capabilityTraces: parseCapabilityTraces(json['capabilityTraces']),
    );
  }
}

class TranslatedTextResult {
  const TranslatedTextResult({
    required this.text,
    this.from = 'auto',
    this.to = 'en',
    this.capabilityTraces = const [],
  });

  final String text;
  final String from;
  final String to;
  final List<AiCapabilityTrace> capabilityTraces;

  factory TranslatedTextResult.fromJson(Map<String, dynamic> json) {
    return TranslatedTextResult(
      text: json['text'] as String? ?? '',
      from: json['from'] as String? ?? 'auto',
      to: json['to'] as String? ?? 'en',
      capabilityTraces: parseCapabilityTraces(json['capabilityTraces']),
    );
  }
}
