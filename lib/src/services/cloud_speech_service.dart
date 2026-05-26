import 'dart:convert';

import 'vivo_capability_service.dart';

class CloudSpeechService {
  CloudSpeechService(this._capabilities);

  final VivoCapabilityService _capabilities;

  Future<String> transcribeBytes(
    List<int> audioBytes, {
    String mimeType = 'audio/m4a',
    bool longForm = false,
  }) async {
    final result = await _capabilities.transcribeAudio(
      audioBase64: base64Encode(audioBytes),
      mimeType: mimeType,
      mode: longForm ? 'long' : 'short',
    );
    return result['text'] as String? ?? '';
  }
}
