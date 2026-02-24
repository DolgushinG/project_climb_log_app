/// Модели для API планов тренировок.

int? _parseInt(dynamic v) =>
    v == null ? null : (v is int ? v : (v is num ? v.toInt() : null));

/// Guide для экрана «О плане» / «Как это работает».
class PlanGuide {
  final String? shortDescription;
  final PlanGuideSection? howItWorks;
  final PlanGuideSection? whatWeConsider;
  final PlanGuideSection? whatYouGet;
  final Map<String, PlanSessionTypeInfo>? sessionTypes;

  PlanGuide({
    this.shortDescription,
    this.howItWorks,
    this.whatWeConsider,
    this.whatYouGet,
    this.sessionTypes,
  });

  factory PlanGuide.fromJson(Map<String, dynamic>? json) {
    if (json == null) return PlanGuide();
    final stRaw = json['session_types'] as Map<String, dynamic>?;
    return PlanGuide(
      shortDescription: json['short_description'] as String?,
      howItWorks: _parseSection(json['how_it_works']),
      whatWeConsider: _parseSection(json['what_we_consider']),
      whatYouGet: _parseSection(json['what_you_get']),
      sessionTypes: stRaw != null
          ? stRaw.map((k, v) => MapEntry(k, PlanSessionTypeInfo.fromJson(Map<String, dynamic>.from(v as Map))))
          : null,
    );
  }

  static PlanGuideSection? _parseSection(dynamic raw) {
    if (raw == null || raw is! Map) return null;
    return PlanGuideSection.fromJson(Map<String, dynamic>.from(raw));
  }
}

class PlanGuideSection {
  final String? title;
  final List<PlanGuideSectionItem>? sections;
  final List<PlanGuideLabelText>? items;

  PlanGuideSection({this.title, this.sections, this.items});

