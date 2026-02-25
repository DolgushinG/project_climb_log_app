import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_rustore_push/flutter_rustore_push.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:login_app/main.dart';

/// Сервис пуш-уведомлений RuStore.
/// Работает только на Android при установленном RuStore.
/// Документация: https://www.rustore.ru/help/en/sdk/push-notifications/flutter
class RustorePushService {
  static const String _pushTokenKey = 'rustore_push_token';

  /// Инициализация: подписка на события и получение токена.
  static Future<void> init() async {
    if (!_isAndroid) return;

    try {
      RustorePushClient.setup();
      await RustorePushClient.attachCallbacks(
        onDeletedMessages: () {
          if (kDebugMode) {
            print('[RuStore Push] onDeletedMessages');
          }
        },
        onError: (dynamic err) {
          if (kDebugMode) {
            print('[RuStore Push] onError: $err');
          }
        },
        onMessageReceived: (message) {
          if (kDebugMode) {
            print('[RuStore Push] onMessageReceived: id=${message.messageId}, '
                'title=${message.notification?.title}, body=${message.notification?.body}');
          }
        },
        onNewToken: (String token) async {
          if (kDebugMode) {
            print('[RuStore Push] onNewToken: $token');
          }
          await _saveToken(token);
          await _onTokenReceived(token);
        },
        onMessageOpenedApp: (message) {
          if (kDebugMode) {
            print('[RuStore Push] onMessageOpenedApp: ${message.notification?.title}');
          }
          // Можно открыть конкретный экран по message.data
        },
      );

      // SDK инициализируется асинхронно. Запрашиваем токен с задержкой — onNewToken
      // может не вызваться при первом запуске, getToken() создаёт/возвращает токен.
      Future.delayed(const Duration(seconds: 3), () async {
        try {
          final available = await RustorePushClient.available();
          if (kDebugMode) {
            print('[RuStore Push] available: $available');
          }
          if (available) {
            final token = await RustorePushClient.getToken();
            if (kDebugMode) {
              print('[RuStore Push] getToken: ${token.isNotEmpty ? "ok" : "empty"}');
            }
            if (token.isNotEmpty) {
              await _saveToken(token);
              await _onTokenReceived(token);
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('[RuStore Push] delayed getToken error: $e');
          }
        }
      });
    } catch (e, st) {
      if (kDebugMode) {
        print('[RuStore Push] init error: $e\n$st');
      }
    }
  }

  static bool get _isAndroid {
    try {
      // flutter_rustore_push только для Android
      return defaultTargetPlatform == TargetPlatform.android;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pushTokenKey, token);
  }

  /// Текущий push-токен (если уже получен).
  static Future<String?> getStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pushTokenKey);
  }

  /// Отправить сохранённый токен на бэкенд (вызвать после входа пользователя).
  static Future<void> sendStoredTokenToBackend() async {
    final pushToken = await getStoredToken();
    if (pushToken != null) await _onTokenReceived(pushToken);
  }

  /// Запросить токен у RuStore вручную (для кнопки «Получить токен» в debug).
  /// Возвращает true, если токен получен и сохранён.
  static Future<bool> requestToken() async {
    if (!_isAndroid) return false;
    try {
      final available = await RustorePushClient.available();
      if (kDebugMode) {
        print('[RuStore Push] requestToken available: $available');
      }
      if (!available) return false;
      final token = await RustorePushClient.getToken();
      if (kDebugMode) {
        print('[RuStore Push] requestToken: ${token.isNotEmpty ? "ok" : "empty"}');
      }
      if (token.isEmpty) return false;
      await _saveToken(token);
      await _onTokenReceived(token);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[RuStore Push] requestToken error: $e');
      }
      return false;
    }
  }

  /// Отправка токена на бэкенд для рассылки пушей.
  static Future<void> _onTokenReceived(String token) async {
    final authToken = await getToken();
    if (authToken == null || authToken.trim().isEmpty) {
      if (kDebugMode) {
        print('[RuStore Push] Токен не отправлен на бэкенд: пользователь не авторизован');
      }
      return;
    }

    try {
      final body = jsonEncode({
        'token': token,
        'platform': 'rustore',
        'device_id': await _getOrCreateDeviceId(),
      });
      final response = await http.post(
        Uri.parse('$DOMAIN/api/climbing-logs/device-push-token'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: body,
      );
      if (kDebugMode) {
        print('[RuStore Push] device-push-token: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[RuStore Push] device-push-token error: $e');
      }
    }
  }

  static const String _deviceIdKey = 'device_push_id';

  static Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdKey);
    if (id == null || id.isEmpty) {
      id = 'rustore_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(_deviceIdKey, id);
    }
    return id;
  }

  /// Проверка доступности пушей (RuStore установлен и готов).
  static Future<bool> available() async {
    if (!_isAndroid) return false;
    try {
      return await RustorePushClient.available();
    } catch (_) {
      return false;
    }
  }

  /// Подписка на топик (например, "news").
  static Future<void> subscribeToTopic(String topicName) async {
    if (!_isAndroid) return;
    try {
      await RustorePushClient.subscibeToTopic(topicName);
    } catch (e) {
      if (kDebugMode) print('[RuStore Push] subscribeToTopic error: $e');
    }
  }

  /// Отписка от топика.
  static Future<void> unsubscribeFromTopic(String topicName) async {
    if (!_isAndroid) return;
    try {
      await RustorePushClient.unsubscribeFromTopic(topicName);
    } catch (e) {
      if (kDebugMode) print('[RuStore Push] unsubscribeFromTopic error: $e');
    }
  }
}
