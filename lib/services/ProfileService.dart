import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../login.dart';
import '../main.dart';
import '../models/UserProfile.dart';

class ProfileService {
  final String baseUrl;

  ProfileService({required this.baseUrl});

  // Получить данные профиля
  Future<UserProfile?> getProfile(context) async {
    final String? token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/api/profile'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return UserProfile.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 401 || response.statusCode == 419) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LoginScreen(),
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сессии')),
      );
    } else {
      throw Exception('Failed to load profile');
    }
    return null;
  }

  // Отправить изменения профиля
  Future updateProfile(UserProfile profile) async {
    final String? token = await getToken();
     // Ваш токен авторизации
    final response = await http.post(
      Uri.parse('$baseUrl/api/profile/edit'),
      body: jsonEncode(profile.toJson()),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    return response;
  }
}
