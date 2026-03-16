import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../main.dart';
import '../models/TrainerStudent.dart';
import '../models/TrainerExercise.dart';
import '../models/TrainerInvitation.dart';
import '../utils/app_snackbar.dart';
import '../utils/session_error_helper.dart';
import '../utils/network_error_helper.dart';

/// API для режима тренера: ученики, назначения, данные учеников.
class TrainerService {
  final String baseUrl;

  TrainerService({required this.baseUrl});

  Map<String, String> _headers(String? token) => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  /// GET /api/trainer/students
  Future<List<TrainerStudent>> getStudents(BuildContext context) async {
    final token = await getToken();
    if (token == null) return [];
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/trainer/students'),
        headers: _headers(token),
      );
      if (response.statusCode == 401) {
        if (context.mounted) redirectToLoginOnSessionError(context);
        return [];
      }
      if (response.statusCode == 403) {
        return [];
      }
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        final list = data?['students'] as List<dynamic>? ?? [];
        return list
            .map((e) => TrainerStudent.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      throw Exception('Ошибка ${response.statusCode}');
    } catch (e) {
      throw Exception(networkErrorMessage(e, 'Не удалось загрузить список учеников'));
    }
  }

  /// POST /api/trainer/students — отправить приглашение по user_id или email
  Future<bool> addStudent(BuildContext context, {int? userId, String? email}) async {
    final token = await getToken();
    if (token == null) {
      if (context.mounted) showAppError(context, 'Войдите в аккаунт для отправки приглашения');
      return false;
    }
    final body = <String, dynamic>{};
    if (userId != null) body['user_id'] = userId;
    if (email != null && email.isNotEmpty) body['email'] = email;
    if (body.isEmpty) {
      if (context.mounted) showAppError(context, 'Укажите email или ID пользователя');
      return false;
    }
    try {
      final url = '$baseUrl/api/trainer/students';
      if (kDebugMode) debugPrint('[TrainerService] POST $url body=$body');
      final response = await http.post(
        Uri.parse(url),
        headers: _headers(token),
        body: jsonEncode(body),
      );
      if (kDebugMode) debugPrint('[TrainerService] addStudent response ${response.statusCode}');
      if (response.statusCode == 401) {
        if (context.mounted) redirectToLoginOnSessionError(context);
        return false;
      }
      if (response.statusCode == 201 || response.statusCode == 200) {
        final b = response.body.isNotEmpty ? jsonDecode(response.body) : null;
        if (b is Map && (b['error'] == 'User not found' || b['error'] == 'user_not_found')) {
          if (context.mounted) {
            showAppError(context, (b['message'] ?? 'Пользователь не найден').toString());
          }
          return false;
        }
        return true;
      }
      if (response.statusCode == 403) {
        if (context.mounted) showAppError(context, 'Режим тренера не включён');
        return false;
      }
      if (response.statusCode == 404) {
        if (context.mounted) showAppError(context, 'Пользователь не найден');
        return false;
      }
      if (response.statusCode == 422) {
        final b = response.body.isNotEmpty ? jsonDecode(response.body) : null;
        final msg = b is Map ? (b['message'] ?? b['error'])?.toString() : null;
        if (context.mounted) showAppError(context, msg ?? 'Ученик уже в группе или ошибка');
        return false;
      }
      if (context.mounted) showAppError(context, 'Ошибка: ${response.statusCode}');
      return false;
    } catch (e) {
      if (context.mounted) {
        showAppError(context, networkErrorMessage(e, 'Не удалось добавить ученика'));
      }
      return false;
    }
  }

  /// GET /api/trainer/invitations — отправленные приглашения со статусом pending
  Future<List<TrainerInvitation>> getInvitations(BuildContext context) async {
    final token = await getToken();
    if (token == null) return [];
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/trainer/invitations'),
        headers: _headers(token),
      );
      if (response.statusCode == 401) {
        if (context.mounted) redirectToLoginOnSessionError(context);
        return [];
      }
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        final list = data?['invitations'] as List<dynamic>? ?? [];
        return list
            .map((e) => TrainerInvitation.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      return [];
    } catch (_) {}
    return [];
  }

  /// GET /api/profile/trainer-invitations — входящие приглашения для ученика
  Future<List<TrainerInvitation>> getProfileTrainerInvitations(BuildContext context) async {
    final token = await getToken();
    if (token == null) return [];
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/profile/trainer-invitations'),
        headers: _headers(token),
      );
      if (response.statusCode == 401) {
        if (context.mounted) redirectToLoginOnSessionError(context);
        return [];
      }
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        final list = data?['invitations'] as List<dynamic>? ?? [];
        return list
            .map((e) => TrainerInvitation.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      return [];
    } catch (_) {}
    return [];
  }

  /// POST /api/trainer/invitations/{id}/accept — принять приглашение (ученик)
  Future<bool> acceptInvitation(BuildContext context, int invitationId) async {
    final token = await getToken();
    if (token == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/trainer/invitations/$invitationId/accept'),
        headers: _headers(token),
      );
      if (response.statusCode == 401) {
        if (context.mounted) redirectToLoginOnSessionError(context);
        return false;
      }
      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) return true;
      if (context.mounted) showAppError(context, 'Не удалось принять приглашение');
      return false;
    } catch (e) {
      if (context.mounted) showAppError(context, networkErrorMessage(e, 'Ошибка'));
      return false;
    }
  }

  /// DELETE /api/trainer/invitations/{id}/reject — отклонить приглашение (ученик)
  Future<bool> rejectInvitation(BuildContext context, int invitationId) async {
    final token = await getToken();
    if (token == null) return false;
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/trainer/invitations/$invitationId/reject'),
        headers: _headers(token),
      );
      if (response.statusCode == 401) {
        if (context.mounted) redirectToLoginOnSessionError(context);
        return false;
      }
      if (response.statusCode == 200 || response.statusCode == 204) return true;
      if (context.mounted) showAppError(context, 'Не удалось отклонить');
      return false;
    } catch (e) {
      if (context.mounted) showAppError(context, networkErrorMessage(e, 'Ошибка'));
      return false;
    }
  }

  /// DELETE /api/trainer/invitations/{id} — отозвать приглашение (тренер)
  Future<bool> revokeInvitation(BuildContext context, int invitationId) async {
    final token = await getToken();
    if (token == null) return false;
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/trainer/invitations/$invitationId'),
        headers: _headers(token),
      );
      if (response.statusCode == 401) {
        if (context.mounted) redirectToLoginOnSessionError(context);
        return false;
      }
      if (response.statusCode == 200 || response.statusCode == 204) return true;
      if (response.statusCode == 404 || response.statusCode == 422) {
        if (context.mounted) {
          showAppError(context, 'Приглашение уже отозвано или принято');
        }
        return false;
      }
      if (response.statusCode == 403) {
        if (context.mounted) showAppError(context, 'Не удалось отозвать приглашение');
        return false;
      }
      if (context.mounted) showAppError(context, 'Ошибка: ${response.statusCode}');
      return false;
    } catch (e) {
      if (context.mounted) {
        showAppError(context, networkErrorMessage(e, 'Не удалось отозвать приглашение'));
      }
      return false;
    }
  }

  /// DELETE /api/trainer/students/{user_id}
  Future<bool> removeStudent(BuildContext context, int userId) async {
    final token = await getToken();
    if (token == null) return false;
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/trainer/students/$userId'),
        headers: _headers(token),
      );
      if (response.statusCode == 401) {
        if (context.mounted) redirectToLoginOnSessionError(context);
        return false;
      }
      if (response.statusCode == 200 || response.statusCode == 204) return true;
      if (response.statusCode == 403 || response.statusCode == 404) {
        if (context.mounted) showAppError(context, 'Не удалось удалить ученика');
        return false;
      }
      if (context.mounted) showAppError(context, 'Ошибка: ${response.statusCode}');
      return false;
    } catch (e) {
      if (context.mounted) {
        showAppError(context, networkErrorMessage(e, 'Не удалось удалить ученика'));
      }
      return false;
    }
  }

  /// GET /api/trainer/students/{id}/climbing-history
  Future<List<Map<String, dynamic>>> getStudentClimbingHistory(
    BuildContext context,
    int studentId, {
    int periodDays = 90,
  }) async {
    final token = await getToken();
    if (token == null) return [];
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/trainer/students/$studentId/climbing-history')
            .replace(queryParameters: {'period_days': periodDays.toString()}),
        headers: _headers(token),
      );
      if (response.statusCode == 401) {
        if (context.mounted) redirectToLoginOnSessionError(context);
        return [];
      }
      if (response.statusCode == 403 || response.statusCode == 404) return [];
      if (response.statusCode == 200) {
        final raw = jsonDecode(response.body);
        if (raw is List) {
          return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
      return [];
    } catch (_) {}
    return [];
  }

  /// GET /api/trainer/students/{id}/exercise-completions
  Future<List<Map<String, dynamic>>> getStudentExerciseCompletions(
    BuildContext context,
    int studentId, {
    String? date,
    int? periodDays,
  }) async {
    final token = await getToken();
    if (token == null) return [];
    try {
      final params = <String, String>{};
      if (date != null) params['date'] = date;
      if (periodDays != null) params['period_days'] = periodDays.toString();
      final response = await http.get(
        Uri.parse('$baseUrl/api/trainer/students/$studentId/exercise-completions')
            .replace(queryParameters: params.isNotEmpty ? params : null),
        headers: _headers(token),
      );
      if (response.statusCode == 401) {
        if (context.mounted) redirectToLoginOnSessionError(context);
        return [];
      }
      if (response.statusCode == 403 || response.statusCode == 404) return [];
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        final list = data?['completions'] as List<dynamic>? ?? [];
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (_) {}
    return [];
  }

  /// GET /api/profile/trainer-assignments — задания текущего пользователя (ученика).
  Future<List<Map<String, dynamic>>> getMyAssignments(
    BuildContext context, {
    String? date,
    int? periodDays,
  }) async {
    final token = await getToken();
    if (token == null) return [];
    try {
      final params = <String, String>{};
      if (date != null) params['date'] = date;
      if (periodDays != null) params['period_days'] = periodDays.toString();
      final response = await http.get(
        Uri.parse('$baseUrl/api/profile/trainer-assignments')
            .replace(queryParameters: params.isNotEmpty ? params : null),
        headers: _headers(token),
      );
      if (response.statusCode == 401) {
        if (context.mounted) redirectToLoginOnSessionError(context);
        return [];
      }
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        final list = data?['assignments'] as List<dynamic>? ?? [];
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (_) {}
    return [];
  }

  /// GET /api/trainer/assignments?student_id=
  Future<List<Map<String, dynamic>>> getAssignments(
    BuildContext context,
    int studentId, {
    String? date,
    int? periodDays,
  }) async {
    final token = await getToken();
    if (token == null) return [];
    try {
      final params = <String, String>{'student_id': studentId.toString()};
      if (date != null) params['date'] = date;
      if (periodDays != null) params['period_days'] = periodDays.toString();
      final response = await http.get(
        Uri.parse('$baseUrl/api/trainer/assignments').replace(queryParameters: params),
        headers: _headers(token),
      );
      if (response.statusCode == 401) {
        if (context.mounted) redirectToLoginOnSessionError(context);
        return [];
      }
      if (response.statusCode == 403 || response.statusCode == 404) return [];
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        final list = data?['assignments'] as List<dynamic>? ?? [];
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (_) {}
    return [];
  }

  /// POST /api/trainer/assignments
  Future<bool> createAssignment(
    BuildContext context, {
    required int studentId,
    required String exerciseId,
    required String date,
    required int sets,
    required String reps,
    int? holdSeconds,
    int? restSeconds,
  }) async {
    final token = await getToken();
    if (token == null) return false;
    try {
      final body = <String, dynamic>{
        'student_id': studentId,
        'exercise_id': exerciseId,
        'date': date,
        'sets': sets,
        'reps': reps,
      };
      if (holdSeconds != null) body['hold_seconds'] = holdSeconds;
      if (restSeconds != null) body['rest_seconds'] = restSeconds;
      final response = await http.post(
        Uri.parse('$baseUrl/api/trainer/assignments'),
        headers: _headers(token),
        body: jsonEncode(body),
      );
      if (response.statusCode == 401) {
        if (context.mounted) redirectToLoginOnSessionError(context);
        return false;
      }
      if (response.statusCode == 201 || response.statusCode == 200) return true;
      if (response.statusCode == 403 || response.statusCode == 404) {
        if (context.mounted) showAppError(context, 'Не удалось создать упражнение');
        return false;
      }
      if (context.mounted) showAppError(context, 'Ошибка: ${response.statusCode}');
      return false;
    } catch (e) {
      if (context.mounted) {
        showAppError(context, networkErrorMessage(e, 'Не удалось создать упражнение'));
      }
      return false;
    }
  }

  /// GET /api/trainer/exercises — свои упражнения (быстрый доступ при назначении)
  Future<List<TrainerExercise>> getTrainerExercises(BuildContext context) async {
    final token = await getToken();
    if (token == null) return [];
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/trainer/exercises'),
        headers: _headers(token),
      );
      if (response.statusCode == 401) {
        if (context.mounted) redirectToLoginOnSessionError(context);
        return [];
      }
      if (response.statusCode == 403) return [];
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        final list = data?['exercises'] as List<dynamic>? ?? [];
        return list
            .map((e) => TrainerExercise.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      return [];
    } catch (_) {}
    return [];
  }

  /// POST /api/trainer/exercises
  Future<TrainerExercise?> createTrainerExercise(BuildContext context, TrainerExercise exercise) async {
    final token = await getToken();
    if (token == null) return null;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/trainer/exercises'),
        headers: _headers(token),
        body: jsonEncode(exercise.toJson()),
      );
      if (response.statusCode == 401) {
        if (context.mounted) redirectToLoginOnSessionError(context);
        return null;
      }
      if (response.statusCode == 201 || response.statusCode == 200) {
        final raw = jsonDecode(response.body);
        Map<String, dynamic>? data;
        if (raw is Map<String, dynamic>) {
          data = raw.containsKey('exercise') ? raw['exercise'] as Map<String, dynamic>? : raw;
        }
        return data != null ? TrainerExercise.fromJson(data) : null;
      }
      if (response.statusCode == 403) {
        if (context.mounted) showAppError(context, 'Режим тренера не включён');
        return null;
      }
      if (response.statusCode == 422) {
        final b = response.body.isNotEmpty ? jsonDecode(response.body) : null;
        final msg = b is Map ? (b['message'] ?? b['error'])?.toString() : null;
        if (context.mounted) showAppError(context, msg ?? 'Ошибка создания');
        return null;
      }
      return null;
    } catch (e) {
      if (context.mounted) {
        showAppError(context, networkErrorMessage(e, 'Не удалось создать упражнение'));
      }
      return null;
    }
  }

  /// POST /api/trainer/exercises/generate-ai — сгенерировать «как выполнять» и «польза» по названию.
  /// Возвращает null при ошибке.
  Future<({String howToPerform, String climbingBenefits})?> generateExerciseAI(
    BuildContext context,
    String exerciseName,
  ) async {
    if (exerciseName.trim().isEmpty) return null;
    final token = await getToken();
    if (token == null) return null;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/trainer/exercises/generate-ai'),
        headers: _headers(token),
        body: jsonEncode({'name': exerciseName.trim()}),
      );
      if (response.statusCode == 401) {
        if (context.mounted) redirectToLoginOnSessionError(context);
        return null;
      }
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        if (data != null) {
          final howTo = (data['how_to_perform'] ?? data['howToPerform'])?.toString() ?? '';
          final benefits = (data['climbing_benefits'] ?? data['climbingBenefits'])?.toString() ?? '';
          return (howToPerform: howTo, climbingBenefits: benefits);
        }
      }
      if (context.mounted) {
        showAppError(context, 'Не удалось сгенерировать. Проверьте подключение или попробуйте позже.');
      }
      return null;
    } catch (e) {
      if (context.mounted) {
        showAppError(context, networkErrorMessage(e, 'Ошибка генерации'));
      }
      return null;
    }
  }

  /// DELETE /api/trainer/assignments/{id}
  Future<bool> deleteAssignment(BuildContext context, int assignmentId) async {
    final token = await getToken();
    if (token == null) return false;
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/trainer/assignments/$assignmentId'),
        headers: _headers(token),
      );
      if (response.statusCode == 401) {
        if (context.mounted) redirectToLoginOnSessionError(context);
        return false;
      }
      if (response.statusCode == 200 || response.statusCode == 204) return true;
      if (context.mounted) showAppError(context, 'Ошибка: ${response.statusCode}');
      return false;
    } catch (e) {
      if (context.mounted) {
        showAppError(context, networkErrorMessage(e, 'Не удалось удалить упражнение'));
      }
      return false;
    }
  }
}
