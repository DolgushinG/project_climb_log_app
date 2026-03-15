import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/Screens/CustomSetBuilderScreen.dart';
import 'package:login_app/Screens/CustomSetLandingScreen.dart';
import 'package:login_app/Screens/SavedSetsScreen.dart';

void main() {
  testWidgets('CustomSetLandingScreen shows title and subtitle', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CustomSetLandingScreen(),
      ),
    );

    expect(find.text('Собственный сет'), findsOneWidget);
    expect(find.text('Собственный сет упражнений'), findsOneWidget);
    expect(find.text('Создайте сет или выберите из сохранённых'), findsOneWidget);
  });

  testWidgets('CustomSetLandingScreen shows "Создать сет" button', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CustomSetLandingScreen(),
      ),
    );

    expect(find.text('Создать сет'), findsOneWidget);
  });

  testWidgets('CustomSetLandingScreen shows "История моих сетов" button', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CustomSetLandingScreen(),
      ),
    );

    expect(find.text('История моих сетов'), findsOneWidget);
  });

  testWidgets('CustomSetLandingScreen has back button', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CustomSetLandingScreen(),
      ),
    );

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
  });

  testWidgets('CustomSetLandingScreen "Создать сет" navigates to CustomSetBuilderScreen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const CustomSetLandingScreen(),
      ),
    );

    await tester.tap(find.text('Создать сет'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(CustomSetBuilderScreen), findsOneWidget);
  });

  testWidgets('CustomSetLandingScreen "История моих сетов" navigates to SavedSetsScreen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const CustomSetLandingScreen(),
      ),
    );

    await tester.tap(find.text('История моих сетов'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(SavedSetsScreen), findsOneWidget);
  });
}
