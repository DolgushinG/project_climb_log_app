import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/Screens/CustomSetLandingScreen.dart';
import 'package:login_app/Screens/PlanOverviewScreen.dart';
import 'package:login_app/Screens/PlanTrainingLandingScreen.dart';

void main() {
  testWidgets('PlanTrainingLandingScreen shows title', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PlanTrainingLandingScreen(),
      ),
    );

    expect(find.text('План тренировок'), findsOneWidget);
  });

  testWidgets('PlanTrainingLandingScreen shows subtitle', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PlanTrainingLandingScreen(),
      ),
    );

    expect(find.text('Выберите тип тренировки'), findsOneWidget);
  });

  testWidgets('PlanTrainingLandingScreen shows Plan and CustomSet blocks', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PlanTrainingLandingScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600)); // дождаться анимации

    expect(find.text('План'), findsOneWidget);
    expect(find.text('Свой сет'), findsOneWidget);
  });

  testWidgets('PlanTrainingLandingScreen Plan block has description', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PlanTrainingLandingScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Персональное расписание ОФП и СФП под ваши цели'), findsOneWidget);
  });

  testWidgets('PlanTrainingLandingScreen CustomSet block has description', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PlanTrainingLandingScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Выберите упражнения и создайте тренировку на сегодня'), findsOneWidget);
  });

  testWidgets('PlanTrainingLandingScreen tapping "Свой сет" navigates to CustomSetLandingScreen', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PlanTrainingLandingScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Свой сет'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(CustomSetLandingScreen), findsOneWidget);
  });

  testWidgets('PlanTrainingLandingScreen tapping "План" navigates to PlanOverviewScreen', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PlanTrainingLandingScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('План'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(PlanOverviewScreen), findsOneWidget);
  });
}
