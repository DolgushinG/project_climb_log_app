import 'package:flutter/foundation.dart';

class AppConstants {
  static const String _prodDomain = 'https://climbing-events.ru';
  static const String _devDomain = 'https://climbing-events.ru.tuna.am';
  static String get domain => kReleaseMode ? _prodDomain : _devDomain;

  /// Правила использования AI-чата тренера (страница на сайте, если добавят).
  static const String aiChatRulesUrl = 'https://climbing-events.ru/ai-chat-rules';
}
