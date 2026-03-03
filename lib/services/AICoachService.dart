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
  static const String _endpointAsync = '/api/ai/chat/async';
  static const String _historyKey = 'ai_coach_history';
  static const String _pendingTaskKey = 'ai_coach_pending_task_id';

  /// Асинхронная отправка: POST → task_id, затем polling. Не таймаутится.
  /// Возвращает task_id при 202, null если async не поддерживается (404).
  Future<String?> sendMessageAsync(String message, {Map<String, dynamic>? context}) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Выполните вход в аккаунт, чтобы пользоваться AI-тренером.');
    }
    final history = await _getLocalHistory();
    final historyJson = history.map((m) => m.toJson()).toList();
    final payload = {
      'message': message,
      'context': context ?? {},
      'history': historyJson,
    };
    final url = Uri.parse('${AppConstants.domain}$_endpointAsync');
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 202) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        final taskId = data?['task_id'] as String?;
        return taskId;
      }
      if (response.statusCode == 404) return null; // async не поддерживается
      if (response.statusCode == 401) throw Exception('Сессия истекла. Выполните вход заново.');
      if (response.statusCode == 429) throw Exception('Слишком много запросов. Попробуйте через несколько минут.');
      if (response.statusCode == 403) throw Exception('Доступ запрещён. Возможно, у вас нет премиум-подписки.');
      if (response.statusCode >= 500) throw Exception('Сервер временно недоступен. Попробуйте позже.');
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Опрос статуса задачи. [interval] — пауза между запросами, [timeout] — общий таймаут.
  /// При completed возвращает ChatMessage. При failed — throws. При timeout — null.
  Future<ChatMessage?> pollChatStatus(
    String taskId, {
    Duration interval = const Duration(seconds: 2),
    Duration timeout = const Duration(seconds: 180),
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) throw Exception('Нет токена');
    final url = Uri.parse('${AppConstants.domain}$_endpointAsync/$taskId/status');
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final response = await http.get(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) continue;
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        final status = data?['status'] as String?;
        if (status == 'completed') {
          final result = data?['result'] as Map<String, dynamic>?;
          final messageData = result?['message'] as Map<String, dynamic>?;
          if (messageData == null) return null;
          return ChatMessage.fromJson(messageData);
        }
        if (status == 'failed') {
          final err = data?['error'] as String? ?? 'Ошибка AI';
          throw Exception(err);
        }
      } catch (e) {
        if (e.toString().startsWith('Exception: ')) rethrow; // наш throw от status==failed
        // сеть/таймаут — продолжаем polling
      }
      await Future.delayed(interval);
    }
    return null; // timeout
  }

  /// Отправляет сообщение в AI и возвращает ответ (синхронный, fallback).
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
        await _addToHistory(ChatMessage(role: 'user', content: message, status: MessageStatus.delivered));
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

  /// Сохранить task_id при старте polling, чтобы при возврате в чат можно было показать «Печатает» и продолжить.
  Future<void> setPendingTaskId(String? taskId) async {
    final prefs = await SharedPreferences.getInstance();
    if (taskId == null) {
      await prefs.remove(_pendingTaskKey);
    } else {
      await prefs.setString(_pendingTaskKey, taskId);
    }
  }

  /// Получить pending task_id, если есть (ожидание ответа при уходе из чата).
  Future<String?> getPendingTaskId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pendingTaskKey);
  }

  /// Сохранить user-сообщение сразу при отправке (до ответа), чтобы при уходе из чата оно не терялось.
  Future<void> addUserMessageToHistory(String userContent) async {
    await _addToHistory(ChatMessage(role: 'user', content: userContent, status: MessageStatus.sent));
  }

  /// Добавить assistant-ответ в историю (user уже сохранён). Идемпотентно — не дублирует, если уже есть.
  Future<void> addReplyToHistory(ChatMessage assistantReply) async {
    final history = await _getLocalHistory();
    if (history.isNotEmpty && history.last.role == 'assistant') return; // уже добавлен (другой экземпляр)
    await _addToHistory(assistantReply);
  }

  /// Добавить user + assistant в историю (для sync-пути или когда user ещё не сохранён).
  Future<void> addToHistory(String userContent, ChatMessage assistantReply, {MessageStatus? userStatus}) async {
    await _addToHistory(ChatMessage(role: 'user', content: userContent, status: userStatus ?? MessageStatus.delivered));
    await _addToHistory(assistantReply);
  }

  /// Возвращает локальную историю чата.
  Future<List<ChatMessage>> getHistory() async {
    return _getLocalHistory();
  }

  /// Очищает историю чата.
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    await prefs.remove(_pendingTaskKey);
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
