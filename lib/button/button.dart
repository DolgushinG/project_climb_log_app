import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:login_app/main.dart';

class MyButtonScreen extends StatefulWidget {
  @override
  _MyButtonScreenState createState() => _MyButtonScreenState();
}

class _MyButtonScreenState extends State<MyButtonScreen> {
  bool _isButtonDisabled = false;  // Переменная для отслеживания состояния кнопки
  String _buttonText = 'Принять участие';  // Текст кнопки

  // Функция для выполнения HTTP-запроса
  Future<void> _makeRequest() async {
    setState(() {
      _isButtonDisabled = true;
      // Блокируем кнопку
      _buttonText = 'Загрузка...';  // Меняем текст кнопки
    });

    try {
      final response = await http.get(Uri.parse('${DOMAIN}api/event/24/take/part'));
      final responseData = json.decode(response.body);
      print(response.body);
      final message = responseData['message'];
      if (response.statusCode == 200) {

        setState(() {
          _buttonText = message;  // Изменяем текст кнопки
        });
      } else {
        // Ошибка сервера
        setState(() {
          _buttonText = message;  // Текст при ошибке
        });
      }
    } catch (e) {
      print(e);
      setState(() {
        _buttonText = 'Ошибка сети';  // Текст при ошибке сети
      });
    } finally {
      // Разблокируем кнопку после выполнения запроса
      Future.delayed(Duration(seconds: 2), () {
        setState(() {
          _isButtonDisabled = false;
          _buttonText = "Принять участие";
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue, // Цвет кнопки (синий)
        disabledForegroundColor: Colors.blue.withOpacity(0.38), disabledBackgroundColor: Colors.blue.withOpacity(0.12), // Цвет кнопки в заблокированном состоянии (синий)
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: EdgeInsets.symmetric(vertical: 12),
      ),
      onPressed: _isButtonDisabled ? null : _makeRequest, // Блокировка кнопки, если она заблокирована
      // Блокировка кнопки, если она заблокирована
      child:
      Text(
        _buttonText, // Текст кнопки
        style: const TextStyle(
          color: Colors.white, // Цвет текста (белый)
          fontSize: 12.0, // Размер шрифта
        ),
        textAlign: TextAlign.center, // Центрируем текст внутри кнопки
      ),

    );
  }
}
