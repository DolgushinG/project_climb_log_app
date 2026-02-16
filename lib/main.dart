import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login_app/MainScreen.dart';
import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/services/RustorePushService.dart';
import 'package:login_app/services/cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'login.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustorePushService.init();
  runApp(MyApp());
}

/// Базовые домены для окружений
const String _prodDomain = "https://climbing-events.ru";
const String _devDomain = "https://climbing-events.ru.tuna.am";

/// Для релиза — прод, для дебага/локально — dev
const String DOMAIN = kReleaseMode ? _prodDomain : _devDomain;

Future<void> saveToken(String token) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('token', token);  // Ждем, пока токен будет сохранен
}

Future<String?> getToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('token');
}

Future<void> clearToken() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('token');
  await CacheService.remove(CacheService.keyProfile);
}

/// Ключ: пользователь нажал «Не сейчас» на предложении добавить Passkey после входа.
const String _keyPasskeyPromptDeclined = 'passkey_prompt_declined';

Future<bool> wasPasskeyPromptDeclined() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_keyPasskeyPromptDeclined) ?? false;
}

Future<void> setPasskeyPromptDeclined(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_keyPasskeyPromptDeclined, value);
}


class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.dark().copyWith(
        primary: AppColors.mutedGold,
        surface: AppColors.surfaceDark,
      ),
    );

    return MaterialApp(
      title: 'Climbing App',
      theme: baseTheme.copyWith(
        scaffoldBackgroundColor: AppColors.anthracite,
        dividerColor: Colors.transparent,
        textTheme: GoogleFonts.unboundedTextTheme(baseTheme.textTheme).copyWith(
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
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
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
            color: AppColors.mutedGold.withOpacity(0.25),
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
          backgroundColor: AppColors.cardDark,
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
          backgroundColor: AppColors.surfaceDark,
          selectedItemColor: AppColors.mutedGold,
          unselectedItemColor: Colors.grey,
          selectedIconTheme: const IconThemeData(size: 26),
          unselectedIconTheme: const IconThemeData(size: 22),
          showUnselectedLabels: false,
          type: BottomNavigationBarType.fixed,
        ),
        cardTheme: baseTheme.cardTheme.copyWith(
          color: AppColors.cardDark,
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
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.anthracite,
                AppColors.surfaceDark,
                AppColors.mutedGold.withOpacity(0.3),
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
    // После загрузки токена: без токена — гостевой режим (сразу в приложение), с токеном — полный MainScreen
    return MainScreen(isGuest: token == null);
  }
}

class StartPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/poster.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                Text(
                  'Добро пожаловать',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'CLIMBING EVENTS.',
                  style: GoogleFonts.unbounded(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Регистрация и результат соревнований по скалолазанию в одном месте.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LoginScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.mutedGold,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Center(
                        child: Text(
                          'Продолжить',
                          style: GoogleFonts.unbounded(
                            color: AppColors.anthracite,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
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
            gradient: SweepGradient(
            colors: [
              AppColors.mutedGold.withOpacity(0.8),
              AppColors.graphite,
              AppColors.mutedGold.withOpacity(0.6),
              AppColors.mutedGold.withOpacity(0.8),
            ],
          ),
            boxShadow: [
            BoxShadow(
              color: AppColors.mutedGold.withOpacity(0.3),
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
              color: AppColors.anthracite,
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

