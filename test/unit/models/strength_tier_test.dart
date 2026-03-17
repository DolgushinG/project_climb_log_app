import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/models/StrengthTier.dart';

void main() {
  group('StrengthTier.fromAveragePct', () {
    test('returns grasshopper when avgPct < 30', () {
      expect(StrengthTierExt.fromAveragePct(0), StrengthTier.grasshopper);
      expect(StrengthTierExt.fromAveragePct(29.9), StrengthTier.grasshopper);
    });

    test('returns stoneGecko when 30 <= avgPct < 50', () {
      expect(StrengthTierExt.fromAveragePct(30), StrengthTier.stoneGecko);
      expect(StrengthTierExt.fromAveragePct(49.9), StrengthTier.stoneGecko);
    });

    test('returns mountainLynx when 50 <= avgPct < 70', () {
      expect(StrengthTierExt.fromAveragePct(50), StrengthTier.mountainLynx);
      expect(StrengthTierExt.fromAveragePct(69.9), StrengthTier.mountainLynx);
    });

    test('returns gravityDefier when 70 <= avgPct < 90', () {
      expect(StrengthTierExt.fromAveragePct(70), StrengthTier.gravityDefier);
      expect(StrengthTierExt.fromAveragePct(89.9), StrengthTier.gravityDefier);
    });

    test('returns apexPredator when avgPct >= 90', () {
      expect(StrengthTierExt.fromAveragePct(90), StrengthTier.apexPredator);
      expect(StrengthTierExt.fromAveragePct(100), StrengthTier.apexPredator);
    });
  });

  group('StrengthTierExt.minPctForTier', () {
    test('returns correct thresholds', () {
      expect(StrengthTierExt.minPctForTier(StrengthTier.grasshopper), 0);
      expect(StrengthTierExt.minPctForTier(StrengthTier.stoneGecko), 30);
      expect(StrengthTierExt.minPctForTier(StrengthTier.mountainLynx), 50);
      expect(StrengthTierExt.minPctForTier(StrengthTier.gravityDefier), 70);
      expect(StrengthTierExt.minPctForTier(StrengthTier.apexPredator), 90);
    });
  });

  group('StrengthTierExt.titleRu', () {
    test('returns Russian titles', () {
      expect(StrengthTier.grasshopper.titleRu, 'Камешек');
      expect(StrengthTier.stoneGecko.titleRu, 'Скала');
      expect(StrengthTier.mountainLynx.titleRu, 'Рокки');
      expect(StrengthTier.gravityDefier.titleRu, 'Нео');
      expect(StrengthTier.apexPredator.titleRu, 'Терминатор');
    });
  });

  group('StrengthTierExt.titleEn', () {
    test('returns English titles', () {
      expect(StrengthTier.grasshopper.titleEn, 'Pebble');
      expect(StrengthTier.stoneGecko.titleEn, 'The Rock');
      expect(StrengthTier.mountainLynx.titleEn, 'Rocky');
      expect(StrengthTier.gravityDefier.titleEn, 'Neo');
      expect(StrengthTier.apexPredator.titleEn, 'Terminator');
    });
  });

  group('StrengthTierExt.level', () {
    test('returns index + 1', () {
      expect(StrengthTier.grasshopper.level, 1);
      expect(StrengthTier.apexPredator.level, 5);
    });
  });

  group('StrengthTierExt.nextTier', () {
    test('returns next tier for non-apex', () {
      expect(StrengthTier.grasshopper.nextTier, StrengthTier.stoneGecko);
      expect(StrengthTier.stoneGecko.nextTier, StrengthTier.mountainLynx);
      expect(StrengthTier.mountainLynx.nextTier, StrengthTier.gravityDefier);
      expect(StrengthTier.gravityDefier.nextTier, StrengthTier.apexPredator);
    });

    test('returns null for apexPredator', () {
      expect(StrengthTier.apexPredator.nextTier, isNull);
    });
  });

  group('StrengthTierExt.gapToNext', () {
    test('returns gap to next tier', () {
      expect(StrengthTier.grasshopper.gapToNext(20), 10); // 30 - 20
      expect(StrengthTier.stoneGecko.gapToNext(40), 10); // 50 - 40
    });

    test('returns 0 for apexPredator', () {
      expect(StrengthTier.apexPredator.gapToNext(95), 0);
    });
  });
}
