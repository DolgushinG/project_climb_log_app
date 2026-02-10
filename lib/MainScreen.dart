import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'CompetitionScreen.dart';
import 'ProfileScreen.dart';
import 'Screens/ParticipationHistoryScreen.dart';
import 'services/connectivity_service.dart';
import 'services/cache_service.dart';
import 'widgets/top_notification_banner.dart';



class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  bool _isOnline = true;
  bool _offlineBannerDismissed = false;
  /// Показывать баннер «нет интернета» только когда офлайн и в кэше нет данных.
  bool _offlineWithNoCache = false;
  StreamSubscription<bool>? _connectivitySubscription;

  static final List<Widget> _screens = <Widget>[
    CompetitionsScreen(),
    const ParticipationHistoryScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    if (!mounted) return;
    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<bool> _onWillPop() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выйти из приложения?'),
        content: const Text(
          'Вы уверены, что хотите выйти из приложения?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    return shouldExit == true;
  }

  @override
  void initState() {
    super.initState();
    final conn = ConnectivityService();
    _isOnline = conn.isOnline;
    if (!_isOnline) {
      _checkOfflineCache();
    }
    _connectivitySubscription = conn.isOnlineStream.listen((online) async {
      if (!mounted) return;
      setState(() {
        _isOnline = online;
        if (online) {
          _offlineBannerDismissed = false;
          _offlineWithNoCache = false;
        }
      });
      if (!online) await _checkOfflineCache();
    });
  }

  Future<void> _checkOfflineCache() async {
    final hasCache = await CacheService.hasAnyData();
    if (mounted) {
      setState(() => _offlineWithNoCache = !hasCache);
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildNavIcon(IconData icon, bool isActive) {
    final color = isActive ? Theme.of(context).colorScheme.primary : Colors.grey;
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Icon(icon, color: color),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          height: isActive ? 4 : 0,
          width: isActive ? 18 : 0,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseNavColor = const Color(0xFF020617).withOpacity(0.96);
    final accentNavColor = theme.colorScheme.primary.withOpacity(0.32);

    // Смещаем акцент градиента в сторону активной вкладки
    final List<Color> navGradientColors;
    switch (_selectedIndex) {
      case 0: // Соревнования – акцент слева
        navGradientColors = [
          accentNavColor,
          baseNavColor,
          baseNavColor,
        ];
        break;
      case 1: // История – акцент по центру
        navGradientColors = [
          baseNavColor,
          accentNavColor,
          baseNavColor,
        ];
        break;
      case 2: // Профиль – акцент справа
      default:
        navGradientColors = [
          baseNavColor,
          baseNavColor,
          accentNavColor,
        ];
        break;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final exit = await _onWillPop();
        if (exit && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            PageView(
          controller: _pageController,
          physics: const BouncingScrollPhysics(),
          onPageChanged: (index) {
            if (!mounted) return;
            setState(() => _selectedIndex = index);
          },
              children: _screens,
            ),
            if (!_isOnline && _offlineWithNoCache && !_offlineBannerDismissed)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: TopNotificationBanner.offline(
                  message: 'Нет подключения к интернету',
                  onClose: () {
                    if (mounted) setState(() => _offlineBannerDismissed = true);
                  },
                ),
              ),
          ],
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: navGradientColors,
                ),
              ),
              child: BottomNavigationBar(
                backgroundColor: Colors.transparent,
                items: <BottomNavigationBarItem>[
                  BottomNavigationBarItem(
                    icon: _buildNavIcon(Icons.emoji_events_outlined, false),
                    activeIcon: _buildNavIcon(Icons.emoji_events_rounded, true),
                    label: 'Соревнования',
                  ),
                  BottomNavigationBarItem(
                    icon: _buildNavIcon(Icons.history, false),
                    activeIcon: _buildNavIcon(Icons.history_rounded, true),
                    label: 'История',
                  ),
                  BottomNavigationBarItem(
                    icon: _buildNavIcon(Icons.person_outline_rounded, false),
                    activeIcon: _buildNavIcon(Icons.person_rounded, true),
                    label: 'Профиль',
                  ),
                ],
                currentIndex: _selectedIndex,
                onTap: _onItemTapped,
                selectedFontSize: 12,
                unselectedFontSize: 11,
                showUnselectedLabels: false,
                type: BottomNavigationBarType.fixed,
              ),
            ),
          ),
        ),
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
