import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/models/NumberSets.dart';
import 'package:login_app/widgets/SetSelectionCards.dart';

void main() {
  NumberSets makeSet({
    int id = 1,
    int numberSet = 1,
    String time = '10:00',
    String dayOfWeek = 'mon',
    int participantsCount = 3,
    int maxParticipants = 10,
  }) {
    return NumberSets(
      number_set: numberSet,
      id: id,
      time: time,
      day_of_week: dayOfWeek,
      max_participants: maxParticipants,
      allow_years: null,
      participants_count: participantsCount,
      free: maxParticipants - participantsCount,
    );
  }

  testWidgets('SetSelectionCards shows empty message when no sets', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SetSelectionCards(
            sets: [],
            selected: null,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Нет доступных сетов'), findsOneWidget);
  });

  testWidgets('SetSelectionCards shows set cards when sets provided', (tester) async {
    final sets = [makeSet(id: 1, numberSet: 1), makeSet(id: 2, numberSet: 2)];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SetSelectionCards(
            sets: sets,
            selected: null,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Сет 1'), findsOneWidget);
    expect(find.text('Сет 2'), findsOneWidget);
  });

  testWidgets('SetSelectionCards shows occupied/total places', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SetSelectionCards(
            sets: [makeSet(participantsCount: 5, maxParticipants: 10)],
            selected: null,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('5/10 мест'), findsOneWidget);
  });

  testWidgets('SetSelectionCards calls onChanged when card tapped', (tester) async {
    NumberSets? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SetSelectionCards(
            sets: [makeSet(id: 1, numberSet: 1), makeSet(id: 2, numberSet: 2)],
            selected: null,
            onChanged: (s) => selected = s,
          ),
        ),
      ),
    );
    // Tap "Сет 2" which is unique (avoids ambiguity with formatSetCompact "№1")
    await tester.tap(find.text('Сет 2'));
    await tester.pump();
    expect(selected, isNotNull);
    expect(selected!.id, 2);
  });
}
