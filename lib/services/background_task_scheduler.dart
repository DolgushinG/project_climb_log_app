import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'package:login_app/main.dart';
import 'package:login_app/services/cache_service.dart';
import 'package:login_app/services/offline_queue_service.dart';
import 'package:http/http.dart' as http;

/// Идентификатор фоновой задачи (должен совпадать с Info.plist и AppDelegate).
const String _taskIdentifier = 'com.climbingevents.app.background_sync';

/// Ключ настройки: отключить фоновые задачи для экономии батареи.
const String _keyBackgroundTasksDisabled = 'background_tasks_disabled';

/// Топ-уровневый коллбек для WorkManager. Вызывается в отдельном isolate.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != _taskIdentifier) return false;
    return _runBackgroundSync();
  });
}

Future<bool> _runBackgroundSync() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_keyBackgroundTasksDisabled) == true) return true;

    final token = await getToken();
    if (token == null) return true;

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    await Future.wait([
      _prefetchCompetitions(headers),
      _prefetchRating(),
      OfflineQueueService.flush(),
    ]);
    return true;
  } catch (e) {
    if (kDebugMode) debugPrint('[BackgroundTaskScheduler] $e');
    return false;
  }
}

Future<void> _prefetchCompetitions(Map<String, String> headers) async {
  try {
    final response = await http.get(
      Uri.parse('$DOMAIN/api/competitions'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      await CacheService.set(
        CacheService.keyCompetitions,
        response.body,
        ttl: CacheService.ttlCompetitions,
      );
    }
  } catch (_) {}
}

Future<void> _prefetchRating() async {
  try {
    final response = await http.get(
      Uri.parse('$DOMAIN/api/rating'),
      headers: {'Accept': 'application/json'},
    );
    if (response.statusCode == 200) {
      await CacheService.set(
        CacheService.keyRating,
        response.body,
        ttl: CacheService.ttlRating,
      );
    }
  } catch (_) {}
}

/// Сервис для планирования энергоэффективных фоновых задач.
class BackgroundTaskScheduler {
  static Future<bool> get isBackgroundTasksDisabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBackgroundTasksDisabled) ?? false;
  }

  static Future<void> setBackgroundTasksDisabled(bool disabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBackgroundTasksDisabled, disabled);
    if (disabled) {
      await cancelAll();
    }
  }

  /// Запланировать периодические задачи, если пользователь авторизован и не отключил фоновые задачи.
  static Future<void> scheduleIfEnabled() async {
    if (kIsWeb) return;
    final token = await getToken();
    if (token == null) return;
    final disabled = await isBackgroundTasksDisabled;
    if (disabled) return;

    await Workmanager().registerPeriodicTask(
      _taskIdentifier,
      _taskIdentifier,
      frequency: const Duration(hours: 12),
      initialDelay: const Duration(hours: 2),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }

  /// Отменить все запланированные задачи (вызывать при выходе).
  static Future<void> cancelAll() async {
    if (kIsWeb) return;
    await Workmanager().cancelByUniqueName(_taskIdentifier);
  }
}
