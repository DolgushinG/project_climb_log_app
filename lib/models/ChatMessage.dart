/// Статус сообщения (как в мессенджерах).
enum MessageStatus {
  sending,    // отправляется
  sent,       // одна галочка — отправлено на сервер
  delivered,  // две галочки — AI ответил
  failed,     // не отправлено
}

/// Сообщение в чате с AI-тренером.
class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;
  /// Статус только для user-сообщений. null = sent (история, assistant).
  final MessageStatus? status;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.status,
  }) : timestamp = timestamp ?? DateTime.now();

  ChatMessage copyWith({
    String? role,
    String? content,
    DateTime? timestamp,
    MessageStatus? status,
  }) =>
      ChatMessage(
        role: role ?? this.role,
        content: content ?? this.content,
        timestamp: timestamp ?? this.timestamp,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() {
    final m = {
      'role': role,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
    };
    if (status != null) m['status'] = status!.name;
    return m;
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final role = json['role'] is String ? json['role'] as String : 'assistant';
    final rawContent = json['content'] ?? json['coach_comment'] ?? json['text'] ?? json['message'];
    final content = rawContent is String ? rawContent : '';
    final ts = json['timestamp'] ?? json['created_at'];
    MessageStatus? st;
    final statusStr = json['status'];
    if (statusStr is String) {
      st = MessageStatus.values.asNameMap()[statusStr];
    }
    return ChatMessage(
      role: role,
      content: content,
      timestamp: ts != null && ts is String ? DateTime.tryParse(ts) ?? DateTime.now() : DateTime.now(),
      status: st,
    );
  }

  @override
  String toString() => '[$role] $content';
}
