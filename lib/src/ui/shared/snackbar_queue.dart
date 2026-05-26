import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

/// 全局 Snackbar 队列，避免连续 AI 动作时多条提示互相覆盖。
///
/// 典型用法：
/// ```dart
/// SnackBarQueue.of(context).enqueue('已打开计时器');
/// ```
/// 也支持自定义 SnackBar：
/// ```dart
/// SnackBarQueue.of(context).enqueueSnackBar(SnackBar(content: ...));
/// ```
class SnackBarQueue {
  SnackBarQueue._();

  static final SnackBarQueue _instance = SnackBarQueue._();
  static SnackBarQueue of(BuildContext _) => _instance;
  static SnackBarQueue get instance => _instance;

  final Queue<_QueuedSnack> _queue = Queue();
  bool _isShowing = false;

  void enqueue(
    String message, {
    Duration duration = const Duration(seconds: 2),
    Color? backgroundColor,
    SnackBarAction? action,
    ScaffoldMessengerState? messenger,
  }) {
    enqueueSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        backgroundColor: backgroundColor,
        action: action,
      ),
      messenger: messenger,
    );
  }

  void enqueueSnackBar(
    SnackBar snackBar, {
    ScaffoldMessengerState? messenger,
  }) {
    _queue.add(_QueuedSnack(snackBar: snackBar, messenger: messenger));
    _pump();
  }

  void _pump() {
    if (_isShowing) return;
    if (_queue.isEmpty) return;
    final next = _queue.removeFirst();
    final messenger = next.messenger ?? _currentMessenger();
    if (messenger == null) {
      // 消息没找到 messenger 就丢掉，避免死循环
      _pump();
      return;
    }
    _isShowing = true;
    final controller = messenger.showSnackBar(next.snackBar);
    controller.closed.then((_) {
      _isShowing = false;
      _pump();
    });
  }

  /// 清空待显示队列（用户切页后 snackbar 可能无意义）
  void clear() {
    _queue.clear();
  }

  // 使用全局 Navigator key 获取最新的 messenger。调用方没有传入时的兜底。
  ScaffoldMessengerState? _currentMessenger() {
    final ctx = _scaffoldMessengerKey?.currentState;
    return ctx;
  }

  static GlobalKey<ScaffoldMessengerState>? _scaffoldMessengerKey;

  /// App 启动时调用：`SnackBarQueue.attachMessengerKey(globalKey)`
  static void attachMessengerKey(GlobalKey<ScaffoldMessengerState> key) {
    _scaffoldMessengerKey = key;
  }
}

class _QueuedSnack {
  const _QueuedSnack({required this.snackBar, this.messenger});

  final SnackBar snackBar;
  final ScaffoldMessengerState? messenger;
}
