import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;


class RegisterScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Регистрация')),
      body: Center(child: Text('Экран регистрации')),
    );
  }
}