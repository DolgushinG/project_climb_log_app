import 'package:login_app/models/StrengthAchievement.dart';

/// Одна сессия замеров с датой.
class StrengthMeasurementSession {
  final String date; // YYYY-MM-DD
  final StrengthMetrics metrics;

  StrengthMeasurementSession({
    required this.date,
    required this.metrics,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'finger_left': metrics.fingerLeftKg,
        'finger_right': metrics.fingerRightKg,
        'pinch': metrics.pinchKg,
        'pinch_block_mm': metrics.pinchBlockMm,
        'pull_added': metrics.pullAddedKg,
        'pull_1rm_pct': metrics.pull1RmPct,
        'lock_sec': metrics.lockOffSec,
        'body_weight': metrics.bodyWeightKg,
      };

  factory StrengthMeasurementSession.fromJson(Map<String, dynamic> json) {
    final m = StrengthMetrics(
      fingerLeftKg: (json['finger_left'] as num?)?.toDouble(),
      fingerRightKg: (json['finger_right'] as num?)?.toDouble(),
      pinchKg: (json['pinch'] as num?)?.toDouble(),
      pinchBlockMm: json['pinch_block_mm'] as int? ?? 40,
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
