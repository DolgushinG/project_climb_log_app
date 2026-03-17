import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/models/SuggestedAction.dart';

void main() {
  group('SuggestedAction', () {
    group('fromJson', () {
      test('parses full link action', () {
        final json = {
          'type': 'link',
          'label': 'Открыть',
          'url': 'https://example.com',
        };
        final a = SuggestedAction.fromJson(json);
        expect(a.type, 'link');
        expect(a.label, 'Открыть');
        expect(a.url, 'https://example.com');
        expect(a.eventId, isNull);
        expect(a.userId, isNull);
      });

      test('parses cancel_registration with event_id and user_id', () {
        final json = {
          'type': 'cancel_registration',
          'label': 'Отменить регистрацию',
          'event_id': 42,
          'user_id': 100,
        };
        final a = SuggestedAction.fromJson(json);
        expect(a.type, 'cancel_registration');
        expect(a.label, 'Отменить регистрацию');
        expect(a.eventId, 42);
        expect(a.userId, 100);
        expect(a.url, isNull);
      });

      test('handles numeric event_id as double', () {
        final json = {
          'type': 'link',
          'label': 'X',
          'event_id': 99.0,
        };
        final a = SuggestedAction.fromJson(json);
        expect(a.eventId, 99);
      });

      test('defaults type to link when missing or invalid', () {
        expect(SuggestedAction.fromJson({'label': 'A'}).type, 'link');
        expect(SuggestedAction.fromJson({'type': null, 'label': 'B'}).type, 'link');
      });

      test('defaults label to empty when missing or invalid', () {
        expect(SuggestedAction.fromJson({'type': 'link'}).label, '');
        expect(SuggestedAction.fromJson({'type': 'link', 'label': null}).label, '');
      });
    });

    group('getters', () {
      test('isLink returns true when type is link', () {
        expect(SuggestedAction(type: 'link', label: 'x').isLink, isTrue);
        expect(SuggestedAction(type: 'cancel_registration', label: 'x').isLink, isFalse);
      });

      test('isCancelRegistration returns true when type is cancel_registration', () {
        expect(SuggestedAction(type: 'cancel_registration', label: 'x').isCancelRegistration, isTrue);
        expect(SuggestedAction(type: 'link', label: 'x').isCancelRegistration, isFalse);
      });
    });
  });
}
