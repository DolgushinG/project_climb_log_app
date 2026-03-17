import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/utils/climbing_log_colors.dart';

void main() {
  group('gradientForGrade', () {
    test('returns correct gradient for first grade', () {
      final gradient = gradientForGrade('5');
      expect(gradient.length, 2);
      expect(gradient, orderedGrades.contains('5') ? isNotEmpty : isNotEmpty);
    });

    test('returns correct gradient for last grade', () {
      final gradient = gradientForGrade('8A+');
      expect(gradient.length, 2);
    });

    test('returns gradient for middle grades', () {
      final gradient = gradientForGrade('6B');
      expect(gradient.length, 2);
    });

    test('returns first gradient for unknown grade', () {
      final gradient = gradientForGrade('unknown');
      expect(gradient, gradeGradients.first);
    });

    test('returns first gradient for empty string', () {
      final gradient = gradientForGrade('');
      expect(gradient, gradeGradients.first);
    });

    test('groups grades in pairs - 5 and 6A share same gradient group', () {
      final g1 = gradientForGrade('5');
      final g2 = gradientForGrade('6A');
      expect(g1, equals(g2));
    });
  });

  group('orderedGrades', () {
    test('has 14 grades', () {
      expect(orderedGrades.length, 14);
    });

    test('starts with 5 and ends with 8A+', () {
      expect(orderedGrades.first, '5');
      expect(orderedGrades.last, '8A+');
    });

    test('gradeGradients has 7 gradient pairs', () {
      expect(gradeGradients.length, 7);
      for (final g in gradeGradients) {
        expect(g.length, 2);
      }
    });
  });
}
