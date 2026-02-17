import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../main.dart';
import '../utils/session_error_helper.dart';
import '../models/RelatedUser.dart';
import '../utils/network_error_helper.dart';

class RelatedUsersService {
  final String baseUrl;

  RelatedUsersService({required this.baseUrl});

  Future<RelatedUsersResponse> getRelatedUsers(BuildContext context) async {
    final String? token = await getToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/profile/related-users'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = data['related_users'];
        final users = list is List
            ? list
                .map((e) => e is Map ? RelatedUser.fromJson(Map<String, dynamic>.from(e)) : null)
                .whereType<RelatedUser>()
                .toList()
            : <RelatedUser>[];
        final categoriesRaw = data['sport_categories'];
        final sportCategories = categoriesRaw is List
            ? (categoriesRaw).map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList()
            : <String>[];
        return RelatedUsersResponse(users: users, sportCategories: sportCategories);
      }
      if (response.statusCode == 401 || response.statusCode == 419) {
        if (context.mounted) redirectToLoginOnSessionError(context);
        throw Exception('Ошибка авторизации');
      }
      throw Exception('Ошибка загрузки (${response.statusCode})');
    } catch (e) {
      throw Exception(networkErrorMessage(e, 'Не удалось загрузить список заявленных'));
    }
  }

  Future<bool> editRelatedUser(BuildContext context, RelatedUser user) async {
    final String? token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/api/profile/related-users/edit'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(user.toEditJson()),
    );

    if (response.statusCode == 401 || response.statusCode == 419) {
      if (context.mounted) redirectToLoginOnSessionError(context);
      return false;
    }
    if (response.statusCode == 200) return true;
    if (response.statusCode == 422) {
      final body = response.body.isNotEmpty ? jsonDecode(response.body) : null;
      final msg = body is Map ? body['message'] : null;
      String text = 'Ошибка валидации';
      if (msg is List && msg.isNotEmpty) {
        text = msg.map((e) => e.toString()).join('\n');
      } else if (msg is String) {
        text = msg;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: Colors.red));
      }
      return false;
    }
    if (response.statusCode == 403 || response.statusCode == 404) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Участник не найден или недоступен'), backgroundColor: Colors.red),
        );
      }
      return false;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: ${response.statusCode}'), backgroundColor: Colors.red),
      );
    }
    return false;
  }

  Future<bool> unlinkRelatedUser(BuildContext context, int userId) async {
    final String? token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/api/profile/related-users/unlink'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'user_id': userId}),
    );

    if (response.statusCode == 401 || response.statusCode == 419) {
      if (context.mounted) redirectToLoginOnSessionError(context);
      return false;
    }
    if (response.statusCode == 200) return true;
    if (response.statusCode == 403 || response.statusCode == 422) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось отвязать участника'), backgroundColor: Colors.red),
        );
      }
      return false;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: ${response.statusCode}'), backgroundColor: Colors.red),
      );
    }
    return false;
  }
}

class RelatedUsersResponse {
  final List<RelatedUser> users;
  final List<String> sportCategories;

  RelatedUsersResponse({required this.users, required this.sportCategories});
}
