

class NumberSets {
  final int number_set;
  final int id;
  final String time;
  final int max_participants;
  final String day_of_week;
  final List<dynamic>? allow_years;

  NumberSets({
    required this.number_set,
    required this.id,
    required this.time,
    required this.max_participants,
    required this.day_of_week,
    required this.allow_years,
  });

  factory NumberSets.fromJson(Map<String, dynamic> json) {
    return NumberSets(
      number_set: json['number_set'],
      id: json['id'],
      time: json['time'],
      max_participants: json['max_participants'],
      day_of_week: json['day_of_week'],
      allow_years: json['allow_years'] ?? [],
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