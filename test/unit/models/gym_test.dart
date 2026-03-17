import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/models/Gym.dart';

void main() {
  group('Gym', () {
    test('fromJson parses gym with all fields', () {
      final json = {
        'id': 1,
        'name': 'Test Gym',
        'address': 'Street 1',
        'url': 'https://gym.com',
        'phone': '+79001234567',
        'hours': '9-21',
        'city': 'Moscow',
        'sum_likes': 50,
        'lat': 55.75,
        'long': 37.62,
        'map_iframe_url': 'https://map.example.com',
      };
      final g = Gym.fromJson(json);
      expect(g.id, 1);
      expect(g.name, 'Test Gym');
      expect(g.address, 'Street 1');
      expect(g.url, 'https://gym.com');
      expect(g.phone, '+79001234567');
      expect(g.hours, '9-21');
      expect(g.city, 'Moscow');
      expect(g.sumLikes, 50);
      expect(g.lat, 55.75);
      expect(g.long, 37.62);
      expect(g.mapIframeUrl, 'https://map.example.com');
    });

    test('fromJson handles missing optional fields', () {
      final json = {'id': 2, 'name': 'Minimal'};
      final g = Gym.fromJson(json);
      expect(g.id, 2);
      expect(g.name, 'Minimal');
      expect(g.address, isNull);
      expect(g.sumLikes, 0);
    });
  });

  group('GymEvent', () {
    test('fromJson parses event', () {
      final json = {
        'id': 10,
        'title': 'Event Title',
        'poster_url': 'https://poster.png',
        'start_date': '2025-01-01',
        'count_participant': 20,
        'is_finished': false,
        'is_registration_state': true,
      };
      final e = GymEvent.fromJson(json);
      expect(e.id, 10);
      expect(e.title, 'Event Title');
      expect(e.posterUrl, 'https://poster.png');
      expect(e.startDate, '2025-01-01');
      expect(e.countParticipant, 20);
      expect(e.isFinished, isFalse);
      expect(e.isRegistrationState, isTrue);
    });

    test('fromJson defaults countParticipant and booleans', () {
      final json = {'id': 1, 'title': 'T'};
      final e = GymEvent.fromJson(json);
      expect(e.countParticipant, 0);
      expect(e.isFinished, isFalse);
      expect(e.isRegistrationState, isFalse);
    });
  });

  group('GymJob', () {
    test('fromJson parses job', () {
      final json = {
        'id': 1,
        'title': 'Инструктор',
        'city': 'Moscow',
        'type': 'full-time',
      };
      final j = GymJob.fromJson(json);
      expect(j.id, 1);
      expect(j.title, 'Инструктор');
      expect(j.city, 'Moscow');
      expect(j.type, 'full-time');
    });

    group('typeLabel', () {
      test('returns Russian label for known types', () {
        expect(GymJob.typeLabel('full-time'), 'Полный день');
        expect(GymJob.typeLabel('part-time'), 'Частичная занятость');
        expect(GymJob.typeLabel('remote'), 'Удалённая работа');
        expect(GymJob.typeLabel('contract'), 'Сдельная работа');
        expect(GymJob.typeLabel('freelance'), 'Фриланс');
      });

      test('returns type as-is for unknown or null', () {
        expect(GymJob.typeLabel('other'), 'other');
        expect(GymJob.typeLabel(null), '');
      });
    });
  });

  group('GymSearchItem', () {
    test('fromJson parses search item', () {
      final json = {'id': 1, 'name': 'Gym A', 'city': 'Moscow'};
      final s = GymSearchItem.fromJson(json);
      expect(s.id, 1);
      expect(s.name, 'Gym A');
      expect(s.city, 'Moscow');
    });
  });

  group('GymListItem', () {
    test('fromJson parses list item', () {
      final json = {
        'id': 1,
        'name': 'Gym',
        'profile_url': '/gyms/1',
        'sum_likes': 5,
      };
      final l = GymListItem.fromJson(json);
      expect(l.id, 1);
      expect(l.name, 'Gym');
      expect(l.profileUrl, '/gyms/1');
      expect(l.sumLikes, 5);
    });
  });

  group('GymsPagination', () {
    test('fromJson parses pagination', () {
      final json = {'current_page': 1, 'last_page': 5, 'per_page': 12, 'total': 50};
      final p = GymsPagination.fromJson(json);
      expect(p.currentPage, 1);
      expect(p.lastPage, 5);
      expect(p.perPage, 12);
      expect(p.total, 50);
      expect(p.hasMore, isTrue);
    });

    test('hasMore returns false when on last page', () {
      final p = GymsPagination.fromJson({'current_page': 3, 'last_page': 3});
      expect(p.hasMore, isFalse);
    });

    test('fromJson defaults missing fields', () {
      final p = GymsPagination.fromJson({});
      expect(p.currentPage, 1);
      expect(p.lastPage, 1);
      expect(p.perPage, 12);
      expect(p.total, 0);
    });
  });

  group('GymsListResponse', () {
    test('fromJson parses response with gyms and pagination', () {
      final json = {
        'gyms': [
          {'id': 1, 'name': 'G1', 'profile_url': '/gyms/1'},
        ],
        'pagination': {'current_page': 1, 'last_page': 2, 'per_page': 12, 'total': 15},
      };
      final r = GymsListResponse.fromJson(json);
      expect(r.gyms.length, 1);
      expect(r.gyms.first.name, 'G1');
      expect(r.pagination.total, 15);
      expect(r.hasMore, isTrue);
    });

    test('fromJson handles empty gyms and missing pagination', () {
      final r = GymsListResponse.fromJson({'gyms': []});
      expect(r.gyms, isEmpty);
      expect(r.pagination.currentPage, 1);
    });
  });
}
