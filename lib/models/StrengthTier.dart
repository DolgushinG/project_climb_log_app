import 'package:flutter/material.dart';

/// Ранг (Strength Tier) на основе среднего % относительной силы по всем тестам.
enum StrengthTier {
  grasshopper,   // < 30%
  stoneGecko,    // 30-50%
  mountainLynx, // 50-70%
  gravityDefier,// 70-90%
  apexPredator, // > 90%
}

extension StrengthTierExt on StrengthTier {
  int get level => index + 1;

  String get titleRu {
    switch (this) {
      case StrengthTier.grasshopper:
        return 'Камешек';
      case StrengthTier.stoneGecko:
        return 'Скала';
      case StrengthTier.mountainLynx:
        return 'Рокки';
      case StrengthTier.gravityDefier:
        return 'Нео';
      case StrengthTier.apexPredator:
        return 'Терминатор';
    }
  }

  String get titleEn {
    switch (this) {
      case StrengthTier.grasshopper:
        return 'Pebble';
      case StrengthTier.stoneGecko:
        return 'The Rock';
      case StrengthTier.mountainLynx:
        return 'Rocky';
      case StrengthTier.gravityDefier:
        return 'Neo';
      case StrengthTier.apexPredator:
        return 'Terminator';
    }
  }

  IconData get icon {
    switch (this) {
      case StrengthTier.grasshopper:
        return Icons.grain;
      case StrengthTier.stoneGecko:
        return Icons.landscape;
      case StrengthTier.mountainLynx:
        return Icons.fitness_center;
      case StrengthTier.gravityDefier:
        return Icons.flight_takeoff;
      case StrengthTier.apexPredator:
        return Icons.smart_toy;
    }
  }

  static StrengthTier fromAveragePct(double avgPct) {
    if (avgPct < 30) return StrengthTier.grasshopper;
    if (avgPct < 50) return StrengthTier.stoneGecko;
    if (avgPct < 70) return StrengthTier.mountainLynx;
    if (avgPct < 90) return StrengthTier.gravityDefier;
    return StrengthTier.apexPredator;
  }

  static double minPctForTier(StrengthTier t) {
    switch (t) {
      case StrengthTier.grasshopper:
        return 0;
      case StrengthTier.stoneGecko:
        return 30;
      case StrengthTier.mountainLynx:
        return 50;
      case StrengthTier.gravityDefier:
        return 70;
      case StrengthTier.apexPredator:
        return 90;
    }
  }

  /// Следующий ранг (null если уже Apex)
  StrengthTier? get nextTier {
    if (this == StrengthTier.apexPredator) return null;
    return StrengthTier.values[index + 1];
  }

  /// Сколько % не хватает до следующего ранга
  double gapToNext(double currentAvg) {
    final next = nextTier;
    if (next == null) return 0;
    return StrengthTierExt.minPctForTier(next) - currentAvg;
  }
}
