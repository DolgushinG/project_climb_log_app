import 'package:login_app/models/StrengthAchievement.dart';
import 'package:login_app/models/TrainingPlan.dart';

/// Эталонные показатели по грейдам (7b как целевой уровень).
/// Формат: % от веса тела.
class GradeBenchmarks {
  static const String grade6b = '6b';
  static const String grade7b = '7b';
  static const String grade7c = '7c';

  /// Эталон 7b: пальцы, спина, щипок (актив = пальцы для сравнения с щипком).
  static Map<String, double> target7b = {
    'finger': 55,
    'pull': 130,
    'pinch': 35,
    'lock': 80, // lock-off score (sec/30*100)
  };

  static Map<String, double> target6b = {
    'finger': 40,
    'pull': 110,
    'pinch': 28,
    'lock': 50,
  };

  static Map<String, double> target7c = {
    'finger': 65,
    'pull': 140,
    'pinch': 42,
    'lock': 100,
  };
}

/// Результат анализа слабого звена.
class WeakLinkAnalysis {
  final bool fingersWeak;   // Пальцы < Спина
  final bool pullWeak;      // Спина < Пальцы
  final bool pinchWeak;     // Щипок < Актив (пальцы)
  final bool asymmetryHigh; // Асимметрия > 10%
  final String focusArea;
  final List<String> protocols;

  WeakLinkAnalysis({
    required this.fingersWeak,
    required this.pullWeak,
    required this.pinchWeak,
    required this.asymmetryHigh,
    required this.focusArea,
    required this.protocols,
  });
}

/// Генератор персонализированных планов на основе замеров.
class TrainingPlanGenerator {
  TrainingPlanGenerator();

  WeakLinkAnalysis analyzeWeakLink(StrengthMetrics m, {String targetGrade = '7b'}) {
    final target = targetGrade == '7c'
        ? GradeBenchmarks.target7c
        : targetGrade == '6b'
            ? GradeBenchmarks.target6b
            : GradeBenchmarks.target7b;

    final finger = m.fingerBestPct ?? 0;
    final pull = m.pull1RmPct ?? 0;
    final pinch = m.pinchPct ?? 0;
    final lockScore = m.lockOffSec != null && m.lockOffSec! > 0
        ? (m.lockOffSec! / 30.0) * 100
        : 0.0;
    final asym = m.asymmetryPct ?? 0;

    final fingersWeak = finger > 0 && pull > 0 && finger < pull * 0.5;
    final pullWeak = finger > 0 && pull > 0 && pull < finger * 1.5;
    final pinchWeak = pinch > 0 && finger > 0 && pinch < finger * 0.7;
    final asymmetryHigh = asym > 10;

    final protocols = <String>[];
    if (fingersWeak) protocols.add('max_hangs');
    if (pullWeak) protocols.add('power_pulls');
    if (pinchWeak) protocols.add('pinch_lifting');
    if (asymmetryHigh) protocols.add('unilateral');

    String focusArea = 'general';
    if (protocols.isEmpty) {
      focusArea = 'maintain';
    } else if (protocols.length == 1) {
      focusArea = protocols.first;
    } else {
      focusArea = protocols.join('_and_');
    }

    return WeakLinkAnalysis(
      fingersWeak: fingersWeak,
      pullWeak: pullWeak,
      pinchWeak: pinchWeak,
      asymmetryHigh: asymmetryHigh,
      focusArea: focusArea,
      protocols: protocols,
    );
  }

  String generateCoachTip(StrengthMetrics m, WeakLinkAnalysis a, {String targetGrade = '7b'}) {
    final finger = m.fingerBestPct ?? 0;
    final pinch = m.pinchPct ?? 0;
    final pull = m.pull1RmPct ?? 0;

    if (a.pinchWeak && finger > 40) {
      final fingerGrade = _pctToGrade(finger);
      final pinchGrade = _pctToGrade(pinch);
      return 'Полуактив у тебя на $fingerGrade, а щипок — на $pinchGrade. '
          'Слабое звено — pinch. Добавляем щипковый блок, чтобы не вылетать с колонитов.';
    }

    if (a.fingersWeak) {
      return 'Спина сильнее пальцев — classic. Max Hangs 3-5-7, '
          'максимальные висы на финге для пиковой силы.';
    }

    if (a.pullWeak) {
      return 'Пальцы опережают спину. Power Pulls — взрывные подтяги, '
          'чтобы тяга догнала хват.';
    }

    if (a.asymmetryHigh) {
      return 'Разрыв между руками > 10%. Offset Pull-ups и однорукие висы '
          'на слабую сторону — без этого травма на долгих кримпах.';
    }

    if (a.pinchWeak) {
      return 'Щипок слабее активника. Pinch Lifting — блок на 90% от макса, '
          '5 сек удержание, 3 подхода.';
    }

    return 'Всё ровно, слабого звена нет. Repeaters 7:13 — поддерживаем выносливость.';
  }

