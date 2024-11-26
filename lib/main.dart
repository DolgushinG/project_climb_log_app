import 'package:flutter/material.dart';
import 'package:login_app/MainScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'Screens/RegisterScreen.dart';
import 'login.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Инициализация Flutter
  runApp(MyApp());
}

// const DOMAIN = "http://127.0.0.1:8000";
const DOMAIN = "https://climbing-events.ru";
// const DOMAIN = "https://8d34-179-43-151-14.ngrok-free.app";
// const DOMAIN = "https://stage-dev.climbing-events.ru";

Future<void> saveToken(String token) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('token', token);  // Ждем, пока токен будет сохранен
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
      supportedLocales: const [
        Locale('en'), // Английский
        Locale('ru'), // Русский
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      locale: const Locale('ru'),
      home: TokenChecker(), // Передаем управление проверке токена
    );
  }
}

class TokenChecker extends StatefulWidget {
  @override
  _TokenCheckerState createState() => _TokenCheckerState();
}

class _TokenCheckerState extends State<TokenChecker> {
  String? token;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    checkToken(); // Загружаем токен при старте
  }

  Future<void> checkToken() async {
    final storedToken = await getToken();
    setState(() {
      token = storedToken;
      isLoading = false; // Отключаем индикатор загрузки
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      // Показываем индикатор загрузки
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    print(token);
    // После загрузки токена выбираем страницу
    return token == null ? StartPage() : MainScreen();
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
            image: AssetImage('assets/poster.png'), // Путь к картинке в папке assets
            fit: BoxFit.cover, // Заставляем изображение покрывать весь экран
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: screenHeight * 0.15, // Поднимаем текст выше середины экрана
              left: screenWidth * 0.13, // Центрируем по горизонтали
              child: Text(
                'ДОБРО ПОЖАЛОВАТЬ В СЕРВИС',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.28,
                ),
              ),
            ),
            // Текст "CLIMBING EVENTS."
            Positioned(
              top: screenHeight * 0.2, // Поднимаем текст выше середины экрана
              left: screenWidth * 0.11, // Центрируем по горизонтали
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
              bottom: screenHeight * 0.23, // Располагаем кнопку ближе к нижней части экрана
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
                      colors: [Colors.blue, Color(0xFF1D67DE)],
                    ),
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(width: 1, color: Color(0xFF44E7FB)),
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
              bottom: screenHeight * 0.13, // Располагаем чуть ниже кнопки "Зарегистрироваться"
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
                      colors: [Colors.blue, Color(0xFF1D67DE)],
                    ),
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(width: 1, color: Color(0xFF44E7FB)),
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

