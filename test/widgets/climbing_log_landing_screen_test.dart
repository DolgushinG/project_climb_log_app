import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/Screens/ClimbingLogLandingScreen.dart';

void main() {
  testWidgets('ClimbingLogLandingScreen shows title and subtitle', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ClimbingLogLandingScreen(),
      ),
    );
    expect(find.text('Climbing Log'), findsOneWidget);
    expect(find.text('Трекер тренировок'), findsOneWidget);
  });

  testWidgets('ClimbingLogLandingScreen shows auth prompt', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ClimbingLogLandingScreen(),
      ),
    );
    expect(find.text('Доступно после авторизации'), findsOneWidget);
  });

  testWidgets('ClimbingLogLandingScreen shows features section', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ClimbingLogLandingScreen(),
      ),
    );
    expect(find.text('Возможности'), findsOneWidget);
    expect(find.text('Тренировка'), findsOneWidget);
    expect(find.text('Прогресс'), findsOneWidget);
    expect(find.text('История'), findsOneWidget);
  });

  testWidgets('ClimbingLogLandingScreen shows login and register buttons', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ClimbingLogLandingScreen(),
      ),
    );
    expect(find.text('Войти'), findsOneWidget);
    expect(find.text('Зарегистрироваться'), findsOneWidget);
  });
}
