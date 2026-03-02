import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/Screens/AICoachScreen.dart';
import 'package:login_app/services/AICoachService.dart';

// Mock service можно добавить позже; сейчас проверяем только UI presence
void main() {
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
