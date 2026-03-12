import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/services/TrainingGamificationService.dart';

void main() {
  late TrainingGamificationService service;

  setUp(() {
    service = TrainingGamificationService();
  });

  group('recoveryStatusText', () {
    test('optimal returns correct text', () {
      expect(
        service.recoveryStatusText('optimal'),
        'Optimal (Last session 48h+ ago)',
      );
    });

    test('recovering returns correct text', () {
      expect(
        service.recoveryStatusText('recovering'),
        'Recovering (24–48h since last)',
      );
    });

    test('rest returns correct text', () {
      expect(
        service.recoveryStatusText('rest'),
        'Rest day (24h since last)',
      );
    });

    test('default/unknown returns ready text', () {
      expect(
        service.recoveryStatusText('ready'),
        'Ready for training',
      );
      expect(
        service.recoveryStatusText('unknown'),
        'Ready for training',
      );
    });
  });

  group('recoveryStatusTextRu', () {
    test('optimal returns Russian text', () {
      expect(
        service.recoveryStatusTextRu('optimal'),
        'Отлично — 48ч+ с последней сессии',
      );
    });

    test('recovering returns Russian text', () {
      expect(
        service.recoveryStatusTextRu('recovering'),
        'Восстанавливаешься (24–48ч)',
      );
    });

    test('rest returns Russian text', () {
      expect(
        service.recoveryStatusTextRu('rest'),
        'День отдыха — меньше 24ч',
      );
    });

    test('default returns ready text', () {
      expect(
        service.recoveryStatusTextRu('ready'),
        'Готов лезть',
      );
    });
  });
}
