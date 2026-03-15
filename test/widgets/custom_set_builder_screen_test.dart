import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/Screens/CustomSetBuilderScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('CustomSetBuilderScreen shows title', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CustomSetBuilderScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Собственный сет упражнений'), findsOneWidget);
  });

  testWidgets('CustomSetBuilderScreen shows loading then catalog when no token', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CustomSetBuilderScreen(),
      ),
    );

    // Сначала loading (getExercises возвращает [] без токена)
    expect(find.text('Загрузка...'), findsOneWidget);

    await tester.pumpAndSettle();

    // После загрузки — пустой каталог, но UI отображается
    expect(find.text('Каталог'), findsOneWidget);
    expect(find.text('Мой сет (0)'), findsOneWidget);
  });

  testWidgets('CustomSetBuilderScreen has filters button', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CustomSetBuilderScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Фильтры'), findsOneWidget);
  });

  testWidgets('CustomSetBuilderScreen has search field', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CustomSetBuilderScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('CustomSetBuilderScreen tap configure without exercises shows SnackBar', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CustomSetBuilderScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Кнопка «Настроить сет (0)» — видна
    expect(find.text('Настроить сет (0)'), findsOneWidget);

    // При нажатии без упражнений — SnackBar
    await tester.tap(find.text('Настроить сет (0)'));
    await tester.pumpAndSettle();

    expect(find.text('Добавьте хотя бы одно упражнение'), findsOneWidget);
  });

  testWidgets('CustomSetBuilderScreen with initialSet shows selected count', (tester) async {
    // С пустым initialSet (нет упражнений в каталоге без API)
    await tester.pumpWidget(
      const MaterialApp(
        home: CustomSetBuilderScreen(
          initialSet: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Мой сет (0)'), findsOneWidget);
  });
}
