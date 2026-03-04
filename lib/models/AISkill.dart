/// Специализированный AI-ассистент (тренировочные планы, питание, психология и т.п.).
class AISkill {
  final String id;
  final String name;

  AISkill({required this.id, required this.name});

  factory AISkill.fromJson(Map<String, dynamic> json) {
    return AISkill(
      id: (json['id'] as String?) ?? 'default',
      name: (json['name'] as String?) ?? 'Универсальный тренер',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}
