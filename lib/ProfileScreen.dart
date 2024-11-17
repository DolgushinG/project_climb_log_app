import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'Screens/ProfileEditScreen.dart';
import 'login.dart';
import 'main.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Данные профиля
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
        title: Text('Profile'),
        backgroundColor: Colors.blueAccent,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.blueAccent,
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: NetworkImage(avatar),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '$firstName $lastName',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            ProfileInfoCard(
              label: 'Город',
              value: city,
            ),
            ProfileInfoCard(
              label: 'Разряд',
              value: rank,
            ),
            ProfileInfoCard(
              label: 'День рождения',
              value: birthYear,
            ),
            ElevatedButton(
              onPressed: () async {
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
              child: Text('Редактировать'),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileInfoCard extends StatelessWidget {
  final String label;
  final String value;

  const ProfileInfoCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: ListTile(
          title: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          subtitle: Text(
            value,
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
