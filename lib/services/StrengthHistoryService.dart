import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:login_app/models/StrengthAchievement.dart';
import 'package:login_app/models/StrengthMeasurementSession.dart';

/// Сервис истории замеров. Хранит сессии локально (до бэкенда).
class StrengthHistoryService {
  static const String _keyHistory = 'strength_measurement_history';
  static const int _maxSessions = 100;

  /// Сохранить текущий замер как новую сессию.
  Future<void> saveSession(StrengthMetrics m) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final session = StrengthMeasurementSession(date: dateStr, metrics: m);
    final list = await getHistory();
    list.insert(0, session);
    final limited = list.take(_maxSessions).toList();

    final jsonList = limited.map((s) => s.toJson()).toList();
    await prefs.setString(_keyHistory, jsonEncode(jsonList));
  }

  /// Получить все сессии (от новых к старым).
  Future<List<StrengthMeasurementSession>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyHistory);
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List<dynamic>?;
      if (list == null) return [];
      return list
          .map((e) => StrengthMeasurementSession.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Последняя сессия (для показа «прошлый раз»).
  Future<StrengthMeasurementSession?> getLastSession() async {
    final list = await getHistory();
    return list.isNotEmpty ? list.first : null;
  }

  /// Сессия по дате (для сравнения).
  Future<StrengthMeasurementSession?> getSessionByDate(String date) async {
    final list = await getHistory();
    try {
      return list.firstWhere((s) => s.date == date);
    } catch (_) {
      return null;
    }
  }
}
