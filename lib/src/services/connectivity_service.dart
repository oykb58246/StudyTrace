import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// 网络连接状态
enum ConnectivityStatus {
  online,
  offline,
  unknown,
}

/// 网络连接监控服务
class ConnectivityService {
  ConnectivityService({String? checkUrl})
      : checkUrl = checkUrl ?? _defaultCheckUrl();

  String checkUrl;
  Timer? _periodicTimer;
  ConnectivityStatus _status = ConnectivityStatus.unknown;

  final StreamController<ConnectivityStatus> _statusController =
      StreamController<ConnectivityStatus>.broadcast();

  /// 连接状态流
  Stream<ConnectivityStatus> get statusStream => _statusController.stream;

  /// 当前连接状态
  ConnectivityStatus get status => _status;

  bool get isOnline => _status == ConnectivityStatus.online;
  bool get isOffline => _status == ConnectivityStatus.offline;

  static String _defaultCheckUrl() {
    final current = Uri.base;
    if ((current.scheme == 'http' || current.scheme == 'https') &&
        current.host == 'studytrace.oykb.cn') {
      return '${current.scheme}://${current.authority}';
    }
    return 'https://studytrace.oykb.cn';
  }

  /// 开始定期检查网络状态
  void startMonitoring({Duration interval = const Duration(seconds: 30)}) {
    _periodicTimer?.cancel();
    _checkConnectivity();
    _periodicTimer = Timer.periodic(interval, (_) => _checkConnectivity());
  }

  /// 停止监控
  void stopMonitoring() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// 手动检查连接状态
  Future<ConnectivityStatus> checkNow() async {
    await _checkConnectivity();
    return _status;
  }

  Future<void> _checkConnectivity() async {
    try {
      final uri = Uri.parse(checkUrl);
      await http.head(uri).timeout(const Duration(seconds: 5));
      _updateStatus(ConnectivityStatus.online);
    } catch (_) {
      _updateStatus(ConnectivityStatus.offline);
    }
  }

  void _updateStatus(ConnectivityStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(newStatus);
      debugPrint('ConnectivityService: status changed to $newStatus');
    }
  }

  void dispose() {
    _periodicTimer?.cancel();
    _statusController.close();
  }
}
