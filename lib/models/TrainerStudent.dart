/// Ученик тренера (краткая карточка).
class TrainerStudent {
  final int id;
  final String firstname;
  final String lastname;
  final String? email;
  final String? avatar;
  final String? createdAt;

  TrainerStudent({
    required this.id,
    required this.firstname,
    required this.lastname,
    this.email,
    this.avatar,
    this.createdAt,
  });

  factory TrainerStudent.fromJson(Map<String, dynamic> json) {
    return TrainerStudent(
      id: _toInt(json['id']) ?? 0,
      firstname: json['firstname']?.toString() ?? '',
      lastname: json['lastname']?.toString() ?? '',
      email: json['email']?.toString(),
      avatar: json['avatar']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }

  String get displayName =>
      '$firstname $lastname'.trim().isEmpty ? (email ?? 'Ученик #$id') : '$firstname $lastname'.trim();
}

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}
