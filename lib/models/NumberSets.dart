

class NumberSets {
  final int number_set;
  final int id;
  final String time;
  final int max_participants;
  final String day_of_week;
  final List<dynamic>? allow_years;

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

  @override
  int get hashCode => id.hashCode;
}