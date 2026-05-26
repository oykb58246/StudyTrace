import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import 'ai_credential_service.dart';
import 'api_client.dart';
import 'local_storage_service.dart';

/// OCR text recognition service. It prefers backend vivo OCR and falls back to MLKit.
class OcrService {
  OcrService({
    LocalStorageService? storage,
    AiCredentialService? credentials,
    ApiClient? backendClient,
  })  : _storage = storage ?? LocalStorageService(),
        _credentials = credentials ?? AiCredentialService(),
        _backendClient = backendClient;

  final ImagePicker _picker = ImagePicker();
  final LocalStorageService _storage;
  final AiCredentialService _credentials;
  final ApiClient? _backendClient;
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.chinese);

  Future<String?> captureAndRecognize({ValueChanged<String>? onStatus}) async {
    try {
      final image = await captureImage();
      if (image == null) return null;
      return await recognizeImageWithCloudFallback(
        image,
        onStatus: onStatus,
      );
    } catch (e) {
      debugPrint('OcrService captureAndRecognize failed: $e');
      return null;
    }
  }

  Future<XFile?> captureImage() {
    return _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 72,
    );
  }

  Future<String?> pickAndRecognize({ValueChanged<String>? onStatus}) async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 72,
      );
      if (image == null) return null;
      return await recognizeImageWithCloudFallback(
        image,
        onStatus: onStatus,
      );
    } catch (e) {
      debugPrint('OcrService pickAndRecognize failed: $e');
      return null;
    }
  }

  Future<String> recognizeImage(XFile imageFile) async {
    try {
      if (kIsWeb) return '';
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final recognized = await _recognizer.processImage(inputImage);
      return recognized.text;
    } catch (e) {
      debugPrint('OcrService recognizeImage failed: $e');
      return '';
    }
  }

  Future<String> recognizeImageWithCloudFallback(
    XFile imageFile, {
    ValueChanged<String>? onStatus,
  }) async {
    onStatus?.call('正在调用 vivo OCR...');
    try {
      final cloudText = await _recognizeByBackend(imageFile);
      if (cloudText.trim().isNotEmpty) return cloudText.trim();
    } catch (e) {
      debugPrint('OcrService backend OCR failed: $e');
    }

    onStatus?.call('云端 OCR 失败，已切换本地识别');
    return recognizeImage(imageFile);
  }

  Future<String> _recognizeByBackend(XFile imageFile) async {
    final backend = _backendClient;
    if (backend == null) return '';
    final bytes = await imageFile.readAsBytes();
    final data = await backend.postJson(
      '/ai/ocr',
      body: {'imageBase64': base64Encode(bytes)},
    );
    return data['text']?.toString() ?? '';
  }

  void dispose() {
    _recognizer.close();
  }
}
