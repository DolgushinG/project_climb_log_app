import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/Screens/SavedSetsScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('SavedSetsScreen shows title "Мои сеты"', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SavedSetsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Мои сеты'), findsOneWidget);
  });

  testWidgets('SavedSetsScreen shows loading then empty state when no sets', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SavedSetsScreen(),
      ),
    );

    // Сначала показывается loading
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    // После загрузки — пустое состояние (без токена getSets возвращает [])
    expect(find.text('Нет сохранённых сетов'), findsOneWidget);
    expect(find.text('Создайте сет и нажмите «Начать» — он сохранится автоматически'), findsOneWidget);
  });

  testWidgets('SavedSetsScreen has back button', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SavedSetsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
  });

  testWidgets('SavedSetsScreen back button pops', (tester) async {
    var popped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SavedSetsScreen()),
                );
                popped = true;
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(SavedSetsScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.byType(SavedSetsScreen), findsNothing);
    expect(popped, true);
  });
}
