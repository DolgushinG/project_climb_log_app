import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/models/TrainingPlan.dart';

void main() {
  group('TrainingDrill', () {
    test('fromJson and toJson roundtrip', () {
      final json = {
        'name': 'Max Hangs',
        'target_weight_kg': 25.5,
        'sets': 3,
        'reps': '7:13',
        'rest': '180s',
        'hint': 'Some hint',
        'exercise_id': 'max_hangs_1',
      };
      final d = TrainingDrill.fromJson(json);
      final out = d.toJson();
      expect(out['name'], 'Max Hangs');
      expect(out['target_weight_kg'], 25.5);
      expect(out['sets'], 3);
      expect(out['reps'], '7:13');
      expect(out['rest'], '180s');
      expect(out['hint'], 'Some hint');
      expect(out['exercise_id'], 'max_hangs_1');
    });

    test('fromJson uses defaults for missing fields', () {
      final json = {'name': 'Drill'};
      final d = TrainingDrill.fromJson(json);
      expect(d.targetWeightKg, isNull);
      expect(d.sets, 3);
      expect(d.reps, '5s hold');
      expect(d.rest, '180s');
      expect(d.hint, isNull);
      expect(d.exerciseId, isNull);
    });
  });

  group('TrainingPlan', () {
    test('fromJson and toJson roundtrip', () {
      final json = {
        'focus_area': 'max_hangs',
        'weeks_plan': 4,
        'sessions_per_week': 2,
        'target_grade': '7b',
        'coach_tip': 'Tip text',
        'drills': [
          {
            'name': 'Drill 1',
            'sets': 3,
            'reps': '5',
            'rest': '90s',
          },
        ],
      };
      final p = TrainingPlan.fromJson(json);
      expect(p.focusArea, 'max_hangs');
      expect(p.weeksPlan, 4);
      expect(p.sessionsPerWeek, 2);
      expect(p.targetGrade, '7b');
      expect(p.coachTip, 'Tip text');
      expect(p.drills.length, 1);
      expect(p.drills.first.name, 'Drill 1');

      final out = p.toJson();
      expect(out['focus_area'], 'max_hangs');
      expect(out['weeks_plan'], 4);
      expect(out['sessions_per_week'], 2);
      expect(out['target_grade'], '7b');
      expect(out['coach_tip'], 'Tip text');
      expect(out['drills'], isA<List>());
    });

    test('fromJson uses defaults when fields missing', () {
      final json = <String, dynamic>{};
      final p = TrainingPlan.fromJson(json);
      expect(p.focusArea, 'general');
      expect(p.weeksPlan, 4);
      expect(p.sessionsPerWeek, 2);
      expect(p.targetGrade, '7b');
      expect(p.coachTip, isNull);
      expect(p.drills, isEmpty);
    });
  });
}
