import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/models/StrengthAchievement.dart';
import 'package:login_app/services/TrainingPlanGenerator.dart';

void main() {
  late TrainingPlanGenerator generator;

  setUp(() {
    generator = TrainingPlanGenerator();
  });

  group('analyzeWeakLink', () {
    test('returns maintain when all metrics balanced', () {
      // finger 57%, pull 100%, pinch 57%, asym ~2% — no weakness
      final m = StrengthMetrics(
        fingerLeftKg: 40,
        fingerRightKg: 39,
        bodyWeightKg: 70,
        pull1RmPct: 100,
        pinch40Kg: 40,
        lockOffSec: 30,
      );
      final a = generator.analyzeWeakLink(m);
      expect(a.focusArea, 'maintain');
      expect(a.protocols, isEmpty);
    });

    test('detects fingersWeak when finger < pull*0.5', () {
      final m = StrengthMetrics(
        fingerLeftKg: 20,
        fingerRightKg: 18,
        bodyWeightKg: 70,
        pull1RmPct: 130,
      );
      final a = generator.analyzeWeakLink(m);
      expect(a.fingersWeak, isTrue);
      expect(a.protocols, contains('max_hangs'));
    });

    test('detects pullWeak when pull < finger*1.5', () {
      final m = StrengthMetrics(
        fingerLeftKg: 50,
        fingerRightKg: 48,
        bodyWeightKg: 70,
        pull1RmPct: 50,
      );
      final a = generator.analyzeWeakLink(m);
      expect(a.pullWeak, isTrue);
      expect(a.protocols, contains('power_pulls'));
    });

    test('detects pinchWeak when pinch < finger*0.7', () {
      final m = StrengthMetrics(
        fingerLeftKg: 50,
        fingerRightKg: 48,
        bodyWeightKg: 70,
        pinch40Kg: 20,
      );
      final a = generator.analyzeWeakLink(m);
      expect(a.pinchWeak, isTrue);
      expect(a.protocols, contains('pinch_lifting'));
    });

    test('detects asymmetryHigh when asym > 10', () {
      final m = StrengthMetrics(
        fingerLeftKg: 50,
        fingerRightKg: 35,
        bodyWeightKg: 70,
      );
      final a = generator.analyzeWeakLink(m);
      expect(a.asymmetryHigh, isTrue);
      expect(a.protocols, contains('unilateral'));
    });

    test('uses target grade 6b when specified', () {
      final m = StrengthMetrics(
        fingerLeftKg: 25,
        fingerRightKg: 24,
        bodyWeightKg: 70,
        pull1RmPct: 120,
      );
      final a = generator.analyzeWeakLink(m, targetGrade: '6b');
      expect(a.focusArea, isNotEmpty);
    });
  });

  group('generateCoachTip', () {
    test('returns fingers tip when fingersWeak', () {
      final m = StrengthMetrics(
        fingerLeftKg: 25,
        bodyWeightKg: 70,
        pull1RmPct: 100,
      );
      final a = generator.analyzeWeakLink(m);
      final tip = generator.generateCoachTip(m, a);
      expect(tip, contains('Max Hangs'));
      expect(tip, contains('пальцев'));
    });

    test('returns pull tip when pullWeak', () {
      final m = StrengthMetrics(
        fingerLeftKg: 50,
        bodyWeightKg: 70,
        pull1RmPct: 40,
      );
      final a = generator.analyzeWeakLink(m);
      final tip = generator.generateCoachTip(m, a);
      expect(tip, contains('Power Pulls'));
      expect(tip, contains('спину'));
    });

    test('returns asymmetry tip when asymmetryHigh', () {
      final m = StrengthMetrics(
        fingerLeftKg: 50,
        fingerRightKg: 35,
        bodyWeightKg: 70,
      );
      final a = generator.analyzeWeakLink(m);
      final tip = generator.generateCoachTip(m, a);
      expect(tip, contains('Offset'));
      expect(tip, contains('рук'));
    });

    test('returns maintain tip when no weakness', () {
      final m = StrengthMetrics(
        fingerLeftKg: 40,
        fingerRightKg: 39,
        bodyWeightKg: 70,
        pull1RmPct: 100,
        pinch40Kg: 40,
      );
      final a = generator.analyzeWeakLink(m);
      final tip = generator.generateCoachTip(m, a);
      expect(tip, contains('Repeaters'));
      expect(tip, contains('слабого звена нет'));
    });
  });

  group('generatePlan', () {
    test('generates plan with drills when fingers weak', () {
      final m = StrengthMetrics(
        fingerLeftKg: 30,
        fingerRightKg: 28,
        bodyWeightKg: 70,
        pull1RmPct: 100,
      );
      final a = generator.analyzeWeakLink(m);
      final plan = generator.generatePlan(m, a);
      expect(plan.drills, isNotEmpty);
      expect(plan.focusArea, isNotEmpty);
      expect(plan.coachTip, isNotNull);
      expect(plan.weeksPlan, 4);
      expect(plan.sessionsPerWeek, 2);
    });

    test('generates Repeaters when maintain', () {
      final m = StrengthMetrics(
        fingerLeftKg: 40,
        fingerRightKg: 39,
        bodyWeightKg: 70,
        pull1RmPct: 100,
        pinch40Kg: 40,
      );
      final a = generator.analyzeWeakLink(m);
      final plan = generator.generatePlan(m, a);
      expect(plan.drills.any((d) => d.name.contains('Repeaters')), isTrue);
    });
  });

  group('prepareRadarData', () {
    test('returns radar data with labels', () {
      final m = StrengthMetrics(
        fingerLeftKg: 40,
        fingerRightKg: 38,
        bodyWeightKg: 70,
        pull1RmPct: 100,
        pinch40Kg: 25,
        lockOffSec: 25,
      );
      final radar = generator.prepareRadarData(m);
      expect(radar.labels, ['Пальцы', 'Спина', 'Щипок', 'Lock', 'Баланс']);
      expect(radar.userValues.length, 5);
      expect(radar.targetValues.length, 5);
    });

    test('clamps values to 0-1 range', () {
      final m = StrengthMetrics(
        fingerLeftKg: 80,
        fingerRightKg: 78,
        bodyWeightKg: 70,
      );
      final radar = generator.prepareRadarData(m);
      for (final v in radar.userValues) {
        expect(v, inInclusiveRange(0.0, 1.0));
      }
    });
  });
}
