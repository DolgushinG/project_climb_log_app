import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:login_app/main.dart';
import 'package:login_app/models/StrengthAchievement.dart';
import 'package:login_app/models/StrengthMeasurementSession.dart';
import 'package:login_app/models/TrainingPlan.dart';

/// API-сервис для тестирования силы. Интеграция с бэкендом.
class StrengthTestApiService {
  StrengthTestApiService();

  Future<String?> _getToken() => getToken();

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

  LeaderboardEntry({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.averageStrengthPct,
    required this.rank,
    this.weightKg,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) => LeaderboardEntry(
        userId: json['user_id'] as int? ?? 0,
        displayName: json['display_name'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
        averageStrengthPct: (json['average_strength_pct'] as num?)?.toDouble() ?? 0,
        rank: json['rank'] as int? ?? 0,
        weightKg: (json['weight_kg'] as num?)?.toDouble(),
      );
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
