import 'dart:convert';

/// Сообщение в чате с AI-тренером.
class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final role = json['role'] is String ? json['role'] as String : 'assistant';
    final rawContent = json['content'] ?? json['coach_comment'] ?? json['text'] ?? json['message'];
    final content = rawContent is String ? rawContent : '';
    final ts = json['timestamp'];
    return ChatMessage(
      role: role,
      content: content,
      timestamp: ts != null && ts is String ? DateTime.tryParse(ts) ?? DateTime.now() : DateTime.now(),
    );
  }

  @override
  String toString() => '[$role] $content';
}
