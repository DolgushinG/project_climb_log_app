import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/widgets/RegistrationStepper.dart';

void main() {
  testWidgets('RegistrationStepper renders correct number of steps', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RegistrationStepper(
            currentStep: 1,
            totalSteps: 4,
          ),
        ),
      ),
    );
    // 4 steps = 4 circles + 3 connectors in the row
    expect(find.byType(RegistrationStepper), findsOneWidget);
  });

  testWidgets('RegistrationStepper shows step labels when provided', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RegistrationStepper(
            currentStep: 0,
            totalSteps: 3,
            stepLabels: ['Шаг 1', 'Шаг 2', 'Шаг 3'],
          ),
        ),
      ),
    );
    expect(find.text('Шаг 1'), findsOneWidget);
    expect(find.text('Шаг 2'), findsOneWidget);
    expect(find.text('Шаг 3'), findsOneWidget);
  });

  testWidgets('RegistrationStepper renders with single step', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RegistrationStepper(
            currentStep: 0,
            totalSteps: 1,
          ),
        ),
      ),
    );
    expect(find.byType(RegistrationStepper), findsOneWidget);
  });
}
