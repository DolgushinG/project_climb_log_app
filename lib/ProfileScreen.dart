import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'main.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Данные профиля
  String avatar = 'https://ui-avatars.com/api/?background=0D8ABC&color=fff';
  String firstName = 'First Name';
  String lastName = 'Last Name';
  String city = 'City';
  String rank = 'Rank';
  String birthYear = 'Birth Year';
  bool isLoading = true;

  // Загрузка данных профиля с сервера
  Future<void> fetchProfileData() async {
    final String? token = await getToken(); // Используем await для получения токена

    final response = await http.get(
      Uri.parse(DOMAIN + 'api/profile'),
      headers: {
        'Authorization': 'Bearer $token', // Используем токен в запросе
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        avatar = data['avatar'] ?? 'https://ui-avatars.com/api/?background=0D8ABC&color=fff';
        firstName = data['firstname'] ?? 'First Name';
        lastName = data['lastname'] ?? 'Last Name';
        city = data['city'] ?? 'City';
        rank = data['sport_category'] ?? 'Rank';
        birthYear = data['birthday']?.toString() ?? 'Birth Year';
        isLoading = false;
      });
    } else {
      print('Failed to load profile data');
      setState(() {
        isLoading = false;
      });
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
              label: 'City',
              value: city,
            ),
            ProfileInfoCard(
              label: 'Rank',
              value: rank,
            ),
            ProfileInfoCard(
              label: 'Birth Year',
              value: birthYear,
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
