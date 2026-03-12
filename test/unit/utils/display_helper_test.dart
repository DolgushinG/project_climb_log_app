import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/models/NumberSets.dart';
import 'package:login_app/utils/display_helper.dart';

void main() {
  group('displayValue', () {
    test('returns value for non-empty string', () {
      expect(displayValue('Hello'), 'Hello');
      expect(displayValue('Тест'), 'Тест');
    });

    test('returns "Нет данных" for null', () {
      expect(displayValue(null), 'Нет данных');
    });

    test('returns "Нет данных" for empty string', () {
      expect(displayValue(''), 'Нет данных');
    });

    test('returns value as-is for whitespace-only string', () {
      // displayValue only checks empty, null, or "null" string — not whitespace
      expect(displayValue('   '), '   ');
    });

    test('returns "Нет данных" for "null" string (case insensitive)', () {
      expect(displayValue('null'), 'Нет данных');
      expect(displayValue('NULL'), 'Нет данных');
      expect(displayValue('Null'), 'Нет данных');
      expect(displayValue('  null  '), 'Нет данных');
    });
  });

  group('extractSetTimeOnly', () {
    test('returns time only from date+time string', () {
      expect(extractSetTimeOnly('12.02.2025 10:00'), '10:00');
    });

    test('returns time range as-is', () {
      expect(extractSetTimeOnly('10:00-11:00'), '10:00-11:00');
    });

    test('returns single time as-is', () {
      expect(extractSetTimeOnly('10:00'), '10:00');
    });

    test('returns empty for empty string', () {
      expect(extractSetTimeOnly(''), '');
      expect(extractSetTimeOnly('   '), '');
    });

    test('trims input', () {
      expect(extractSetTimeOnly('  10:00  '), '10:00');
    });
  });

  group('formatSetCompact', () {
    test('formats with number, day, time', () {
      final s = NumberSets(
        number_set: 1,
        id: 1,
        time: '10:00',
        day_of_week: 'mon',
        max_participants: 10,
        allow_years: null,
      );
      expect(formatSetCompact(s), '№1 · Пн · 10:00');
    });

    test('formats with number only when day and time empty', () {
      final s = NumberSets(
        number_set: 2,
        id: 2,
        time: '',
        day_of_week: '',
        max_participants: 10,
        allow_years: null,
      );
      expect(formatSetCompact(s), '№2');
    });

    test('uses Russian day names', () {
      final s = NumberSets(
        number_set: 3,
        id: 3,
        time: '14:00',
        day_of_week: 'wednesday',
        max_participants: 10,
        allow_years: null,
      );
      expect(formatSetCompact(s), '№3 · Ср · 14:00');
    });
  });
}
