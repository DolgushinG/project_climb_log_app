import 'package:http/http.dart' as http;

import 'package:login_app/main.dart';
import 'package:login_app/services/cache_service.dart';

/// Фоновая предзагрузка соревнований и рейтинга при входе в приложение.
/// Вызывать без await — запросы выполняются в фоне.
void prefetchCompetitionsAndRating() {
  Future(() async {
    try {
      final token = await getToken();
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';

      await Future.wait([
        _prefetchCompetitions(headers),
        _prefetchRating(),
      ]);
    } catch (_) {}
  });
}

Future<void> _prefetchCompetitions(Map<String, String> headers) async {
  try {
    final response = await http.get(
      Uri.parse(DOMAIN + '/api/competitions'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      await CacheService.set(
        CacheService.keyCompetitions,
        response.body,
        ttl: CacheService.ttlCompetitions,
      );
    }
  } catch (_) {}
}

Future<void> _prefetchRating() async {
  try {
    final response = await http.get(
      Uri.parse('$DOMAIN/api/rating'),
      headers: {'Accept': 'application/json'},
    );
    if (response.statusCode == 200) {
      await CacheService.set(
        CacheService.keyRating,
        response.body,
        ttl: CacheService.ttlRating,
      );
    }
  } catch (_) {}
}
