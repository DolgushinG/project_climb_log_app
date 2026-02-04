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

//const DOMAIN = "https://climbing-events.ru.tuna.am";
const DOMAIN = "https://climbing-events.ru";

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
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2563EB),
        brightness: Brightness.dark,
      ),
    );

    return MaterialApp(
      title: 'Climbing App',
      theme: baseTheme.copyWith(
        scaffoldBackgroundColor: const Color(0xFF050816),
        dividerColor: Colors.transparent,
        textTheme: baseTheme.textTheme.copyWith(
          titleLarge: baseTheme.textTheme.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: baseTheme.textTheme.bodyLarge?.copyWith(fontSize: 14),
          bodyMedium: baseTheme.textTheme.bodyMedium?.copyWith(fontSize: 13),
          labelLarge: baseTheme.textTheme.labelLarge?.copyWith(fontSize: 12),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: baseTheme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        tabBarTheme: baseTheme.tabBarTheme.copyWith(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          dividerColor: Colors.transparent,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: Colors.white.withOpacity(0.12),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
        ),
        snackBarTheme: baseTheme.snackBarTheme.copyWith(
          contentTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        dialogTheme: DialogTheme(
          backgroundColor: const Color(0xFF0B1220),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titleTextStyle: baseTheme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
          ),
          contentTextStyle: baseTheme.textTheme.bodyMedium?.copyWith(
            color: Colors.white70,
          ),
        ),
        bottomNavigationBarTheme: baseTheme.bottomNavigationBarTheme.copyWith(
          backgroundColor: const Color(0xFF020617),
          selectedItemColor: baseTheme.colorScheme.primary,
          unselectedItemColor: Colors.grey,
          selectedIconTheme: const IconThemeData(size: 26),
          unselectedIconTheme: const IconThemeData(size: 22),
          showUnselectedLabels: false,
          type: BottomNavigationBarType.fixed,
        ),
        cardTheme: baseTheme.cardTheme.copyWith(
          color: const Color(0xFF0B1220),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 3,
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
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF020617),
                Color(0xFF0B1120),
                Color(0xFF1D4ED8),
              ],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Полупрозрачный постер на фоне
              Opacity(
                opacity: 0.12,
                child: Image.asset(
                  'assets/poster.png',
                  fit: BoxFit.cover,
                ),
              ),
              // Основной лоадер
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Climbing Events',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 24),
                    _ClimbingLoader(),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
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
        width: screenWidth,
        height: screenHeight,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF020617),
              Color(0xFF0F172A),
              Color(0xFF1D4ED8),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                const Text(
                  'Добро пожаловать',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Climbing Events',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Регистрация и результат соревнований по скалолазанию в одном месте.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Image.asset(
                              'assets/poster.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.1),
                                    Colors.black.withOpacity(0.6),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RegistrationScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Зарегистрироваться',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LoginScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Войти',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClimbingLoader extends StatefulWidget {
  const _ClimbingLoader();

  @override
  State<_ClimbingLoader> createState() => _ClimbingLoaderState();
}

class _ClimbingLoaderState extends State<_ClimbingLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.9, end: 1.1)
          .chain(CurveTween(curve: Curves.easeInOut))
          .animate(_controller),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const SweepGradient(
            colors: [
              Color(0xFF38BDF8),
              Color(0xFF6366F1),
              Color(0xFF22C55E),
              Color(0xFF38BDF8),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.4),
              blurRadius: 14,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF020617),
            ),
            child: const Icon(
              Icons.hiking,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

