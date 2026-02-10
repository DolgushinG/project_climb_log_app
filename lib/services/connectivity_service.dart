import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Сервис проверки подключения к интернету и поток его изменений.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._();
  factory ConnectivityService() => _instance;

  ConnectivityService._() {
    _subscription = Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
    _init();
  }

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final _isOnlineController = StreamController<bool>.broadcast();
  bool _lastOnline = true;

  /// Стрим: true — есть подключение, false — офлайн.
  Stream<bool> get isOnlineStream => _isOnlineController.stream;

  /// Текущее значение (после хотя бы одной проверки).
  bool get isOnline => _lastOnline;

  Future<void> _init() async {
    try {
      final result = await Connectivity().checkConnectivity();
      _lastOnline = _anyConnection(result);
      _isOnlineController.add(_lastOnline);
    } catch (e) {
      if (kDebugMode) {
        print('[ConnectivityService] init error: $e');
      }
      _lastOnline = true;
      _isOnlineController.add(true);
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> result) {
    final online = _anyConnection(result);
    if (online != _lastOnline) {
      _lastOnline = online;
      _isOnlineController.add(online);
    }
  }

  static bool _anyConnection(List<ConnectivityResult> result) {
    if (result.isEmpty) return false;
    return result.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet);
  }

  /// Явная проверка сейчас.
  Future<bool> checkNow() async {
    try {
      final result = await Connectivity().checkConnectivity();
      _lastOnline = _anyConnection(result);
      _isOnlineController.add(_lastOnline);
      return _lastOnline;
    } catch (_) {
      return _lastOnline;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _isOnlineController.close();
  }
}
