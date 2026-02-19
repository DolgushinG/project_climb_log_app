import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:login_app/main.dart';
import 'package:login_app/models/ClimbingLog.dart';
import 'package:login_app/utils/session_error_helper.dart';
import 'package:login_app/models/Gym.dart';

/// Сервис API трекера трасс Climbing Log.
/// Все методы с авторизацией требуют Bearer token.
class ClimbingLogService {
  ClimbingLogService();

  Future<String?> _getToken() => getToken();

  static const _historyCacheTtl = Duration(seconds: 60);
  static const _gradesCacheTtl = Duration(hours: 1);
  static List<HistorySession>? _historyCache;
  static DateTime? _historyCacheTime;
  static List<String>? _gradesCache;
  static DateTime? _gradesCacheTime;
  static GradesResponse? _gradesWithGroupsCache;
  static DateTime? _gradesWithGroupsCacheTime;

  static void _invalidateHistoryCache() {
    _historyCache = null;
    _historyCacheTime = null;
  }

  /// Инвалидирует весь in-memory кэш (история, грейды). Вызывать при выходе из аккаунта.
  static void invalidateAllCaches() {
    _historyCache = null;
    _historyCacheTime = null;
    _gradesCache = null;
    _gradesCacheTime = null;
    _gradesWithGroupsCache = null;
    _gradesWithGroupsCacheTime = null;
  }

  static const _gradesFallback = ['5', '6A', '6A+', '6B', '6B+', '6C', '6C+', '7A', '7A+', '7B', '7B+', '7C', '7C+', '8A+'];
  static final GradesResponse _gradesWithGroupsFallback = GradesResponse(
    grades: _gradesFallback,
    gradeGroups: {
      '6A-6C+': ['6A', '6A+', '6B', '6B+', '6C', '6C+'],
      '7A-7C+': ['7A', '7A+', '7B', '7B+', '7C', '7C+'],
      '8A-8C+': ['8A', '8A+', '8B', '8B+', '8C', '8C+'],
    },
  );

  Future<List<String>> getGrades() async {
    final now = DateTime.now();
    if (_gradesCache != null &&
        _gradesCacheTime != null &&
        now.difference(_gradesCacheTime!) < _gradesCacheTtl) {
      return _gradesCache!;
    }
    try {
      final response = await http.get(
        Uri.parse('$DOMAIN/api/climbing-logs/grades'),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        if (json != null) {
          final resp = GradesResponse.fromJson(json);
          _gradesCache = resp.grades;
          _gradesCacheTime = now;
          return resp.grades;
        }
      }
    } catch (_) {}
    return _gradesFallback;
  }

  Future<GradesResponse> getGradesWithGroups() async {
    final now = DateTime.now();
    if (_gradesWithGroupsCache != null &&
        _gradesWithGroupsCacheTime != null &&
        now.difference(_gradesWithGroupsCacheTime!) < _gradesCacheTtl) {
      return _gradesWithGroupsCache!;
    }
    try {
      final response = await http.get(
        Uri.parse('$DOMAIN/api/climbing-logs/grades'),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        if (json != null) {
          final resp = GradesResponse.fromJson(json);
          _gradesWithGroupsCache = resp;
          _gradesWithGroupsCacheTime = now;
          _gradesCache = resp.grades;
          _gradesCacheTime = now;
          return resp;
        }
      }
    } catch (_) {}
    return _gradesWithGroupsFallback;
  }

