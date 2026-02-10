import 'package:flutter/foundation.dart';
import 'package:flutter_rustore_push/flutter_rustore_push.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

      // Не вызываем available()/getToken()/getInitialMessage() сразу: нативный
      // RuStorePushClient.init() выполняется после setup(), и вызов методов до
      // этого приводит к IllegalStateException. Токен придёт в onNewToken когда
      // SDK будет готов. getInitialMessage можно запросить позже при необходимости.
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

  /// Вызывается при получении/обновлении токена. Переопределите отправку на бэкенд здесь.
  static Future<void> _onTokenReceived(String token) async {
    // TODO: отправить token на ваш бэкенд для рассылки пушей, например:
    // await http.post(Uri.parse('$DOMAIN/api/device/push-token'), body: {'token': token}, headers: {...});
    if (kDebugMode) {
      print('[RuStore Push] Token для бэкенда: $token');
    }
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
