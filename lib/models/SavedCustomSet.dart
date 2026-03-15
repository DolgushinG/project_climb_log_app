import 'package:login_app/services/StrengthTestApiService.dart';

/// Сохранённый на бэкенде сет упражнений (шаблон).
class SavedCustomSet {
  final int id;
  final String name;
  final List<SavedCustomSetExercise> exercises;
  final int? exercisesCount;
  final String? createdAt;
  final String? updatedAt;

  SavedCustomSet({
    required this.id,
    required this.name,
    this.exercises = const [],
    this.exercisesCount,
    this.createdAt,
    this.updatedAt,
  });

  factory SavedCustomSet.fromJson(Map<String, dynamic> json) {
    final exRaw = json['exercises'] as List<dynamic>?;
    List<SavedCustomSetExercise> exList = [];
    if (exRaw != null) {
      exList = exRaw
          .map((e) => SavedCustomSetExercise.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return SavedCustomSet(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      exercises: exList,
      exercisesCount: json['exercises_count'] as int?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'exercises': exercises.map((e) => e.toJson()).toList(),
        if (createdAt != null) 'created_at': createdAt,
        if (updatedAt != null) 'updated_at': updatedAt,
      };
}

/// Элемент сета в ответе API.
/// Бэкенд может возвращать полные данные (name, name_ru, category) — используем их,
/// если упражнения нет в локальном каталоге (например, из-за фильтра по уровню).
class SavedCustomSetExercise {
  final String exerciseId;
  final int order;
  final int sets;
  final String reps;
  final int? holdSeconds;
  final int restSeconds;
  /// Из API (GET set) — для fallback, когда нет в каталоге.
  final String? name;
  final String? nameRu;
  final String? category;
  final String? hint;
  final String? description;

  SavedCustomSetExercise({
    required this.exerciseId,
    this.order = 0,
    this.sets = 3,
    this.reps = '10',
    this.holdSeconds,
    this.restSeconds = 90,
    this.name,
    this.nameRu,
    this.category,
    this.hint,
    this.description,
  });

  factory SavedCustomSetExercise.fromJson(Map<String, dynamic> json) =>
      SavedCustomSetExercise(
        exerciseId: json['exercise_id'] as String? ?? '',
        order: json['order'] as int? ?? 0,
        sets: json['sets'] as int? ?? 3,
        reps: json['reps']?.toString() ?? '10',
        holdSeconds: json['hold_seconds'] as int?,
        restSeconds: json['rest_seconds'] as int? ?? 90,
        name: json['name'] as String?,
        nameRu: json['name_ru'] as String?,
        category: json['category'] as String? ?? 'ofp',
        hint: json['hint'] as String?,
        description: json['description'] as String? ?? json['climbing_benefit'] as String?,
      );

  /// Синтетический CatalogExercise из данных API — когда упражнения нет в локальном каталоге.
  CatalogExercise? toCatalogExerciseIfEnriched() {
    final n = name ?? nameRu;
    if (n == null || n.isEmpty) return null;
    return CatalogExercise(
      id: exerciseId,
      name: name ?? exerciseId,
      nameRu: nameRu,
      category: category ?? 'ofp',
      level: 'intermediate',
      description: description,
      hint: hint,
      defaultSets: sets,
      defaultReps: reps,
      defaultRest: '${restSeconds}s',
    );
  }

  Map<String, dynamic> toJson() => {
        'exercise_id': exerciseId,
        'order': order,
        'sets': sets,
        'reps': reps,
        if (holdSeconds != null) 'hold_seconds': holdSeconds,
        'rest_seconds': restSeconds,
      };
}
