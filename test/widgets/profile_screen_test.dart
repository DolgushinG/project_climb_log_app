import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/ProfileScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({'token': 'test-token'});
  });

  testWidgets('ProfileScreen builds and shows initial content', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(),
      ),
    );

    await tester.pump();

    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  testWidgets('ProfileScreen settles after load attempt', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.byType(ProfileScreen), findsOneWidget);
  });
}
