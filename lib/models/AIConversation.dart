/// Чат с AI-тренером (про силу, ловкость и т.п.).
class AIConversation {
  final int id;
  final String title;
  final String? skillId;
  final DateTime createdAt;
  final DateTime updatedAt;

  AIConversation({
    required this.id,
    required this.title,
    this.skillId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AIConversation.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['created_at'];
    final updatedAtRaw = json['updated_at'];
    return AIConversation(
      id: json['id'] as int,
      title: (json['title'] as String?) ?? '',
      skillId: json['skill_id'] as String?,
      createdAt: createdAtRaw is String ? DateTime.tryParse(createdAtRaw) ?? DateTime.now() : DateTime.now(),
      updatedAt: updatedAtRaw is String ? DateTime.tryParse(updatedAtRaw) ?? DateTime.now() : DateTime.now(),
    );
  }
}