  String _pctToGrade(double pct) {
    if (pct >= 65) return '7c';
    if (pct >= 55) return '7b';
    if (pct >= 45) return '7a';
    if (pct >= 40) return '6c';
    if (pct >= 35) return '6b';
    return '6a';
  }

  TrainingPlan generatePlan(
    StrengthMetrics m,
    WeakLinkAnalysis a, {
    String targetGrade = '7b',
    int weeksPlan = 4,
    int sessionsPerWeek = 2,
  }) {
    final bw = m.bodyWeightKg ?? 70;
    final drills = <TrainingDrill>[];

    if (a.fingersWeak && m.fingerBestPct != null) {
      final maxKg = ((m.fingerLeftKg ?? 0) > (m.fingerRightKg ?? 0)
              ? (m.fingerLeftKg ?? 0)
              : (m.fingerRightKg ?? 0));
      final workKg = maxKg * 0.9;
      drills.add(TrainingDrill(
        name: '3-5-7 Protocol (Max Hangs)',
        targetWeightKg: workKg,
        sets: 3,
        reps: '3 сек тяга / 5 сек отдых / 7 повторов',
        rest: '180s',
      ));
    }

    if (a.pullWeak) {
      drills.add(TrainingDrill(
        name: 'Power Pulls (Взрывные подтягивания)',
        targetWeightKg: null,
        sets: 4,
        reps: '5 взрывных подтягиваний',
        rest: '120s',
      ));
    }

    if (a.pinchWeak && m.pinchKg != null) {
      final workKg = m.pinchKg! * 0.9;
      drills.add(TrainingDrill(
        name: 'One-arm Block Pulls (Pinch Lifting)',
        targetWeightKg: workKg,
        sets: 5,
        reps: '5s hold',
        rest: '180s',
      ));
    }

    if (a.asymmetryHigh) {
      drills.add(TrainingDrill(
        name: 'Offset Pull-ups',
        targetWeightKg: null,
        sets: 3,
        reps: 'Подтягивания с разной высотой рук',
        rest: '90s',
      ));
    }

    if (a.protocols.isEmpty || drills.isEmpty) {
      final fingerMax = ((m.fingerLeftKg ?? 0) > (m.fingerRightKg ?? 0)
              ? (m.fingerLeftKg ?? 0)
              : (m.fingerRightKg ?? 0));
      final workKg = fingerMax > 0 ? fingerMax * 0.6 : bw * 0.35;
      drills.add(TrainingDrill(
        name: 'Repeaters (7:13)',
        targetWeightKg: workKg > 0 ? workKg : null,
        sets: 3,
        reps: '7 сек вис / 13 сек отдых, 6 повторов',
        rest: '180s',
      ));
    }

    final coachTip = generateCoachTip(m, a, targetGrade: targetGrade);

    return TrainingPlan(
      focusArea: a.focusArea,
      weeksPlan: weeksPlan,
      sessionsPerWeek: sessionsPerWeek,
      drills: drills,
      coachTip: coachTip,
      targetGrade: targetGrade,
    );
  }

  /// Данные для Radar Chart: пользователь vs эталон.
  /// Оси: Пальцы, Спина, Щипок, Lock-off, Баланс (инверсия асимметрии).
  StrengthRadarData prepareRadarData(StrengthMetrics m, {String targetGrade = '7b'}) {
    final target = targetGrade == '7c'
        ? GradeBenchmarks.target7c
        : targetGrade == '6b'
            ? GradeBenchmarks.target6b
            : GradeBenchmarks.target7b;

    final finger = (m.fingerBestPct ?? 0) / 100;
    final pull = (m.pull1RmPct ?? 0) / 150;
    final pinch = (m.pinchPct ?? 0) / 100;
    final lock = m.lockOffSec != null && m.lockOffSec! > 0
        ? (m.lockOffSec! / 30.0).clamp(0.0, 2.0)
        : 0.0;
    final balance = m.asymmetryPct != null
        ? (1 - (m.asymmetryPct! / 100)).clamp(0.0, 1.0)
        : 0.5;

    final userValues = [
      finger.clamp(0.0, 1.0),
      pull.clamp(0.0, 1.0),
      pinch.clamp(0.0, 1.0),
      lock.clamp(0.0, 1.0),
      balance,
    ];

    final targetNorm = [
      (target['finger']! / 80).clamp(0.0, 1.0),
      (target['pull']! / 150).clamp(0.0, 1.0),
      (target['pinch']! / 60).clamp(0.0, 1.0),
      (target['lock']! / 100).clamp(0.0, 1.0),
      0.9,
    ];

    return StrengthRadarData(
      userValues: userValues,
      targetValues: targetNorm,
      labels: ['Пальцы', 'Спина', 'Щипок', 'Lock', 'Баланс'],
    );
  }
}

/// Данные для Radar Chart (пользователь vs эталон).
class StrengthRadarData {
  final List<double> userValues;
  final List<double> targetValues;
  final List<String> labels;

  StrengthRadarData({
    required this.userValues,
    required this.targetValues,
    required this.labels,
  });
}
