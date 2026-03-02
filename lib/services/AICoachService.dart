import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ChatMessage.dart';
import '../utils/app_constants.dart';

/// Сервис для взаимодействия с AI-тренером через backend.
class AICoachService {
  static const String _endpoint = '/api/ai/chat';
  static const String _historyKey = 'ai_coach_history';

  /// Отправляет сообщение в AI и возвращает ответ.
  /// context: можно передать дополнительные данные (силовые измерения, планы и т.д.)
  Future<ChatMessage> sendMessage(String message, {Map<String, dynamic>? context}) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Unauthorized: no token');
    }

    // Собираем историю диалога из кэша/SharedPreferences
    final history = await _getLocalHistory();

    // Формируем запрос
    final payload = {
      'message': message,
      'context': context ?? {},
      'history': history.map((m) => m.toJson()).toList(),
    };

    final url = Uri.parse('${AppConstants.domain}$_endpoint');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final reply = ChatMessage.fromJson(data['message'] as Map<String, dynamic>);

      // Сохраняем в историю
      await _addToHistory(reply);
      return reply;
    } else if (response.statusCode == 429) {
      throw Exception('Слишком много запросов. Попробуйте позже.');
    } else if (response.statusCode == 403) {
      throw Exception('Доступ запрещён. Возможно, у вас нет премиум-подписки.');
    } else {
      throw Exception('Ошибка сервера: ${response.statusCode} ${response.body}');
    }
  }

  /// Возвращает локальную историю чата.
  Future<List<ChatMessage>> getHistory() async {
    return _getLocalHistory();
  }

  /// Очищает историю чата.
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  // Приватные методы

  Future<List<ChatMessage>> _getLocalHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_historyKey);
    if (jsonStr == null) return [];
    final List<dynamic> jsonList = jsonDecode(jsonStr);
    return jsonList.map((j) => ChatMessage.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<void> _addToHistory(ChatMessage message) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await _getLocalHistory();
    // Ограничиваем историю 50 сообщениями
    if (history.length >= 50) {
      history.removeRange(0, history.length - 49);
    }
    history.add(message);
    final jsonStr = jsonEncode(history.map((m) => m.toJson()).toList());
    await prefs.setString(_historyKey, jsonStr);
  }
}
