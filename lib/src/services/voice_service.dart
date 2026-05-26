import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

/// 语音识别服务，封装 speech_to_text
class VoiceService {
  VoiceService();

  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

  final StreamController<String> _partialController =
      StreamController<String>.broadcast();
  final StreamController<String> _resultController =
      StreamController<String>.broadcast();
  final StreamController<bool> _listeningController =
      StreamController<bool>.broadcast();

  /// 部分识别结果流（实时）
  Stream<String> get partialResults => _partialController.stream;

  /// 最终识别结果流
  Stream<String> get finalResults => _resultController.stream;

  /// 监听状态流
  Stream<bool> get listeningState => _listeningController.stream;

  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;

  /// 初始化语音识别引擎
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      _isInitialized = await _speech.initialize(
        onError: (error) {
          debugPrint('VoiceService error: ${error.errorMsg}');
          _isListening = false;
          _listeningController.add(false);
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            _listeningController.add(false);
          }
        },
      );
    } catch (e) {
      debugPrint('VoiceService init failed: $e');
      _isInitialized = false;
    }
    return _isInitialized;
  }

  /// 开始语音识别
  Future<bool> startListening({
    String localeId = 'zh_CN',
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return false;
    }
    if (_isListening) return true;

    try {
      await _speech.listen(
        onResult: _onResult,
        localeId: localeId,
        listenFor: listenFor,
        pauseFor: pauseFor,
        listenMode: ListenMode.dictation,
        cancelOnError: true,
      );
      _isListening = true;
      _listeningController.add(true);
      return true;
    } catch (e) {
      debugPrint('VoiceService startListening failed: $e');
      return false;
    }
  }

  /// 停止语音识别
  Future<void> stopListening() async {
    if (!_isListening) return;
    try {
      await _speech.stop();
    } catch (_) {}
    _isListening = false;
    _listeningController.add(false);
  }

  /// 取消语音识别
  Future<void> cancelListening() async {
    if (!_isListening) return;
    try {
      await _speech.cancel();
    } catch (_) {}
    _isListening = false;
    _listeningController.add(false);
  }

  void _onResult(SpeechRecognitionResult result) {
    if (result.recognizedWords.isNotEmpty) {
      _partialController.add(result.recognizedWords);
      if (result.finalResult) {
        _resultController.add(result.recognizedWords);
      }
    }
  }

  void dispose() {
    _speech.stop();
    _partialController.close();
    _resultController.close();
    _listeningController.close();
  }
}
