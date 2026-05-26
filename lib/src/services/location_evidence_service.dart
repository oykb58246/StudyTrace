import '../models/community_evidence.dart';
import 'community_evidence_service.dart';
import 'vivo_capability_service.dart';

class LocationEvidenceService {
  LocationEvidenceService(this._capabilities, this._community);

  final VivoCapabilityService _capabilities;
  final CommunityEvidenceService _community;

  Future<LocationCheckIn> confirmCheckIn({
    required String title,
    required String location,
    String? groupId,
    bool shareToGroup = false,
  }) async {
    final result = await _capabilities.reverseGeocode(location);
    final payload = result['result'];
    final address = payload is Map
        ? (payload['address'] ?? payload['formatted_address'] ?? '').toString()
        : '';
    final values = location.split(',');
    final latitude = values.isNotEmpty ? double.tryParse(values.first.trim()) : null;
    final longitude = values.length > 1 ? double.tryParse(values[1].trim()) : null;
    return _community.createLocationCheckIn(
      title: title,
      address: address,
      latitude: latitude,
      longitude: longitude,
      groupId: shareToGroup ? groupId : null,
      visibility: shareToGroup ? 'group' : 'private',
      poiPayloadJson: payload is Map ? Map<String, dynamic>.from(payload) : const {},
    );
  }
}
