import 'package:shared_preferences/shared_preferences.dart';

import 'StrengthTestApiService.dart';
import 'TrainingPlanApiService.dart';

/// Сервис для очистки локальных и серверных данных плана, генерации и отметок выполнения.
/// Используется для корректного тестирования.
class PlanCompletionClearService {
  static const List<String> _keyPrefixes = [
    'exercise_completion_screen_cache_',
    'exercise_completions_',
    'exercise_completion_section_expanded_',
    'exercises_all_done_',
  ];

  /// Удаляет все локальные SharedPreferences ключи, связанные с планом,
  /// кэшем упражнений и отметками выполнения.
  static Future<int> clearLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    int removed = 0;
    for (final key in prefs.getKeys()) {
      for (final prefix in _keyPrefixes) {
        if (key.startsWith(prefix)) {
          await prefs.remove(key);
          removed++;
          break;
        }
      }
    }
    return removed;
  }

  /// Удаляет отметки выполнения (exercise-completions) с сервера за указанную дату.
  /// Сначала пробует DELETE ?date= (массово), при ошибке — удаляет по одному.
  /// Возвращает количество удалённых записей.
  static Future<int> clearCompletionsForDate(String date) async {
    final api = StrengthTestApiService();
    final bulk = await api.clearExerciseCompletionsForDate(date);
    if (bulk != null) return bulk;
    final completions = await api.getExerciseCompletions(date: date);
    int deleted = 0;
    for (final c in completions) {
      final ok = await api.deleteExerciseCompletion(c.id);
      if (ok) deleted++;
    }
    return deleted;
  }

  /// Полная очистка «как новый пользователь»: план на бэке, все отметки, локальный кэш.
  /// Возвращает {'planDeleted': 0|1, 'apiCompletions': N, 'localKeys': M}.
  static Future<Map<String, int>> clearAllAsNewUser() async {
    final planApi = TrainingPlanApiService();
    final completionsApi = StrengthTestApiService();
    int planDeleted = (await planApi.deleteActivePlan()) ? 1 : 0;
    int apiCompletions = 0;
    final allDeleted = await completionsApi.clearAllExerciseCompletions();
    if (allDeleted != null) {
      apiCompletions = allDeleted;
    } else {
      final n = DateTime.now();
      final dateStr =
          '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
      apiCompletions = await clearCompletionsForDate(dateStr);
    }
    final localKeys = await clearLocalData();
    return {'planDeleted': planDeleted, 'apiCompletions': apiCompletions, 'localKeys': localKeys};
  }
}
