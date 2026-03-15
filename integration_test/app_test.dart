import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:login_app/login.dart';
import 'package:login_app/MainScreen.dart';
import 'package:login_app/main.dart' as app;
import 'package:login_app/Screens/RegisterScreen.dart';
import 'package:login_app/services/AuthService.dart';
import 'package:login_app/theme/app_theme.dart';

/// Тестовый аккаунт для быстрого E2E-логина (должен существовать на dev-бэкенде).
const String _testEmail = 'new@gmail.com';
const String _testPassword = 'password';

/// Тема для тестов (тёмный фон).
MaterialApp _buildThemedApp(Widget home) => MaterialApp(
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.anthracite,
        colorScheme: ColorScheme.dark().copyWith(primary: AppColors.mutedGold),
      ),
      home: home,
    );

/// Закрывает модалки после логина: сначала верхнюю («Начать»), затем Passkey («Не сейчас»).
Future<void> _dismissPostLoginOverlays(WidgetTester tester) async {
  await tester.pumpAndSettle(const Duration(milliseconds: 500));
  while (true) {
    if (find.text('Начать').evaluate().isNotEmpty) {
      await tester.tap(find.text('Начать').first);
    } else if (find.text('Позже').evaluate().isNotEmpty) {
      await tester.tap(find.text('Позже').first);
    } else if (find.text('Не сейчас').evaluate().isNotEmpty) {
      await tester.tap(find.text('Не сейчас').first);
    } else {
      break;
    }
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  AuthService.init(app.DOMAIN);

  group('E2E — главный экран', () {
    testWidgets('приложение загружается и показывает главный экран (гость)',
        (tester) async {
      // Запуск приложения (без main — pumpWidget, чтобы избежать Workmanager/RuStore в тесте)
      await tester.pumpWidget(app.MyApp());

      // Ожидание завершения async init (TokenChecker → MainScreen в гостевом режиме)
      await tester.pumpAndSettle(const Duration(seconds: 20));

      // Главный экран в гостевом режиме: вкладки Тренировки, Рейтинг, Соревнования, Скалодромы
      // "Тренировки" встречается дважды: заголовок экрана + label вкладки в нижней навигации
      expect(find.text('Тренировки'), findsAtLeastNWidgets(1));
      expect(find.text('Соревнования'), findsAtLeastNWidgets(1));
    });

    testWidgets('переключение на вкладку Соревнования', (tester) async {
      await tester.pumpWidget(app.MyApp());
      await tester.pumpAndSettle(const Duration(seconds: 20));

      // Тап по вкладке «Соревнования»
      await tester.tap(find.text('Соревнования'));
      await tester.pumpAndSettle();

      // Проверка, что экран соревнований отображается (ValueKey от CompetitionsScreen)
      expect(find.byKey(const ValueKey('competitions')), findsOneWidget);
    });
  });

  group('E2E — логин', () {
    testWidgets('вход по new@gmail.com / password → MainScreen с профилем', (tester) async {
      await tester.pumpWidget(_buildThemedApp(LoginScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, _testEmail);
      await tester.enterText(find.byType(TextFormField).last, _testPassword);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Вход'));
      await tester.pumpAndSettle(const Duration(seconds: 15));

      expect(find.byType(MainScreen), findsOneWidget);
      await _dismissPostLoginOverlays(tester);
      expect(find.byKey(const ValueKey('profile')), findsOneWidget);
    });
  });

  group('E2E — регистрация', () {
    testWidgets('регистрация нового пользователя → MainScreen', (tester) async {
      final uniqueEmail = 'e2e_reg_${DateTime.now().millisecondsSinceEpoch}@gmail.com';

      await tester.pumpWidget(_buildThemedApp(RegistrationScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(RegistrationScreen), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'Тест');
      await tester.enterText(find.byType(TextFormField).at(1), 'Тестов');
      await tester.enterText(find.byType(TextFormField).at(2), uniqueEmail);
      await tester.enterText(find.byType(TextFormField).at(3), 'password123');
      await tester.enterText(find.byType(TextFormField).at(4), 'password123');

      await tester.tap(find.text('Выберите пол'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Мужской'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Создать аккаунт'));
      await tester.pumpAndSettle(const Duration(seconds: 15));

      expect(find.byType(MainScreen), findsOneWidget);
      await _dismissPostLoginOverlays(tester);
      expect(find.byKey(const ValueKey('profile')), findsOneWidget);
    });
  });

  group('E2E — логин и вкладки', () {
    testWidgets('логин → переключение всех вкладок, проверка отображения', (tester) async {
      await tester.pumpWidget(_buildThemedApp(LoginScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, _testEmail);
      await tester.enterText(find.byType(TextFormField).last, _testPassword);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Вход'));
      await tester.pumpAndSettle(const Duration(seconds: 15));

      expect(find.byType(MainScreen), findsOneWidget);
      await _dismissPostLoginOverlays(tester);

      // Вкладки авторизованного: Тренировки, Рейтинг, Соревнования, Скалодромы, Профиль
      final tabs = [
        ('Тренировки', ValueKey('climbing_log')),
        ('Рейтинг', ValueKey('rating')),
        ('Соревнования', ValueKey('competitions')),
        ('Скалодромы', ValueKey('gyms')),
        ('Профиль', ValueKey('profile')),
      ];

      for (final (label, key) in tabs) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle(const Duration(seconds: 3));
        await _dismissPostLoginOverlays(tester); // «Пробный период» на Тренировки и др.
        expect(find.byKey(key), findsOneWidget);
      }
    });
  });
}
