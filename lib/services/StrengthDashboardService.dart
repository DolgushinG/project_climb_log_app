import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:login_app/models/StrengthAchievement.dart';

/// Сервис для загрузки последних замеров на дашборд.
class StrengthDashboardService {
  static const String _keyLastMetrics = 'strength_last_metrics';

  Future<StrengthMetrics?> getLastMetrics() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyLastMetrics);
    if (json == null) return null;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return StrengthMetrics(
        fingerLeftKg: (map['finger_left'] as num?)?.toDouble(),
        fingerRightKg: (map['finger_right'] as num?)?.toDouble(),
        pinchKg: (map['pinch'] as num?)?.toDouble(),
        pinchBlockMm: map['pinch_block_mm'] as int? ?? 40,
        pullAddedKg: (map['pull_added'] as num?)?.toDouble(),
        pull1RmPct: (map['pull_1rm_pct'] as num?)?.toDouble(),
        lockOffSec: map['lock_sec'] as int?,
        bodyWeightKg: (map['body_weight'] as num?)?.toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveMetrics(StrengthMetrics m) async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, dynamic>{
      'finger_left': m.fingerLeftKg,
      'finger_right': m.fingerRightKg,
      'pinch': m.pinchKg,
      'pinch_block_mm': m.pinchBlockMm,
      'pull_added': m.pullAddedKg,
      'pull_1rm_pct': m.pull1RmPct,
      'lock_sec': m.lockOffSec,
      'body_weight': m.bodyWeightKg,
    };
    await prefs.setString(_keyLastMetrics, jsonEncode(map));
  }
}
