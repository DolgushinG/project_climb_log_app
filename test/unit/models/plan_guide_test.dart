import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/models/PlanModels.dart';

void main() {
  group('PlanGuide', () {
    test('fromJson returns empty when json is null', () {
      final g = PlanGuide.fromJson(null);
      expect(g.shortDescription, isNull);
      expect(g.howItWorks, isNull);
      expect(g.whatWeConsider, isNull);
      expect(g.whatYouGet, isNull);
      expect(g.sessionTypes, isNull);
      expect(g.injuriesRecoveryHint, isNull);
    });

    test('fromJson parses short_description and injuries_recovery_hint', () {
      final json = {
        'short_description': 'Plan description',
        'injuries_recovery_hint': 'Rest when injured',
      };
      final g = PlanGuide.fromJson(json);
      expect(g.shortDescription, 'Plan description');
      expect(g.injuriesRecoveryHint, 'Rest when injured');
    });

    test('fromJson parses how_it_works section', () {
      final json = {
        'how_it_works': {
          'title': 'How',
          'sections': [
            {'title': 'S1', 'text': 'Text1'},
          ],
          'items': [
            {'label': 'L1', 'text': 'T1'},
          ],
        },
      };
      final g = PlanGuide.fromJson(json);
      expect(g.howItWorks, isNotNull);
      expect(g.howItWorks!.title, 'How');
      expect(g.howItWorks!.sections!.length, 1);
      expect(g.howItWorks!.sections!.first.title, 'S1');
      expect(g.howItWorks!.items!.length, 1);
      expect(g.howItWorks!.items!.first.label, 'L1');
    });

    test('fromJson parses session_types', () {
      final json = {
        'session_types': {
          'climbing': {'name': 'Climbing', 'description': 'Climb'},
        },
      };
      final g = PlanGuide.fromJson(json);
      expect(g.sessionTypes, isNotNull);
      expect(g.sessionTypes!['climbing']!.name, 'Climbing');
      expect(g.sessionTypes!['climbing']!.description, 'Climb');
    });
  });

  group('PlanGuideSection', () {
    test('fromJson parses section with sections and items', () {
      final json = {
        'title': 'Section Title',
        'sections': [
          {'title': 'Sub', 'text': 'Sub text'},
        ],
        'items': [
          {'label': 'Item', 'text': 'Item text'},
        ],
      };
      final s = PlanGuideSection.fromJson(json);
      expect(s.title, 'Section Title');
      expect(s.sections!.length, 1);
      expect(s.sections!.first.title, 'Sub');
      expect(s.sections!.first.text, 'Sub text');
      expect(s.items!.length, 1);
      expect(s.items!.first.label, 'Item');
      expect(s.items!.first.text, 'Item text');
    });
  });

  group('PlanGuideSectionItem', () {
    test('fromJson parses item', () {
      final json = {'title': 'T', 'text': 'Text'};
      final i = PlanGuideSectionItem.fromJson(json);
      expect(i.title, 'T');
      expect(i.text, 'Text');
    });
  });

  group('PlanGuideLabelText', () {
    test('fromJson parses label and text', () {
      final json = {'label': 'Label', 'text': 'Text'};
      final t = PlanGuideLabelText.fromJson(json);
      expect(t.label, 'Label');
      expect(t.text, 'Text');
    });
  });

  group('PlanSessionTypeInfo', () {
    test('fromJson parses session type', () {
      final json = {'name': 'Climbing', 'description': 'Climb session'};
      final i = PlanSessionTypeInfo.fromJson(json);
      expect(i.name, 'Climbing');
      expect(i.description, 'Climb session');
    });
  });
}
