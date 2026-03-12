import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/login.dart';
import 'package:login_app/services/AuthService.dart';
import 'package:login_app/MainScreen.dart';
import 'package:login_app/Screens/RegisterScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fake AuthService для тестов логина.
class FakeAuthService extends AuthService {
  FakeAuthService({
    this.loginResult,
    this.loginError,
  }) : super(baseUrl: 'https://test.local');

  final String? loginResult;
  final AuthException? loginError;

  @override
  Future<String> login(String email, String password) async {
    if (loginError != null) throw loginError!;
    return loginResult ?? 'fake-token';
  }
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    AuthService.testInstance = null;
  });

  testWidgets('LoginScreen показывает поля email, пароль и кнопки', (tester) async {
    AuthService.testInstance = FakeAuthService();

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Вход'), findsWidgets);
    expect(find.text('Email'), findsWidgets);
    expect(find.text('Пароль'), findsWidgets);
    expect(find.text('Гостевой режим'), findsOneWidget);
    expect(find.text('Регистрация'), findsOneWidget);
  });

  testWidgets('Гостевой режим — переход на MainScreen', (tester) async {
    AuthService.testInstance = FakeAuthService();

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Гостевой режим'));
    await tester.pumpAndSettle();

    expect(find.byType(MainScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('climbing_log')), findsOneWidget);
  });

  testWidgets('Кнопка Регистрация — переход на RegistrationScreen', (tester) async {
    AuthService.testInstance = FakeAuthService();

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Регистрация'));
    await tester.tap(find.text('Регистрация'));
    await tester.pumpAndSettle();

    expect(find.byType(RegistrationScreen), findsOneWidget);
  });

  testWidgets('Успешный логин — переход на MainScreen с профилем', (tester) async {
    AuthService.testInstance = FakeAuthService(loginResult: 'test-token');

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'new@gmail.com');
    await tester.enterText(find.byType(TextFormField).last, 'password');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Вход'));
    await tester.pumpAndSettle();

    expect(find.byType(MainScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('profile')), findsOneWidget);
  });

  testWidgets('Ошибка логина — показывается диалог', (tester) async {
    AuthService.testInstance = FakeAuthService(
      loginError: AuthException('Неверный email или пароль'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'wrong@mail.com');
    await tester.enterText(find.byType(TextFormField).last, 'wrongpass');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Вход'));
    await tester.pumpAndSettle();

    expect(find.text('Ошибка входа'), findsOneWidget);
    expect(find.text('Неверный email или пароль'), findsOneWidget);
  });
}
