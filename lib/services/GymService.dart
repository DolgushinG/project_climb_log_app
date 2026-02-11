import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:login_app/main.dart';
import 'package:login_app/models/Gym.dart';

/// Список скалодромов с пагинацией и фильтрами (GET /api/gyms)
Future<GymsListResponse?> fetchGyms({
  int page = 1,
  int perPage = 12,
  String? search,
  String? city,
  String? country,
}) async {
  try {
    final uri = Uri.parse('$DOMAIN/api/gyms').replace(
      queryParameters: {
        'page': page.toString(),
        'per_page': perPage.toString(),
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
        if (country != null && country.trim().isNotEmpty)
          'country': country.trim(),
      },
    );

    final response = await http.get(
      uri,
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return GymsListResponse.fromJson(json);
    }
    return null;
  } catch (_) {
    return null;
  }
}

/// Данные страницы скалодрома
class GymProfileData {
  final Gym gym;
  final int vacanciesCount;
  final List<GymEvent> events;
  final List<GymJob> jobs;
  final GymJobsPagination? jobsPagination;

  GymProfileData({
    required this.gym,
    required this.vacanciesCount,
    required this.events,
    required this.jobs,
    this.jobsPagination,
  });

  factory GymProfileData.fromJson(Map<String, dynamic> json) {
    final gymRaw = json['gym'];
    final eventsRaw = json['events'] as List<dynamic>? ?? [];
    final jobsRaw = json['jobs'] as List<dynamic>? ?? [];

    return GymProfileData(
      gym: gymRaw is Map
          ? Gym.fromJson(Map<String, dynamic>.from(gymRaw))
          : Gym(id: 0, name: ''),
      vacanciesCount: json['vacancies_count'] as int? ?? jobsRaw.length,
      events: eventsRaw
          .map((e) =>
              GymEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      jobs: jobsRaw
          .map((j) => GymJob.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList(),
      jobsPagination: json['jobs_pagination'] != null
          ? GymJobsPagination.fromJson(
              Map<String, dynamic>.from(json['jobs_pagination'] as Map))
          : null,
    );
  }
}

class GymJobsPagination {
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  GymJobsPagination({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  factory GymJobsPagination.fromJson(Map<String, dynamic> json) =>
      GymJobsPagination(
        currentPage: json['current_page'] as int? ?? 1,
        lastPage: json['last_page'] as int? ?? 1,
        perPage: json['per_page'] as int? ?? 10,
        total: json['total'] as int? ?? 0,
      );
}

Future<GymProfileData?> fetchGymProfile(int gymId,
    {int page = 1, int perPage = 10}) async {
  try {
    final response = await http.get(
      Uri.parse('$DOMAIN/api/gyms/$gymId?page=$page&per_page=$perPage'),
      headers: {'Accept': 'application/json'},
    );
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return GymProfileData.fromJson(json);
    }
    return null;
  } catch (_) {
    return null;
  }
}

/// Поиск скалодромов по названию или городу. Возвращает до 10 результатов.
Future<List<GymSearchItem>> searchGyms(String query) async {
  if (query.trim().isEmpty) return [];
  try {
    final response = await http.get(
      Uri.parse('$DOMAIN/api/search-gyms?query=${Uri.encodeComponent(query.trim())}'),
      headers: {'Accept': 'application/json'},
    );
    if (response.statusCode == 200) {
      final raw = jsonDecode(response.body);
      if (raw is List) {
        return raw
            .map((e) =>
                GymSearchItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    }
    return [];
  } catch (_) {
    return [];
  }
}
