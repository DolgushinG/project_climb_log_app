import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/button/result_entry_button.dart';

void main() {
  testWidgets('ResultEntryButton shows "Внести результаты" when not active', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              ResultEntryButton(
                eventId: 1,
                isParticipantActive: false,
                isAccessUserEditResult: true,
                isRoutesExists: true,
                onResultSubmitted: () async {},
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Внести результаты'), findsOneWidget);
  });

  testWidgets('ResultEntryButton shows "Обновить результаты" when can edit', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              ResultEntryButton(
                eventId: 1,
                isParticipantActive: true,
                isAccessUserEditResult: true,
                isRoutesExists: true,
                onResultSubmitted: () async {},
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Обновить результаты'), findsOneWidget);
  });

  testWidgets('ResultEntryButton shows "Результаты добавлены" when no edit access', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              ResultEntryButton(
                eventId: 1,
                isParticipantActive: true,
                isAccessUserEditResult: false,
                isRoutesExists: true,
                onResultSubmitted: () async {},
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Результаты добавлены'), findsOneWidget);
  });

  testWidgets('ResultEntryButton is disabled when no routes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              ResultEntryButton(
                eventId: 1,
                isParticipantActive: false,
                isAccessUserEditResult: true,
                isRoutesExists: false,
                onResultSubmitted: () async {},
              ),
            ],
          ),
        ),
      ),
    );
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });
}
