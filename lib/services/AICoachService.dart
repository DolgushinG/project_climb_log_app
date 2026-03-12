import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../models/AIConversation.dart';
import '../models/AISkill.dart';
import '../models/ChatMessage.dart';
import '../models/SendMessageResult.dart';
import '../utils/app_constants.dart';
import '../utils/network_error_helper.dart';

/// Сервис для взаимодействия с AI-тренером через backend.
class AICoachService {
  static const String _endpoint = '/api/ai/chat';
  static const String _endpointAsync = '/api/ai/chat/async';
  static const String _historyKey = 'ai_coach_history';
  static const String _conversationIdKey = 'ai_conversation_id';
  static const String _pendingTaskKey = 'ai_coach_pending_task_id';
  static const String _memoryConsentKey = 'ai_chat_memory_consent';
  static const String _skillsCacheKey = 'ai_skills_cache';

  /// Список доступных скиллов (ассистентов). Кэшируется.
  /// GET /api/ai/skills — публичный endpoint.
  Future<List<AISkill>> getSkills() async {
    try {
      final url = Uri.parse('${AppConstants.domain}/api/ai/skills');
      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return _getDefaultSkillsFallback();
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>?;
      final list = data?['skills'];
      if (list is! List) return _getDefaultSkillsFallback();
      final skills = list
          .whereType<Map<String, dynamic>>()
          .map((m) => AISkill.fromJson(m))
          .toList();
      if (skills.isEmpty) return _getDefaultSkillsFallback();
      // Кэшируем для офлайн
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_skillsCacheKey, jsonEncode(skills.map((s) => s.toJson()).toList()));
      return skills;
    } catch (_) {
      return _getSkillsFromCache();
    }
  }

  /// Локальный fallback при отсутствии сети или если бэкенд не поддерживает.
  static List<AISkill> _getDefaultSkillsFallback() => [
        AISkill(id: 'default', name: 'Универсальный тренер'),
        AISkill(id: 'training_plan', name: 'Тренировочные планы'),
        AISkill(id: 'nutrition', name: 'Питание скалолазов'),
        AISkill(id: 'psychology', name: 'Спортивная психология'),
        AISkill(id: 'gear_recommendation', name: 'Подбор снаряжения'),
        AISkill(id: 'recovery', name: 'Восстановление'),
        AISkill(id: 'competition_analysis', name: 'Анализ соревнований'),
        AISkill(id: 'climb_analysis', name: 'Анализ восхождения'),
      ];

  /// Имя скилла по id (из кэша или fallback).
  Future<String> getSkillName(String skillId) async {
    final skills = await _getSkillsFromCache();
    for (final s in skills) {
      if (s.id == skillId) return s.name;
    }
    return skillId;
  }

  Future<List<AISkill>> _getSkillsFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_skillsCacheKey);
    if (jsonStr == null || jsonStr.isEmpty) return _getDefaultSkillsFallback();
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! List) return _getDefaultSkillsFallback();
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((m) => AISkill.fromJson(m))
          .toList();
    } catch (_) {
      return _getDefaultSkillsFallback();
    }
  }

  /// Согласие на обработку данных: true = с памятью, false = без памяти.
  /// null = ещё не спрашивали.
  Future<bool?> getMemoryConsent() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_memoryConsentKey);
    if (v == 'granted') return true;
    if (v == 'denied') return false;
    return null;
  }

  Future<void> setMemoryConsent(bool granted) async {
    try {
      await _updateMemoryConsentOnServer(granted);
    } catch (_) {
      // Сохраняем локально даже при ошибке сети; синхронизация произойдёт при следующем успешном вызове
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_memoryConsentKey, granted ? 'granted' : 'denied');
    if (!granted) {
      await _clearConversationId();
      await prefs.remove(_historyKey);
      await prefs.remove(_pendingTaskKey);
    }
  }

  /// Отправляет предпочтение на бэкенд. PATCH /api/ai/memory-consent.
  Future<void> _updateMemoryConsentOnServer(bool granted) async {
    final token = await getToken();
    if (token == null || token.isEmpty) return;
    final url = Uri.parse('${AppConstants.domain}/api/ai/memory-consent');
    final response = await http.patch(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'ai_memory_consent': granted}),
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode == 401) throw Exception('Сессия истекла. Выполните вход заново.');
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Не удалось обновить настройки (${response.statusCode}).');
    }
  }

  /// Синхронизирует согласие с бэкенда (GET /api/profile). Возвращает true если на сервере есть значение.
  Future<bool?> syncMemoryConsentFromProfile() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return null;
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.domain}/api/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>?;
      final consent = data?['ai_memory_consent'];
      if (consent is bool) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_memoryConsentKey, consent ? 'granted' : 'denied');
        return consent;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// true — сохраняем переписку и память; false — работаем как белый лист.
  Future<bool> isMemoryConsentGranted() async {
    final c = await getMemoryConsent();
    return c == true;
  }

  /// Получить сохранённый AI-комментарий к упражнению. null если нет или endpoint не поддерживается.
  /// Экономит токены при повторном вопросе — показываем кэш вместо нового запроса.
  Future<String?> getExerciseAiComment(String exerciseId) async {
    final token = await getToken();
    if (token == null || token.isEmpty) return null;
    try {
      final url = Uri.parse('${AppConstants.domain}/api/ai/exercise-comments')
          .replace(queryParameters: {'exercise_id': exerciseId});
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>?;
      final comment = data?['comment'] as String?;
      return (comment != null && comment.trim().isNotEmpty) ? comment.trim() : null;
    } catch (_) {
      return null;
    }
  }

  /// Асинхронная отправка: POST → task_id, затем polling. Не таймаутится.
  /// Возвращает task_id при 202, null если async не поддерживается (404).
  /// [explicitConversationId] — ID чата (при открытии из списка). null — новый чат (не подставлять сохранённый).
  /// skill не передаём — бэкенд делает auto-detect по тексту сообщения.
  Future<String?> sendMessageAsync(
    String message, {
    int? explicitConversationId,
    Map<String, dynamic>? context,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Выполните вход в аккаунт, чтобы пользоваться AI-тренером.');
    }
    final conversationId = explicitConversationId;
    final payload = <String, dynamic>{
      'message': message,
      if (conversationId != null) 'conversation_id': conversationId,
    };
    // history нужен только при отсутствии conversation_id (бэкенд игнорирует при conversation_id)
    if (conversationId == null) {
      final history = await _getLocalHistory();
      payload['history'] = history.map((m) => m.toJson()).toList();
    }
    if (context != null && context.isNotEmpty) payload['context'] = context;
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
      if (response.statusCode == 404) {
        await _clearConversationId(); // может быть неверный conversation_id
        return null; // async не поддерживается или диалог не найден — fallback на sync
      }
      if (response.statusCode == 401) throw Exception('Сессия истекла. Выполните вход заново.');
      if (response.statusCode == 402) throw Exception('Доступ запрещён. Возможно, у вас нет премиум-подписки.');
      if (response.statusCode == 429) throw Exception('Слишком много запросов. Попробуйте через несколько минут.');
      if (response.statusCode == 403) {
        final msg = _parse403Message(response.body);
        throw Exception(msg);
      }
      if (response.statusCode >= 500) throw Exception('Сервер временно недоступен. Попробуйте позже.');
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Опрос статуса задачи. [interval] — пауза между запросами, [timeout] — общий таймаут.
  /// При completed возвращает SendMessageResult. При failed — throws. При timeout — null.
  Future<SendMessageResult?> pollChatStatus(
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
          final convId = result?['conversation_id'];
          final skillId = result?['skill_id'] as String?;
          if (convId != null && convId is int && await isMemoryConsentGranted()) {
            await _setConversationId(convId);
          }
          return SendMessageResult(
            message: ChatMessage.fromJson(messageData),
            conversationId: convId is int ? convId : null,
            skillId: skillId,
          );
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
  /// [explicitConversationId] — ID чата (при открытии из списка). null — новый чат (не подставлять сохранённый).
  /// skill не передаём — бэкенд делает auto-detect по тексту сообщения.
  Future<SendMessageResult> sendMessage(
    String message, {
    int? explicitConversationId,
    Map<String, dynamic>? context,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Выполните вход в аккаунт, чтобы пользоваться AI-тренером.');
    }

    final conversationId = explicitConversationId;
    final payload = <String, dynamic>{
      'message': message,
      if (conversationId != null) 'conversation_id': conversationId,
    };
    if (conversationId == null) {
      final history = await _getLocalHistory();
      payload['history'] = history.map((m) => m.toJson()).toList();
    }
    if (context != null && context.isNotEmpty) payload['context'] = context;

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
        final conversationIdResp = data['conversation_id'];
        final skillIdResp = data['skill_id'] as String?;
        if (conversationIdResp != null &&
            conversationIdResp is int &&
            await isMemoryConsentGranted()) {
          await _setConversationId(conversationIdResp);
        }
        final reply = ChatMessage.fromJson(messageData);
        // Сохраняем в локальную историю только при согласии и отсутствии explicitConversationId
        if (explicitConversationId == null && await isMemoryConsentGranted()) {
          await _addToHistory(ChatMessage(role: 'user', content: message, status: MessageStatus.delivered));
          await _addToHistory(reply);
        }
        return SendMessageResult(
          message: reply,
          conversationId: conversationIdResp is int ? conversationIdResp : null,
          skillId: skillIdResp,
        );
      } catch (e) {
        if (e is FormatException) {
          throw Exception('Ошибка чтения ответа. Попробуйте ещё раз.');
        }
        rethrow;
      }
    } else if (response.statusCode == 401) {
      throw Exception('Сессия истекла. Выполните вход заново.');
    } else if (response.statusCode == 402) {
      throw Exception('Доступ запрещён. Возможно, у вас нет премиум-подписки.');
    } else if (response.statusCode == 404) {
      await _clearConversationId();
      throw Exception('Диалог не найден. Начните новый разговор.');
    } else if (response.statusCode == 429) {
      throw Exception('Слишком много запросов. Попробуйте через несколько минут.');
    } else if (response.statusCode == 403) {
      final msg = _parse403Message(response.body);
      throw Exception(msg);
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

  /// Возвращает локальную историю чата (для режима без conversation_id).
  Future<List<ChatMessage>> getHistory() async {
    return _getLocalHistory();
  }

  /// Список чатов пользователя.
  Future<List<AIConversation>> getConversations() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Выполните вход в аккаунт.');
    }
    final url = Uri.parse('${AppConstants.domain}/api/ai/conversations');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode == 401) throw Exception('Сессия истекла. Выполните вход заново.');
    if (response.statusCode != 200) {
      throw Exception('Ошибка загрузки чатов (${response.statusCode}).');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>?;
    final list = data?['conversations'];
    if (list is! List) return [];
    return list
        .whereType<Map<String, dynamic>>()
        .map((m) => AIConversation.fromJson(m))
        .toList();
  }

  /// Сообщения выбранного чата.
  /// Возвращает { conversationId, title, skillId, messages }.
  Future<({int conversationId, String title, String? skillId, List<ChatMessage> messages})> getConversationMessages(int id) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Выполните вход в аккаунт.');
    }
    final url = Uri.parse('${AppConstants.domain}/api/ai/conversations/$id/messages');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode == 401) throw Exception('Сессия истекла. Выполните вход заново.');
    if (response.statusCode == 404) throw Exception('Чат не найден.');
    if (response.statusCode != 200) {
      throw Exception('Ошибка загрузки сообщений (${response.statusCode}).');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final convId = data['conversation_id'] as int? ?? id;
    final title = data['title'] as String? ?? '';
    final skillId = data['skill_id'] as String?;
    final list = data['messages'];
    final messages = <ChatMessage>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          messages.add(ChatMessage.fromJson(item));
        }
      }
    }
    return (conversationId: convId, title: title, skillId: skillId, messages: messages);
  }

  /// Удаляет чат на бэкенде. 204 или 404 — успех.
  Future<void> deleteConversation(int id) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Выполните вход в аккаунт.');
    }
    final url = Uri.parse('${AppConstants.domain}/api/ai/conversations/$id');
    final response = await http.delete(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode == 401) throw Exception('Сессия истекла. Выполните вход заново.');
    if (response.statusCode == 404) return; // уже удалён
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Не удалось удалить чат (${response.statusCode}).');
    }
  }

  /// Очищает локальный кэш (история, conversation_id, pending task).
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    await prefs.remove(_conversationIdKey);
    await prefs.remove(_pendingTaskKey);
  }

  // Приватные методы

  /// Разбор сообщения при 403: ai_banned — блокировка за нарушения, иначе общий запрет.
  static String _parse403Message(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>?;
      if (data?['code'] == 'ai_banned') {
        return data?['error'] as String? ??
            'Доступ заблокирован из-за нарушения правил использования. Пожалуйста, соблюдайте правила сервиса.';
      }
      return data?['error'] as String? ?? 'Доступ запрещён.';
    } catch (_) {
      return 'Доступ запрещён.';
    }
  }

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

  Future<int?> _getConversationId() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.get(_conversationIdKey);
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  Future<void> _setConversationId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_conversationIdKey, id);
  }

  Future<void> _clearConversationId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_conversationIdKey);
  }
}
