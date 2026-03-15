import 'package:login_app/models/Workout.dart';
import 'package:login_app/services/StrengthTestApiService.dart';

/// Элемент сета упражнений — выбранное упражнение с настроенными параметрами.
class CustomSetExercise {
  final CatalogExercise catalog;
  int sets;
  String reps;
  int? holdSeconds;
  int restSeconds;

  CustomSetExercise({
    required this.catalog,
    this.sets = 3,
    this.reps = '10',
    this.holdSeconds,
    this.restSeconds = 90,
  });

  /// Сброс к преднастройкам из каталога.
  void resetToDefaults() {
    sets = catalog.defaultSets;
    reps = catalog.defaultReps;
    restSeconds = _parseRestSeconds(catalog.defaultRest);
    if (catalog.category == 'stretching' && catalog.dosage != null) {
      final sec = _parseHoldFromDosage(catalog.dosage!);
      if (sec != null) holdSeconds = sec;
    } else {
      holdSeconds = null;
    }
  }

  static int _parseRestSeconds(String v) {
    if (v.endsWith('s')) {
      return int.tryParse(v.replaceAll(RegExp(r'[^\d]'), '')) ?? 90;
    }
    return 90;
  }

  static int? _parseHoldFromDosage(String dosage) {
    final match = RegExp(r'(\d+)\s*сек|(\d+)\s*s').firstMatch(dosage);
    if (match != null) {
      return int.tryParse(match.group(1) ?? match.group(2) ?? '') ?? 30;
    }
    return null;
  }

  factory CustomSetExercise.fromCatalog(CatalogExercise c) {
    final ex = CustomSetExercise(catalog: c);
    ex.resetToDefaults();
    return ex;
  }

  /// Преобразование в WorkoutBlockExercise для ExerciseCompletionScreen.
  WorkoutBlockExercise toWorkoutBlockExercise({required String blockKey}) {
    return WorkoutBlockExercise(
      exerciseId: catalog.id,
      name: catalog.name,
      nameRu: catalog.nameRu,
      category: catalog.category,
      defaultSets: sets,
      defaultReps: holdSeconds != null ? holdSeconds! : (int.tryParse(reps) ?? 10),
      holdSeconds: holdSeconds,
      defaultRestSeconds: restSeconds,
      dosage: holdSeconds != null ? '$sets×${holdSeconds}с' : '$sets × $reps',
      hint: catalog.hint,
      comment: catalog.description,
    );
  }
}
