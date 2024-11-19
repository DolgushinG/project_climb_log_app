import 'package:flutter/material.dart';
import 'package:login_app/MainScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'Screens/RegisterScreen.dart';
import 'login.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final token = await getToken();
  MyApp(token: token);
  runApp(MyApp());
}

// const DOMAIN = "http://127.0.0.1:8000";
const DOMAIN = "https://climbing-events.ru";
// const DOMAIN = "https://stage-dev.climbing-events.ru";

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
  final String? token;

  MyApp({this.token});

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
      home: token == null ? StartPage() : MainScreen(), // Начальная страница
    );
  }
}

class StartPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Получаем размеры экрана устройства
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        // Фон на весь экран
        width: screenWidth,
        height: screenHeight,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.png'), // Путь к картинке в папке assets
            fit: BoxFit.cover, // Заставляем изображение покрывать весь экран
          ),
        ),
        child: Stack(
          children: [
            // Текст "CLIMBING EVENTS."
            Positioned(
              top: screenHeight * 0.2, // Поднимаем текст выше середины экрана
              left: screenWidth * 0.15, // Центрируем по горизонтали
              child: Text(
                'CLIMBING EVENTS.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.28,
                ),
              ),
            ),
            // Кнопка "Зарегистрироваться"
            Positioned(
              bottom: screenHeight * 0.15, // Располагаем кнопку ближе к нижней части экрана
              left: screenWidth * 0.15, // Центрируем кнопку
              child: GestureDetector(
                onTap: () {
                  // Переход на экран регистрации
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => RegisterScreen()),
                  );
                },
                child: Container(
                  width: screenWidth * 0.7,
                  height: 48,
                  decoration: ShapeDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment(0.00, -1.00),
                      end: Alignment(0, 1),
                      colors: [Colors.blue, Color(0xFF43E6FA)],
                    ),
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(width: 1, color: Color(0xFF1D67DE)),
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'Зарегистрироваться',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.64,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Кнопка "Вход"
            Positioned(
              bottom: screenHeight * 0.05, // Располагаем чуть ниже кнопки "Зарегистрироваться"
              left: screenWidth * 0.15,
              child: GestureDetector(
                onTap: () {
                  // Переход на экран входа
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()), // Переход на LoginScreen
                  );
                },
                child: Container(
                  width: screenWidth * 0.7,
                  height: 48,
                  decoration: ShapeDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment(0.00, -1.00),
                      end: Alignment(0, 1),
                      colors: [Colors.blue, Color(0xFF43E6FA)],
                    ),
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(width: 1, color: Color(0xFF1D67DE)),
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'Вход',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.64,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

