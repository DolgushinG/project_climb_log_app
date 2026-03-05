import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../models/ChatMessage.dart';
import '../models/SupportChatResponse.dart';
import '../utils/app_constants.dart';
import '../utils/network_error_helper.dart';

/// Сервис для AI Support (поддержка). Stateless — история на клиенте.
class AISupportService {
  static const String _basePath = '/api/ai/support';
  static const String _statusCacheKey = 'ai_support_status';
  static const String _statusCacheTimeKey = 'ai_support_status_time';
  static const Duration _statusCacheDuration = Duration(minutes: 5);

  String get _domain => AppConstants.domain;

  Future<Map<String, String>> _headers({bool includeAuth = true}) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (includeAuth) {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  /// Проверка доступности AI Support. Кэш 5 минут.
  Future<bool> getStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedTime = prefs.getInt(_statusCacheTimeKey);
    if (cachedTime != null) {
      final elapsed = DateTime.now().millisecondsSinceEpoch - cachedTime;
      if (elapsed < _statusCacheDuration.inMilliseconds) {
        final cached = prefs.getBool(_statusCacheKey);
        return cached ?? false;
      }
    }

    try {
      final url = Uri.parse('$_domain$_basePath/status');
      final response = await http.get(
        url,
        headers: await _headers(),
      ).timeout(const Duration(seconds: 10));

      final enabled = response.statusCode == 200 &&
          (jsonDecode(response.body) as Map?)?['enabled'] == true;

      await prefs.setBool(_statusCacheKey, enabled);
      await prefs.setInt(_statusCacheTimeKey, DateTime.now().millisecondsSinceEpoch);
      return enabled;
    } catch (_) {
      return prefs.getBool(_statusCacheKey) ?? false;
    }
  }

  /// Отправка сообщения в AI Support.
  Future<SupportChatResponse> sendMessage(
    String message, {
    int? eventId,
    required String page,
    String? pathname,
    String? pageTitle,
    List<ChatMessage> history = const [],
  }) async {
    final url = Uri.parse('$_domain$_basePath/chat');
    final body = <String, dynamic>{
      'message': message.substring(0, message.length > 2000 ? 2000 : message.length),
      'page': page,
    };
    if (eventId != null) body['event_id'] = eventId;
    if (pathname != null && pathname.length <= 500) body['pathname'] = pathname;
    if (pageTitle != null && pageTitle.length <= 300) body['page_title'] = pageTitle;
    if (history.isNotEmpty) {
      body['history'] = history.map((m) => {
            'role': m.role,
            'content': m.content,
            'timestamp': m.timestamp.toIso8601String(),
          }).toList();
    }

    final response = await http.post(
      url,
      headers: await _headers(),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode == 403) {
      throw Exception('AI Support временно недоступен.');
    }
    if (response.statusCode == 503) {
      throw Exception('Сервис AI временно недоступен. Попробуйте позже.');
    }
    if (response.statusCode != 200) {
      throw Exception(networkErrorMessage(
        Exception('HTTP ${response.statusCode}'),
        'Не удалось получить ответ. Повторите попытку.',
      ));
    }

    final data = jsonDecode(response.body);
    if (data is! Map) throw Exception('Неверный формат ответа.');
    return SupportChatResponse.fromJson(Map<String, dynamic>.from(data));
  }

  /// Трекинг событий (аналитика).
  Future<void> trackEvent(
    String eventType, {
    int? eventId,
    String? page,
    Map<String, dynamic>? payload,
  }) async {
    try {
      final url = Uri.parse('$_domain$_basePath/event');
      final body = <String, dynamic>{'event_type': eventType};
      if (eventId != null) body['event_id'] = eventId;
      if (page != null) body['page'] = page;
      if (payload != null) body['payload'] = payload;

      await http.post(
        url,
        headers: await _headers(),
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {
      // Fire-and-forget, не блокируем UI
    }
  }

  /// Обратная связь на ответ AI (👍 / 👎).
  Future<void> sendFeedback({
    required String question,
    String? responsePreview,
    String? responseFull,
    required String rating,
    String? comment,
    int? eventId,
  }) async {
    try {
      final url = Uri.parse('$_domain$_basePath/feedback');
      final body = <String, dynamic>{
        'question': question.substring(0, question.length > 500 ? 500 : question.length),
        'rating': rating,
      };
      if (responsePreview != null && responsePreview.length <= 500) {
        body['response_preview'] = responsePreview;
      }
      if (responseFull != null && responseFull.length <= 16000) {
        body['response_full'] = responseFull;
      }
      if (comment != null && comment.length <= 1000) body['comment'] = comment;
      if (eventId != null) body['event_id'] = eventId;

      await http.post(
        url,
        headers: await _headers(),
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {
      // Fire-and-forget
    }
  }

  /// Отмена регистрации на событие (для suggested_action cancel_registration).
  Future<void> cancelRegistration(int eventId) async {
    final url = Uri.parse('$_domain/api/event/$eventId/cancel-take-part');
    final headers = await _headers();
    final response = await http.post(url, headers: headers, body: '{}')
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 401) {
      throw Exception('Выполните вход для отмены регистрации.');
    }
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Не удалось отменить регистрацию.');
    }
  }

  /// Сброс кэша status (для тестирования или принудительной перепроверки).
  Future<void> invalidateStatusCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_statusCacheKey);
    await prefs.remove(_statusCacheTimeKey);
  }
}
