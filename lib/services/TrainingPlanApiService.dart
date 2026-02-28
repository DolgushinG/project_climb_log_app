import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:login_app/main.dart';
import 'package:login_app/models/PlanModels.dart';
import 'package:login_app/utils/session_error_helper.dart';

/// Исключение при 429 или другой ошибке API — чтобы UI показал «Повторить», а не «Создать план».
class PlanApiException implements Exception {
  final int statusCode;
  final String message;
  PlanApiException({required this.statusCode, required this.message});
}

/// Запись кэша с TTL.
class _PlanCacheEntry<T> {
  final T value;
  final DateTime cachedAt;
  _PlanCacheEntry(this.value, this.cachedAt);
}

/// API планов тренировок: шаблоны, создание, календарь, день, отметка выполнения.
class TrainingPlanApiService {
  Future<String?> _getToken() => getToken();

  static const _cacheTtl = Duration(seconds: 60);
  static _PlanCacheEntry<ActivePlanResult>? _activePlanCache;
  static final Map<String, _PlanCacheEntry<PlanDayResponse?>> _planDayCache = {};
  static final Map<String, _PlanCacheEntry<PlanCalendarResponse?>> _planCalendarCache = {};
  static final Map<int, _PlanCacheEntry<PlanProgressResponse?>> _planProgressCache = {};

  /// Инвалидирует весь in-memory кэш планов. Вызывать при выходе из аккаунта.
  static void invalidatePlanCaches() {
    _activePlanCache = null;
    _planDayCache.clear();
    _planCalendarCache.clear();
    _planProgressCache.clear();
  }

  static void _invalidatePlanCaches() => invalidatePlanCaches();

  static void _invalidatePlanDayCache(int planId, String date) {
    _planDayCache.removeWhere((k, _) => k.startsWith('$planId:$date'));
    _planCalendarCache.removeWhere((k, _) => k.startsWith('$planId:'));
    _planProgressCache.remove(planId);
  }

