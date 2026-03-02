import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../models/ChatMessage.dart';
import '../utils/app_constants.dart';
import '../utils/network_error_helper.dart';

/// Сервис для взаимодействия с AI-тренером через backend.
class AICoachService {
  static const String _endpoint = '/api/ai/chat';
  static const String _historyKey = 'ai_coach_history';

  /// Отправляет сообщение в AI и возвращает ответ.
  /// context: можно передать дополнительные данные (силовые измерения, планы и т.д.)
  Future<ChatMessage> sendMessage(String message, {Map<String, dynamic>? context}) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Выполните вход в аккаунт, чтобы пользоваться AI-тренером.');
    }

    // Собираем полную историю [user, assistant, user, assistant, ...]
    final history = await _getLocalHistory();

    // Формируем history для API — полный контекст диалога (user + assistant чередуются)
    final historyJson = history.map((m) => m.toJson()).toList();

    final payload = {
      'message': message,
      'context': context ?? {},
      'history': historyJson,
    };

    final url = Uri.parse('${AppConstants.domain}$_endpoint');
    http.Response response;
    try {
      response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));
    } catch (e) {
      throw Exception(networkErrorMessage(e, 'Не удалось отправить сообщение. Повторите попытку.'));
    }

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final messageData = data['message'];
        if (messageData == null || messageData is! Map<String, dynamic>) {
          throw Exception('Некорректный ответ сервера. Попробуйте ещё раз.');
        }
        final reply = ChatMessage.fromJson(messageData);
        // Сохраняем user-сообщение и ответ assistant для полного контекста
        await _addToHistory(ChatMessage(role: 'user', content: message));
        await _addToHistory(reply);
        return reply;
      } catch (e) {
        if (e is FormatException) {
          throw Exception('Ошибка чтения ответа. Попробуйте ещё раз.');
        }
        rethrow;
      }
    } else if (response.statusCode == 401) {
      throw Exception('Сессия истекла. Выполните вход заново.');
    } else if (response.statusCode == 429) {
      throw Exception('Слишком много запросов. Попробуйте через несколько минут.');
    } else if (response.statusCode == 403) {
      throw Exception('Доступ запрещён. Возможно, у вас нет премиум-подписки.');
    } else if (response.statusCode >= 500) {
      throw Exception('Сервер временно недоступен. Попробуйте позже.');
    } else {
      throw Exception('Ошибка сервера (${response.statusCode}). Повторите попытку.');
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
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! List) return [];
      final List<ChatMessage> result = [];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          result.add(ChatMessage.fromJson(item));
        }
      }
      return result;
    } catch (_) {
      // Повреждённая история — очищаем
      await prefs.remove(_historyKey);
      return [];
    }
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
