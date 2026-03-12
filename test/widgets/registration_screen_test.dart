import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/Screens/RegisterScreen.dart';
import 'package:login_app/services/AuthService.dart';
import 'package:login_app/MainScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fake AuthService для тестов регистрации.
class FakeRegisterAuthService extends AuthService {
  FakeRegisterAuthService({
    this.registerResult,
    this.registerError,
  }) : super(baseUrl: 'https://test.local');

  final String? registerResult;
  final AuthException? registerError;

  @override
  Future<String> register({
    required String firstname,
    required String lastname,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? gender,
  }) async {
    if (registerError != null) throw registerError!;
    return registerResult ?? 'fake-token';
  }
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    AuthService.testInstance = null;
  });

  testWidgets('RegistrationScreen показывает поля формы', (tester) async {
    AuthService.testInstance = FakeRegisterAuthService();

    await tester.pumpWidget(
      MaterialApp(
        home: RegistrationScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Регистрация'), findsOneWidget);
    expect(find.text('Имя'), findsWidgets);
    expect(find.text('Фамилия'), findsWidgets);
    expect(find.text('E-mail'), findsWidgets);
    expect(find.text('Пароль'), findsWidgets);
    expect(find.text('Подтвердите пароль'), findsWidgets);
  });

  testWidgets('Валидация: пустое имя — ошибка', (tester) async {
    AuthService.testInstance = FakeRegisterAuthService();

    await tester.pumpWidget(
      MaterialApp(
        home: RegistrationScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Создать аккаунт'));
    await tester.pumpAndSettle();

    expect(find.text('Введите имя'), findsOneWidget);
  });

  testWidgets('Валидация: неверный email — ошибка', (tester) async {
    AuthService.testInstance = FakeRegisterAuthService();

    await tester.pumpWidget(
      MaterialApp(
        home: RegistrationScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Test');
    await tester.enterText(find.byType(TextFormField).at(1), 'User');
    await tester.enterText(find.byType(TextFormField).at(2), 'invalid-email');
    await tester.enterText(find.byType(TextFormField).at(3), 'password123');
    await tester.enterText(find.byType(TextFormField).at(4), 'password123');

    await tester.tap(find.text('Создать аккаунт'));
    await tester.pumpAndSettle();

    expect(find.text('Введите корректный e-mail'), findsOneWidget);
  });

  testWidgets('Без согласия с политикой — snackbar', (tester) async {
    AuthService.testInstance = FakeRegisterAuthService();

    await tester.pumpWidget(
      MaterialApp(
        home: RegistrationScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Иван');
    await tester.enterText(find.byType(TextFormField).at(1), 'Иванов');
    await tester.enterText(find.byType(TextFormField).at(2), 'test@mail.com');
    await tester.enterText(find.byType(TextFormField).at(3), 'password123');
    await tester.enterText(find.byType(TextFormField).at(4), 'password123');

    await tester.tap(find.text('Создать аккаунт'));
    await tester.pumpAndSettle();

    expect(find.text('Необходимо согласиться с обработкой данных'), findsOneWidget);
  });

  testWidgets('Успешная регистрация — переход на MainScreen', (tester) async {
    AuthService.testInstance = FakeRegisterAuthService(registerResult: 'token');

    await tester.pumpWidget(
      MaterialApp(
        home: RegistrationScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Иван');
    await tester.enterText(find.byType(TextFormField).at(1), 'Иванов');
    await tester.enterText(find.byType(TextFormField).at(2), 'new@mail.com');
    await tester.enterText(find.byType(TextFormField).at(3), 'password123');
    await tester.enterText(find.byType(TextFormField).at(4), 'password123');

    await tester.tap(find.text('Выберите пол'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Мужской'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Создать аккаунт'));
    await tester.pumpAndSettle();

    expect(find.byType(MainScreen), findsOneWidget);
  });
}
