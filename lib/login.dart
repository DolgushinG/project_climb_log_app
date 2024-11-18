import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:login_app/MainScreen.dart';
import 'dart:convert';
import 'main.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}



class _LoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/background.png"),
            fit: BoxFit.cover, // растягиваем изображение на весь экран
          ),
        ),
        child: SafeArea(
          child: Center( // Центрируем форму по вертикали и горизонтали
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9, // 80% от ширины экрана
              height: MediaQuery.of(context).size.height * 0.8, // 60% от высоты экрана
              padding: EdgeInsets.symmetric(horizontal: 10), // отступы по бокам
              decoration: BoxDecoration(
                color: Colors.transparent, // Прозрачный фон для формы
                borderRadius: BorderRadius.circular(48),
              ),
              child: Stack(
                children: [
                  // Заголовок
                  Positioned(
                    left: 30,
                    top: 20,
                    child: Text(
                      'CLIMBING EVENTS.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.28,
                      ),
                    ),
                  ),

                  // Поля для ввода
                  Positioned(
                    left: 20,
                    top: 80,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.7,
                      child: Column(
                        children: [
                          // Email
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: TextFormField(
                              decoration: InputDecoration(
                                labelText: 'Email',
                                labelStyle: TextStyle(color: Colors.white),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.3),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          // Пароль
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: TextFormField(
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: 'Пароль',
                                labelStyle: TextStyle(color: Colors.white),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.3),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          // Ссылка "Забыл пароль?"
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: GestureDetector(
                                onTap: () {
                                  // Логика для восстановления пароля
                                },
                                child: Text(
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
                        ],
                      ),
                    ),
                  ),

                  // Кнопка входа
                  Positioned(
                    left: 20,
                    top: 300, // немного пониже, чтобы не перекрывать поля
                    child: GestureDetector(
                      onTap: () {
                        // Логика входа
                      },
                      child: Container(
                        width: 304,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x0043E6FA), Color(0xFF43E6FA)],
                          ),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Center(
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
                  ),

                  // Кнопки соцсетей
                  Positioned(
                    left: 41,
                    top: 370, // разместим ниже кнопки входа
                    child: Row(
                      children: [
                        SocialLoginButton(imageUrl: "https://via.placeholder.com/32x32"),
                        SizedBox(width: 14),
                        SocialLoginButton(imageUrl: "https://via.placeholder.com/40x40"),
                        SizedBox(width: 14),
                        SocialLoginButton(imageUrl: "https://via.placeholder.com/32x32"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SocialLoginButton extends StatelessWidget {
  final String imageUrl;

  const SocialLoginButton({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: NetworkImage(imageUrl),
          fit: BoxFit.contain,
        ),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1),
      ),
    );
  }
}