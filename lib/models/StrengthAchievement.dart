import 'package:flutter/material.dart';

/// Достижение (badge) за биометрические показатели.
class StrengthAchievement {
  final String id;
  final String titleRu;
  final String descriptionRu;
  /// Подсказка, как получить достижение.
  final String? hintRu;
  final IconData icon;
  final bool Function(StrengthMetrics m) check;

  const StrengthAchievement({
    required this.id,
    required this.titleRu,
    required this.descriptionRu,
    this.hintRu,
    required this.icon,
    required this.check,
  });
}

/// Агрегированные метрики для проверки достижений.
class StrengthMetrics {
  final double? fingerLeftKg;
  final double? fingerRightKg;
  final double? pinchKg;
  final int pinchBlockMm;
  final double? pullAddedKg;
  final double? pull1RmPct;
  final int? lockOffSec;
  final double? bodyWeightKg;

  StrengthMetrics({
    this.fingerLeftKg,
    this.fingerRightKg,
    this.pinchKg,
    this.pinchBlockMm = 40,
    this.pullAddedKg,
    this.pull1RmPct,
    this.lockOffSec,
    this.bodyWeightKg,
  });

  double? get fingerBestPct {
    if (bodyWeightKg == null || bodyWeightKg! <= 0) return null;
    final left = fingerLeftKg;
    final right = fingerRightKg;
    if (left == null && right == null) return null;
    final best = (left ?? 0) > (right ?? 0) ? (left ?? 0) : (right ?? 0);
    return (best / bodyWeightKg!) * 100;
  }

  double? get pinchPct {
    if (bodyWeightKg == null || bodyWeightKg! <= 0 || pinchKg == null) return null;
    return (pinchKg! / bodyWeightKg!) * 100;
  }

  double? get asymmetryPct {
    final l = fingerLeftKg;
    final r = fingerRightKg;
    if (l == null || r == null) return null;
    final maxVal = l > r ? l : r;
    if (maxVal <= 0) return null;
    return ((maxVal - (l < r ? l : r)) / maxVal) * 100;
  }

  bool get hasPullData =>
      pullAddedKg != null && bodyWeightKg != null && bodyWeightKg! > 0;
}

/// Все доступные достижения.
final List<StrengthAchievement> strengthAchievements = [
  StrengthAchievement(
    id: 'crab_claws',
    titleRu: 'Клешни краба',
    descriptionRu: 'Щипок — твоя фишка. Колониты не страшны.',
    hintRu: 'Щипок ≥40% от веса тела. Введи вес и замер щипка в разделе «Тест».',
    icon: Icons.pan_tool,
    check: (m) => m.pinchPct != null && m.pinchPct! >= 40,
  ),
  StrengthAchievement(
    id: 'steel_crimp',
    titleRu: 'Стальной crimp',
    descriptionRu: 'Активники — твоя тема.',
    hintRu: 'Лучший палец (левая или правая) ≥60% от веса. Замерь пальцы в «Тест».',
    icon: Icons.back_hand,
    check: (m) =>
        m.fingerBestPct != null &&
        m.fingerBestPct! >= 60,
  ),
  StrengthAchievement(
    id: 'hauler',
    titleRu: 'Тягач',
    descriptionRu: 'Вертикаль — как лифт. +50% к весу на подтяге.',
    hintRu: 'Добавочный вес на подтяге ≥50% от веса тела. Введи вес и замер в «Тест».',
    icon: Icons.fitness_center,
    check: (m) =>
        m.hasPullData &&
        m.pullAddedKg! >= (m.bodyWeightKg! * 0.5),
  ),
  StrengthAchievement(
    id: 'balance_of_power',
    titleRu: 'Баланс',
    descriptionRu: 'Левая = правая. Асимметрия меньше 3%.',
    hintRu: 'Разница между левой и правой рукой <3%. Замерь оба пальца в «Тест».',
    icon: Icons.balance,
    check: (m) =>
        m.asymmetryPct != null &&
        m.asymmetryPct! < 3,
  ),
  StrengthAchievement(
    id: 'iron_lock',
    titleRu: 'Железный lock',
    descriptionRu: '30+ сек lock-off на одной — мало кто так может.',
    hintRu: 'Lock-off 90° на одной руке ≥30 сек. Засеки время в «Тест».',
    icon: Icons.lock,
    check: (m) =>
        m.lockOffSec != null &&
        m.lockOffSec! >= 30,
  ),
];
