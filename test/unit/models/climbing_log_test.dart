import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/models/ClimbingLog.dart';

void main() {
  group('RouteEntry', () {
    test('toJson returns correct map', () {
      final e = RouteEntry(grade: '6b', count: 3);
      expect(e.toJson(), {'grade': '6b', 'count': 3});
    });
  });

  group('ClimbingSessionRequest', () {
    test('toJson includes routes, date, gym_id when set', () {
      final r = ClimbingSessionRequest(
        routes: [RouteEntry(grade: '6a', count: 1)],
        date: '2025-01-15',
        gymId: 10,
      );
      expect(r.toJson(), {
        'routes': [
          {'grade': '6a', 'count': 1},
        ],
        'date': '2025-01-15',
        'gym_id': 10,
      });
    });

    test('toJson omits date and gym_id when null', () {
      final r = ClimbingSessionRequest(
        routes: [RouteEntry(grade: '7a', count: 2)],
      );
      expect(r.toJson(), {
        'routes': [
          {'grade': '7a', 'count': 2},
        ],
      });
    });
  });

  group('ClimbingProgress', () {
    test('fromJson parses full data', () {
      final json = {
        'maxGrade': '7a',
        'progressPercentage': 75,
        'grades': {'6a': 5, '6b': 3, '7a': 1},
      };
      final p = ClimbingProgress.fromJson(json);
      expect(p.maxGrade, '7a');
      expect(p.progressPercentage, 75);
      expect(p.grades, {'6a': 5, '6b': 3, '7a': 1});
    });

    test('fromJson handles numeric progressPercentage as string', () {
      final json = <String, dynamic>{
        'maxGrade': null,
        'progressPercentage': '50',
        'grades': <String, dynamic>{},
      };
      final p = ClimbingProgress.fromJson(json);
      expect(p.progressPercentage, 50);
    });

    test('fromJson handles missing grades', () {
      final json = {'maxGrade': '6b', 'progressPercentage': 0};
      final p = ClimbingProgress.fromJson(json);
      expect(p.grades, isEmpty);
    });
  });

  group('HistoryRoute', () {
    test('fromJson parses grade and count', () {
      final json = {'grade': '6c', 'count': 2};
      final r = HistoryRoute.fromJson(json);
      expect(r.grade, '6c');
      expect(r.count, 2);
    });

    test('fromJson handles count as num', () {
      final json = {'grade': '7a', 'count': 3.0};
      final r = HistoryRoute.fromJson(json);
      expect(r.count, 3);
    });
  });

  group('HistorySession', () {
    test('fromJson parses full session', () {
      final json = {
        'id': 1,
        'date': '2025-01-10',
        'gym_name': 'Скалодром',
        'gym_id': 5,
        'routes': [
          {'grade': '6a', 'count': 2},
        ],
      };
      final s = HistorySession.fromJson(json);
      expect(s.id, 1);
      expect(s.date, '2025-01-10');
      expect(s.gymName, 'Скалодром');
      expect(s.gymId, 5);
      expect(s.routes.length, 1);
      expect(s.routes.first.grade, '6a');
      expect(s.routes.first.count, 2);
    });

    test('fromJson uses default gym name when missing', () {
      final json = {'date': '2025-01-10', 'routes': []};
      final s = HistorySession.fromJson(json);
      expect(s.gymName, 'Не указан');
    });
  });
}
