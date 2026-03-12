import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/models/NumberSets.dart';

void main() {
  group('NumberSets.fromJson', () {
    test('parses full JSON', () {
      final json = {
        'number_set': 1,
        'id': 42,
        'time': '10:00',
        'max_participants': 20,
        'day_of_week': 'mon',
        'allow_years': [],
        'allow_years_from': 1990,
        'allow_years_to': 2010,
        'participants_count': 5,
        'free': 15,
        'procent': 25.5,
        'progress_class': 'custom-progress-low',
        'text_class': 'text-low',
      };
      final s = NumberSets.fromJson(json);
      expect(s.number_set, 1);
      expect(s.id, 42);
      expect(s.time, '10:00');
      expect(s.day_of_week, 'mon');
      expect(s.allow_years_from, 1990);
      expect(s.allow_years_to, 2010);
      expect(s.procent, 25.5);
    });

    test('handles missing optional fields with defaults', () {
      final json = {'number_set': 1, 'id': 1};
      final s = NumberSets.fromJson(json);
      expect(s.time, '');
      expect(s.day_of_week, '');
      expect(s.allow_years_from, isNull);
      expect(s.allow_years_to, isNull);
      expect(s.participants_count, 0);
      expect(s.free, 0);
      expect(s.procent, 0);
    });
  });

  group('NumberSets.matchesBirthYear', () {
    test('returns true when no age restrictions', () {
      final s = NumberSets(
        number_set: 1,
        id: 1,
        time: '10:00',
        day_of_week: 'mon',
        max_participants: 10,
        allow_years: null,
      );
      expect(s.matchesBirthYear(2000), isTrue);
      expect(s.matchesBirthYear(null), isTrue);
    });

    test('returns true when birthYear in range', () {
      final s = NumberSets(
        number_set: 1,
        id: 1,
        time: '10:00',
        day_of_week: 'mon',
        max_participants: 10,
        allow_years: null,
        allow_years_from: 1990,
        allow_years_to: 2010,
      );
      expect(s.matchesBirthYear(2000), isTrue);
      expect(s.matchesBirthYear(1990), isTrue);
      expect(s.matchesBirthYear(2010), isTrue);
    });

    test('returns false when birthYear below range', () {
      final s = NumberSets(
        number_set: 1,
        id: 1,
        time: '10:00',
        day_of_week: 'mon',
        max_participants: 10,
        allow_years: null,
        allow_years_from: 1990,
        allow_years_to: 2010,
      );
      expect(s.matchesBirthYear(1985), isFalse);
    });

    test('returns false when birthYear above range', () {
      final s = NumberSets(
        number_set: 1,
        id: 1,
        time: '10:00',
        day_of_week: 'mon',
        max_participants: 10,
        allow_years: null,
        allow_years_from: 1990,
        allow_years_to: 2010,
      );
      expect(s.matchesBirthYear(2015), isFalse);
    });

    test('returns true when birthYear null', () {
      final s = NumberSets(
        number_set: 1,
        id: 1,
        time: '10:00',
        day_of_week: 'mon',
        max_participants: 10,
        allow_years: null,
        allow_years_from: 1990,
        allow_years_to: 2010,
      );
      expect(s.matchesBirthYear(null), isTrue);
    });
  });

  group('NumberSets.matchesCategoryYearRange', () {
    test('returns true when no set restrictions', () {
      final s = NumberSets(
        number_set: 1,
        id: 1,
        time: '10:00',
        day_of_week: 'mon',
        max_participants: 10,
        allow_years: null,
      );
      expect(s.matchesCategoryYearRange(1990, 2000), isTrue);
    });

    test('returns true when ranges overlap', () {
      final s = NumberSets(
        number_set: 1,
        id: 1,
        time: '10:00',
        day_of_week: 'mon',
        max_participants: 10,
        allow_years: null,
        allow_years_from: 1995,
        allow_years_to: 2005,
      );
      expect(s.matchesCategoryYearRange(2000, 2010), isTrue);
      expect(s.matchesCategoryYearRange(1990, 2000), isTrue);
    });

    test('returns false when ranges do not overlap', () {
      final s = NumberSets(
        number_set: 1,
        id: 1,
        time: '10:00',
        day_of_week: 'mon',
        max_participants: 10,
        allow_years: null,
        allow_years_from: 1995,
        allow_years_to: 2000,
      );
      expect(s.matchesCategoryYearRange(2005, 2010), isFalse);
      expect(s.matchesCategoryYearRange(1985, 1990), isFalse);
    });
  });
}