  Future<bool> saveSession(ClimbingSessionRequest request) async {
    _invalidateHistoryCache();
    final token = await _getToken();
    if (token == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$DOMAIN/api/climbing-logs'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(request.toJson()),
      );
      if (await redirectIfUnauthorized(response.statusCode)) return false;
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Обновить сессию. Требует id в истории от бэкенда.
  Future<bool> updateSession(int id, ClimbingSessionRequest request) async {
    _invalidateHistoryCache();
    final token = await _getToken();
    if (token == null) return false;
    try {
      final response = await http.put(
        Uri.parse('$DOMAIN/api/climbing-logs/$id'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(request.toJson()),
      );
      if (await redirectIfUnauthorized(response.statusCode)) return false;
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Удалить сессию.
  Future<bool> deleteSession(int id) async {
    _invalidateHistoryCache();
    final token = await _getToken();
    if (token == null) return false;
    try {
      final response = await http.delete(
        Uri.parse('$DOMAIN/api/climbing-logs/$id'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (await redirectIfUnauthorized(response.statusCode)) return false;
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Залы, на которых пользователь уже тренировался (для подсказок).
  Future<List<UsedGym>> getUsedGyms() async {
    final token = await _getToken();
    if (token == null) return [];
    try {
      final response = await http.get(
        Uri.parse('$DOMAIN/api/climbing-logs/used-gyms'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (await redirectIfUnauthorized(response.statusCode)) return [];
      if (response.statusCode == 200) {
        final raw = jsonDecode(response.body);
        if (raw is List && raw.isNotEmpty) {
          return raw
              .map((e) =>
                  UsedGym.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      }
    } catch (_) {}
    return _buildUsedGymsFromHistory(await getHistory());
  }

  List<UsedGym> _buildUsedGymsFromHistory(List<HistorySession> sessions) {
    final seen = <int>{};
    final result = <UsedGym>[];
    for (final s in sessions) {
      if (s.gymId != null && s.gymId! > 0 && !seen.contains(s.gymId)) {
        seen.add(s.gymId!);
        result.add(UsedGym(
          id: s.gymId!,
          name: s.gymName.replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '').trim(),
          city: null,
          lastUsed: s.date,
        ));
      }
    }
    return result;
  }

  Future<ClimbingProgress?> getProgress() async {
    final token = await _getToken();
    if (token == null) return null;
    try {
      final response = await http.get(
        Uri.parse('$DOMAIN/api/climbing-logs/progress'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (await redirectIfUnauthorized(response.statusCode)) return null;
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        if (json != null) return ClimbingProgress.fromJson(json);
      }
    } catch (_) {}
    return null;
  }

  /// Сводка для экрана «Обзор».
  Future<ClimbingLogSummary?> getSummary({String period = 'all'}) async {
    final token = await _getToken();
    if (token == null) return null;
    try {
      final uri = Uri.parse('$DOMAIN/api/climbing-logs/summary').replace(
        queryParameters: {'period': period},
      );
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (await redirectIfUnauthorized(response.statusCode)) return null;
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        if (json != null) return ClimbingLogSummary.fromJson(json);
      }
    } catch (_) {}
    return null;
  }

  /// Статистика для графиков.
  Future<ClimbingLogStatistics?> getStatistics({
    String groupBy = 'week',
    int periodDays = 56,
  }) async {
    final token = await _getToken();
    if (token == null) return null;
    try {
      final uri = Uri.parse('$DOMAIN/api/climbing-logs/statistics').replace(
        queryParameters: {
          'group_by': groupBy,
          'period_days': periodDays.toString(),
        },
      );
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (await redirectIfUnauthorized(response.statusCode)) return null;
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        if (json != null) return ClimbingLogStatistics.fromJson(json);
      }
    } catch (_) {}
    return null;
  }

  /// Рекомендации.
  Future<List<ClimbingLogRecommendation>> getRecommendations() async {
    final token = await _getToken();
    if (token == null) return [];
    try {
      final response = await http.get(
        Uri.parse('$DOMAIN/api/climbing-logs/recommendations'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (await redirectIfUnauthorized(response.statusCode)) return [];
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        if (json != null) {
          final raw = json['recommendations'] as List<dynamic>? ?? [];
          return raw
              .map((e) =>
                  ClimbingLogRecommendation.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// История сессий. Кэш 60 сек — снижает нагрузку при повторных запросах (план, день и т.д.).
  Future<List<HistorySession>> getHistory() async {
    final now = DateTime.now();
    if (_historyCache != null &&
        _historyCacheTime != null &&
        now.difference(_historyCacheTime!) < _historyCacheTtl) {
      return _historyCache!;
    }
    final token = await _getToken();
    if (token == null) return [];
    try {
      final response = await http.get(
        Uri.parse('$DOMAIN/api/climbing-logs/history'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (await redirectIfUnauthorized(response.statusCode)) return [];
      if (response.statusCode == 200) {
        final raw = jsonDecode(response.body);
        if (raw is List) {
          final list = raw
              .map((e) =>
                  HistorySession.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          _historyCache = list;
          _historyCacheTime = now;
          return list;
        }
      }
    } catch (_) {}
    return [];
  }

  /// Сессия лазания за указанную дату (YYYY-MM-DD). Для связи плана с лазанием.
  Future<HistorySession?> getSessionForDate(String date) async {
    final list = await getHistory();
    try {
      return list.firstWhere((s) => s.date == date);
    } catch (_) {
      return null;
    }
  }
}
