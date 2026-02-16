import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:login_app/main.dart';
import 'package:login_app/models/StrengthAchievement.dart';
import 'package:login_app/models/StrengthMeasurementSession.dart';
import 'package:login_app/models/TrainingPlan.dart';
import 'package:login_app/models/Workout.dart';

/// Запись кэша с TTL.
class _CacheEntry<T> {
  final T value;
  final DateTime cachedAt;
  _CacheEntry(this.value, this.cachedAt);
}

/// API-сервис для тестирования силы. Интеграция с бэкендом.
class StrengthTestApiService {
  StrengthTestApiService();

  Future<String?> _getToken() => getToken();

  static const _cacheTtl = Duration(seconds: 60);
  static final Map<String, _CacheEntry<List<ExerciseCompletion>>> _completionsCache = {};
  static final Map<String, _CacheEntry<List<ExerciseSkip>>> _skipsCache = {};

  static void _invalidateCompletionsCache([String? date]) {
    if (date != null) {
      _completionsCache.remove('date:$date');
    } else {
      _completionsCache.clear();
    }
  }

  static void _invalidateSkipsCache([String? date]) {
    if (date != null) {
      _skipsCache.remove('date:$date');
    } else {
      _skipsCache.clear();
    }
  }

  Map<String, String> _headers(String? token) => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  /// GET /api/climbing-logs/strength-test-settings
  Future<double?> getBodyWeight() async {
    final token = await _getToken();
    if (token == null) return null;
    try {
      final response = await http.get(
        Uri.parse('$DOMAIN/api/climbing-logs/strength-test-settings'),
        headers: _headers(token),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        final bw = json?['body_weight'] ?? json?['body_weight_kg'];
        if (bw != null) return (bw as num).toDouble();
      }
    } catch (_) {}
    return null;
  }

