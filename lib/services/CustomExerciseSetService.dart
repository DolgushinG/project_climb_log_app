import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:login_app/main.dart';
import 'package:login_app/models/SavedCustomSet.dart';
import 'package:login_app/utils/session_error_helper.dart';

/// API-сервис для сохранённых сетов упражнений (шаблонов).
class CustomExerciseSetService {
  CustomExerciseSetService();

  Future<String?> _getToken() => getToken();

  Map<String, String> _headers(String? token) => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  /// GET /api/climbing-logs/custom-exercise-sets
  Future<List<SavedCustomSet>> getSets() async {
    final token = await _getToken();
    if (token == null) return [];
    try {
      final response = await http.get(
        Uri.parse('$DOMAIN/api/climbing-logs/custom-exercise-sets'),
        headers: _headers(token),
      );
      if (await redirectIfUnauthorized(response.statusCode)) return [];
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        final list = json?['sets'] as List<dynamic>? ?? [];
        return list
            .map((e) {
              final m = Map<String, dynamic>.from(e as Map);
              if (!m.containsKey('exercises') && m.containsKey('exercises_count')) {
                m['exercises'] = [];
              }
              return SavedCustomSet.fromJson(m);
            })
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// GET /api/climbing-logs/custom-exercise-sets/{id}
  Future<SavedCustomSet?> getSet(int id) async {
    final token = await _getToken();
    if (token == null) return null;
    try {
      final response = await http.get(
        Uri.parse('$DOMAIN/api/climbing-logs/custom-exercise-sets/$id'),
        headers: _headers(token),
      );
      if (await redirectIfUnauthorized(response.statusCode)) return null;
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        return json != null ? SavedCustomSet.fromJson(json) : null;
      }
    } catch (_) {}
    return null;
  }

  /// POST /api/climbing-logs/custom-exercise-sets
  Future<SavedCustomSet?> createSet(SavedCustomSet set) async {
    final token = await _getToken();
    if (token == null) return null;
    try {
      final body = <String, dynamic>{
        'name': set.name,
        'exercises': set.exercises.map((e) => e.toJson()).toList(),
      };
      final response = await http.post(
        Uri.parse('$DOMAIN/api/climbing-logs/custom-exercise-sets'),
        headers: _headers(token),
        body: jsonEncode(body),
      );
      if (await redirectIfUnauthorized(response.statusCode)) return null;
      if (response.statusCode == 201 || response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        return json != null ? SavedCustomSet.fromJson(json) : null;
      }
    } catch (_) {}
    return null;
  }

  /// PUT /api/climbing-logs/custom-exercise-sets/{id}
  Future<SavedCustomSet?> updateSet(int id, SavedCustomSet set) async {
    final token = await _getToken();
    if (token == null) return null;
    try {
      final body = <String, dynamic>{
        'name': set.name,
        'exercises': set.exercises.map((e) => e.toJson()).toList(),
      };
      final response = await http.put(
        Uri.parse('$DOMAIN/api/climbing-logs/custom-exercise-sets/$id'),
        headers: _headers(token),
        body: jsonEncode(body),
      );
      if (await redirectIfUnauthorized(response.statusCode)) return null;
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        return json != null ? SavedCustomSet.fromJson(json) : null;
      }
    } catch (_) {}
    return null;
  }

  /// DELETE /api/climbing-logs/custom-exercise-sets/{id}
  Future<bool> deleteSet(int id) async {
    final token = await _getToken();
    if (token == null) return false;
    try {
      final response = await http.delete(
        Uri.parse('$DOMAIN/api/climbing-logs/custom-exercise-sets/$id'),
        headers: _headers(token),
      );
      if (await redirectIfUnauthorized(response.statusCode)) return false;
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {}
    return false;
  }
}
