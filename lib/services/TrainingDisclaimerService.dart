import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:login_app/main.dart';

/// Сервис подтверждения ознакомления с дисклеймером плана и тренировок.
/// Сохраняет локально (SharedPreferences) и отправляет на бэкенд.
class TrainingDisclaimerService {
  static const String _prefsKey = 'training_disclaimer_acknowledged';

  Future<String?> _getToken() => getToken();

  Map<String, String> _headers(String? token) => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  /// Проверяет, подтвердил ли пользователь дисклеймер.
  /// Сначала локально, при переустановке — запрос на бэкенд.
  Future<bool> isAcknowledged() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefsKey) == true) return true;

    final token = await _getToken();
    if (token == null) return false;

    try {
      final response = await http.get(
        Uri.parse('$DOMAIN/api/climbing-logs/training-disclaimer-acknowledged'),
        headers: _headers(token),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        final ack = json?['acknowledged'] == true || json?['acknowledged_at'] != null;
        if (ack) {
          await prefs.setBool(_prefsKey, true);
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// Сохраняет подтверждение локально и отправляет на бэкенд.
  /// Возвращает true при успехе (локально или API).
  Future<bool> acknowledge() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);

    final token = await _getToken();
    if (token == null) return true;

    try {
      final response = await http.post(
        Uri.parse('$DOMAIN/api/climbing-logs/training-disclaimer-acknowledged'),
        headers: _headers(token),
        body: jsonEncode({
          'acknowledged': true,
          'acknowledged_at': DateTime.now().toUtc().toIso8601String(),
        }),
      );
      return response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204;
    } catch (_) {
      return true; // Локально сохранено — пользователь может продолжить
    }
  }
}
