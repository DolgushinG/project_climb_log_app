// Тесты приложения Climbing Events.
// Запуск: flutter test test/widget_test.dart --reporter expanded

import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/models/StrengthAchievement.dart';

void main() {
  test('StrengthAchievement — полная проверка всех ачивок с выводом', () {
    final results = <String, bool>{};

    for (final a in strengthAchievements) {
      final m = _metricsForAchievement(a.id);
      final passed = m != null && a.check(m);
      results[a.id] = passed;
      print('  ${a.titleRu}: ${passed ? "✓ разблокирована" : "✗ заблокирована"}');
    }

    expect(results.length, equals(5));
    expect(results['crab_claws'], isTrue);
    expect(results['steel_crimp'], isTrue);
    expect(results['hauler'], isTrue);
    expect(results['balance_of_power'], isTrue);
    expect(results['iron_lock'], isTrue);
    print('');
    print('Все 5 ачивок проверены корректно.');
  });

  group('StrengthAchievement', () {
    test('все ачивки проверяются корректно — Клешни краба', () {
      // Щипок ≥40% от веса. Вес 70 кг → pinch нужно ≥28 кг
      final m = StrengthMetrics(
        pinchKg: 30,
        bodyWeightKg: 70,
      );
      final a = strengthAchievements.firstWhere((e) => e.id == 'crab_claws');
      expect(a.check(m), isTrue);

      final m2 = StrengthMetrics(pinchKg: 20, bodyWeightKg: 70);
      expect(a.check(m2), isFalse);
    });

    test('все ачивки проверяются корректно — Стальной crimp', () {
      // Палец (лучший из левого/правого) ≥60% от веса
      final m = StrengthMetrics(
        fingerLeftKg: 45,
        fingerRightKg: 40,
        bodyWeightKg: 70,
      );
      final a = strengthAchievements.firstWhere((e) => e.id == 'steel_crimp');
      expect(a.check(m), isTrue);

      final m2 = StrengthMetrics(
        fingerLeftKg: 30,
        bodyWeightKg: 70,
      );
      expect(a.check(m2), isFalse);
    });

    test('все ачивки проверяются корректно — Тягач', () {
      // +50% к весу на подтяге. Вес 70 → добавить ≥35 кг
      final m = StrengthMetrics(
        pullAddedKg: 40,
        bodyWeightKg: 70,
      );
      final a = strengthAchievements.firstWhere((e) => e.id == 'hauler');
      expect(a.check(m), isTrue);

      final m2 = StrengthMetrics(pullAddedKg: 30, bodyWeightKg: 70);
      expect(a.check(m2), isFalse);
    });

    test('все ачивки проверяются корректно — Баланс', () {
      // Асимметрия <3%
      final m = StrengthMetrics(
        fingerLeftKg: 40,
        fingerRightKg: 39.5,
      );
      final a = strengthAchievements.firstWhere((e) => e.id == 'balance_of_power');
      expect(a.check(m), isTrue);

      final m2 = StrengthMetrics(
        fingerLeftKg: 40,
        fingerRightKg: 35,
      );
      expect(a.check(m2), isFalse);
    });

    test('все ачивки проверяются корректно — Железный lock', () {
      final m = StrengthMetrics(lockOffSec: 35);
      final a = strengthAchievements.firstWhere((e) => e.id == 'iron_lock');
      expect(a.check(m), isTrue);

      final m2 = StrengthMetrics(lockOffSec: 25);
      expect(a.check(m2), isFalse);
    });

    test('StrengthMetrics вычисляет fingerBestPct и pinchPct', () {
      final m = StrengthMetrics(
        fingerLeftKg: 42,
        fingerRightKg: 38,
        pinchKg: 28,
        bodyWeightKg: 70,
      );
      expect(m.fingerBestPct, closeTo(60.0, 0.1));
      expect(m.pinchPct, closeTo(40.0, 0.1));
      expect(m.asymmetryPct, greaterThan(3));
    });
  });
}

StrengthMetrics? _metricsForAchievement(String id) {
  switch (id) {
    case 'crab_claws':
      return StrengthMetrics(pinchKg: 30, bodyWeightKg: 70);
    case 'steel_crimp':
      return StrengthMetrics(fingerLeftKg: 45, fingerRightKg: 40, bodyWeightKg: 70);
    case 'hauler':
      return StrengthMetrics(pullAddedKg: 40, bodyWeightKg: 70);
    case 'balance_of_power':
      return StrengthMetrics(fingerLeftKg: 40, fingerRightKg: 39.5);
    case 'iron_lock':
      return StrengthMetrics(lockOffSec: 35);
    default:
      return null;
  }
}
