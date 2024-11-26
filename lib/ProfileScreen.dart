import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:login_app/Screens/AuthSettingScreen.dart';
import 'dart:convert';

import 'Screens/AnalyticsScreen.dart';
import 'Screens/FranceResultScreen.dart';
import 'Screens/ProfileEditScreen.dart';
import 'Screens/ChangePasswordScreen.dart';
import 'login.dart';
import 'main.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String avatar = 'https://ui-avatars.com/api/?background=0D8ABC&color=fff';
  String firstName = 'Имя';
  String lastName = 'Фамилия';
  String city = 'Город';
  String rank = 'Разряд';
  String birthYear = 'День рождения';
  bool isLoading = true;

  // Загрузка данных профиля с сервера
  Future<void> fetchProfileData() async {
    final String? token = await getToken(); // Используем await для получения токена

    final response = await http.get(
      Uri.parse(DOMAIN + '/api/profile'),
      headers: {
        'Authorization': 'Bearer $token', // Используем токен в запросе
        'Content-Type': 'application/json',
      },
    );
    print(DOMAIN + '/api/profile');
    print(response.body);
    print(token);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (mounted) {
        setState(() {
          avatar = data['avatar'] ??
              'https://ui-avatars.com/api/?background=0D8ABC&color=fff';
          firstName = data['firstname'] ?? '';
          lastName = data['lastname'] ?? '';
          city = data['city'] ?? '';
          rank = data['sport_category'] ?? '';
          birthYear = data['birthday']?.toString() ?? '';
          isLoading = false;
        });
      }
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
      print('Failed to load profile data');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    fetchProfileData();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text('Профиль'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: NetworkImage(avatar),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$firstName $lastName',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text('Город: $city'),
                        Text('Разряд: $rank'),
                        Text('День рождения: $birthYear'),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Column(
                children: [
                  ProfileActionCard(
                    title: 'Изменить данные',
                    icon: Icons.edit,
                    onTap:  () async {
                      final updatedProfile = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfileEditScreen(),
                        ),
                      );
                      if (updatedProfile != null) {
                        // Обновляем данные после редактирования
                        setState(() {
                          firstName = updatedProfile.firstName;
                          lastName = updatedProfile.lastName;
                          city = updatedProfile.city;
                          rank = updatedProfile.sportCategory;
                          birthYear = updatedProfile.birthday;
                        });
                      }
                    },
                  ),
                  ProfileActionCard(
                    title: 'Изменение пароля',
                    icon: Icons.lock,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChangePasswordScreen()
                        ),
                      );
                    },
                  ),
                  ProfileActionCard(
                    title: 'Настройка',
                    icon: Icons.settings,
                    onTap: () {
                      // Navigator.push(
                      //   context,
                      //   MaterialPageRoute(
                      //       builder: (context) => ChangePasswordScreen()
                      //   ),
                      // );
                    },
                  ),

                  ProfileActionCard(
                    title: 'История участия',
                    icon: Icons.history,
                    onTap: () {
                      // Логика для истории участия
                    },
                  ),
                  ProfileActionCard(
                    title: 'Статистика',
                    icon: Icons.bar_chart,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => AnalyticsScreen(
                              analytics: {
                                'labels': ['Jan', 'Feb', 'Mar', 'Apr', 'May'],
                                'flashes': [10, 20, 30, 25, 40],
                                'redpoints': [5, 15, 10, 20, 25],
                              },
                              analyticsProgress: {
                                'labels': ['Week 1', 'Week 2', 'Week 3', 'Week 4'],
                                'flashes': [12, 18, 25, 30],
                                'redpoints': [7, 14, 18, 22],
                              },
                            ) // Заглушка для будущих экранов
                        ),
                      );

                    },
                  ),
                  ProfileActionCard(
                    title: 'Авторизация',
                    icon: Icons.login,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => AuthSettingScreen()
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const ProfileActionCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: ListTile(
          leading: Icon(icon, color: Colors.blueAccent),
          title: Text(
            title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

