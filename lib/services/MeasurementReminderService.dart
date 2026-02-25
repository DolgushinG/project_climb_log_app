import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Сервис локальных напоминаний о замерах силы.
/// Рекомендуемый интервал: 2–4 недели.
class MeasurementReminderService {
  static const String _keyReminderScheduled = 'measurement_reminder_scheduled';
  static const int _reminderDays = 14;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) return;

    try {
      tz_data.initializeTimeZones();
      final moscow = tz.getLocation('Europe/Moscow');
      tz.setLocalLocation(moscow);
    } catch (_) {
      // fallback
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
    );
    const initSettings = InitializationSettings(
      android: android,
      iOS: ios,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  static void _onNotificationTapped(NotificationResponse response) {
    // Пользователь открыл приложение по напоминанию — навигация в Testing
    // обрабатывается в main через payload
  }

  /// Запланировать напоминание через 2 недели после сохранения замера.
  static Future<void> scheduleReminder() async {
    if (!_initialized) await init();
    if (kIsWeb) return;

    try {
      await _plugin.zonedSchedule(
        0,
        'Пора замериться',
        'Рекомендуем делать замеры раз в 2–4 недели для отслеживания прогресса.',
        tz.TZDateTime.now(tz.local).add(const Duration(days: _reminderDays)),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'measurement_reminder',
            'Напоминания о замерах',
            channelDescription: 'Напоминания о необходимости замера силы',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyReminderScheduled, true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[MeasurementReminder] schedule failed: $e');
      }
    }
  }

  /// Отменить запланированное напоминание.
  static Future<void> cancelReminder() async {
    if (!_initialized) await init();
    try {
      await _plugin.cancel(0);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyReminderScheduled, false);
    } catch (_) {}
  }

  /// Проверить, сколько дней прошло с последнего замера.
  static int? daysSinceLastMeasurement(String? lastDate) {
    if (lastDate == null || lastDate.isEmpty) return null;
    try {
      final parts = lastDate.split('-');
      if (parts.length < 3) return null;
      final last = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      final now = DateTime.now();
      return now.difference(last).inDays;
    } catch (_) {
      return null;
    }
  }

  /// Показывать ли подсказку «Рекомендуем замериться раз в 2–4 недели».
  static bool shouldShowHint(String? lastDate) {
    final days = daysSinceLastMeasurement(lastDate);
    if (days == null) return true; // никогда не замерялся
    return days >= 14;
  }
}
