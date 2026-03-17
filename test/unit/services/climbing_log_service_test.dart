import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:login_app/services/ClimbingLogService.dart';

/// Mock HTTP client that returns predefined responses for grades API.
class MockGradesHttpClient extends http.BaseClient {
  final int statusCode;
  final String body;

  MockGradesHttpClient({this.statusCode = 200, this.body = '{}'});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path.contains('climbing-logs/grades')) {
      return http.StreamedResponse(
        Stream.value(utf8.encode(body)),
        statusCode,
        headers: {'content-type': 'application/json'},
      );
    }
    throw Exception('Unmocked: ${request.method} ${request.url}');
  }
}

void main() {
  setUp(() {
    ClimbingLogService.invalidateAllCaches();
  });

  group('ClimbingLogService', () {
    group('getGrades', () {
      test('returns grades from API when 200 with valid JSON', () async {
        final grades = ['5', '6A', '6A+', '7A'];
        final body = jsonEncode({'grades': grades});
        final client = MockGradesHttpClient(body: body);
        final service = ClimbingLogService(client: client);

        final result = await service.getGrades();

        expect(result, equals(grades));
      });

      test('returns fallback when API returns 500', () async {
        final client = MockGradesHttpClient(statusCode: 500);
        final service = ClimbingLogService(client: client);

        final result = await service.getGrades();

        expect(result, contains('5'));
        expect(result, contains('8A+'));
      });

      test('returns fallback when API throws', () async {
        final client = _ThrowingHttpClient();
        final service = ClimbingLogService(client: client);

        final result = await service.getGrades();

        expect(result, isNotEmpty);
        expect(result.first, '5');
      });

      test('returns fallback when response body is invalid', () async {
        final client = MockGradesHttpClient(body: 'not json');
        final service = ClimbingLogService(client: client);

        final result = await service.getGrades();

        expect(result, isNotEmpty);
      });
    });

    group('getGradesWithGroups', () {
      test('returns GradesResponse when 200 with valid JSON', () async {
        final body = jsonEncode({
          'grades': ['5', '6A'],
          'grade_groups': {
            '6A-6C+': ['6A', '6A+', '6B', '6B+', '6C', '6C+'],
          },
        });
        final client = MockGradesHttpClient(body: body);
        final service = ClimbingLogService(client: client);

        final result = await service.getGradesWithGroups();

        expect(result.grades, equals(['5', '6A']));
        expect(result.gradeGroups['6A-6C+'], equals(['6A', '6A+', '6B', '6B+', '6C', '6C+']));
      });

      test('returns fallback when API fails', () async {
        final client = MockGradesHttpClient(statusCode: 404);
        final service = ClimbingLogService(client: client);

        final result = await service.getGradesWithGroups();

        expect(result.grades, isNotEmpty);
        expect(result.gradeGroups, isNotEmpty);
      });
    });

    group('invalidateAllCaches', () {
      test('clears cache so next getGrades fetches from API', () async {
        final grades = ['5', '6A'];
        final body = jsonEncode({'grades': grades});
        final client = MockGradesHttpClient(body: body);
        final service = ClimbingLogService(client: client);

        await service.getGrades();
        ClimbingLogService.invalidateAllCaches();
        final result = await service.getGrades();

        expect(result, equals(grades));
      });
    });
  });
}

class _ThrowingHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw Exception('Network error');
  }
}
