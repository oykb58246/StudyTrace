import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import 'ai_credential_service.dart';
import 'api_client.dart';
import 'local_storage_service.dart';

/// 图片文字识别服务，优先尝试在线识别，并在可用设备上回退到本机识别。
class OcrService {
  OcrService({
    LocalStorageService? storage,
    AiCredentialService? credentials,
    ApiClient? backendClient,
  }) : _backendClient = backendClient;

  final ImagePicker _picker = ImagePicker();
  final ApiClient? _backendClient;
  TextRecognizer? _recognizer;

  Future<String?> captureAndRecognize({ValueChanged<String>? onStatus}) async {
    try {
      final image = await captureImage(onStatus: onStatus);
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

  Future<XFile?> captureImage({ValueChanged<String>? onStatus}) {
    final source = _cameraCaptureSupported
        ? ImageSource.camera
        : _fallbackGallerySource(onStatus);
    return _pickImageSafely(
      source: source,
      onStatus: onStatus,
    );
  }

  ImageSource _fallbackGallerySource(ValueChanged<String>? onStatus) {
    onStatus?.call('当前设备不支持直接拍照，请从本地选择图片');
    return ImageSource.gallery;
  }

  Future<XFile?> _pickImageSafely({
    required ImageSource source,
    ValueChanged<String>? onStatus,
  }) async {
    try {
      return await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 72,
      );
    } on StateError catch (error) {
      if (source != ImageSource.camera ||
          !error.message.contains('cameraDelegate')) {
        rethrow;
      }
      onStatus?.call('当前设备不支持直接拍照，请从本地选择图片');
      return _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 72,
      );
    }
  }

  Future<XFile?> pickImageFromGallery() {
    return _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 72,
    );
  }

  Future<String?> pickAndRecognize({ValueChanged<String>? onStatus}) async {
    try {
      final image = await pickImageFromGallery();
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
      if (!_localTextRecognitionSupported) return '';
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final recognized = await _localRecognizer.processImage(inputImage);
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
    onStatus?.call('正在识别图片文字...');
    try {
      final cloudText = await _recognizeByBackend(imageFile);
      if (cloudText.trim().isNotEmpty) return cloudText.trim();
    } catch (e) {
      debugPrint('OcrService backend OCR failed: $e');
    }

    if (!_localTextRecognitionSupported) {
      onStatus?.call('图片文字暂时没有识别出来，可以手动补充要整理的内容');
      return '';
    }
    onStatus?.call('图片识别暂时不稳定，已切换本机识别');
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

  TextRecognizer get _localRecognizer {
    return _recognizer ??=
        TextRecognizer(script: TextRecognitionScript.chinese);
  }

  bool get _cameraCaptureSupported {
    if (kIsWeb) return true;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
  }

  bool get _localTextRecognitionSupported {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
  }

  void dispose() {
    final recognizer = _recognizer;
    if (recognizer == null) return;
    unawaited(_closeRecognizer(recognizer));
  }

  Future<void> _closeRecognizer(TextRecognizer recognizer) async {
    try {
      await recognizer.close();
    } on MissingPluginException catch (e) {
      debugPrint('OcrService text recognizer close skipped: ${e.message}');
    } catch (e) {
      debugPrint('OcrService text recognizer close failed: $e');
    }
  }
}