  factory PlanGuideSection.fromJson(Map<String, dynamic> json) {
    final secRaw = json['sections'] as List<dynamic>?;
    final itemsRaw = json['items'] as List<dynamic>?;
    return PlanGuideSection(
      title: json['title'] as String?,
      sections: secRaw?.map((e) => PlanGuideSectionItem.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      items: itemsRaw?.map((e) => PlanGuideLabelText.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    );
  }
}

class PlanGuideSectionItem {
  final String? title;
  final String? text;

  PlanGuideSectionItem({this.title, this.text});

  factory PlanGuideSectionItem.fromJson(Map<String, dynamic> json) => PlanGuideSectionItem(
        title: json['title'] as String?,
        text: json['text'] as String?,
      );
}

class PlanGuideLabelText {
  final String? label;
  final String? text;

  PlanGuideLabelText({this.label, this.text});

  factory PlanGuideLabelText.fromJson(Map<String, dynamic> json) => PlanGuideLabelText(
        label: json['label'] as String?,
        text: json['text'] as String?,
      );
}

class PlanSessionTypeInfo {
  final String? name;
  final String? description;

  PlanSessionTypeInfo({this.name, this.description});

  factory PlanSessionTypeInfo.fromJson(Map<String, dynamic> json) => PlanSessionTypeInfo(
        name: json['name'] as String?,
        description: json['description'] as String?,
      );
}

class PlanTemplateResponse {
  final List<Audience> audiences;
  final List<PlanTemplate> templates;
  /// Цели планов: базовая подготовка, усилить тягу и т.д. Используется для фильтрации и бейджей.
  final List<PlanGoal> planGoals;
  final int minDurationWeeks;
  final int maxDurationWeeks;
  final int defaultDurationWeeks;
  final List<String> generalRecommendations;
  final PlanGuide? planGuide;
  /// Варианты времени на ОФП/СФП+растяжку: [15, 30, 45, 60, 90] и др. Бэк может отдавать объект {"15": {...}, "30": {...}}.
  final List<int> availableMinutesOptions;

  PlanTemplateResponse({
    required this.audiences,
    required this.templates,
    this.planGoals = const [],
    required this.minDurationWeeks,
    required this.maxDurationWeeks,
    required this.defaultDurationWeeks,
    this.generalRecommendations = const [],
    this.planGuide,
    this.availableMinutesOptions = const [15, 30, 45, 60, 90],
  });

  factory PlanTemplateResponse.fromJson(Map<String, dynamic> json) {
    final audRaw = json['audiences'] as List<dynamic>? ?? [];
    final templRaw = json['templates'] as List<dynamic>? ?? [];
    final goalsRaw = json['plan_goals'] as List<dynamic>? ?? [];
    final recRaw = json['general_recommendations'] as List<dynamic>? ?? [];
    final pgRaw = json['plan_guide'] as Map<String, dynamic>?;
    List<int> options = [15, 30, 45, 60, 90];
    try {
      final optRaw = json['available_minutes_options'];
      if (optRaw is List) {
        final parsed = optRaw.map((e) => (e is num ? e.toInt() : int.tryParse(e?.toString() ?? ''))).whereType<int>().toList();
        if (parsed.isNotEmpty) options = parsed;
      } else if (optRaw is Map) {
        final parsed = optRaw.keys.map((k) => int.tryParse(k.toString())).whereType<int>().toList()..sort();
        if (parsed.isNotEmpty) options = parsed;
      }
    } catch (_) {}
    return PlanTemplateResponse(
      audiences: audRaw.map((e) => Audience.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      templates: templRaw.map((e) => PlanTemplate.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      planGoals: goalsRaw.map((e) => PlanGoal.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      minDurationWeeks: json['min_duration_weeks'] as int? ?? 2,
      maxDurationWeeks: json['max_duration_weeks'] as int? ?? 12,
      defaultDurationWeeks: json['default_duration_weeks'] as int? ?? 2,
      generalRecommendations: recRaw.map((e) => e.toString()).toList(),
      planGuide: pgRaw != null ? PlanGuide.fromJson(pgRaw) : null,
      availableMinutesOptions: options.isNotEmpty ? options : [15, 30, 45, 60, 90],
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

/// Цель плана: базовая подготовка, усилить тягу и т.д.
class PlanGoal {
  final String key;
  final String labelRu;
  final String? description;

  PlanGoal({required this.key, required this.labelRu, this.description});

  factory PlanGoal.fromJson(Map<String, dynamic> json) => PlanGoal(
        key: json['key'] as String? ?? '',
        labelRu: json['label_ru'] as String? ?? json['label'] as String? ?? json['key'] as String? ?? '',
        description: json['description'] as String?,
      );
}

class PlanTemplate {
  final String key;
  final String nameRu;
  final String? description;
  /// Цель плана (key из plan_goals). null — план без явной цели.
  final String? planGoal;
  final int ofpPerWeek;
  final int sfpPerWeek;
  /// Растяжка каждый день (даже в дни без силовой).
  final bool stretchingDaily;

  PlanTemplate({
    required this.key,
    required this.nameRu,
    this.description,
    this.planGoal,
    this.ofpPerWeek = 2,
    this.sfpPerWeek = 1,
    this.stretchingDaily = false,
  });

  factory PlanTemplate.fromJson(Map<String, dynamic> json) => PlanTemplate(
        key: json['key'] as String? ?? '',
        nameRu: json['name_ru'] as String? ?? json['name'] as String? ?? json['key'] as String? ?? '',
        description: json['description'] as String? ?? json['description_ru'] as String?,
        planGoal: json['plan_goal'] as String?,
        ofpPerWeek: json['ofp_per_week'] as int? ?? 2,
        sfpPerWeek: json['sfp_per_week'] as int? ?? 1,
        stretchingDaily: json['stretching_daily'] as bool? ?? false,
      );
}

/// Результат GET /plans/{id}/progress — completed/total за один запрос (вместо N calendar).
class PlanProgressResponse {
  final int completed;
  final int total;

  PlanProgressResponse({required this.completed, required this.total});

  factory PlanProgressResponse.fromJson(Map<String, dynamic> json) => PlanProgressResponse(
        completed: _parseInt(json['completed']) ?? 0,
        total: _parseInt(json['total']) ?? 0,
      );
}

/// Результат GET /plans/active: план (или null) + plan_guide.
class ActivePlanResult {
  final ActivePlan? plan;
  final PlanGuide? planGuide;

  ActivePlanResult({this.plan, this.planGuide});

  factory ActivePlanResult.fromJson(Map<String, dynamic> json) {
    final planRaw = json['plan'] as Map<String, dynamic>?;
    final pgRaw = json['plan_guide'] as Map<String, dynamic>?;
    ActivePlan? plan;
    if (planRaw != null) {
      plan = ActivePlan.fromJson(planRaw);
      if (plan.id <= 0) plan = null;
    }
    return ActivePlanResult(
      plan: plan,
      planGuide: pgRaw != null ? PlanGuide.fromJson(pgRaw) : null,
    );
  }
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
  /// Фокус ОФП/СФП: balanced | sfp | ofp. От бэка при GET plans/active — для предзаполнения при редактировании.
  final String? ofpSfpFocus;
  /// Персонализация — для предзаполнения при редактировании (если бэк возвращает в GET plans/active).
  final int? availableMinutes;
  final bool? hasFingerboard;
  final List<String>? injuries;
  final String? preferredStyle;
  final int? experienceMonths;
  final List<int>? ofpWeekdays;
  final List<int>? sfpWeekdays;

  ActivePlan({
    required this.id,
    required this.templateKey,
    required this.startDate,
    required this.endDate,
    this.scheduledWeekdays,
    this.scheduledWeekdaysLabels,
    this.includeClimbingInDays = true,
    this.ofpSfpFocus,
    this.availableMinutes,
    this.hasFingerboard,
    this.injuries,
    this.preferredStyle,
    this.experienceMonths,
    this.ofpWeekdays,
    this.sfpWeekdays,
  });

  factory ActivePlan.fromJson(Map<String, dynamic> json) {
    final sw = json['scheduled_weekdays'] as List<dynamic>?;
    final labels = json['scheduled_weekdays_labels'] as List<dynamic>?;
    final injRaw = json['injuries'] as List<dynamic>?;
    final ofpRaw = json['ofp_weekdays'] as List<dynamic>?;
    final sfpRaw = json['sfp_weekdays'] as List<dynamic>?;
    return ActivePlan(
      id: json['id'] as int? ?? 0,
      templateKey: json['template_key'] as String? ?? '',
      startDate: json['start_date'] as String? ?? '',
      endDate: json['end_date'] as String? ?? '',
      scheduledWeekdays: sw?.map((e) => (e as num).toInt()).toList(),
      scheduledWeekdaysLabels: labels?.map((e) => e.toString()).toList(),
      includeClimbingInDays: json['include_climbing_in_days'] as bool? ?? true,
      ofpSfpFocus: json['ofp_sfp_focus'] as String?,
      availableMinutes: _parseInt(json['available_minutes']),
      hasFingerboard: json['has_fingerboard'] as bool?,
      injuries: injRaw?.map((e) => e.toString()).toList(),
      preferredStyle: json['preferred_style'] as String?,
      experienceMonths: _parseInt(json['experience_months']),
      ofpWeekdays: ofpRaw?.map((e) => (e as num).toInt()).toList(),
      sfpWeekdays: sfpRaw?.map((e) => (e as num).toInt()).toList(),
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

/// Ответ GET /plans/{id}/day-coach-comment — AI-комментарий, загружаемый в фоне.
class PlanDayCoachCommentResponse {
  final String? coachComment;
  final String? whyThisSession;
  final bool aiCoachAvailable;

  PlanDayCoachCommentResponse({
    this.coachComment,
    this.whyThisSession,
    this.aiCoachAvailable = false,
  });

  factory PlanDayCoachCommentResponse.fromJson(Map<String, dynamic> json) =>
      PlanDayCoachCommentResponse(
        coachComment: json['coach_comment'] as String?,
        whyThisSession: json['why_this_session'] as String?,
        aiCoachAvailable: json['ai_coach_available'] as bool? ?? false,
      );
}

class PlanDayResponse {
  final String date;
  final String sessionType; // ofp | sfp | rest | climbing
  final int? weekNumber;
  final int? ofpDayIndex;
  final int? sfpDayIndex;
  final List<PlanDayExercise> exercises;
  final List<PlanStretchingZone> stretching;
  final bool completed;
  final String? completedAt;
  final String? coachRecommendation;
  /// true — комментарий от GigaChat (AI), false — rule-based.
  final bool? aiCoachAvailable;

  /// Оценка времени на сессию (мин). Бэк: session_estimated_minutes или estimated_minutes.
  final int? estimatedMinutes;
  /// Оценка времени на растяжку (мин). Бэк: stretching_estimated_minutes.
  final int? stretchingEstimatedMinutes;
  final String? loadLevel;
  final String? sessionFocus;
  /// Ожидается лазание в этот день (от бэка или из плана). Показывать блок «1. Лазание» перед ОФП/СФП.
  final bool expectsClimbing;
  /// Обоснование нагрузки — для экрана «Почему эта тренировка».
  final String? whyThisSession;
  /// 0.6 / 0.8 или null (при 1.0) — компактный вариант по настройкам на сегодня.
  final double? sessionIntensityModifier;
  /// Слабые звенья пользователя — фокус на сегодня (блок «Твои слабые места»).
  /// Nullable для обратной совместимости с закэшированными/старыми объектами.
  final List<WeakLink>? weakLinks;
  /// Предупреждение о недельной нагрузке (уже близко к пределу / облегчённый вариант).
  /// null — всё в норме.
  final String? weeklyFatigueWarning;

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
    this.aiCoachAvailable,
    this.estimatedMinutes,
    this.stretchingEstimatedMinutes,
    this.loadLevel,
    this.sessionFocus,
    this.expectsClimbing = false,
    this.whyThisSession,
    this.sessionIntensityModifier,
    this.weakLinks,
    this.weeklyFatigueWarning,
  });

  bool get isRest => sessionType == 'rest';
  bool get isOfp => sessionType == 'ofp';
  bool get isSfp => sessionType == 'sfp';
  bool get isClimbing => sessionType == 'climbing';

  factory PlanDayResponse.fromJson(Map<String, dynamic> json) {
    final exRaw = json['exercises'] as List<dynamic>? ?? [];
    final strRaw = json['stretching'] as List<dynamic>? ?? [];
    final wlRaw = json['weak_links'] as List<dynamic>? ?? [];
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
      aiCoachAvailable: json['ai_coach_available'] as bool?,
      estimatedMinutes: _parseInt(json['session_estimated_minutes'] ?? json['estimated_minutes']),
      stretchingEstimatedMinutes: _parseInt(json['stretching_estimated_minutes']),
      loadLevel: json['load_level'] as String?,
      sessionFocus: json['session_focus'] as String?,
      expectsClimbing: json['expects_climbing'] as bool? ?? false,
      whyThisSession: json['why_this_session'] as String?,
      sessionIntensityModifier: (json['session_intensity_modifier'] as num?)?.toDouble(),
      weakLinks: wlRaw.map((e) => WeakLink.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      weeklyFatigueWarning: json['weekly_fatigue_warning'] as String?,
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
  /// Подсказка «как это поможет в лазании» (для ОФП/СФП).
  final String? climbingBenefit;
  /// Оценка времени на упражнение (мин). Бэк: estimated_minutes.
  final int? estimatedMinutes;
  /// Слабое звено, которое закрывает это упражнение (совпадает с weak_links[].key).
  final String? targetsWeakLink;

  PlanDayExercise({
    this.exerciseId,
    required this.name,
    required this.sets,
    required this.reps,
    this.dosage,
    this.comment,
    this.hint,
    this.climbingBenefit,
    this.estimatedMinutes,
    this.targetsWeakLink,
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
        climbingBenefit: json['climbing_benefit'] as String?,
        estimatedMinutes: _parseInt(json['estimated_minutes']),
        targetsWeakLink: json['targets_weak_link'] as String?,
      );
}

/// Слабое звено пользователя — фокус дня из бэкенда.
class WeakLink {
  final String key;
  final String labelRu;
  final String hint;
  /// Почему слабое (метрики, порог) — для bottom sheet «почему они слабые».
  final String? reason;

  WeakLink({required this.key, required this.labelRu, required this.hint, this.reason});

  factory WeakLink.fromJson(Map<String, dynamic> json) => WeakLink(
        key: json['key'] as String? ?? '',
        labelRu: json['label_ru'] as String? ?? json['label'] as String? ?? '',
        hint: json['hint'] as String? ?? '',
        reason: json['reason'] as String?,
      );
}

/// Одно упражнение растяжки в зоне.
class PlanStretchingExercise {
  final String name;
  final String? exerciseId;
  final String? hint;
  final String? climbingBenefit;
  /// Оценка времени (мин). Бэк: estimated_minutes.
  final int? estimatedMinutes;

  PlanStretchingExercise({
    required this.name,
    this.exerciseId,
    this.hint,
    this.climbingBenefit,
    this.estimatedMinutes,
  });

  factory PlanStretchingExercise.fromJson(dynamic json) {
    if (json is String) return PlanStretchingExercise(name: json);
    if (json is Map<String, dynamic>) {
      return PlanStretchingExercise(
        name: json['name'] as String? ?? '',
        exerciseId: json['exercise_id'] as String?,
        hint: json['hint'] as String?,
        climbingBenefit: json['climbing_benefit'] as String?,
        estimatedMinutes: _parseInt(json['estimated_minutes']),
      );
    }
    return PlanStretchingExercise(name: json.toString());
  }
}

class PlanStretchingZone {
  final String zone;
  final List<PlanStretchingExercise> exercises;

  PlanStretchingZone({required this.zone, this.exercises = const []});

  factory PlanStretchingZone.fromJson(Map<String, dynamic> json) {
    final exRaw = json['exercises'] as List<dynamic>? ?? [];
    return PlanStretchingZone(
      zone: json['zone'] as String? ?? '',
      exercises: exRaw.map((e) => PlanStretchingExercise.fromJson(e)).toList(),
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
