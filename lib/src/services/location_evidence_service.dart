import '../models/community_evidence.dart';
import 'community_evidence_service.dart';

class LocationEvidenceService {
  LocationEvidenceService(this._community);

  final CommunityEvidenceService _community;

  Future<LocationCheckIn> confirmCheckIn({
    required String title,
    required String location,
    String? groupId,
    bool shareToGroup = false,
  }) async {
    return _community.createLocationCheckIn(
      title: title,
      address: location.trim(),
      groupId: shareToGroup ? groupId : null,
      visibility: shareToGroup ? 'group' : 'private',
      poiPayloadJson: {
        'source': 'manual',
        if (location.trim().isNotEmpty) 'campusOrRemark': location.trim(),
      },
    );
  }
}
