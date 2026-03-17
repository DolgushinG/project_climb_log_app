import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/models/SavedCustomSet.dart';

void main() {
  group('SavedCustomSet', () {
    test('fromJson parses set with exercises', () {
      final json = {
        'id': 1,
        'name': 'My Set',
        'exercises': [
          {
            'exercise_id': 'ex1',
            'order': 0,
            'sets': 3,
            'reps': '10',
            'rest_seconds': 90,
          },
        ],
        'created_at': '2025-01-01',
        'updated_at': '2025-01-02',
      };
      final s = SavedCustomSet.fromJson(json);
      expect(s.id, 1);
      expect(s.name, 'My Set');
      expect(s.exercises.length, 1);
      expect(s.exercises.first.exerciseId, 'ex1');
      expect(s.exercises.first.sets, 3);
      expect(s.exercises.first.reps, '10');
      expect(s.createdAt, '2025-01-01');
      expect(s.updatedAt, '2025-01-02');
    });

    test('fromJson handles empty or missing exercises', () {
      final s = SavedCustomSet.fromJson({'id': 0, 'name': 'Empty'});
      expect(s.exercises, isEmpty);
    });

    test('toJson roundtrip', () {
      final s = SavedCustomSet(
        id: 1,
        name: 'Test',
        exercises: [
          SavedCustomSetExercise(exerciseId: 'ex1', sets: 4, reps: '8'),
        ],
      );
      final json = s.toJson();
      expect(json['id'], 1);
      expect(json['name'], 'Test');
      expect((json['exercises'] as List).length, 1);
      expect((json['exercises'] as List).first['exercise_id'], 'ex1');
    });
  });

  group('SavedCustomSetExercise', () {
    test('fromJson parses exercise with defaults', () {
      final json = {'exercise_id': 'ex1'};
      final ex = SavedCustomSetExercise.fromJson(json);
      expect(ex.exerciseId, 'ex1');
      expect(ex.order, 0);
      expect(ex.sets, 3);
      expect(ex.reps, '10');
      expect(ex.restSeconds, 90);
    });

    test('fromJson parses full exercise from API', () {
      final json = {
        'exercise_id': 'ex1',
        'order': 1,
        'sets': 4,
        'reps': '15',
        'hold_seconds': 7,
        'rest_seconds': 60,
        'name': 'Pull-ups',
        'name_ru': 'Подтягивания',
        'category': 'ofp',
        'description': 'Desc',
      };
      final ex = SavedCustomSetExercise.fromJson(json);
      expect(ex.exerciseId, 'ex1');
      expect(ex.sets, 4);
      expect(ex.reps, '15');
      expect(ex.holdSeconds, 7);
      expect(ex.restSeconds, 60);
      expect(ex.name, 'Pull-ups');
      expect(ex.nameRu, 'Подтягивания');
    });

    test('displayName prefers nameRu over name', () {
      expect(
        SavedCustomSetExercise(exerciseId: 'x', name: 'A', nameRu: 'Б').displayName,
        'Б',
      );
      expect(
        SavedCustomSetExercise(exerciseId: 'x', name: 'A').displayName,
        'A',
      );
      expect(
        SavedCustomSetExercise(exerciseId: 'x').displayName,
        'x',
      );
    });

    test('displayName uses exerciseId when name and nameRu are null', () {
      expect(
        SavedCustomSetExercise(exerciseId: 'ex_id').displayName,
        'ex_id',
      );
    });

    test('displayName returns empty when name is empty string', () {
      expect(
        SavedCustomSetExercise(exerciseId: 'ex_id', name: '', nameRu: '').displayName,
        '',
      );
    });

    test('toCatalogExerciseIfEnriched returns null when no name', () {
      expect(
        SavedCustomSetExercise(exerciseId: 'x').toCatalogExerciseIfEnriched(),
        isNull,
      );
      expect(
        SavedCustomSetExercise(exerciseId: 'x', name: '', nameRu: '').toCatalogExerciseIfEnriched(),
        isNull,
      );
    });

    test('toCatalogExerciseIfEnriched returns CatalogExercise when enriched', () {
      final ex = SavedCustomSetExercise(
        exerciseId: 'ex1',
        name: 'Pull',
        nameRu: 'Подтяг',
        sets: 4,
        reps: '10',
        restSeconds: 90,
      );
      final cat = ex.toCatalogExerciseIfEnriched();
      expect(cat, isNotNull);
      expect(cat!.id, 'ex1');
      expect(cat.name, 'Pull');
      expect(cat.nameRu, 'Подтяг');
      expect(cat.category, 'ofp');
      expect(cat.level, 'intermediate');
      expect(cat.defaultSets, 4);
      expect(cat.defaultReps, '10');
      expect(cat.defaultRest, '90s');
    });

    test('toJson serializes exercise', () {
      final ex = SavedCustomSetExercise(
        exerciseId: 'ex1',
        order: 0,
        sets: 3,
        reps: '10',
        holdSeconds: 5,
        restSeconds: 90,
      );
      final json = ex.toJson();
      expect(json['exercise_id'], 'ex1');
      expect(json['order'], 0);
      expect(json['sets'], 3);
      expect(json['reps'], '10');
      expect(json['hold_seconds'], 5);
      expect(json['rest_seconds'], 90);
    });
  });
}
