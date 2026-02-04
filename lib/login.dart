import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:login_app/Screens/RegisterScreen.dart';
import 'dart:convert';
import 'MainScreen.dart';
import 'Screens/PasswordRecoveryScreen.dart';
import 'Screens/WebViewScreen.dart';
import 'main.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}



class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    final email = _emailController.text;
    final password = _passwordController.text;

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final response = await http.post(
        Uri.parse(DOMAIN + '/api/auth/token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final token = responseData['token'];
        saveToken(token);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MainScreen()),
        );
        // Здесь вы можете добавить навигацию на другой экран после успешного входа
      } else {
        _showError('Invalid credentials');
      }
    } catch (error) {
      _showError('Something went wrong');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/poster.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Заголовок
                Text(
                  'CLIMBING EVENTS.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.28,
                  ),
                ),
                SizedBox(height: 20), // Отступ между заголовком и формой
                // Форма
                Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  padding: EdgeInsets.all(20),
                  decoration: ShapeDecoration(
                    color: Colors.white.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Email
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: TextFormField(
                          controller: _emailController,
                          style: TextStyle(color: Colors.white), // Белый текст
                          decoration: InputDecoration(
                            labelText: 'Email',
                            labelStyle: TextStyle(color: Colors.white),
                            filled: true,
                            fillColor: Colors.transparent,
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue),
                            ),
                          ),
                        ),
                      ),
                      // Пароль
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          style: TextStyle(color: Colors.white), // Белый текст
                          decoration: InputDecoration(
                            labelText: 'Пароль',
                            labelStyle: TextStyle(color: Colors.white),
                            filled: true,
                            fillColor: Colors.transparent,
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue),
                            ),
                          ),
                        ),
                      ),
                      // Ссылка "Забыл пароль?"
                      Align(
                        alignment: Alignment.center,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) =>  PasswordRecoveryScreen()), // Переход на LoginScreen
                              );
                              // Логика для восстановления пароля
                            },
                            child: const Text(
                              'Забыл пароль?',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 40), // Отступ перед кнопкой
                      // Кнопка входа
                      GestureDetector(
                        onTap: _login,
                        child: Container(
                          width: double.infinity,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.blue, Color(0xFF43E6FA)],
                            ),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Center(
                            child: Text(
                              'Вход',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.64,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 40),
                      Align(
                        alignment: Alignment.center,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => RegistrationScreen()), // Переход на LoginScreen
                              );
                            },
                            child: const Text(
                              'Регистрация',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 32),// Отступ перед кнопками соцсетей
                      Text(
                        'Или войти с помощью',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          letterSpacing: 0.64,
                        ),
                      ),
                      SizedBox(height: 32), // Отступ перед кнопками
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SocialLoginButton(
                            imageUrl: "assets/icon-vk.png",
                            loginUrl: "$DOMAIN/auth/vkontakte/redirect", // VK
                          ),
                          SizedBox(width: 16),
                          SocialLoginButton(
                            imageUrl: "assets/icon-telegram.png",
                            loginUrl: "https://oauth.telegram.org/auth?bot_id=6378620522&origin=https://climbing-events.ru&embed=1&request_access=write&return_to=https://climbing-events.ru/auth/telegram/redirect",
                          ),

                          SizedBox(width: 16),
                          SocialLoginButton(
                            imageUrl: "assets/yandex-icon.png",
                            loginUrl: "$DOMAIN/auth/yandex/redirect", // Yandex
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
            )
          ),
        ),
      ),
    );
  }
}

class SocialLoginButton extends StatelessWidget {
  final String imageUrl;
  final String loginUrl;

  const SocialLoginButton({
    Key? key,
    required this.imageUrl,
    required this.loginUrl,
  }) : super(key: key);

  void _openWebView(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebViewScreen(url: loginUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openWebView(context),
      child: Image.asset(
        imageUrl,
        width: 50,
        height: 50,
      ),
    );
  }
}
