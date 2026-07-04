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
    final data = _objectMap(json['data']);
    return GeneratedImageTask(
      taskId: _firstString([
        json['taskId'],
        json['task_id'],
        json['traceId'],
        json['trace_id'],
        json['provider_request_id'],
        data?['taskId'],
        data?['task_id'],
        data?['traceId'],
        data?['trace_id'],
        data?['provider_request_id'],
      ]),
      status: _firstNullableString([json['status'], data?['status']]) ??
          'submitted',
      imagesUrl: _extractUrlList([
        json,
        json['imagesUrl'],
        json['images_url'],
        json['imageUrl'],
        json['image_url'],
        json['image'],
        json['url'],
        json['urls'],
        json['images'],
        json['output'],
        json['result'],
        json['content'],
        data,
        data?['imagesUrl'],
        data?['images_url'],
        data?['imageUrl'],
        data?['image_url'],
        data?['image'],
        data?['url'],
        data?['urls'],
        data?['images'],
        data?['output'],
        data?['result'],
        data?['content'],
      ]),
      auditStatus: _firstNullableString([
        json['auditStatus'],
        json['audit_status'],
        json['finish_reason'],
        data?['auditStatus'],
        data?['audit_status'],
        data?['finish_reason'],
      ]),
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
    final data = _objectMap(json['data']);
    return GeneratedVideoTask(
      taskId: _firstString([
        json['taskId'],
        json['task_id'],
        json['traceId'],
        json['trace_id'],
        json['provider_request_id'],
        data?['taskId'],
        data?['task_id'],
        data?['traceId'],
        data?['trace_id'],
        data?['provider_request_id'],
      ]),
      status: _firstNullableString([json['status'], data?['status']]) ??
          'submitted',
      videosUrl: _extractUrlList([
        json,
        json['videosUrl'],
        json['videos_url'],
        json['videoUrl'],
        json['video_url'],
        json['video'],
        json['url'],
        json['urls'],
        json['videos'],
        json['output'],
        json['result'],
        json['content'],
        data,
        data?['videosUrl'],
        data?['videos_url'],
        data?['videoUrl'],
        data?['video_url'],
        data?['video'],
        data?['url'],
        data?['urls'],
        data?['videos'],
        data?['output'],
        data?['result'],
        data?['content'],
      ]),
      coverUrl: _firstNullableString([
        json['coverUrl'],
        json['cover_url'],
        data?['coverUrl'],
        data?['cover_url'],
      ]),
      auditStatus: _firstNullableString([
        json['auditStatus'],
        json['audit_status'],
        json['finish_reason'],
        data?['auditStatus'],
        data?['audit_status'],
        data?['finish_reason'],
      ]),
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

Map<String, dynamic>? _objectMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return null;
}

String _firstString(List<dynamic> values) => _firstNullableString(values) ?? '';

String? _firstNullableString(List<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return null;
}

List<String> _extractUrlList(List<dynamic> values) {
  final urls = <String>[];
  void add(dynamic value) {
    if (value == null) return;
    if (value is List) {
      for (final item in value) {
        add(item);
      }
      return;
    }
    if (value is Map) {
      for (final key in const [
        'url',
        'uri',
        'urls',
        'image',
        'images',
        'imageUrl',
        'image_url',
        'imageURL',
        'imageUrls',
        'image_urls',
        'video',
        'videos',
        'videoUrl',
        'video_url',
        'videoURL',
        'videoUrls',
        'video_urls',
        'coverUrl',
        'cover_url',
        'downloadUrl',
        'download_url',
        'fileUrl',
        'file_url',
        'outputUrl',
        'output_url',
        'result',
        'data',
        'content',
        'output',
        'outputs',
        'resources',
        'items',
      ]) {
        add(value[key]);
      }
      return;
    }
    final text = value.toString().trim();
    if (text.isEmpty) return;
    final matches = RegExp(
      r"""(?:https?://|data:image/|file://)[^\s"'<>\])}]+""",
      caseSensitive: false,
    ).allMatches(text);
    if (matches.isEmpty) {
      if (_looksLikeMediaUrl(text) && !urls.contains(text)) urls.add(text);
      return;
    }
    for (final match in matches) {
      final url = match.group(0)?.trim() ?? '';
      if (url.isNotEmpty && !urls.contains(url)) urls.add(url);
    }
  }

  for (final value in values) {
    add(value);
  }
  return urls;
}

bool _looksLikeMediaUrl(String value) {
  final uri = Uri.tryParse(value);
  final scheme = uri?.scheme.toLowerCase() ?? '';
  return scheme == 'http' || scheme == 'https' || scheme == 'data' || scheme == 'file';
}
