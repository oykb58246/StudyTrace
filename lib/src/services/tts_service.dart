import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// TTS 朗读服务封装。
///
/// - 懒初始化 `FlutterTts`
/// - `speak(text)` 返回一个 Future，朗读完成才 resolve（基于 `setCompletionHandler`）
/// - 不支持 TTS 的平台（如 Linux 部分环境）静默降级为 no-op
class TtsService {
  TtsService();

  FlutterTts? _tts;
  bool _initialized = false;
  bool _available = true;
  bool _speaking = false;
  Completer<void>? _completion;
  Completer<void>? _cancelCompletion;

  bool get isSpeaking => _speaking;
  bool get isAvailable => _available;

  Future<void> _ensureInit({
    String language = 'zh-CN',
    double rate = 0.5,
  }) async {
    if (_initialized) return;
    try {
      _tts = FlutterTts();
      await _tts!.setLanguage(language);
      await _tts!.setSpeechRate(rate);
      await _tts!.setVolume(1.0);
      await _tts!.setPitch(1.0);
      _tts!.setCompletionHandler(() {
        _speaking = false;
        _completion?.complete();
      });
      _tts!.setErrorHandler((msg) {
        debugPrint('TtsService error: $msg');
        _speaking = false;
        _completion?.complete();
      });
      _tts!.setCancelHandler(() {
        _speaking = false;
        _cancelCompletion?.complete();
        _completion?.complete();
      });
      _initialized = true;
    } catch (e) {
      debugPrint('TtsService init failed: $e');
      _available = false;
    }
  }

  /// 朗读一段文字。朗读结束才 resolve。
  /// 如果传入空或超限文本会被截断到 800 字。
  Future<void> speak(
    String text, {
    String language = 'zh-CN',
    double rate = 0.5,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await _ensureInit(language: language, rate: rate);
    if (!_available || _tts == null) return;

    // 避免 TTS 朗读过长文本阻塞
    final content = trimmed.length > 800
        ? '${trimmed.substring(0, 800)}，余下省略。'
        : trimmed;
    // 如果正在朗读，先停掉
    if (_speaking) {
      await stop();
    }
    try {
      await _tts!.setLanguage(language);
      await _tts!.setSpeechRate(rate);
    } catch (_) {}
    _completion = Completer<void>();
    _speaking = true;
    try {
      await _tts!.speak(content);
    } catch (e) {
      debugPrint('TtsService speak failed: $e');
      _speaking = false;
      _completion?.complete();
    }
    return _completion!.future;
  }

  /// 打断当前朗读。
  Future<void> stop() async {
    if (!_initialized || _tts == null) return;
    if (!_speaking) return;
    _cancelCompletion = Completer<void>();
    try {
      await _tts!.stop();
    } catch (_) {}
    // 有些平台 cancelHandler 不触发，兜底 200ms 超时
    await Future.any([
      _cancelCompletion!.future,
      Future.delayed(const Duration(milliseconds: 300)),
    ]);
    _speaking = false;
  }

  Future<void> dispose() async {
    try {
      await _tts?.stop();
    } catch (_) {}
    _tts = null;
    _initialized = false;
    _speaking = false;
  }
}
