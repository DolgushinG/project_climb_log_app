import 'dart:convert';
import 'package:http/http.dart' as http;
import '../main.dart';
import '../models/UserProfile.dart';

class ProfileService {
  final String baseUrl;

  ProfileService({required this.baseUrl});

  // Получить данные профиля
  Future<UserProfile> getProfile() async {
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
    } else {
      throw Exception('Failed to load profile');
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
}
