import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/widgets/top_notification_banner.dart';

void main() {
  testWidgets('TopNotificationBanner shows message and icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TopNotificationBanner(
            message: 'Тестовое сообщение',
            icon: Icons.info_outline,
          ),
        ),
      ),
    );
    expect(find.text('Тестовое сообщение'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
  });

  testWidgets('TopNotificationBanner.offline shows wifi_off icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TopNotificationBanner.offline(
            message: 'Нет подключения',
          ),
        ),
      ),
    );
    expect(find.text('Нет подключения'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
  });

  testWidgets('TopNotificationBanner.warning shows message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TopNotificationBanner.warning(
            message: 'Предупреждение',
          ),
        ),
      ),
    );
    expect(find.text('Предупреждение'), findsOneWidget);
  });

  testWidgets('TopNotificationBanner.info shows message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TopNotificationBanner.info(
            message: 'Данные из кэша',
          ),
        ),
      ),
    );
    expect(find.text('Данные из кэша'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
  });

  testWidgets('TopNotificationBanner.subscriptionExpired shows Оформить button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TopNotificationBanner.subscriptionExpired(
            onSubscribe: () {},
          ),
        ),
      ),
    );
    expect(find.text('Подписка закончилась. Оформите снова'), findsOneWidget);
    expect(find.text('Оформить'), findsOneWidget);
  });

  testWidgets('TopNotificationBanner onClose triggers callback', (tester) async {
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TopNotificationBanner(
            message: 'Закрыть тест',
            onClose: () => closed = true,
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    expect(closed, isTrue);
  });
}
