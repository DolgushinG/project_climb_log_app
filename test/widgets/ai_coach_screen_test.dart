import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/Screens/AICoachScreen.dart';
import 'package:login_app/services/AICoachService.dart';

// Mock service можно добавить позже; сейчас проверяем только UI presence
void main() {
  testWidgets('AICoachScreen shows quick action chips', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AICoachScreen()),
      ),
    );
    // Дадим время на инициализацию
    await tester.pumpAndSettle();

    // Проверяем, что есть chips с текстом
    expect(find.text('Как улучшить finger strength?'), findsOneWidget);
    expect(find.text('Что добавить в план?'), findsOneWidget);
    expect(find.text('Почему я застрял на 6b?'), findsOneWidget);
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
