import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../main.dart';
import '../models/AppConfig.dart';

/// Загружает конфиг/фича-флаги с бэкенда.
/// Без кэша: при каждом входе в приложение — свежий запрос. true → показать AI Тренер, false → скрыть.
class AppConfigService {
  static final AppConfigService _instance = AppConfigService._();
  factory AppConfigService() => _instance;

  AppConfigService._();

  Future<AppConfig>? _fetchInProgress;

  /// Получить конфиг. Всегда запрос к API (без кэша).
  Future<AppConfig> getConfig({bool forceRefresh = false}) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      return AppConfig.fallback;
    }

    if (_fetchInProgress != null) {
      return _fetchInProgress!;
    }

    final future = _fetch();
    _fetchInProgress = future;
    try {
      return await future;
    } finally {
      _fetchInProgress = null;
    }
  }

  Future<AppConfig> _fetch() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      return AppConfig.fallback;
    }

    try {
      final url = Uri.parse('$DOMAIN/api/app/config');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          if (kDebugMode) {
            debugPrint('[AppConfig] aiCoachEnabled=${AppConfig.fromJson(data).aiCoachEnabled}');
          }
          return AppConfig.fromJson(data);
        }
      }
    } catch (_) {}

    return AppConfig.fallback;
  }

  void invalidateCache() {
    _fetchInProgress = null;
  }

  Future<void> clearCacheStorage() async {
    invalidateCache();
  }
}
