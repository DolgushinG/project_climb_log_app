import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:login_app/Screens/AuthSettingScreen.dart';
import 'dart:convert';

import 'Screens/AnalyticsScreen.dart';
import 'Screens/FranceResultScreen.dart';
import 'Screens/ProfileEditScreen.dart';
import 'Screens/RelatedUsersScreen.dart';
import 'Screens/ChangePasswordScreen.dart';
import 'Screens/ParticipationHistoryScreen.dart';
import 'Screens/AboutScreen.dart';
import 'login.dart';
import 'main.dart';
import 'utils/display_helper.dart';
import 'services/cache_service.dart';
import 'utils/network_error_helper.dart';
import 'widgets/top_notification_banner.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String avatar = '';
  String firstName = 'Имя';
  String lastName = 'Фамилия';
  String city = 'Город';
  String rank = 'Разряд';
  String birthYear = 'День рождения';
  bool isLoading = true;
  String? _loadError;

  void _applyProfileData(Map<String, dynamic> data) {
    if (!mounted) return;
    setState(() {
      avatar = data['avatar']?.toString() ?? '';
      firstName = data['firstname']?.toString() ?? 'Имя';
      lastName = data['lastname']?.toString() ?? 'Фамилия';
      city = data['city']?.toString() ?? 'Город';
      rank = data['sport_category']?.toString() ?? 'Разряд';
      birthYear = data['birthday']?.toString() ?? 'День рождения';
      isLoading = false;
      _loadError = null;
    });
  }

  Future<void> fetchProfileData() async {
    final cached = await CacheService.getStale(CacheService.keyProfile);
    if (cached != null && mounted) {
      try {
        final data = json.decode(cached) as Map<String, dynamic>;
        _applyProfileData(data);
      } catch (_) {}
    }

    final String? token = await getToken();
    try {
      final response = await http.get(
        Uri.parse(DOMAIN + '/api/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        await CacheService.set(
          CacheService.keyProfile,
          response.body,
          ttl: CacheService.ttlProfile,
        );
        if (mounted) _applyProfileData(data);
        return;
      }
      if (response.statusCode == 401 || response.statusCode == 419) {
        if (mounted) {
          setState(() => isLoading = false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LoginScreen(),
            ),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ошибка сессии')),
          );
        }
        return;
      }
      if (mounted) {
        setState(() {
          isLoading = false;
          if (avatar.isEmpty && firstName == 'Имя') _loadError = 'Не удалось загрузить данные';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          if (avatar.isEmpty && firstName == 'Имя') {
            _loadError = networkErrorMessage(e, 'Не удалось загрузить данные');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_loadError ?? '')),
            );
          }
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
        automaticallyImplyLeading: false,
        title: const Text('Профиль'),
      ),
      body: isLoading && avatar.isEmpty && firstName == 'Имя'
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (_loadError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  child: TopNotificationBanner(
                    message: _loadError!,
                    icon: Icons.wifi_off_rounded,
                    backgroundColor: const Color(0xFF78350F),
                    iconColor: Colors.orange.shade200,
                    textColor: Colors.white,
                    useSafeArea: false,
                    fullWidth: true,
                    showCloseButton: true,
                    onClose: () => setState(() => _loadError = null),
                    trailing: TextButton(
                      onPressed: () {
                        setState(() => _loadError = null);
                        fetchProfileData();
                      },
                      child: const Text('Повторить'),
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.blueGrey.shade700,
                    backgroundImage:
                        avatar.isNotEmpty ? NetworkImage(avatar) : null,
                    child: avatar.isNotEmpty
                        ? null
                        : Text(
                            (firstName.isNotEmpty ? firstName[0] : '?'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
                        Text('Город: ${displayValue(city)}'),
                        Text('Разряд: ${displayValue(rank)}'),
                        Text('День рождения: ${displayValue(birthYear)}'),
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
                    title: 'Заявленные',
                    icon: Icons.people,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RelatedUsersScreen(),
                        ),
                      );
                    },
                  ),
                  ProfileActionCard(
                    title: 'История участия',
                    icon: Icons.history,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ParticipationHistoryScreen(),
                        ),
                      );
                    },
                  ),
                  ProfileActionCard(
                    title: 'Статистика',
                    icon: Icons.bar_chart,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AnalyticsScreen(),
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
                  ProfileActionCard(
                    title: 'О приложении',
                    icon: Icons.info_outline,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AboutScreen(),
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

