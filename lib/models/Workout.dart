/// Запрос на генерацию тренировки.
class GenerateWorkoutRequest {
  final int userLevel;
  final String goal;
  final List<String> injuries;
  final int availableTimeMinutes;
  final int experienceMonths;
  final int? minPullups;
  final int? dayOffset;
  final UserProfile? userProfile;
  final PerformanceMetrics? performanceMetrics;
  final RecentClimbingData? recentClimbingData;
  final FatigueData? fatigueData;
  final String? currentPhase;

  GenerateWorkoutRequest({
    required this.userLevel,
    required this.goal,
    this.injuries = const [],
    required this.availableTimeMinutes,
    required this.experienceMonths,
    this.minPullups,
    this.dayOffset,
    this.userProfile,
    this.performanceMetrics,
    this.recentClimbingData,
    this.fatigueData,
    this.currentPhase,
  });

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'user_level': userLevel,
      'goal': goal,
      if (injuries.isNotEmpty) 'injuries': injuries,
      'available_time_minutes': availableTimeMinutes,
      'experience_months': experienceMonths,
      if (minPullups != null) 'min_pullups': minPullups,
      if (dayOffset != null) 'day_offset': dayOffset,
      if (userProfile != null) 'user_profile': userProfile!.toJson(),
      if (performanceMetrics != null) 'performance_metrics': performanceMetrics!.toJson(),
      if (recentClimbingData != null) 'recent_climbing_data': recentClimbingData!.toJson(),
      if (fatigueData != null) 'fatigue_data': fatigueData!.toJson(),
      if (currentPhase != null) 'current_phase': currentPhase,
    };
    return m;
  }
}

class UserProfile {
  final double bodyweight;
  final String? preferredStyle; // boulder | lead | both

  UserProfile({required this.bodyweight, this.preferredStyle});

  Map<String, dynamic> toJson() => {
        'bodyweight': bodyweight,
        if (preferredStyle != null) 'preferred_style': preferredStyle,
      };
}

class PerformanceMetrics {
  final int? maxPullups;
  final int? deadHangSeconds;
  final int? lsitSeconds;

  PerformanceMetrics({this.maxPullups, this.deadHangSeconds, this.lsitSeconds});

  Map<String, dynamic> toJson() => {
        if (maxPullups != null) 'max_pullups': maxPullups,
        if (deadHangSeconds != null) 'dead_hang_seconds': deadHangSeconds,
        if (lsitSeconds != null) 'lsit_seconds': lsitSeconds,
      };
}

class RecentClimbingData {
  final int? sessionsLast7Days;
  final List<String>? dominantCategories;
  final String? averageGrade;

  RecentClimbingData({this.sessionsLast7Days, this.dominantCategories, this.averageGrade});

  Map<String, dynamic> toJson() => {
        if (sessionsLast7Days != null) 'sessions_last_7_days': sessionsLast7Days,
        if (dominantCategories != null && dominantCategories!.isNotEmpty) 'dominant_categories': dominantCategories,
        if (averageGrade != null) 'average_grade': averageGrade,
      };
}

class FatigueData {
  final int? weeklyFatigueSum;
  final String? fatigueTrend; // up | down | stable

  FatigueData({this.weeklyFatigueSum, this.fatigueTrend});

  Map<String, dynamic> toJson() => {
        if (weeklyFatigueSum != null) 'weekly_fatigue_sum': weeklyFatigueSum,
        if (fatigueTrend != null) 'fatigue_trend': fatigueTrend,
      };
}

/// Упражнение из блока тренировки (расширенные поля).
class WorkoutBlockExercise {
  final String exerciseId;
  final String name;
  final String? nameRu;
  final String category;
  final String? trainingGoal;
  final String? loadType;
  final int fatigueIndex;
  final int defaultSets;
  final dynamic defaultReps;
  final int? holdSeconds;
  final int defaultRestSeconds;
  final String executionType;
  final String? progressionType;
  final String? comment;
  final String? hint;
  final String? dosage;

  WorkoutBlockExercise({
    required this.exerciseId,
    required this.name,
    this.nameRu,
    required this.category,
    this.trainingGoal,
    this.loadType,
    this.fatigueIndex = 0,
    this.defaultSets = 3,
    this.defaultReps = 6,
    this.holdSeconds,
    this.defaultRestSeconds = 90,
    this.executionType = 'reps',
    this.progressionType,
    this.comment,
    this.hint,
    this.dosage,
  });

  Map<String, dynamic> toJson() => {
        'exercise_id': exerciseId,
        'name': name,
        if (nameRu != null) 'name_ru': nameRu,
        'category': category,
        if (trainingGoal != null) 'training_goal': trainingGoal,
        if (loadType != null) 'load_type': loadType,
        'fatigue_index': fatigueIndex,
        'default_sets': defaultSets,
        'default_reps': defaultReps,
        if (holdSeconds != null) 'hold_seconds': holdSeconds,
        'default_rest_seconds': defaultRestSeconds,
        'execution_type': executionType,
        if (progressionType != null) 'progression_type': progressionType,
        if (comment != null) 'comment': comment,
        if (hint != null) 'hint': hint,
        if (dosage != null) 'dosage': dosage,
      };

