import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/models/ChatMessage.dart';

void main() {
  group('ChatMessage', () {
    test('constructor and toJson/fromJson roundtrip', () {
      final now = DateTime.now();
      final msg = ChatMessage(role: 'user', content: 'Привет', timestamp: now);

      final json = msg.toJson();
      final restored = ChatMessage.fromJson(json);

      expect(restored.role, 'user');
      expect(restored.content, 'Привет');
      expect(restored.timestamp.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
    });

    test('fromJson handles missing timestamp', () {
      final json = {'role': 'assistant', 'content': 'Пока'};
      final msg = ChatMessage.fromJson(json);
      expect(msg.role, 'assistant');
      expect(msg.content, 'Пока');
      // timestamp должен быть установлен в DateTime.now()
      expect(msg.timestamp, isNotNull);
    });
  });
}
