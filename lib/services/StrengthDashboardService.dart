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
      var pinch40 = (map['pinch_40'] as num?)?.toDouble();
      var pinch60 = (map['pinch_60'] as num?)?.toDouble();
      var pinch80 = (map['pinch_80'] as num?)?.toDouble();
      final oldPinch = (map['pinch'] as num?)?.toDouble();
      final oldBlock = map['pinch_block_mm'] as int? ?? 40;
      if (pinch40 == null && pinch60 == null && pinch80 == null && oldPinch != null) {
        if (oldBlock == 40) pinch40 = oldPinch;
        else if (oldBlock == 60) pinch60 = oldPinch;
        else pinch80 = oldPinch;
      }
      return StrengthMetrics(
        fingerLeftKg: (map['finger_left'] as num?)?.toDouble(),
        fingerRightKg: (map['finger_right'] as num?)?.toDouble(),
        pinch40Kg: pinch40,
        pinch60Kg: pinch60,
        pinch80Kg: pinch80,
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
      'pinch_40': m.pinch40Kg,
      'pinch_60': m.pinch60Kg,
      'pinch_80': m.pinch80Kg,
      'pull_added': m.pullAddedKg,
      'pull_1rm_pct': m.pull1RmPct,
      'lock_sec': m.lockOffSec,
      'body_weight': m.bodyWeightKg,
    };
    await prefs.setString(_keyLastMetrics, jsonEncode(map));
  }
}