  factory WorkoutBlockExercise.fromJson(Map<String, dynamic> json) {
    final reps = json['default_reps'];
    return WorkoutBlockExercise(
      exerciseId: json['exercise_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      nameRu: json['name_ru'] as String?,
      category: json['category'] as String? ?? 'ofp',
      trainingGoal: json['training_goal'] as String?,
      loadType: json['load_type'] as String?,
      fatigueIndex: json['fatigue_index'] as int? ?? 0,
      defaultSets: json['default_sets'] as int? ?? 3,
      defaultReps: reps,
      holdSeconds: json['hold_seconds'] as int?,
      defaultRestSeconds: json['default_rest_seconds'] as int? ?? 90,
      executionType: json['execution_type'] as String? ?? 'reps',
      progressionType: json['progression_type'] as String?,
      comment: json['comment'] as String?,
      hint: json['hint'] as String?,
      dosage: json['dosage'] as String?,
    );
  }

  String get displayName => nameRu ?? name;

  String get repsDisplay {
    if (holdSeconds != null && holdSeconds! > 0) return '${holdSeconds}с';
    if (defaultReps is int) return '$defaultReps';
    return defaultReps.toString();
  }

  String get restDisplay => '${defaultRestSeconds}с';
}

/// Ответ POST /workout/generate.
class WorkoutGenerateResponse {
  final Map<String, WorkoutBlockExercise?> blocks;
  final List<String> warnings;
  final String? weeklyFatigueWarning;
  final String? intensityExplanation;
  final String? whyThisSession;
  final String? progressionHint;
  final Map<String, int>? loadDistribution;
  final String? coachComment;

  WorkoutGenerateResponse({
    required this.blocks,
    this.warnings = const [],
    this.weeklyFatigueWarning,
    this.intensityExplanation,
    this.whyThisSession,
    this.progressionHint,
    this.loadDistribution,
    this.coachComment,
  });

  factory WorkoutGenerateResponse.fromJson(Map<String, dynamic> json) {
    final blocksRaw = json['blocks'] as Map<String, dynamic>? ?? {};
    final Map<String, WorkoutBlockExercise?> blocks = {};
    for (final e in blocksRaw.entries) {
      final v = e.value;
      if (v != null && v is Map<String, dynamic>) {
        blocks[e.key] = WorkoutBlockExercise.fromJson(v);
      } else {
        blocks[e.key] = null;
      }
    }
    final warningsRaw = json['warnings'] as List<dynamic>? ?? [];
    Map<String, int>? loadDist;
    final ld = json['load_distribution'] as Map<String, dynamic>?;
    if (ld != null) {
      loadDist = ld.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0));
    }
    return WorkoutGenerateResponse(
      blocks: blocks,
      warnings: warningsRaw.map((e) => e.toString()).toList(),
      weeklyFatigueWarning: json['weekly_fatigue_warning'] as String?,
      intensityExplanation: json['intensity_explanation'] as String?,
      whyThisSession: json['why_this_session'] as String?,
      progressionHint: json['progression_hint'] as String?,
      loadDistribution: loadDist,
      coachComment: json['coach_comment'] as String?,
    );
  }

  static const _blockOrder = [
    'warmup',
    'main',
    'secondary',
    'antagonist',
    'core',
    'cooldown',
  ];

  static const _blockTitlesRu = {
    'warmup': 'Разминка',
    'main': 'Основной блок',
    'secondary': 'Дополнительно',
    'antagonist': 'Антагонисты',
    'core': 'Кор',
    'cooldown': 'Заминка',
  };

  List<MapEntry<String, WorkoutBlockExercise?>> get orderedBlocks =>
      _blockOrder
          .where((k) => blocks.containsKey(k))
          .map((k) => MapEntry(k, blocks[k]))
          .toList();

  String blockTitleRu(String key) => _blockTitlesRu[key] ?? key;
}

/// Результат генерации — упражнения + комментарии тренера для сохранения и передачи в экран выполнения.
class GeneratedWorkoutResult {
  final List<MapEntry<String, WorkoutBlockExercise>> entries;
  final String? coachComment;
  final Map<String, int>? loadDistribution;
  final String? progressionHint;

  GeneratedWorkoutResult({
    required this.entries,
    this.coachComment,
    this.loadDistribution,
    this.progressionHint,
  });
}

/// Ответ GET /weekly-fatigue.
class WeeklyFatigueResponse {
  final int weeklyFatigueSum;
  final int? maxRecommended;
  final String? warning;

  WeeklyFatigueResponse({
    required this.weeklyFatigueSum,
    this.maxRecommended,
    this.warning,
  });

  /// Совместимость со старым API (current/limit).
  int get current => weeklyFatigueSum;
  int? get limit => maxRecommended;

  factory WeeklyFatigueResponse.fromJson(Map<String, dynamic> json) =>
      WeeklyFatigueResponse(
        weeklyFatigueSum: json['weekly_fatigue_sum'] as int? ?? json['current'] as int? ?? 0,
        maxRecommended: json['max_recommended'] as int? ?? json['limit'] as int?,
        warning: json['warning'] as String?,
      );
}