  /// PUT /api/climbing-logs/strength-test-settings
  Future<bool> saveBodyWeight(double kg) async {
    final token = await _getToken();
    if (token == null) return false;
    if (kg < 30 || kg > 200) return false;
    try {
      final response = await http.put(
        Uri.parse('$DOMAIN/api/climbing-logs/strength-test-settings'),
        headers: _headers(token),
        body: jsonEncode({'body_weight': kg}),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// POST /api/climbing-logs/strength-tests
  Future<int?> saveStrengthTest(Map<String, dynamic> body) async {
    final token = await _getToken();
    if (token == null) return null;
    try {
      final response = await http.post(
        Uri.parse('$DOMAIN/api/climbing-logs/strength-tests'),
        headers: _headers(token),
        body: jsonEncode(body),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        final id = json?['id'];
        return id is int ? id : (id is num ? id.toInt() : null);
      }
    } catch (_) {}
    return null;
  }

  /// GET /api/climbing-logs/strength-tests
  Future<List<StrengthMeasurementSession>> getStrengthTestsHistory({
    int periodDays = 90,
    String? testType,
  }) async {
    final token = await _getToken();
    if (token == null) return [];
    try {
      var uri = Uri.parse('$DOMAIN/api/climbing-logs/strength-tests')
          .replace(queryParameters: {'period_days': periodDays.toString()});
      if (testType != null) {
        uri = uri.replace(queryParameters: {
          ...uri.queryParameters,
          'test_type': testType,
        });
      }
      final response = await http.get(uri, headers: _headers(token));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        final tests = json?['tests'] as List<dynamic>? ?? [];
        return tests.map((e) {
          final m = e as Map<String, dynamic>;
          return StrengthMeasurementSession(
            date: m['date'] as String? ?? '',
            metrics: StrengthMetrics(
              fingerLeftKg: (m['finger_left_kg'] as num?)?.toDouble(),
              fingerRightKg: (m['finger_right_kg'] as num?)?.toDouble(),
              pinchKg: _pinchFromTest(m),
              pinchBlockMm: 40,
              pullAddedKg: (m['pulling_added_weight_kg'] as num?)?.toDouble(),
              pull1RmPct: (m['pulling_relative_strength_pct'] as num?)?.toDouble(),
              lockOffSec: (m['lock_off_sec'] as num?)?.toInt(),
              bodyWeightKg: (m['body_weight_kg'] as num?)?.toDouble(),
            ),
          );
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  double? _pinchFromTest(Map<String, dynamic> m) {
    final v = m['pinch_40mm_kg'] ?? m['pinch_60mm_kg'] ?? m['pinch_80mm_kg'];
    return v != null ? (v as num).toDouble() : null;
  }

  /// GET /api/climbing-logs/strength-leaderboard
  Future<StrengthLeaderboard?> getLeaderboard({
    String period = 'week',
    String? weightRangeKg,
  }) async {
    final token = await _getToken();
    if (token == null) return null;
    try {
      final params = <String, String>{'period': period};
      if (weightRangeKg != null) params['weight_range_kg'] = weightRangeKg;
      final uri = Uri.parse('$DOMAIN/api/climbing-logs/strength-leaderboard')
          .replace(queryParameters: params);
      final response = await http.get(uri, headers: _headers(token));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        return StrengthLeaderboard.fromJson(json ?? {});
      }
    } catch (_) {}
    return null;
  }

  /// GET /api/climbing-logs/gamification
  Future<GamificationData?> getGamification() async {
    final token = await _getToken();
    if (token == null) return null;
    try {
      final response = await http.get(
        Uri.parse('$DOMAIN/api/climbing-logs/gamification'),
        headers: _headers(token),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        return GamificationData.fromJson(json ?? {});
      }
    } catch (_) {}
    return null;
  }

  /// POST /api/climbing-logs/session-xp
  Future<SessionXpResult?> addSessionXp({int? sessionId}) async {
    final token = await _getToken();
    if (token == null) return null;
    try {
      final body = sessionId != null ? {'session_id': sessionId} : <String, dynamic>{};
      final response = await http.post(
        Uri.parse('$DOMAIN/api/climbing-logs/session-xp'),
        headers: _headers(token),
        body: jsonEncode(body),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        return SessionXpResult(
          xpGained: json?['xp_gained'] as int? ?? 0,
          totalXp: json?['total_xp'] as int? ?? 0,
        );
      }
    } catch (_) {}
    return null;
  }

  /// POST /api/climbing-logs/training-plans
  Future<int?> saveTrainingPlan(TrainingPlan plan) async {
    final token = await _getToken();
    if (token == null) return null;
    try {
      final response = await http.post(
        Uri.parse('$DOMAIN/api/climbing-logs/training-plans'),
        headers: _headers(token),
        body: jsonEncode(plan.toJson()),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        final id = json?['id'];
        return id is int ? id : (id is num ? id.toInt() : null);
      }
    } catch (_) {}
    return null;
  }

  /// GET /api/climbing-logs/strength-level
  /// Уровень по силе + грейду лазания (бэкенд).
  Future<StrengthLevel?> getStrengthLevel() async {
    final token = await _getToken();
    if (token == null) return null;
    try {
      final response = await http.get(
        Uri.parse('$DOMAIN/api/climbing-logs/strength-level'),
        headers: _headers(token),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        if (json != null && json['level'] != null) {
          return StrengthLevel(
            level: json['level'] as String,
            averageStrengthPct: (json['average_strength_pct'] as num?)?.toDouble(),
            maxClimbingGrade: json['max_climbing_grade'] as String?,
            strengthTier: json['strength_tier'] as int?,
            gradeTier: json['grade_tier'] as int?,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  /// GET /api/climbing-logs/exercises
  /// Для ОФП (category=ofp) бэкенд дозирует по уровню. Опционально:
  /// [sessionType] — short (5), standard (7), full (без лимита)
  /// [limit] — жёсткий лимит 1–50
  /// [dayOffset] — 0–6 (день недели) или дата для ротации упражнений
  Future<List<CatalogExercise>> getExercises({
    String? level,
    String? category,
    String? sessionType,
    int? limit,
    int? dayOffset,
  }) async {
    final token = await _getToken();
    if (token == null) return [];
    try {
      final params = <String, String>{};
      if (level != null) params['level'] = level;
      if (category != null) params['category'] = category;
      if (sessionType != null) params['session_type'] = sessionType;
      if (limit != null && limit >= 1 && limit <= 50) params['limit'] = limit.toString();
      if (dayOffset != null && dayOffset >= 0 && dayOffset <= 6) params['day_offset'] = dayOffset.toString();
      final uri = Uri.parse('$DOMAIN/api/climbing-logs/exercises')
          .replace(queryParameters: params.isNotEmpty ? params : null);
      final response = await http.get(uri, headers: _headers(token));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        final list = json?['exercises'] as List<dynamic>? ?? [];
        return list
            .map((e) => CatalogExercise.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// GET /api/climbing-logs/exercise-completions. Кэш 60 сек по date/period.
  Future<List<ExerciseCompletion>> getExerciseCompletions({String? date, int? periodDays}) async {
    final key = date != null ? 'date:$date' : 'period:${periodDays ?? 365}';
    final cached = _completionsCache[key];
    if (cached != null && DateTime.now().difference(cached.cachedAt) < _cacheTtl) {
      return cached.value;
    }
    final token = await _getToken();
    if (token == null) return [];
    try {
      final params = <String, String>{};
      if (date != null) params['date'] = date;
      if (periodDays != null) params['period_days'] = periodDays.toString();
      final uri = Uri.parse('$DOMAIN/api/climbing-logs/exercise-completions')
          .replace(queryParameters: params.isNotEmpty ? params : null);
      final response = await http.get(uri, headers: _headers(token));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        final list = json?['completions'] as List<dynamic>? ?? [];
        final result = list
            .map((e) => ExerciseCompletion.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _completionsCache[key] = _CacheEntry(result, DateTime.now());
        return result;
      }
    } catch (_) {}
    return [];
  }

  /// POST /api/climbing-logs/exercise-completions
  Future<int?> saveExerciseCompletion({
    required String date,
    required String exerciseId,
    int setsDone = 1,
    double? weightKg,
    String notes = '',
  }) async {
    final token = await _getToken();
    if (token == null) return null;
    try {
      final body = <String, dynamic>{
        'date': date,
        'exercise_id': exerciseId,
        'sets_done': setsDone,
        'notes': notes,
      };
      if (weightKg != null) body['weight_kg'] = weightKg;
      final response = await http.post(
        Uri.parse('$DOMAIN/api/climbing-logs/exercise-completions'),
        headers: _headers(token),
        body: jsonEncode(body),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        _invalidateCompletionsCache(date);
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        final id = json?['id'];
        return id is int ? id : (id is num ? id.toInt() : null);
      }
    } catch (_) {}
    return null;
  }

  /// DELETE /api/climbing-logs/exercise-completions?date=YYYY-MM-DD — массовая очистка за дату (для тестирования).
  /// Бэкенд удаляет все exercise-completions пользователя за указанную дату.
  /// Возвращает количество удалённых записей или null при ошибке.
  Future<int?> clearExerciseCompletionsForDate(String date) async {
    final token = await _getToken();
    if (token == null) return null;
    try {
      final uri = Uri.parse('$DOMAIN/api/climbing-logs/exercise-completions')
          .replace(queryParameters: {'date': date});
      final response = await http.delete(uri, headers: _headers(token));
      if (response.statusCode == 200 || response.statusCode == 204) {
        _invalidateCompletionsCache(date);
        final body = response.body.trim();
        if (body.isEmpty) return 0;
        final json = jsonDecode(body) as Map<String, dynamic>?;
        final deleted = json?['deleted'];
        return deleted is int ? deleted : (deleted is num ? deleted.toInt() : 0);
      }
    } catch (_) {}
    return null;
  }

  /// DELETE /api/climbing-logs/exercise-completions — полная очистка всех отметок пользователя (для тестирования).
  /// Бэкенд удаляет все exercise-completions. Возвращает количество или null.
  Future<int?> clearAllExerciseCompletions() async {
    final token = await _getToken();
    if (token == null) return null;
    try {
      final response = await http.delete(
        Uri.parse('$DOMAIN/api/climbing-logs/exercise-completions'),
        headers: _headers(token),
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        _invalidateCompletionsCache();
        final body = response.body.trim();
        if (body.isEmpty) return 0;
        final json = jsonDecode(body) as Map<String, dynamic>?;
        final deleted = json?['deleted'];
        return deleted is int ? deleted : (deleted is num ? deleted.toInt() : 0);
      }
    } catch (_) {}
    return null;
  }

  /// DELETE /api/climbing-logs/exercise-completions/:id (если бэк поддерживает отмену)
  Future<bool> deleteExerciseCompletion(int id) async {
    final token = await _getToken();
    if (token == null) return false;
    try {
      final response = await http.delete(
        Uri.parse('$DOMAIN/api/climbing-logs/exercise-completions/$id'),
        headers: _headers(token),
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        _invalidateCompletionsCache();
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// GET /api/climbing-logs/exercise-skips. Кэш 60 сек по date/period.
  Future<List<ExerciseSkip>> getExerciseSkips({String? date, int? periodDays}) async {
    final key = date != null ? 'date:$date' : 'period:${periodDays ?? 365}';
    final cached = _skipsCache[key];
    if (cached != null && DateTime.now().difference(cached.cachedAt) < _cacheTtl) {
      return cached.value;
    }
    final token = await _getToken();
    if (token == null) return [];
    try {
      final params = <String, String>{};
      if (date != null) params['date'] = date;
      if (periodDays != null) params['period_days'] = periodDays.toString();
      final uri = Uri.parse('$DOMAIN/api/climbing-logs/exercise-skips')
          .replace(queryParameters: params.isNotEmpty ? params : null);
      final response = await http.get(uri, headers: _headers(token));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        final list = json?['skips'] as List<dynamic>? ?? [];
        final result = list
            .map((e) => ExerciseSkip.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _skipsCache[key] = _CacheEntry(result, DateTime.now());
        return result;
      }
    } catch (_) {}
    return [];
  }

  /// POST /api/climbing-logs/exercise-skips
  Future<int?> saveExerciseSkip({
    required String date,
    required String exerciseId,
    String? reason,
  }) async {
    final token = await _getToken();
    if (token == null) return null;
    try {
      final body = <String, dynamic>{
        'date': date,
        'exercise_id': exerciseId,
      };
      if (reason != null && reason.isNotEmpty) body['reason'] = reason;
      final response = await http.post(
        Uri.parse('$DOMAIN/api/climbing-logs/exercise-skips'),
        headers: _headers(token),
        body: jsonEncode(body),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        _invalidateSkipsCache(date);
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        final id = json?['id'];
        return id is int ? id : (id is num ? id.toInt() : null);
      }
    } catch (_) {}
    return null;
  }

  /// DELETE /api/climbing-logs/exercise-skips/:id
  Future<bool> deleteExerciseSkip(int id) async {
    final token = await _getToken();
    if (token == null) return false;
    try {
      final response = await http.delete(
        Uri.parse('$DOMAIN/api/climbing-logs/exercise-skips/$id'),
        headers: _headers(token),
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        _invalidateSkipsCache();
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Собрать тело запроса для POST strength-tests из StrengthMetrics.
  Map<String, dynamic> buildStrengthTestBody(
    StrengthMetrics m, {
    String? currentRank,
    List<String>? unlockedBadges,
  }) {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final body = <String, dynamic>{
      'date': dateStr,
      'body_weight_kg': m.bodyWeightKg,
    };
    if (m.fingerLeftKg != null || m.fingerRightKg != null) {
      body['finger_isometrics'] = {
        'grip_type': 'half_crimp',
        'left_kg': m.fingerLeftKg,
        'right_kg': m.fingerRightKg,
      };
    }
    if (m.pinchKg != null) {
      body['pinch_grip'] = {
        'block_width_mm': m.pinchBlockMm,
        'max_weight_kg': m.pinchKg,
      };
    }
    if (m.pullAddedKg != null && m.bodyWeightKg != null && m.bodyWeightKg! > 0) {
      final total = m.bodyWeightKg! + m.pullAddedKg!;
      body['pulling_power'] = {
        'added_weight_kg': m.pullAddedKg,
        'reps': 1,
        'estimated_1rm_kg': total,
        'relative_strength_pct': m.pull1RmPct ?? (total / m.bodyWeightKg! * 100),
      };
    }
    if (m.lockOffSec != null && m.lockOffSec! > 0) {
      body['lock_off_sec'] = m.lockOffSec;
    }
    if (currentRank != null) body['current_rank'] = currentRank;
    if (unlockedBadges != null && unlockedBadges.isNotEmpty) {
      body['unlocked_badges'] = unlockedBadges;
    }
    return body;
  }

  /// POST /api/climbing-logs/workout/generate
  Future<WorkoutGenerateResponse?> generateWorkout(GenerateWorkoutRequest req) async {
    final token = await _getToken();
    if (token == null) return null;
    try {
      final response = await http.post(
        Uri.parse('$DOMAIN/api/climbing-logs/workout/generate'),
        headers: _headers(token),
        body: jsonEncode(req.toJson()),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        return json != null ? WorkoutGenerateResponse.fromJson(json) : null;
      }
    } catch (_) {}
    return null;
  }

  /// GET /api/climbing-logs/weekly-fatigue
  Future<WeeklyFatigueResponse?> getWeeklyFatigue() async {
    final token = await _getToken();
    if (token == null) return null;
    try {
      final response = await http.get(
        Uri.parse('$DOMAIN/api/climbing-logs/weekly-fatigue'),
        headers: _headers(token),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        return json != null ? WeeklyFatigueResponse.fromJson(json) : null;
      }
    } catch (_) {}
    return null;
  }
}

class StrengthLeaderboard {
  final List<LeaderboardEntry> leaderboard;
  final int? userPosition;
  final int totalParticipants;

  StrengthLeaderboard({
    required this.leaderboard,
    this.userPosition,
    this.totalParticipants = 0,
  });

  factory StrengthLeaderboard.fromJson(Map<String, dynamic> json) {
    final list = (json['leaderboard'] as List<dynamic>?) ?? [];
    return StrengthLeaderboard(
      leaderboard: list
          .map((e) => LeaderboardEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      userPosition: json['user_position'] as int?,
      totalParticipants: json['total_participants'] as int? ?? 0,
    );
  }
}

class LeaderboardEntry {
  final int userId;
  final String displayName;
  final String? avatarUrl;
  final double averageStrengthPct;
  final int rank;
  final double? weightKg;
  final double? fingerLeftKg;
  final double? fingerRightKg;
  final double? pinchKg;
  final double? pullAddedKg;
  final double? pull1RmKg;

  LeaderboardEntry({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.averageStrengthPct,
    required this.rank,
    this.weightKg,
    this.fingerLeftKg,
    this.fingerRightKg,
    this.pinchKg,
    this.pullAddedKg,
    this.pull1RmKg,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) => LeaderboardEntry(
        userId: json['user_id'] as int? ?? 0,
        displayName: json['display_name'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
        averageStrengthPct: (json['average_strength_pct'] as num?)?.toDouble() ?? 0,
        rank: json['rank'] as int? ?? 0,
        weightKg: (json['weight_kg'] as num?)?.toDouble(),
        fingerLeftKg: (json['finger_left_kg'] as num?)?.toDouble(),
        fingerRightKg: (json['finger_right_kg'] as num?)?.toDouble(),
        pinchKg: (json['pinch_kg'] as num?)?.toDouble(),
        pullAddedKg: (json['pull_added_kg'] as num?)?.toDouble(),
        pull1RmKg: (json['pull_1rm_kg'] as num?)?.toDouble(),
      );

  bool get hasDetailedMetrics =>
      fingerLeftKg != null || fingerRightKg != null || pinchKg != null || pullAddedKg != null || pull1RmKg != null;
}

class GamificationData {
  final int totalXp;
  final int streakDays;
  final String? lastSessionDate;
  final String recoveryStatus;
  final bool bossFightDue;
  final String? lastMeasureDate;

  GamificationData({
    this.totalXp = 0,
    this.streakDays = 0,
    this.lastSessionDate,
    this.recoveryStatus = 'ready',
    this.bossFightDue = false,
    this.lastMeasureDate,
  });

  factory GamificationData.fromJson(Map<String, dynamic> json) => GamificationData(
        totalXp: json['total_xp'] as int? ?? 0,
        streakDays: json['streak_days'] as int? ?? 0,
        lastSessionDate: json['last_session_date'] as String?,
        recoveryStatus: json['recovery_status'] as String? ?? 'ready',
        bossFightDue: json['boss_fight_due'] as bool? ?? false,
        lastMeasureDate: json['last_measure_date'] as String?,
      );
}

class SessionXpResult {
  final int xpGained;
  final int totalXp;

  SessionXpResult({required this.xpGained, required this.totalXp});
}

/// Выполнение упражнения (ответ API).
/// Упражнение из каталога API.
class CatalogExercise {
  final String id;
  final String name;
  final String? nameRu;
  final String category;
  final String level;
  final String? description;
  final String? hint;
  final String? dosage;
  final String? imageUrl;
  final List<String> muscleGroups;
  final int defaultSets;
  final String defaultReps;
  final String defaultRest;
  final bool targetWeightOptional;

  CatalogExercise({
    required this.id,
    required this.name,
    this.nameRu,
    required this.category,
    required this.level,
    this.description,
    this.hint,
    this.dosage,
    this.imageUrl,
    this.muscleGroups = const [],
    this.defaultSets = 3,
    this.defaultReps = '6',
    this.defaultRest = '180s',
    this.targetWeightOptional = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (nameRu != null) 'name_ru': nameRu,
        'category': category,
        'level': level,
        if (description != null) 'description': description,
        if (hint != null) 'hint': hint,
        if (dosage != null) 'dosage': dosage,
        if (imageUrl != null) 'image_url': imageUrl,
        if (muscleGroups.isNotEmpty) 'muscle_groups': muscleGroups,
        'default_sets': defaultSets,
        'default_reps': defaultReps,
        'default_rest': defaultRest,
        'target_weight_optional': targetWeightOptional,
      };

  factory CatalogExercise.fromJson(Map<String, dynamic> json) {
    final mgRaw = json['muscle_groups'];
    List<String> mg = [];
    if (mgRaw is List) {
      mg = mgRaw.map((e) => e.toString()).toList();
    }
    return CatalogExercise(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      nameRu: json['name_ru'] as String?,
      category: json['category'] as String? ?? 'sfp',
      level: json['level'] as String? ?? 'intermediate',
      description: json['description'] as String?,
      hint: json['hint'] as String?,
      dosage: json['dosage'] as String?,
      imageUrl: json['image_url'] as String?,
      muscleGroups: mg,
      defaultSets: json['default_sets'] as int? ?? 3,
      defaultReps: json['default_reps'] as String? ?? '6',
      defaultRest: json['default_rest'] as String? ?? '180s',
      targetWeightOptional: json['target_weight_optional'] as bool? ?? true,
    );
  }

  String get displayName => nameRu ?? name;

  /// Текст дозировки: dosage, если есть, иначе «defaultSets × defaultReps».
  String get dosageDisplay =>
      (dosage != null && dosage!.isNotEmpty) ? dosage! : '$defaultSets × $defaultReps';

  /// Создаёт CatalogExercise из WorkoutBlockExercise (для экрана выполнения).
  static CatalogExercise fromWorkoutBlock(WorkoutBlockExercise w) {
    String reps;
    if (w.holdSeconds != null && w.holdSeconds! > 0) {
      reps = '${w.holdSeconds}s';
    } else if (w.defaultReps is int) {
      reps = '${w.defaultReps}';
    } else {
      reps = w.defaultReps.toString();
    }
    return CatalogExercise(
      id: w.exerciseId,
      name: w.name,
      nameRu: w.nameRu,
      category: w.category,
      level: 'intermediate',
      description: w.comment,
      hint: w.hint,
      dosage: w.dosage,
      defaultSets: w.defaultSets,
      defaultReps: reps,
      defaultRest: '${w.defaultRestSeconds}s',
    );
  }
}

class ExerciseCompletion {
  final int id;
  final String date;
  final String exerciseId;
  final String? exerciseName;
  final int setsDone;
  final double? weightKg;

  ExerciseCompletion({
    required this.id,
    required this.date,
    required this.exerciseId,
    this.exerciseName,
    this.setsDone = 1,
    this.weightKg,
  });

  factory ExerciseCompletion.fromJson(Map<String, dynamic> json) => ExerciseCompletion(
        id: json['id'] as int? ?? 0,
        date: json['date'] as String? ?? '',
        exerciseId: json['exercise_id'] as String? ?? '',
        exerciseName: json['exercise_name'] as String?,
        setsDone: json['sets_done'] as int? ?? 1,
        weightKg: (json['weight_kg'] as num?)?.toDouble(),
      );
}

/// Пропуск упражнения (не могу выполнить). Не идёт в exercise-completions.
class ExerciseSkip {
  final int id;
  final String date;
  final String exerciseId;
  final String? exerciseName;
  final String? reason;

  ExerciseSkip({
    required this.id,
    required this.date,
    required this.exerciseId,
    this.exerciseName,
    this.reason,
  });

  factory ExerciseSkip.fromJson(Map<String, dynamic> json) => ExerciseSkip(
        id: json['id'] as int? ?? 0,
        date: json['date'] as String? ?? '',
        exerciseId: json['exercise_id'] as String? ?? '',
        exerciseName: json['exercise_name'] as String?,
        reason: json['reason'] as String?,
      );
}

/// Уровень силы + грейда из GET /api/climbing-logs/strength-level.
class StrengthLevel {
  final String level;
  final double? averageStrengthPct;
  final String? maxClimbingGrade;
  final int? strengthTier;
  final int? gradeTier;

  StrengthLevel({
    required this.level,
    this.averageStrengthPct,
    this.maxClimbingGrade,
    this.strengthTier,
    this.gradeTier,
  });
}
