import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/widgets/error_report_button.dart';

void main() {
  testWidgets('ErrorReportButton shows send button and icon initially', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErrorReportButton(errorMessage: 'Test error'),
        ),
      ),
    );
    expect(find.text('Отправить ошибку'), findsOneWidget);
    expect(find.byIcon(Icons.bug_report_outlined), findsOneWidget);
  });
}
