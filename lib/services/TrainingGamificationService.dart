import 'package:shared_preferences/shared_preferences.dart';

/// Геймификация тренировочного процесса: XP, Streak, Boss Fight.
class TrainingGamificationService {
  static const String _keyXp = 'training_xp';
  static const String _keyStreakDays = 'training_streak_days';
  static const String _keyLastSessionDate = 'training_last_session_date';
  static const String _keyLastMeasureDate = 'training_last_measure_date';
  static const String _keyBossFightWeek = 'training_boss_fight_week';

  static const int xpPerSession = 50;
  static const int streakMultiplier = 2;
  static const int measurementsPerMonthForStreak = 2;
  static const int bossFightIntervalWeeks = 4;

  Future<int> getTotalXp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyXp) ?? 0;
  }

  Future<int> getStreakDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyStreakDays) ?? 0;
  }

  Future<DateTime?> getLastSessionDate() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyLastSessionDate);
    return str != null ? DateTime.tryParse(str) : null;
  }

  Future<DateTime?> getLastMeasureDate() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyLastMeasureDate);
    return str != null ? DateTime.tryParse(str) : null;
  }

  /// Добавить XP за завершенную тренировку.
  /// Учитывает streak: если соблюден график (2+ замера в месяц), множитель x2.
  Future<int> addSessionXp() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final last = await getLastSessionDate();
    final streak = await getStreakDays();
    final lastMeasure = await getLastMeasureDate();

    int baseXp = xpPerSession;
    int newStreak = streak;

    if (last != null) {
      final diff = now.difference(last).inDays;
      if (diff == 1) {
        newStreak = streak + 1;
      } else if (diff > 1) {
        newStreak = 1;
      }
    } else {
      newStreak = 1;
    }

    final hasStreakBonus = lastMeasure != null &&
        now.month == lastMeasure.month &&
        now.difference(lastMeasure).inDays <= 14;

    final xpGain = hasStreakBonus ? baseXp * streakMultiplier : baseXp;
    final total = (prefs.getInt(_keyXp) ?? 0) + xpGain;

    await prefs.setInt(_keyXp, total);
    await prefs.setInt(_keyStreakDays, newStreak);
    await prefs.setString(_keyLastSessionDate, now.toIso8601String());

    return xpGain;
  }

  /// Зафиксировать контрольный замер (Boss Fight).
  /// Раз в 4 недели — обновление ранга, открытие новых упражнений.
  Future<void> recordMeasurement() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setString(_keyLastMeasureDate, now.toIso8601String());
    final week = now.difference(DateTime(2020)).inDays ~/ 7;
    await prefs.setInt(_keyBossFightWeek, week);
  }

  Future<bool> isBossFightDue() async {
    final last = await getLastMeasureDate();
    if (last == null) return true;
    final weeksSince = DateTime.now().difference(last).inDays ~/ 7;
    return weeksSince >= bossFightIntervalWeeks;
  }

  /// Статус восстановления (для Health Check).
  /// Optimal: последняя сессия 48+ часов назад.
  Future<String> getRecoveryStatus() async {
    final last = await getLastSessionDate();
    if (last == null) return 'ready'; // Готов к первой
    final hours = DateTime.now().difference(last).inHours;
    if (hours >= 48) return 'optimal';
    if (hours >= 24) return 'recovering';
    return 'rest';
  }

  String recoveryStatusText(String status) {
    switch (status) {
      case 'optimal':
        return 'Optimal (Last session 48h+ ago)';
      case 'recovering':
        return 'Recovering (24–48h since last)';
      case 'rest':
        return 'Rest day (24h since last)';
      default:
        return 'Ready for training';
    }
  }

  String recoveryStatusTextRu(String status) {
    switch (status) {
      case 'optimal':
        return 'Отлично — 48ч+ с последней сессии';
      case 'recovering':
        return 'Восстанавливаешься (24–48ч)';
      case 'rest':
        return 'День отдыха — меньше 24ч';
      default:
        return 'Готов лезть';
    }
  }
}
