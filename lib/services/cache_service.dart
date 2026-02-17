import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Кэш с TTL на базе SharedPreferences.
class CacheService {
  static const _prefix = 'cache_';
  static const _tsSuffix = '_ts';

  static Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();

  /// Сохранить JSON-строку с меткой времени.
  static Future<void> set(String key, String jsonValue, {Duration ttl = const Duration(minutes: 15)}) async {
    final prefs = await _prefs;
    await prefs.setString(_prefix + key, jsonValue);
    await prefs.setInt(
      _prefix + key + _tsSuffix,
      DateTime.now().add(ttl).millisecondsSinceEpoch,
    );
  }

  /// Получить значение, если кэш ещё действителен. Иначе null.
  static Future<String?> get(String key) async {
    final prefs = await _prefs;
    final ts = prefs.getInt(_prefix + key + _tsSuffix);
    if (ts == null) return null;
    if (DateTime.now().millisecondsSinceEpoch > ts) {
      await remove(key);
      return null;
    }
    return prefs.getString(_prefix + key);
  }

  /// Получить без проверки TTL (для отображения «последних данных»).
  static Future<String?> getStale(String key) async {
    final prefs = await _prefs;
    return prefs.getString(_prefix + key);
  }

  /// Удалить ключ кэша.
  static Future<void> remove(String key) async {
    final prefs = await _prefs;
    await prefs.remove(_prefix + key);
    await prefs.remove(_prefix + key + _tsSuffix);
  }

  /// Ключи кэша приложения.
  static const String keyCompetitions = 'competitions';
  static const String keyProfile = 'profile';
  static const String keyAnalytics = 'profile_analytics';
  static const String keyHistory = 'profile_history';
  static String keyRoutes(int eventId) => 'routes_$eventId';
  static String keyEventStatistics(int eventId) => 'event_stats_$eventId';
  static String keyEventDetails(int eventId) => 'event_details_$eventId';
  static const String keyRating = 'rating';

  /// Есть ли хоть какие-то данные в кэше (соревнования, профиль, история), чтобы работать офлайн.
  static Future<bool> hasAnyData() async {
    final comps = await getStale(keyCompetitions);
    final profile = await getStale(keyProfile);
    final history = await getStale(keyHistory);
    final rating = await getStale(keyRating);
    return (comps != null && comps.isNotEmpty) ||
        (profile != null && profile.isNotEmpty) ||
        (history != null && history.isNotEmpty) ||
        (rating != null && rating.isNotEmpty);
  }

  /// Очистить весь пользовательский кэш (профиль, соревнования, история, аналитика).
  /// Вызывать при загрузке без токена, чтобы не показывать данные от предыдущей сессии.
  static Future<void> clearAllUserData() async {
    await remove(keyProfile);
    await remove(keyCompetitions);
    await remove(keyHistory);
    await remove(keyAnalytics);
  }

  /// TTL по умолчанию.
  static const ttlCompetitions = Duration(minutes: 15);
  static const ttlProfile = Duration(minutes: 5);
  static const ttlRoutes = Duration(minutes: 30);
  static const ttlAnalytics = Duration(minutes: 10);
  static const ttlHistory = Duration(minutes: 15);
  static const ttlEventStatistics = Duration(minutes: 10);
  static const ttlEventDetails = Duration(minutes: 10);
  static const ttlRating = Duration(minutes: 15);
}

