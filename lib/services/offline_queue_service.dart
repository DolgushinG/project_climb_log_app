import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:login_app/main.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

const String _keyQueue = 'offline_queue_results';

/// Элемент очереди: отправка результатов по event_id.
class PendingResultsItem {
  final int eventId;
  final List<Map<String, dynamic>> results;
  final String createdAt;

  PendingResultsItem({
    required this.eventId,
    required this.results,
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'results': results,
        'createdAt': createdAt,
      };

  static PendingResultsItem fromJson(Map<String, dynamic> json) {
    final resultsRaw = json['results'];
    final List<Map<String, dynamic>> list = resultsRaw is List
        ? (resultsRaw as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList()
        : [];
    return PendingResultsItem(
      eventId: json['eventId'] as int? ?? 0,
      results: list,
      createdAt: json['createdAt'] as String?,
    );
  }
}

/// Очередь отложенной отправки результатов при офлайне.
class OfflineQueueService {
  static Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();

  static Future<List<PendingResultsItem>> _load() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_keyQueue);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>? ?? [];
      return list
          .map((e) => PendingResultsItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      if (kDebugMode) print('[OfflineQueue] parse error: $e');
      return [];
    }
  }

  static Future<void> _save(List<PendingResultsItem> items) async {
    final prefs = await _prefs;
    final list = items.map((e) => e.toJson()).toList();
    await prefs.setString(_keyQueue, jsonEncode(list));
  }

  /// Добавить в очередь отправку результатов.
  static Future<void> enqueueSendResults(int eventId, List<Map<String, dynamic>> results) async {
    final list = await _load();
    list.removeWhere((e) => e.eventId == eventId);
    list.add(PendingResultsItem(eventId: eventId, results: results));
    await _save(list);
  }

  /// Количество ожидающих отправки.
  static Future<int> get pendingCount async {
    final list = await _load();
    return list.length;
  }

  /// Попытаться отправить все элементы очереди. Возвращает количество успешно отправленных.
  static Future<int> flush() async {
    final token = await getToken();
    if (token == null) return 0;
    final list = await _load();
    if (list.isEmpty) return 0;
    int sent = 0;
    final remaining = <PendingResultsItem>[];
    for (final item in list) {
      try {
        final response = await http.post(
          Uri.parse('$DOMAIN/api/event/${item.eventId}/send/results'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'results': item.results}),
        );
        if (response.statusCode == 200) {
          sent++;
        } else {
          remaining.add(item);
        }
      } catch (_) {
        remaining.add(item);
      }
    }
    await _save(remaining);
    return sent;
  }

  /// Удалить из очереди по eventId (после успешной отправки с экрана).
  static Future<void> removeByEventId(int eventId) async {
    final list = await _load();
    list.removeWhere((e) => e.eventId == eventId);
    await _save(list);
  }
}
