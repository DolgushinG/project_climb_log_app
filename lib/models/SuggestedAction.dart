/// Кнопка под ответом AI Support.
class SuggestedAction {
  final String type; // 'link' | 'cancel_registration'
  final String label;
  final String? url;
  final int? eventId;
  final int? userId;

  SuggestedAction({
    required this.type,
    required this.label,
    this.url,
    this.eventId,
    this.userId,
  });

  factory SuggestedAction.fromJson(Map<String, dynamic> json) {
    return SuggestedAction(
      type: json['type'] is String ? json['type'] as String : 'link',
      label: json['label'] is String ? json['label'] as String : '',
      url: json['url'] is String ? json['url'] as String : null,
      eventId: json['event_id'] is int
          ? json['event_id'] as int
          : (json['event_id'] is num ? (json['event_id'] as num).toInt() : null),
      userId: json['user_id'] is int
          ? json['user_id'] as int
          : (json['user_id'] is num ? (json['user_id'] as num).toInt() : null),
    );
  }

  bool get isLink => type == 'link';
  bool get isCancelRegistration => type == 'cancel_registration';
}
