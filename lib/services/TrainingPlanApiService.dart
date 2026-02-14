import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:login_app/main.dart';
import 'package:login_app/models/PlanModels.dart';

/// API планов тренировок: шаблоны, создание, календарь, день, отметка выполнения.
class TrainingPlanApiService {
  Future<String?> _getToken() => getToken();

  Map<String, String> _headers(String? token) => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  /// GET /api/climbing-logs/plan-templates
  Future<PlanTemplateResponse?> getPlanTemplates({String? audience}) async {
    final token = await _getToken();
    if (token == null) return null;
    try {
      final params = audience != null ? {'audience': audience} : null;
      final uri = Uri.parse('$DOMAIN/api/climbing-logs/plan-templates')
          .replace(queryParameters: params);
      final response = await http.get(uri, headers: _headers(token));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        return json != null ? PlanTemplateResponse.fromJson(json) : null;
      }
    } catch (_) {}
    return null;
  }

  /// POST /api/climbing-logs/plans
  /// Персонализация: days_per_week, has_fingerboard, injuries, preferred_style, experience_months.
  Future<ActivePlan?> createPlan({
    required String templateKey,
    required int durationWeeks,
    String? startDate,
    int? daysPerWeek,
    List<int>? scheduledWeekdays,
    bool? hasFingerboard,
    List<String>? injuries,
    String? preferredStyle,
    int? experienceMonths,
    bool? includeClimbingInDays,
  }) async {
    final token = await _getToken();
    if (token == null) return null;
    try {
      final body = <String, dynamic>{
        'template_key': templateKey,
        'duration_weeks': durationWeeks,
      };
      if (startDate != null) body['start_date'] = startDate;
      if (daysPerWeek != null) body['days_per_week'] = daysPerWeek;
      if (scheduledWeekdays != null && scheduledWeekdays.isNotEmpty) body['scheduled_weekdays'] = scheduledWeekdays;
      if (hasFingerboard != null) body['has_fingerboard'] = hasFingerboard;
      if (injuries != null && injuries.isNotEmpty) body['injuries'] = injuries;
      if (preferredStyle != null) body['preferred_style'] = preferredStyle;
      if (experienceMonths != null) body['experience_months'] = experienceMonths;
      if (includeClimbingInDays != null) body['include_climbing_in_days'] = includeClimbingInDays;
      final response = await http.post(
        Uri.parse('$DOMAIN/api/climbing-logs/plans'),
        headers: _headers(token),
        body: jsonEncode(body),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        if (json == null) return null;
        final planData = json['plan'] as Map<String, dynamic>? ?? json;
        return ActivePlan.fromJson(planData);
      }
    } catch (_) {}
    return null;
  }

  /// DELETE /api/climbing-logs/plans/active — удаление активного плана (для тестирования).
  Future<bool> deleteActivePlan() async {
    final token = await _getToken();
    if (token == null) return false;
    try {
      final response = await http.delete(
        Uri.parse('$DOMAIN/api/climbing-logs/plans/active'),
        headers: _headers(token),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {}
    return false;
  }

  /// GET /api/climbing-logs/plans/active
  /// Возвращает null, если плана нет (200 + пустой/без плана).
  /// Бросает исключение при сетевой ошибке — чтобы UI показал «Повторить», а не «Создать план».
  Future<ActivePlan?> getActivePlan() async {
    final token = await _getToken();
    if (token == null) return null;
    final response = await http.get(
      Uri.parse('$DOMAIN/api/climbing-logs/plans/active'),
      headers: _headers(token),
    );
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>?;
      if (json == null) return null;
      final planData = json['plan'] as Map<String, dynamic>? ?? json;
      final plan = ActivePlan.fromJson(planData);
      return plan.id > 0 ? plan : null;
    }
    return null;
  }

  /// GET /api/climbing-logs/plans/{id}/day?date=
  /// Опционально: feeling (1–5), focus (climbing|strength|recovery), available_minutes.
  Future<PlanDayResponse?> getPlanDay(
    int planId,
    String date, {
    int? feeling,
    String? focus,
    int? availableMinutes,
  }) async {
    final token = await _getToken();
    if (token == null) return null;
    try {
      final params = <String, String>{'date': date};
      if (feeling != null && feeling >= 1 && feeling <= 5) params['feeling'] = feeling.toString();
      if (focus != null) params['focus'] = focus;
      if (availableMinutes != null && availableMinutes > 0) params['available_minutes'] = availableMinutes.toString();
      final uri = Uri.parse('$DOMAIN/api/climbing-logs/plans/$planId/day')
          .replace(queryParameters: params);
      final response = await http.get(uri, headers: _headers(token));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        return json != null ? PlanDayResponse.fromJson(json) : null;
      }
    } catch (_) {}
    return null;
  }

  /// GET /api/climbing-logs/plans/{id}/calendar?month=
  Future<PlanCalendarResponse?> getPlanCalendar(int planId, String month) async {
    final token = await _getToken();
    if (token == null) return null;
    try {
      final uri = Uri.parse('$DOMAIN/api/climbing-logs/plans/$planId/calendar')
          .replace(queryParameters: {'month': month});
      final response = await http.get(uri, headers: _headers(token));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        return json != null ? PlanCalendarResponse.fromJson(json) : null;
      }
    } catch (_) {}
    return null;
  }

  /// POST /api/climbing-logs/plans/{id}/complete
  Future<bool> completeSession({
    required int planId,
    required String date,
    required String sessionType,
    int? ofpDayIndex,
  }) async {
    final token = await _getToken();
    if (token == null) return false;
    try {
      final body = <String, dynamic>{
        'date': date,
        'session_type': sessionType,
      };
      if (ofpDayIndex != null) body['ofp_day_index'] = ofpDayIndex;
      final response = await http.post(
        Uri.parse('$DOMAIN/api/climbing-logs/plans/$planId/complete'),
        headers: _headers(token),
        body: jsonEncode(body),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {}
    return false;
  }

  /// DELETE /api/climbing-logs/plans/{id}/complete
  Future<bool> uncompleteSession({
    required int planId,
    required String date,
    required String sessionType,
  }) async {
    final token = await _getToken();
    if (token == null) return false;
    try {
      final body = <String, dynamic>{
        'date': date,
        'session_type': sessionType,
      };
      final response = await http.delete(
        Uri.parse('$DOMAIN/api/climbing-logs/plans/$planId/complete'),
        headers: _headers(token),
        body: jsonEncode(body),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {}
    return false;
  }
}
