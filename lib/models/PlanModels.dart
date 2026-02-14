/// Модели для API планов тренировок.

class PlanTemplateResponse {
  final List<Audience> audiences;
  final List<PlanTemplate> templates;
  final int minDurationWeeks;
  final int maxDurationWeeks;
  final int defaultDurationWeeks;
  final List<String> generalRecommendations;

  PlanTemplateResponse({
    required this.audiences,
    required this.templates,
    required this.minDurationWeeks,
    required this.maxDurationWeeks,
    required this.defaultDurationWeeks,
    this.generalRecommendations = const [],
  });

  factory PlanTemplateResponse.fromJson(Map<String, dynamic> json) {
    final audRaw = json['audiences'] as List<dynamic>? ?? [];
    final templRaw = json['templates'] as List<dynamic>? ?? [];
    final recRaw = json['general_recommendations'] as List<dynamic>? ?? [];
    return PlanTemplateResponse(
      audiences: audRaw.map((e) => Audience.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      templates: templRaw.map((e) => PlanTemplate.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      minDurationWeeks: json['min_duration_weeks'] as int? ?? 2,
      maxDurationWeeks: json['max_duration_weeks'] as int? ?? 12,
      defaultDurationWeeks: json['default_duration_weeks'] as int? ?? 2,
      generalRecommendations: recRaw.map((e) => e.toString()).toList(),
    );
  }
}

class Audience {
  final String key;
  final String nameRu;
  final int templateCount;

  Audience({required this.key, required this.nameRu, required this.templateCount});

  factory Audience.fromJson(Map<String, dynamic> json) => Audience(
        key: json['key'] as String? ?? '',
        nameRu: json['name_ru'] as String? ?? json['name'] as String? ?? json['key'] as String? ?? '',
        templateCount: json['template_count'] as int? ?? 0,
      );
}

class PlanTemplate {
  final String key;
  final String nameRu;
  final String? description;
  final int ofpPerWeek;
  final int sfpPerWeek;

  PlanTemplate({
    required this.key,
    required this.nameRu,
    this.description,
    this.ofpPerWeek = 2,
    this.sfpPerWeek = 1,
  });

  factory PlanTemplate.fromJson(Map<String, dynamic> json) => PlanTemplate(
        key: json['key'] as String? ?? '',
        nameRu: json['name_ru'] as String? ?? json['name'] as String? ?? json['key'] as String? ?? '',
        description: json['description'] as String? ?? json['description_ru'] as String?,
        ofpPerWeek: json['ofp_per_week'] as int? ?? 2,
        sfpPerWeek: json['sfp_per_week'] as int? ?? 1,
      );
}

class ActivePlan {
  final int id;
  final String templateKey;
  final String startDate;
  final String endDate;
  /// Дни недели для тренировок: [1]=Пн, [2]=Вт, ..., [7]=Вс. Опционально от бэка.
  final List<int>? scheduledWeekdays;
  /// Метки от бэка ["Пн","Ср","Пт"] — приоритет над нашим маппингом.
  final List<String>? scheduledWeekdaysLabels;
  /// День = лазание (1–2 ч) + ОФП/СФП. По умолчанию true — типичный сценарий «сначала лазание, потом силовая».
  final bool includeClimbingInDays;

  ActivePlan({
    required this.id,
    required this.templateKey,
    required this.startDate,
    required this.endDate,
    this.scheduledWeekdays,
    this.scheduledWeekdaysLabels,
    this.includeClimbingInDays = true,
  });

  factory ActivePlan.fromJson(Map<String, dynamic> json) {
    final sw = json['scheduled_weekdays'] as List<dynamic>?;
    final labels = json['scheduled_weekdays_labels'] as List<dynamic>?;
    return ActivePlan(
      id: json['id'] as int? ?? 0,
      templateKey: json['template_key'] as String? ?? '',
      startDate: json['start_date'] as String? ?? '',
      endDate: json['end_date'] as String? ?? '',
      scheduledWeekdays: sw?.map((e) => (e as num).toInt()).toList(),
      scheduledWeekdaysLabels: labels?.map((e) => e.toString()).toList(),
      includeClimbingInDays: json['include_climbing_in_days'] as bool? ?? true,
    );
  }

  static const _weekdayNames = ['', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
  String get scheduledWeekdaysDisplay {
    if (scheduledWeekdaysLabels != null && scheduledWeekdaysLabels!.isNotEmpty) {
      return scheduledWeekdaysLabels!.join(', ');
    }
    if (scheduledWeekdays == null || scheduledWeekdays!.isEmpty) return '';
    return scheduledWeekdays!.map((d) => _weekdayNames[d.clamp(1, 7)]).join(', ');
  }
}

class PlanDayResponse {
  final String date;
  final String sessionType; // ofp | sfp | rest
  final int? weekNumber;
  final int? ofpDayIndex;
  final int? sfpDayIndex;
  final List<PlanDayExercise> exercises;
  final List<PlanStretchingZone> stretching;
  final bool completed;
  final String? completedAt;
  final String? coachRecommendation;
  final int? estimatedMinutes;
  final String? loadLevel;
  final String? sessionFocus;
  /// Ожидается лазание в этот день (от бэка или из плана). Показывать блок «1. Лазание» перед ОФП/СФП.
  final bool expectsClimbing;

  PlanDayResponse({
    required this.date,
    required this.sessionType,
    this.weekNumber,
    this.ofpDayIndex,
    this.sfpDayIndex,
    this.exercises = const [],
    this.stretching = const [],
    this.completed = false,
    this.completedAt,
    this.coachRecommendation,
    this.estimatedMinutes,
    this.loadLevel,
    this.sessionFocus,
    this.expectsClimbing = false,
  });

  bool get isRest => sessionType == 'rest';
  bool get isOfp => sessionType == 'ofp';
  bool get isSfp => sessionType == 'sfp';

  factory PlanDayResponse.fromJson(Map<String, dynamic> json) {
    final exRaw = json['exercises'] as List<dynamic>? ?? [];
    final strRaw = json['stretching'] as List<dynamic>? ?? [];
    return PlanDayResponse(
      date: json['date'] as String? ?? '',
      sessionType: json['session_type'] as String? ?? 'rest',
      weekNumber: json['week_number'] as int?,
      ofpDayIndex: json['ofp_day_index'] as int?,
      sfpDayIndex: json['sfp_day_index'] as int?,
      exercises: exRaw.map((e) => PlanDayExercise.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      stretching: strRaw.map((e) => PlanStretchingZone.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      completed: json['completed'] as bool? ?? false,
      completedAt: json['completed_at'] as String?,
      coachRecommendation: json['coach_recommendation'] as String? ?? json['coach_comment'] as String?,
      estimatedMinutes: json['estimated_minutes'] as int?,
      loadLevel: json['load_level'] as String?,
      sessionFocus: json['session_focus'] as String?,
      expectsClimbing: json['expects_climbing'] as bool? ?? false,
    );
  }
}

class PlanDayExercise {
  final String? exerciseId;
  final String name;
  final int sets;
  final String reps;
  /// Готовый текст дозировки («3 подхода по 12 повторений»). При наличии — приоритет над sets+reps.
  final String? dosage;
  final String? comment;
  final String? hint;

  PlanDayExercise({
    this.exerciseId,
    required this.name,
    required this.sets,
    required this.reps,
    this.dosage,
    this.comment,
    this.hint,
  });

  /// Текст дозировки для отображения: dosage, если есть, иначе «sets × reps».
  String get dosageDisplay =>
      (dosage != null && dosage!.isNotEmpty) ? dosage! : '$sets × $reps';

  factory PlanDayExercise.fromJson(Map<String, dynamic> json) => PlanDayExercise(
        exerciseId: json['exercise_id'] as String?,
        name: json['name'] as String? ?? '',
        sets: json['sets'] as int? ?? 3,
        reps: json['reps'] as String? ?? '',
        dosage: json['dosage'] as String?,
        comment: json['comment'] as String?,
        hint: json['hint'] as String?,
      );
}

class PlanStretchingZone {
  final String zone;
  final List<String> exercises;

  PlanStretchingZone({required this.zone, this.exercises = const []});

  factory PlanStretchingZone.fromJson(Map<String, dynamic> json) {
    final exRaw = json['exercises'] as List<dynamic>? ?? [];
    return PlanStretchingZone(
      zone: json['zone'] as String? ?? '',
      exercises: exRaw.map((e) => e.toString()).toList(),
    );
  }
}

class PlanCalendarResponse {
  final String month;
  final ActivePlan plan;
  final List<CalendarDay> days;

  PlanCalendarResponse({
    required this.month,
    required this.plan,
    this.days = const [],
  });

  factory PlanCalendarResponse.fromJson(Map<String, dynamic> json) {
    final planRaw = json['plan'] as Map<String, dynamic>?;
    final daysRaw = json['days'] as List<dynamic>? ?? [];
    return PlanCalendarResponse(
      month: json['month'] as String? ?? '',
      plan: planRaw != null ? ActivePlan.fromJson(planRaw) : ActivePlan(id: 0, templateKey: '', startDate: '', endDate: ''),
      days: daysRaw.map((e) => CalendarDay.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    );
  }
}

class CalendarDay {
  final String date;
  final int dayOfWeek; // 0=Вс, 1=Пн, ..., 6=Сб
  final bool inPlanRange;
  final int? weekNumber;
  final String? sessionType;
  final int? ofpDayIndex;
  final int? sfpDayIndex;
  final bool completed;

  CalendarDay({
    required this.date,
    required this.dayOfWeek,
    this.inPlanRange = false,
    this.weekNumber,
    this.sessionType,
    this.ofpDayIndex,
    this.sfpDayIndex,
    this.completed = false,
  });

  factory CalendarDay.fromJson(Map<String, dynamic> json) => CalendarDay(
        date: json['date'] as String? ?? '',
        dayOfWeek: json['day_of_week'] as int? ?? 0,
        inPlanRange: json['in_plan_range'] as bool? ?? false,
        weekNumber: json['week_number'] as int?,
        sessionType: json['session_type'] as String?,
        ofpDayIndex: json['ofp_day_index'] as int?,
        sfpDayIndex: json['sfp_day_index'] as int?,
        completed: json['completed'] as bool? ?? false,
      );
}
