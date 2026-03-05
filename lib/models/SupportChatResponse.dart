import 'ChatMessage.dart';
import 'SuggestedAction.dart';

/// Ответ на сообщение в AI Support.
class SupportChatResponse {
  final String content;
  final DateTime timestamp;
  final List<SuggestedAction> suggestedActions;
  final List<ChatMessage> history;

  SupportChatResponse({
    required this.content,
    required this.timestamp,
    required this.suggestedActions,
    required this.history,
  });

  factory SupportChatResponse.fromJson(Map<String, dynamic> json) {
    final content = json['content'] is String ? json['content'] as String : '';
    final tsRaw = json['timestamp'];
    final timestamp = tsRaw is String
        ? DateTime.tryParse(tsRaw) ?? DateTime.now()
        : DateTime.now();

    final actionsRaw = json['suggested_actions'];
    List<SuggestedAction> suggestedActions = [];
    if (actionsRaw is List) {
      for (final a in actionsRaw) {
        if (a is Map) {
          suggestedActions.add(SuggestedAction.fromJson(Map<String, dynamic>.from(a)));
        }
      }
    }

    final historyRaw = json['history'];
    List<ChatMessage> history = [];
    if (historyRaw is List) {
      for (final h in historyRaw) {
        if (h is Map) {
          history.add(ChatMessage.fromJson(Map<String, dynamic>.from(h)));
        }
      }
    }

    return SupportChatResponse(
      content: content,
      timestamp: timestamp,
      suggestedActions: suggestedActions,
      history: history,
    );
  }
}
