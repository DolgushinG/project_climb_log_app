import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:login_app/models/ClimbingLog.dart';

/// Очередь офлайн-данных: замеры, тренировки, выполнения упражнений.
/// Сохранение сначала локально, отправка при наличии сети; при ошибке — в очередь.
class PendingSyncService {
  static const String _keyStrengthTests = 'pending_sync_strength_tests';
  static const String _keyClimbingSessions = 'pending_sync_climbing_sessions';
  static const String _keyExerciseCompletions = 'pending_sync_exercise_completions';

  static Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();

  // --- Замеры силы ---

  static Future<void> addPendingStrengthTest(Map<String, dynamic> body) async {
    final prefs = await _prefs;
    final list = await _getPendingStrengthTestsRaw(prefs);
    list.add(body);
    await prefs.setString(_keyStrengthTests, jsonEncode(list));
  }

  static Future<List<Map<String, dynamic>>> getPendingStrengthTests() async {
    final prefs = await _prefs;
    return _getPendingStrengthTestsRaw(prefs);
  }

  static Future<List<Map<String, dynamic>>> _getPendingStrengthTestsRaw(
      SharedPreferences prefs) async {
    final raw = prefs.getString(_keyStrengthTests);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>?;
      if (list == null) return [];
      return list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> removePendingStrengthTestAt(int index) async {
    final prefs = await _prefs;
    final list = await _getPendingStrengthTestsRaw(prefs);
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      await prefs.setString(_keyStrengthTests, jsonEncode(list));
    }
  }

  // --- Тренировки (лазание) ---

  static Future<void> addPendingClimbingSession(
    Map<String, dynamic> requestJson, {
    String? gymName,
  }) async {
    final prefs = await _prefs;
    final list = await _getPendingClimbingSessionsRaw(prefs);
    list.add({'request': requestJson, 'gym_name': gymName ?? ''});
    await prefs.setString(_keyClimbingSessions, jsonEncode(list));
  }

  static Future<List<Map<String, dynamic>>> getPendingClimbingSessions() async {
    final prefs = await _prefs;
    return _getPendingClimbingSessionsRaw(prefs);
  }

  static Future<List<Map<String, dynamic>>> _getPendingClimbingSessionsRaw(
      SharedPreferences prefs) async {
    final raw = prefs.getString(_keyClimbingSessions);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>?;
      if (list == null) return [];
      return list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> removePendingClimbingSessionAt(int index) async {
    final prefs = await _prefs;
    final list = await _getPendingClimbingSessionsRaw(prefs);
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      await prefs.setString(_keyClimbingSessions, jsonEncode(list));
    }
  }

  /// Удалить одну pending-сессию по совпадению запроса (дата + маршруты).
  static Future<void> removePendingClimbingSessionMatching(
      Map<String, dynamic> requestJson) async {
    final prefs = await _prefs;
    final list = await _getPendingClimbingSessionsRaw(prefs);
    final date = requestJson['date'] as String?;
    final routes = requestJson['routes'] as List<dynamic>?;
    if (date == null) return;
    final idx = list.indexWhere((item) {
      final req = item['request'] as Map<String, dynamic>?;
      if (req == null) return false;
      if (req['date'] != date) return false;
      final r = req['routes'] as List<dynamic>?;
      if (routes == null && r == null) return true;
      if (routes == null || r == null || routes.length != r.length) return false;
      for (var i = 0; i < routes.length; i++) {
        final a = routes[i] as Map?;
        final b = r[i] as Map?;
        if (a?['grade'] != b?['grade'] || a?['count'] != b?['count']) return false;
      }
      return true;
    });
    if (idx >= 0) {
      list.removeAt(idx);
      await prefs.setString(_keyClimbingSessions, jsonEncode(list));
    }
  }

  /// Преобразовать pending-сессии в HistorySession для отображения в истории.
  static Future<List<HistorySession>> getPendingClimbingSessionsAsHistory() async {
    final list = await getPendingClimbingSessions();
    final result = <HistorySession>[];
    for (final item in list) {
      final req = item['request'] as Map<String, dynamic>?;
      if (req == null) continue;
      final routes = (req['routes'] as List<dynamic>?)
          ?.map((e) => HistoryRoute.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList() ?? [];
      final gymName = item['gym_name'] as String? ?? 'Будет синхронизировано';
      result.add(HistorySession(
        id: null,
        date: req['date'] as String? ?? '',
        gymName: gymName.isEmpty ? 'Будет синхронизировано' : gymName,
        gymId: req['gym_id'] as int?,
        routes: routes,
      ));
    }
    return result;
  }

  // --- Выполнения упражнений ---

  static Future<void> addPendingExerciseCompletion({
    required String date,
    required String exerciseId,
    int setsDone = 1,
    double? weightKg,
    String notes = '',
  }) async {
    final prefs = await _prefs;
    final list = await getAllPendingExerciseCompletionsRaw();
    list.add({
      'date': date,
      'exercise_id': exerciseId,
      'sets_done': setsDone,
      if (weightKg != null) 'weight_kg': weightKg,
      'notes': notes,
    });
    await prefs.setString(_keyExerciseCompletions, jsonEncode(list));
  }

  static Future<List<Map<String, dynamic>>> getPendingExerciseCompletionsForDate(
      String date) async {
    final all = await getAllPendingExerciseCompletionsRaw();
    return all.where((e) => e['date'] == date).toList();
  }

  /// Все pending completions (для синхронизации).
  static Future<List<Map<String, dynamic>>> getAllPendingExerciseCompletionsRaw() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_keyExerciseCompletions);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>?;
      if (list == null) return [];
      return list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> removePendingExerciseCompletion(
      String date, String exerciseId) async {
    final prefs = await _prefs;
    final list = await getAllPendingExerciseCompletionsRaw();
    list.removeWhere((e) =>
        e['date'] == date && e['exercise_id'] == exerciseId);
    await prefs.setString(_keyExerciseCompletions, jsonEncode(list));
  }

  static Future<bool> hasPendingData() async {
    final st = await getPendingStrengthTests();
    final cs = await getPendingClimbingSessions();
    final ec = await getAllPendingExerciseCompletionsRaw();
    return st.isNotEmpty || cs.isNotEmpty || ec.isNotEmpty;
  }
}
