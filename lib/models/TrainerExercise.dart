/// Разделитель в description для обратной совместимости (если бэкенд не вернул отдельные поля).
const String _kDescDelimiter = '\n\n---ПОЛЬЗА---\n';

/// Упражнение, созданное тренером. Видно только тренеру и его ученикам.
class TrainerExercise {
  final String id;
  final String name;
  final String? nameRu;
  final String category;
  final String? description;
  /// Как выполнять упражнение (обязательное при создании).
  final String? howToPerform;
  /// Польза для скалолазания (обязательное при создании).
  final String? climbingBenefits;
  final int defaultSets;
  final String defaultReps;
  final String defaultRest;
  final int? holdSeconds;

  TrainerExercise({
    required this.id,
    required this.name,
    this.nameRu,
    required this.category,
    this.description,
    this.howToPerform,
    this.climbingBenefits,
    this.defaultSets = 3,
    this.defaultReps = '6',
    this.defaultRest = '90s',
    this.holdSeconds,
  });

  factory TrainerExercise.fromJson(Map<String, dynamic> json) {
    String? howTo = json['how_to_perform']?.toString();
    String? benefits = json['climbing_benefits']?.toString();
    final desc = json['description']?.toString();
    if (desc != null && desc.isNotEmpty) {
      if ((howTo == null || howTo.isEmpty || benefits == null || benefits.isEmpty) &&
          desc.contains(_kDescDelimiter)) {
        final parts = desc.split(_kDescDelimiter);
        howTo ??= parts[0].trim();
        benefits ??= parts.length > 1 ? parts[1].trim() : null;
      } else if (howTo == null || howTo.isEmpty) {
        howTo ??= desc;
      }
    }
    return TrainerExercise(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      nameRu: json['name_ru']?.toString(),
      category: json['category']?.toString() ?? 'ofp',
      description: desc,
      howToPerform: howTo?.isNotEmpty == true ? howTo : null,
      climbingBenefits: benefits?.isNotEmpty == true ? benefits : null,
      defaultSets: json['default_sets'] as int? ?? 3,
      defaultReps: json['default_reps']?.toString() ?? '6',
      defaultRest: json['default_rest']?.toString() ?? '90s',
      holdSeconds: json['hold_seconds'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name,
      if (nameRu != null && nameRu!.isNotEmpty) 'name_ru': nameRu,
      'category': category,
      'default_sets': defaultSets,
      'default_reps': defaultReps,
      'default_rest': defaultRest,
      if (holdSeconds != null) 'hold_seconds': holdSeconds,
    };
    if (howToPerform != null && howToPerform!.isNotEmpty) {
      map['how_to_perform'] = howToPerform;
    }
    if (climbingBenefits != null && climbingBenefits!.isNotEmpty) {
      map['climbing_benefits'] = climbingBenefits;
    }
    // Fallback для бэкендов, у которых пока только description
    if (howToPerform != null && climbingBenefits != null) {
      map['description'] = '$howToPerform$_kDescDelimiter$climbingBenefits';
    } else if (description != null && description!.isNotEmpty) {
      map['description'] = description;
    }
    return map;
  }

  String get displayName => (nameRu != null && nameRu!.isNotEmpty) ? nameRu! : name;
}
