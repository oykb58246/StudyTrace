class GroupChallenge {
  const GroupChallenge({
    required this.id,
    required this.groupId,
    required this.title,
    this.description = '',
    this.planJson = const {},
    this.coverImageUrl,
    this.status = 'active',
    this.participantCount = 0,
    this.evidenceCount = 0,
    this.createdAt,
  });

  final String id;
  final String groupId;
  final String title;
  final String description;
  final Map<String, dynamic> planJson;
  final String? coverImageUrl;
  final String status;
  final int participantCount;
  final int evidenceCount;
  final DateTime? createdAt;

  factory GroupChallenge.fromJson(Map<String, dynamic> json) {
    return GroupChallenge(
      id: json['id'] as String? ?? '',
      groupId: json['groupId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      planJson: json['planJson'] is Map
          ? Map<String, dynamic>.from(json['planJson'] as Map)
          : const {},
      coverImageUrl: json['coverImageUrl'] as String?,
      status: json['status'] as String? ?? 'active',
      participantCount: (json['participantCount'] as num?)?.toInt() ?? 0,
      evidenceCount: (json['evidenceCount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }
}

class ChallengeEvidence {
  const ChallengeEvidence({
    required this.id,
    required this.evidenceType,
    required this.title,
    this.summary = '',
    this.sourceType,
    this.sourceId,
  });

  final String id;
  final String evidenceType;
  final String title;
  final String summary;
  final String? sourceType;
  final String? sourceId;

  factory ChallengeEvidence.fromJson(Map<String, dynamic> json) {
    return ChallengeEvidence(
      id: json['id'] as String? ?? '',
      evidenceType: json['evidenceType'] as String? ?? '',
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      sourceType: json['sourceType'] as String?,
      sourceId: json['sourceId'] as String?,
    );
  }
}

class EvidencePackage {
  const EvidencePackage({
    required this.id,
    required this.title,
    this.courseName = '',
    this.description = '',
    this.metricsJson = const {},
    this.sourceRefsJson = const [],
    this.groupId,
    this.coverImageUrl,
    this.visibility = 'private',
    this.featured = false,
  });

  final String id;
  final String title;
  final String courseName;
  final String description;
  final Map<String, dynamic> metricsJson;
  final List<dynamic> sourceRefsJson;
  final String? groupId;
  final String? coverImageUrl;
  final String visibility;
  final bool featured;

  factory EvidencePackage.fromJson(Map<String, dynamic> json) {
    return EvidencePackage(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      courseName: json['courseName'] as String? ?? '',
      description: json['description'] as String? ?? '',
      metricsJson: json['metricsJson'] is Map
          ? Map<String, dynamic>.from(json['metricsJson'] as Map)
          : const {},
      sourceRefsJson:
          json['sourceRefsJson'] is List ? json['sourceRefsJson'] as List : const [],
      groupId: json['groupId'] as String?,
      coverImageUrl: json['coverImageUrl'] as String?,
      visibility: json['visibility'] as String? ?? 'private',
      featured: json['featured'] as bool? ?? false,
    );
  }
}

class LocationCheckIn {
  const LocationCheckIn({
    required this.id,
    required this.title,
    this.address = '',
    this.latitude,
    this.longitude,
    this.visibility = 'private',
    this.groupId,
    this.createdAt,
  });

  final String id;
  final String title;
  final String address;
  final double? latitude;
  final double? longitude;
  final String visibility;
  final String? groupId;
  final DateTime? createdAt;

  factory LocationCheckIn.fromJson(Map<String, dynamic> json) {
    return LocationCheckIn(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      visibility: json['visibility'] as String? ?? 'private',
      groupId: json['groupId'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }
}
