/// Тренировочный план, сгенерированный на основе замеров.
class TrainingPlan {
  final String focusArea;
  final int weeksPlan;
  final int sessionsPerWeek;
  final List<TrainingDrill> drills;
  final String? coachTip;
  final String targetGrade;

  TrainingPlan({
    required this.focusArea,
    required this.weeksPlan,
    required this.sessionsPerWeek,
    required this.drills,
    this.coachTip,
    this.targetGrade = '7b',
  });

  Map<String, dynamic> toJson() => {
        'focus_area': focusArea,
        'weeks_plan': weeksPlan,
        'sessions_per_week': sessionsPerWeek,
        'target_grade': targetGrade,
        'coach_tip': coachTip,
        'drills': drills.map((d) => d.toJson()).toList(),
      };

  factory TrainingPlan.fromJson(Map<String, dynamic> json) {
    final drillsList = (json['drills'] as List<dynamic>?)
        ?.map((e) => TrainingDrill.fromJson(e as Map<String, dynamic>))
        .toList() ?? [];
    return TrainingPlan(
      focusArea: json['focus_area'] as String? ?? 'general',
      weeksPlan: json['weeks_plan'] as int? ?? 4,
      sessionsPerWeek: json['sessions_per_week'] as int? ?? 2,
      targetGrade: json['target_grade'] as String? ?? '7b',
      coachTip: json['coach_tip'] as String?,
      drills: drillsList,
    );
  }
}

/// Упражнение в плане.
class TrainingDrill {
  final String name;
  final double? targetWeightKg;
  final int sets;
  final String reps;
  final String rest;
  /// Краткое пояснение «что это и зачем» — для подсказки в UI.
  final String? hint;
  /// Идентификатор для API exercise-completions (если бэк знает этот id).
  final String? exerciseId;

  TrainingDrill({
    required this.name,
    this.targetWeightKg,
    required this.sets,
    required this.reps,
    required this.rest,
    this.hint,
    this.exerciseId,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'target_weight_kg': targetWeightKg,
        'sets': sets,
        'reps': reps,
        'rest': rest,
        if (hint != null) 'hint': hint,
        if (exerciseId != null) 'exercise_id': exerciseId,
      };

  factory TrainingDrill.fromJson(Map<String, dynamic> json) => TrainingDrill(
        name: json['name'] as String? ?? '',
        targetWeightKg: (json['target_weight_kg'] as num?)?.toDouble(),
        sets: json['sets'] as int? ?? 3,
        reps: json['reps'] as String? ?? '5s hold',
        rest: json['rest'] as String? ?? '180s',
        hint: json['hint'] as String?,
        exerciseId: json['exercise_id'] as String?,
      );
}
