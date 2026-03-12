import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/models/UserProfile.dart';

void main() {
  group('UserProfile', () {
    test('fromJson and toJson roundtrip', () {
      final json = {
        'firstname': 'Иван',
        'lastname': 'Петров',
        'team': 'Команда',
        'city': 'Москва',
        'contact': '+79001234567',
        'birthday': '1990-05-15',
        'sport_category': 'М',
        'gender': 'male',
        'email': 'test@example.com',
      };
      final p = UserProfile.fromJson(json);
      final out = p.toJson();
      expect(out['firstname'], 'Иван');
      expect(out['lastname'], 'Петров');
      expect(out['team'], 'Команда');
      expect(out['city'], 'Москва');
      expect(out['contact'], '+79001234567');
      expect(out['birthday'], '1990-05-15');
      expect(out['sport_category'], 'М');
      expect(out['gender'], 'male');
      expect(out['email'], 'test@example.com');
    });

    test('fromJson handles optional team and city defaults', () {
      final json = {
        'firstname': 'A',
        'lastname': 'B',
        'team': null,
        'city': null,
        'contact': '',
        'birthday': '',
        'sport_category': '',
        'gender': '',
        'email': 'a@b.com',
      };
      final p = UserProfile.fromJson(json);
      expect(p.team, '');
      expect(p.city, '');
    });

    test('fromJson handles aiMemoryConsent', () {
      final json = {
        'firstname': 'A',
        'lastname': 'B',
        'team': '',
        'city': '',
        'contact': '',
        'birthday': '',
        'sport_category': '',
        'gender': '',
        'email': 'a@b.com',
        'ai_memory_consent': true,
      };
      final p = UserProfile.fromJson(json);
      expect(p.aiMemoryConsent, isTrue);
    });
  });
}
