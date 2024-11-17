import 'package:flutter/material.dart';
import 'package:login_app/MainScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'login.dart';

void main() {
  runApp(MyApp());
}

// const DOMAIN = "http://127.0.0.1:8000";
const DOMAIN = "http://climbing-events.ru";
// const DOMAIN = "http://stage-dev.climbing-events.ru";

Future<void> saveToken(String token) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('token', token);
}

Future<String?> getToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('token');
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Climbing App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
        ),
      ),
      // Поддерживаемые локали
      supportedLocales: const [
        Locale('en'), // Английский
        Locale('ru'), // Русский
      ],
      // Локализация для Flutter
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Устанавливаем русскую локаль по умолчанию
      locale: const Locale('ru'),
      home: LoginScreen(),
    );

  }
}
