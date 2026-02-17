import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import '../models/UserProfile.dart';
import 'cache_service.dart';
import '../utils/network_error_helper.dart';
import '../utils/session_error_helper.dart';

class ProfileService {
  final String baseUrl;

  ProfileService({required this.baseUrl});

  // Получить данные профиля (с кэшем; при ошибке сети — исключение с понятным текстом)
  Future<UserProfile?> getProfile(BuildContext context) async {
    final String? token = await getToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        await CacheService.set(
          CacheService.keyProfile,
          response.body,
          ttl: CacheService.ttlProfile,
        );
        return UserProfile.fromJson(jsonDecode(response.body));
      }
      if (response.statusCode == 401) {
        if (context.mounted) redirectToLoginOnSessionError(context);
        return null;
      }
      throw Exception('Ошибка загрузки профиля (${response.statusCode})');
    } catch (e) {
      final cached = await CacheService.getStale(CacheService.keyProfile);
      if (cached != null) {
        try {
          return UserProfile.fromJson(jsonDecode(cached) as Map<String, dynamic>);
        } catch (_) {}
      }
      throw Exception(networkErrorMessage(e, 'Не удалось загрузить профиль'));
    }
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

  /// Получить аналитику профиля (полуфиналы, финалы, стабильность, призы, прогресс)
  Future<Map<String, dynamic>?> getProfileAnalytics(BuildContext context) async {
    final String? token = await getToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/profile/analytics'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 401) {
        if (context.mounted) redirectToLoginOnSessionError(context);
        return null;
      }
      throw Exception('Ошибка загрузки аналитики');
    } catch (e) {
      throw Exception(networkErrorMessage(e, 'Не удалось загрузить аналитику'));
    }
  }
}
