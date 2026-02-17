import 'dart:convert';

import 'package:http/http.dart' as http;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import '../main.dart';

/// Флаги доступности входа по соцсетям.
/// Ключи: vkontakte, telegram, yandex.
class SocialLoginFlags {
  final bool vkontakte;
  final bool telegram;
  final bool yandex;

  const SocialLoginFlags({
    this.vkontakte = false,
    this.telegram = false,
    this.yandex = false,
  });

  bool get hasAny => vkontakte || telegram || yandex;
}

/// Получает конфиг авторизации с бэкенда.
/// GET /api/auth/config → { "social_login": { "vkontakte": true, "telegram": true, "yandex": true } }

class AuthConfigService {
  String get _platform {
    if (kIsWeb) {
      // Определяем, запущено ли как PWA или обычный web
      return 'webapp';
    } else if (Platform.isIOS || Platform.isAndroid) {
      return 'mobile';
    } else {
      // Для других платформ (macOS, Windows, Linux)
      return 'desktop';
    }
  }

  Future<SocialLoginFlags> getSocialLoginFlags() async {
    try {
      final uri = Uri.parse('$DOMAIN/api/auth/config')
          .replace(queryParameters: {'platform': _platform});
      
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        return const SocialLoginFlags();
      }

      final body = json.decode(response.body);
      if (body is! Map) return const SocialLoginFlags();

      final social = body['social_login'];
      if (social is! Map) return const SocialLoginFlags();

      return SocialLoginFlags(
        vkontakte: social['vkontakte'] == true,
        telegram: social['telegram'] == true,
        yandex: social['yandex'] == true,
      );
    } catch (_) {
      return const SocialLoginFlags();
    }
  }
}