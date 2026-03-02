import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/Screens/AICoachScreen.dart';
import 'package:login_app/services/AICoachService.dart';

// Mock service можно добавить позже; сейчас проверяем только UI presence
void main() {
  testWidgets('AICoachScreen shows quick action chips when input is focused', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AICoachScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Тап по полю ввода — показываются подсказки
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    expect(find.text('Как прокачать силу пальцев?'), findsOneWidget);
    expect(find.text('Что скажешь насчет моего плана?'), findsOneWidget);
    expect(find.text('Почему я застрял на категории 6B?'), findsOneWidget);
  });

  testWidgets('AICoachScreen has input field and send button', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AICoachScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget);
  });
}
