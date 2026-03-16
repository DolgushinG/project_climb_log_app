/// Приглашение от тренера (отправленное или входящее).
class TrainerInvitation {
  final int id;
  final String? email;
  final int? trainerId;
  final String? trainerName;
  final String status;
  final String? createdAt;

  TrainerInvitation({
    required this.id,
    this.email,
    this.trainerId,
    this.trainerName,
    this.status = 'pending',
    this.createdAt,
  });

  factory TrainerInvitation.fromJson(Map<String, dynamic> json) {
    return TrainerInvitation(
      id: (json['id'] as num?)?.toInt() ?? 0,
      email: json['email']?.toString(),
      trainerId: (json['trainer_id'] as num?)?.toInt(),
      trainerName: json['trainer_name']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      createdAt: json['created_at']?.toString(),
    );
  }

  bool get isPending => status == 'pending';
}
