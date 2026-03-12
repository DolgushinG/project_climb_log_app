import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../utils/app_constants.dart';
import 'connectivity_service.dart';

const String _path = '/api/app/error-report';
const String _queueKey = 'error_report_queue';
const String _sentKey = 'error_report_sent';
const Duration _dedupDuration = Duration(hours: 24);

/// Сервис для отправки отчётов об ошибках на бэкенд.
/// Очередь при офлайне, дедупликация одинаковых ошибок, автопередача при появлении сети.
class ErrorReportService {
  static final ErrorReportService _instance = ErrorReportService._();
  factory ErrorReportService() => _instance;

  ErrorReportService._() {
    ConnectivityService().isOnlineStream.listen((online) {
      if (online) _flushQueue();
    });
    // Отправить накопленную очередь при старте (если есть сеть)
    if (ConnectivityService().isOnline) _flushQueue();
  }

  String get _domain => AppConstants.domain;

  Future<Map<String, String>> _headers() async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    final token = await getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  String _dedupKey(String message, String? screen, int? eventId) {
    final m = message.length > 300 ? message.substring(0, 300) : message;
    return '${m}_${screen ?? ''}_${eventId ?? ''}';
  }

  Future<bool> _isRecentlySent(String dedupKey) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_sentKey);
    if (json == null) return false;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(json) as Map);
      final ts = map[dedupKey];
      if (ts is! num) return false;
      final sentAt = DateTime.fromMillisecondsSinceEpoch(ts.toInt());
      return DateTime.now().difference(sentAt) < _dedupDuration;
    } catch (_) {
      return false;
    }
  }

  Future<void> _markSent(String dedupKey) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_sentKey);
    Map<String, dynamic> map = {};
    if (json != null) {
      try {
        map = Map<String, dynamic>.from(jsonDecode(json) as Map);
      } catch (_) {}
    }
    final cutoff = DateTime.now().subtract(_dedupDuration).millisecondsSinceEpoch;
    map.removeWhere((_, v) => v is num && v < cutoff);
    map[dedupKey] = DateTime.now().millisecondsSinceEpoch;
    await prefs.setString(_sentKey, jsonEncode(map));
  }

  Future<void> _addToQueue(Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance();
    List<dynamic> queue = [];
    final json = prefs.getString(_queueKey);
    if (json != null) {
      try {
        queue = List.from(jsonDecode(json) as List);
      } catch (_) {}
    }
    item['created_at'] = DateTime.now().toIso8601String();
    queue.add(item);
    await prefs.setString(_queueKey, jsonEncode(queue));
  }

  Future<List<Map<String, dynamic>>> _getQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_queueKey);
    if (json == null) return [];
    try {
      return List<Map<String, dynamic>>.from(
        (jsonDecode(json) as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
    } catch (_) {
      return [];
    }
  }

  Future<void> _removeFromQueue(int index) async {
    final queue = await _getQueue();
    if (index < 0 || index >= queue.length) return;
    queue.removeAt(index);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_queueKey, jsonEncode(queue));
  }

  Future<void> _flushQueue() async {
    final queue = await _getQueue();
    for (var i = queue.length - 1; i >= 0; i--) {
      final item = queue[i];
      final msg = item['message'] as String? ?? '';
      final screen = item['screen'] as String?;
      final eventId = item['event_id'] as int?;
      final key = _dedupKey(msg, screen, eventId);
      if (await _isRecentlySent(key)) {
        await _removeFromQueue(i);
        continue;
      }
      final ok = await _sendReport(
        message: msg,
        screen: screen,
        eventId: eventId,
        stackTrace: item['stack_trace'] as String?,
        extra: item['extra'] is Map ? Map<String, dynamic>.from(item['extra'] as Map) : null,
      );
      if (ok) {
        await _markSent(key);
        await _removeFromQueue(i);
      }
    }
  }

  Future<bool> _sendReport({
    required String message,
    String? screen,
    int? eventId,
    String? stackTrace,
    Map<String, dynamic>? extra,
  }) async {
    try {
      String platform = 'unknown';
      if (kIsWeb) {
        platform = 'web';
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            platform = 'android';
            break;
          case TargetPlatform.iOS:
            platform = 'ios';
            break;
          case TargetPlatform.macOS:
            platform = 'macos';
            break;
          case TargetPlatform.windows:
            platform = 'windows';
            break;
          case TargetPlatform.linux:
            platform = 'linux';
            break;
          case TargetPlatform.fuchsia:
            platform = 'fuchsia';
            break;
          default:
            platform = 'unknown';
        }
      }

      String? appVersion;
      try {
        final info = await PackageInfo.fromPlatform();
        appVersion = '${info.version}+${info.buildNumber}';
      } catch (_) {}

      final body = <String, dynamic>{
        'message': message.length > 4000 ? message.substring(0, 4000) : message,
        'platform': platform,
      };
      if (screen != null && screen.isNotEmpty) body['screen'] = screen;
      if (eventId != null) body['event_id'] = eventId;
      if (stackTrace != null && stackTrace.isNotEmpty) {
        body['stack_trace'] = stackTrace.length > 8000 ? stackTrace.substring(0, 8000) : stackTrace;
      }
      if (appVersion != null) body['app_version'] = appVersion;
      if (extra != null && extra.isNotEmpty) body['extra'] = extra;

      final url = Uri.parse('$_domain$_path');
      final response = await http.post(
        url,
        headers: await _headers(),
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Отправляет отчёт об ошибке на сервер.
  /// При офлайне — добавляет в очередь (отправится при появлении сети).
  /// Дубликаты (та же ошибка+экран за 24ч) не отправляются.
  /// Возвращает: true — отправлено или уже было отправлено недавно, false — не удалось и добавлено в очередь.
  Future<bool> reportError({
    required String message,
    String? screen,
    int? eventId,
    String? stackTrace,
    Map<String, dynamic>? extra,
  }) async {
    final key = _dedupKey(message, screen, eventId);
    if (await _isRecentlySent(key)) {
      return true; // Уже отправляли, считаем успехом
    }

    final ok = await _sendReport(
      message: message,
      screen: screen,
      eventId: eventId,
      stackTrace: stackTrace,
      extra: extra,
    );

    if (ok) {
      await _markSent(key);
      return true;
    }

    // Сеть недоступна — в очередь
    await _addToQueue({
      'message': message,
      'screen': screen,
      'event_id': eventId,
      'stack_trace': stackTrace,
      'extra': extra ?? {},
    });
    return false;
  }
}