  Map<String, String> _headers(String? token) => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  /// GET /api/climbing-logs/plan-templates
  /// Возвращает null при ошибке (нет токена, не 200, исключение при парсинге).
  Future<PlanTemplateResponse?> getPlanTemplates({String? audience}) async {
    final token = await _getToken();
    if (token == null) return null;
    try {
      final params = audience != null ? {'audience': audience} : null;
      final uri = Uri.parse('$DOMAIN/api/climbing-logs/plan-templates')
          .replace(queryParameters: params);
      final response = await http.get(uri, headers: _headers(token));
      if (await redirectIfUnauthorized(response.statusCode)) return null;
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        if (json == null) return null;
        return PlanTemplateResponse.fromJson(json);
      }
    } catch (e) {
      // Ошибка сети или парсинга — возвращаем null
    }
    return null;
  }

  /// POST /api/climbing-logs/plans
  /// Персонализация: days_per_week, has_fingerboard, injuries, preferred_style, experience_months, available_minutes, ofp_sfp_focus.
  Future<ActivePlan?> createPlan({
    required String templateKey,
    required int durationWeeks,
    String? startDate,
    int? daysPerWeek,
    List<int>? scheduledWeekdays,
    List<int>? ofpWeekdays,
    List<int>? sfpWeekdays,
    bool? hasFingerboard,
    List<String>? injuries,
    String? preferredStyle,
    int? experienceMonths,
    bool? includeClimbingInDays,
    int? availableMinutes,
    String? ofpSfpFocus,
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
      if (ofpWeekdays != null) body['ofp_weekdays'] = ofpWeekdays;
      if (sfpWeekdays != null) body['sfp_weekdays'] = sfpWeekdays;
      if (hasFingerboard != null) body['has_fingerboard'] = hasFingerboard;
      if (injuries != null && injuries.isNotEmpty) body['injuries'] = injuries;
      if (preferredStyle != null) body['preferred_style'] = preferredStyle;
      if (experienceMonths != null) body['experience_months'] = experienceMonths;
      if (includeClimbingInDays != null) body['include_climbing_in_days'] = includeClimbingInDays;
      if (availableMinutes != null) body['available_minutes'] = availableMinutes;
      if (ofpSfpFocus != null && ofpSfpFocus.isNotEmpty) body['ofp_sfp_focus'] = ofpSfpFocus;
      final response = await http.post(
        Uri.parse('$DOMAIN/api/climbing-logs/plans'),
        headers: _headers(token),
        body: jsonEncode(body),
      );
      if (await redirectIfUnauthorized(response.statusCode)) return null;
      if (response.statusCode == 200 || response.statusCode == 201) {
        _invalidatePlanCaches();
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        if (json == null) return null;
        final planData = json['plan'] as Map<String, dynamic>? ?? json;
        return ActivePlan.fromJson(planData);
      }
    } catch (_) {}
    return null;
  }

  /// PATCH /api/climbing-logs/plans/{id} — обновление плана (продление, смена дней, времени и т.д.)
  Future<ActivePlan?> patchPlan({
    required int planId,
    String? templateKey,
    int? durationWeeks,
    String? startDate,
    int? daysPerWeek,
    List<int>? scheduledWeekdays,
    List<int>? ofpWeekdays,
    List<int>? sfpWeekdays,
    bool? hasFingerboard,
    List<String>? injuries,
    String? preferredStyle,
    int? experienceMonths,
    bool? includeClimbingInDays,
    int? availableMinutes,
    int? extendWeeks,
    String? ofpSfpFocus,
  }) async {
    final token = await _getToken();
    if (token == null) return null;
    try {
      final body = <String, dynamic>{};
      if (templateKey != null && templateKey.isNotEmpty) body['template_key'] = templateKey;
      if (extendWeeks != null) body['extend_weeks'] = extendWeeks;
      if (durationWeeks != null) body['duration_weeks'] = durationWeeks;
      if (startDate != null) body['start_date'] = startDate;
      if (daysPerWeek != null) body['days_per_week'] = daysPerWeek;
      if (scheduledWeekdays != null && scheduledWeekdays.isNotEmpty) body['scheduled_weekdays'] = scheduledWeekdays;
      if (ofpWeekdays != null) body['ofp_weekdays'] = ofpWeekdays;
      if (sfpWeekdays != null) body['sfp_weekdays'] = sfpWeekdays;
      if (hasFingerboard != null) body['has_fingerboard'] = hasFingerboard;
      if (injuries != null && injuries.isNotEmpty) body['injuries'] = injuries;
      if (preferredStyle != null) body['preferred_style'] = preferredStyle;
      if (experienceMonths != null) body['experience_months'] = experienceMonths;
      if (includeClimbingInDays != null) body['include_climbing_in_days'] = includeClimbingInDays;
      if (availableMinutes != null) body['available_minutes'] = availableMinutes;
      if (ofpSfpFocus != null && ofpSfpFocus.isNotEmpty) body['ofp_sfp_focus'] = ofpSfpFocus;
      if (body.isEmpty) return null;
      final response = await http.patch(
        Uri.parse('$DOMAIN/api/climbing-logs/plans/$planId'),
        headers: _headers(token),
        body: jsonEncode(body),
      );
      if (await redirectIfUnauthorized(response.statusCode)) return null;
      if (response.statusCode == 200) {
        _invalidatePlanCaches();
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        if (json == null) return null;
        final planData = json['plan'] as Map<String, dynamic>? ?? json;
        return ActivePlan.fromJson(planData);
      }
    } catch (_) {}
    return null;
  }

  /// DELETE /api/climbing-logs/plans/active или /plans/{id} — удаление активного плана.
  /// [planId] — опционально: если /plans/active не сработал, пробуем DELETE /plans/{id}.
  Future<bool> deleteActivePlan({int? planId}) async {
    final token = await _getToken();
    if (token == null) return false;
    try {
      var response = await http.delete(
        Uri.parse('$DOMAIN/api/climbing-logs/plans/active'),
        headers: _headers(token),
      );
      if (await redirectIfUnauthorized(response.statusCode)) return false;
      if (response.statusCode == 200 || response.statusCode == 204) {
        _invalidatePlanCaches();
        return true;
      }
      // Fallback: некоторые бэкенды ожидают DELETE /plans/{id}
      if (planId != null && planId > 0) {
        response = await http.delete(
          Uri.parse('$DOMAIN/api/climbing-logs/plans/$planId'),
          headers: _headers(token),
        );
        if (await redirectIfUnauthorized(response.statusCode)) return false;
        if (response.statusCode == 200 || response.statusCode == 204 || response.statusCode == 404) {
          _invalidatePlanCaches();
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// GET /api/climbing-logs/plans/active. Кэш 60 сек — снижает дубли при навигации.
  Future<ActivePlanResult> getActivePlan() async {
    final cached = _activePlanCache;
    if (cached != null && DateTime.now().difference(cached.cachedAt) < _cacheTtl) {
      return cached.value;
    }
    final token = await _getToken();
    if (token == null) return ActivePlanResult();
    final response = await http.get(
      Uri.parse('$DOMAIN/api/climbing-logs/plans/active'),
      headers: _headers(token),
    );
    if (await redirectIfUnauthorized(response.statusCode)) {
      throw PlanApiException(statusCode: 401, message: 'Сессия истекла');
    }
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>?;
      final result = json != null ? ActivePlanResult.fromJson(json) : ActivePlanResult();
      _activePlanCache = _PlanCacheEntry(result, DateTime.now());
      return result;
    }
    throw PlanApiException(
      statusCode: response.statusCode,
      message: response.statusCode == 429
          ? 'Слишком много запросов. Подождите немного и попробуйте снова.'
          : 'Ошибка загрузки (${response.statusCode})',
    );
  }

  /// GET /api/climbing-logs/plans/{id}/day?date=.
  /// [light] = true — отключает AI, rule-based ответ ~200–500 ms. Используется для быстрого показа экрана.
  /// Кэш 60 сек.
  Future<PlanDayResponse?> getPlanDay(
    int planId,
    String date, {
    int? feeling,
    String? focus,
    int? availableMinutes,
    bool light = false,
  }) async {
    final key = '$planId:$date:$feeling:$focus:$availableMinutes:light$light';
    final cached = _planDayCache[key];
    if (cached != null && DateTime.now().difference(cached.cachedAt) < _cacheTtl) {
      return cached.value;
    }
    final token = await _getToken();
    if (token == null) return null;
    try {
      final params = <String, String>{'date': date};
      if (feeling != null && feeling >= 1 && feeling <= 5) params['feeling'] = feeling.toString();
      if (focus != null) params['focus'] = focus;
      if (availableMinutes != null && availableMinutes > 0) params['available_minutes'] = availableMinutes.toString();
      if (light) params['light'] = '1';
      final uri = Uri.parse('$DOMAIN/api/climbing-logs/plans/$planId/day')
          .replace(queryParameters: params);
      final response = await http.get(uri, headers: _headers(token));
      if (await redirectIfUnauthorized(response.statusCode)) return null;
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        final result = json != null ? PlanDayResponse.fromJson(json) : null;
        _planDayCache[key] = _PlanCacheEntry(result, DateTime.now());
        return result;
      }
    } catch (_) {}
    return null;
  }

  /// GET /api/climbing-logs/plans/{id}/day-coach-comment — AI-комментарий тренера (без блокировки экрана).
  /// Загружать в фоне после показа дня (getPlanDay с light=1). При ошибке остаётся rule-based из day.
  Future<PlanDayCoachCommentResponse?> getPlanDayCoachComment(
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
      final uri = Uri.parse('$DOMAIN/api/climbing-logs/plans/$planId/day-coach-comment')
          .replace(queryParameters: params);
      final response = await http.get(uri, headers: _headers(token));
      if (await redirectIfUnauthorized(response.statusCode)) return null;
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        return json != null ? PlanDayCoachCommentResponse.fromJson(json) : null;
      }
    } catch (_) {}
    return null;
  }

  /// GET /api/climbing-logs/plans/{id}/progress — completed/total за один запрос. Кэш 60 сек.
  /// Fallback: если 404/ошибка, возвращает null — клиент использует calendar по месяцам.
  Future<PlanProgressResponse?> getPlanProgress(int planId) async {
    final cached = _planProgressCache[planId];
    if (cached != null && DateTime.now().difference(cached.cachedAt) < _cacheTtl) {
      return cached.value;
    }
    final token = await _getToken();
    if (token == null) return null;
    try {
      final response = await http.get(
        Uri.parse('$DOMAIN/api/climbing-logs/plans/$planId/progress'),
        headers: _headers(token),
      );
      if (await redirectIfUnauthorized(response.statusCode)) return null;
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        final result = json != null ? PlanProgressResponse.fromJson(json) : null;
        _planProgressCache[planId] = _PlanCacheEntry(result, DateTime.now());
        return result;
      }
    } catch (_) {}
    return null;
  }

  /// GET /api/climbing-logs/plans/{id}/calendar?month=. Кэш 60 сек.
  Future<PlanCalendarResponse?> getPlanCalendar(int planId, String month) async {
    final key = '$planId:$month';
    final cached = _planCalendarCache[key];
    if (cached != null && DateTime.now().difference(cached.cachedAt) < _cacheTtl) {
      return cached.value;
    }
    final token = await _getToken();
    if (token == null) return null;
    try {
      final uri = Uri.parse('$DOMAIN/api/climbing-logs/plans/$planId/calendar')
          .replace(queryParameters: {'month': month});
      final response = await http.get(uri, headers: _headers(token));
      if (await redirectIfUnauthorized(response.statusCode)) return null;
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        final result = json != null ? PlanCalendarResponse.fromJson(json) : null;
        _planCalendarCache[key] = _PlanCacheEntry(result, DateTime.now());
        return result;
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
      if (await redirectIfUnauthorized(response.statusCode)) return false;
      if (response.statusCode == 200 || response.statusCode == 201) {
        _invalidatePlanDayCache(planId, date);
        return true;
      }
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
      if (await redirectIfUnauthorized(response.statusCode)) return false;
      if (response.statusCode == 200 || response.statusCode == 204) {
        _invalidatePlanDayCache(planId, date);
        return true;
      }
    } catch (_) {}
    return false;
  }
}
