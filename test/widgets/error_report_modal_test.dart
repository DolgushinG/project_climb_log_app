import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/widgets/error_report_modal.dart';

void main() {
  testWidgets('showErrorReportModal shows dialog with message and actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showErrorReportModal(
                context,
                message: 'Ошибка загрузки',
                onRetry: () {},
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    expect(find.text('Ошибка'), findsOneWidget);
    expect(find.text('Ошибка загрузки'), findsOneWidget);
    expect(find.text('Закрыть'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
    expect(find.text('Отправить ошибку'), findsOneWidget);
  });

  testWidgets('showErrorReportModal with custom title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showErrorReportModal(
                context,
                message: 'Ошибка',
                onRetry: () {},
                title: 'Сеть недоступна',
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    expect(find.text('Сеть недоступна'), findsOneWidget);
  });

  testWidgets('showErrorReportModal close button dismisses dialog', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showErrorReportModal(
                context,
                message: 'Тест',
                onRetry: () {},
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    expect(find.text('Ошибка'), findsOneWidget);

    await tester.tap(find.text('Закрыть'));
    await tester.pumpAndSettle();

    expect(find.text('Ошибка'), findsNothing);
  });
}
