import 'package:flutter/material.dart';

import 'CompetitionScreen.dart';
import 'ProfileScreen.dart';
import 'Screens/AnalyticsScreen.dart';
import 'Screens/ProfileEditScreen.dart';
import 'Screens/SettingScreen.dart';


class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _screens = <Widget>[
    ProfileScreen(),
    CompetitionsScreen(),
    AnalyticsScreen(
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
    ), // Заглушка для будущих экранов
    ChangePasswordScreen()// Заглушка для будущих экранов
  ];

  void _onItemTapped(int index) {
    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Профиль'),
          BottomNavigationBarItem(icon: Icon(Icons.emoji_events), label: 'Соревнования'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Аналитика'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Настройка'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey, // Цвет неактивных иконок
        onTap: _onItemTapped,
      ),
    );
  }
}



// Заглушка для других экранов
class PlaceholderWidget extends StatelessWidget {
  final String title;

  PlaceholderWidget(this.title);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        title,
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }
}
