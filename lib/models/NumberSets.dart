int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

class NumberSets {
  final int number_set;
  final int id;
  final String time;
  final int max_participants;
  final String day_of_week;
  final List<dynamic>? allow_years;
  /// Год рождения от (для ограничения по возрасту)
  final int? allow_years_from;
  /// Год рождения до (для ограничения по возрасту)
  final int? allow_years_to;

  /// Количество участников (для блока сетов)
  final int participants_count;

  /// Свободных мест
  final int free;

  /// Заполненность 0–100%
  final num procent;

  /// CSS-класс для цвета прогресс-бара: custom-progress-low/medium/high
  final String progress_class;

  /// CSS-класс для цвета текста: text-low/medium/high
  final String text_class;

  NumberSets({
    required this.number_set,
    required this.id,
    required this.time,
    required this.max_participants,
    required this.day_of_week,
    required this.allow_years,
    this.allow_years_from,
    this.allow_years_to,
    this.participants_count = 0,
    this.free = 0,
    this.procent = 0,
    this.progress_class = 'custom-progress-low',
    this.text_class = 'text-low',
  });

  factory NumberSets.fromJson(Map<String, dynamic> json) {
    return NumberSets(
      number_set: json['number_set'] ?? 0,
      id: json['id'] ?? 0,
      time: (json['time'] ?? '').toString(),
      max_participants: json['max_participants'] ?? 0,
      day_of_week: (json['day_of_week'] ?? '').toString(),
      allow_years: json['allow_years'] ?? [],
      allow_years_from: _parseInt(json['allow_years_from']),
      allow_years_to: _parseInt(json['allow_years_to']),
      participants_count: json['participants_count'] ?? 0,
      free: json['free'] ?? 0,
      procent: (json['procent'] ?? 0).toDouble(),
      progress_class: (json['progress_class'] ?? 'custom-progress-low').toString(),
      text_class: (json['text_class'] ?? 'text-low').toString(),
    );
  }
  @override
  bool operator == (Object other) {
    if (identical(this, other)) return true;
    return other is NumberSets && other.id == id;
  }

  /// Проверяет, подходит ли год рождения пользователя под ограничения сета.
  /// Если оба allow_years_from и allow_years_to null — сет без ограничений по возрасту.
  bool matchesBirthYear(int? birthYear) {
    if (birthYear == null) return true;
    if (allow_years_from == null && allow_years_to == null) return true;
    if (allow_years_from != null && birthYear < allow_years_from!) return false;
    if (allow_years_to != null && birthYear > allow_years_to!) return false;
    return true;
  }

  /// Проверяет, пересекается ли диапазон годов категории с ограничениями сета.
  /// catYearFrom/catYearTo — год рождения от/до из категории (your_group).
  bool matchesCategoryYearRange(int? catYearFrom, int? catYearTo) {
    if (catYearFrom == null && catYearTo == null) return true;
    if (allow_years_from == null && allow_years_to == null) return true;
    final setFrom = allow_years_from ?? 0;
    final setTo = allow_years_to ?? 9999;
    final from = catYearFrom ?? 0;
    final to = catYearTo ?? 9999;
    return setFrom <= to && setTo >= from;
  }

  @override
  int get hashCode => id.hashCode;
}