import 'ChatMessage.dart';

/// Результат отправки сообщения AI (сообщение + conversation_id + skill_id при первом сообщении).
class SendMessageResult {
  final ChatMessage message;
  final int? conversationId;
  /// ID скилла (ассистента) — для отображения в UI.
  final String? skillId;

  SendMessageResult({required this.message, this.conversationId, this.skillId});
}
