import 'package:login_app/models/StrengthAchievement.dart';

/// Одна сессия замеров с датой.
class StrengthMeasurementSession {
  final int? id; // ID с бэкенда (для удаления)
  final String date; // YYYY-MM-DD
  final StrengthMetrics metrics;

  StrengthMeasurementSession({
    this.id,
    required this.date,
    required this.metrics,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'finger_left': metrics.fingerLeftKg,
        'finger_right': metrics.fingerRightKg,
        'pinch_40': metrics.pinch40Kg,
        'pinch_60': metrics.pinch60Kg,
        'pinch_80': metrics.pinch80Kg,
        'pull_added': metrics.pullAddedKg,
        'pull_1rm_pct': metrics.pull1RmPct,
        'lock_sec': metrics.lockOffSec,
        'body_weight': metrics.bodyWeightKg,
      };

  factory StrengthMeasurementSession.fromJson(Map<String, dynamic> json) {
    var pinch40 = (json['pinch_40'] as num?)?.toDouble();
    var pinch60 = (json['pinch_60'] as num?)?.toDouble();
    var pinch80 = (json['pinch_80'] as num?)?.toDouble();
    final oldPinch = (json['pinch'] as num?)?.toDouble();
    final oldBlock = json['pinch_block_mm'] as int? ?? 40;
    if (pinch40 == null && pinch60 == null && pinch80 == null && oldPinch != null) {
      if (oldBlock == 40) pinch40 = oldPinch;
      else if (oldBlock == 60) pinch60 = oldPinch;
      else pinch80 = oldPinch;
    }
    final m = StrengthMetrics(
      fingerLeftKg: (json['finger_left'] as num?)?.toDouble(),
      fingerRightKg: (json['finger_right'] as num?)?.toDouble(),
      pinch40Kg: pinch40,
      pinch60Kg: pinch60,
      pinch80Kg: pinch80,
      pullAddedKg: (json['pull_added'] as num?)?.toDouble(),
      pull1RmPct: (json['pull_1rm_pct'] as num?)?.toDouble(),
      lockOffSec: json['lock_sec'] as int?,
      bodyWeightKg: (json['body_weight'] as num?)?.toDouble(),
    );
    return StrengthMeasurementSession(
      date: json['date'] as String? ?? '',
      metrics: m,
    );
  }

  String get dateFormatted {
    if (date.isEmpty || date.length < 10) return date;
    final parts = date.split('-');
    if (parts.length >= 3) {
      const months = ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
      final m = int.tryParse(parts[1]) ?? 1;
      return '${parts[2]} ${months[m.clamp(1, 12) - 1]} ${parts[0]}';
    }
    return date;
  }
}
