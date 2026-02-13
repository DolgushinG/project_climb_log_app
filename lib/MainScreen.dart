import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'CompetitionScreen.dart';
import 'theme/app_theme.dart';
import 'ProfileScreen.dart';
import 'Screens/AuthSettingScreen.dart';
import 'Screens/ClimbingLogScreen.dart';
import 'Screens/GymsListScreen.dart';
import 'Screens/RatingScreen.dart';
import 'Screens/RegisterScreen.dart';
import 'login.dart';
import 'main.dart';
import 'services/connectivity_service.dart';
import 'services/cache_service.dart';
import 'widgets/top_notification_banner.dart';

class MainScreen extends StatefulWidget {
  /// Показать после входа предложение добавить Passkey (bottom sheet).
  final bool showPasskeyPrompt;
  /// Гостевой режим: только соревнования + вкладка «Войти», без истории и профиля.
  final bool isGuest;

  const MainScreen({super.key, this.showPasskeyPrompt = false, this.isGuest = false});

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
  late final List<Widget> _screens;

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

  List<Widget> _buildScreens() {
    return widget.isGuest
        ? [
            ClimbingLogScreen(key: const ValueKey('climbing_log'), isGuest: true, isTabVisible: _selectedIndex == 0),
            const RatingScreen(),
            CompetitionsScreen(isGuest: true),
            const GymsListScreen(),
            const _GuestLoginScreen(),
          ]
        : [
            ClimbingLogScreen(key: const ValueKey('climbing_log'), isGuest: false, isTabVisible: _selectedIndex == 0),
            const RatingScreen(),
            CompetitionsScreen(),
            const GymsListScreen(),
            ProfileScreen(),
          ];
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
    if (widget.showPasskeyPrompt) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowPasskeyPrompt());
    }
  }

  Future<void> _maybeShowPasskeyPrompt() async {
    if (!mounted) return;
    final declined = await wasPasskeyPromptDeclined();
    if (!declined && mounted) {
      _showPasskeyPromptSheet();
    }
  }

  void _showPasskeyPromptSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.fingerprint, size: 48, color: AppColors.mutedGold),
              const SizedBox(height: 16),
              Text(
                'Вход по Face ID / Touch ID',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Добавьте Passkey, чтобы входить по отпечатку или лицу без пароля.',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => AuthSettingScreen()),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Добавить Passkey'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () async {
                  await setPasskeyPromptDeclined(true);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: const Text('Не сейчас'),
              ),
            ],
          ),
        ),
      ),
    );
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

  Widget _buildNavItem({
    required IconData icon,
    required IconData iconActive,
    required String label,
    required int index,
  }) {
    final isActive = _selectedIndex == index;
    final color = isActive ? AppColors.mutedGold : Colors.white.withOpacity(0.4);
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onItemTapped(index),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isActive ? iconActive : icon,
                  size: 22,
                  color: color,
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: GoogleFonts.unbounded(
                      fontSize: 9,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final tabCount = widget.isGuest ? 4 : 5;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.graphite.withOpacity(0.5), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              _buildNavItem(icon: Icons.route_outlined, iconActive: Icons.route_rounded, label: 'Тренировки', index: 0),
              _buildNavItem(icon: Icons.leaderboard_outlined, iconActive: Icons.leaderboard_rounded, label: 'Рейтинг', index: 1),
              _buildNavItem(icon: Icons.emoji_events_outlined, iconActive: Icons.emoji_events_rounded, label: 'Соревнования', index: 2),
              _buildNavItem(icon: Icons.business_outlined, iconActive: Icons.business_rounded, label: 'Скалодромы', index: 3),
              if (!widget.isGuest)
                _buildNavItem(icon: Icons.person_outline_rounded, iconActive: Icons.person_rounded, label: 'Профиль', index: 4),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              children: _buildScreens(),
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
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }
}



/// Экран «Войти» для гостя: кнопки входа и регистрации.
class _GuestLoginScreen extends StatelessWidget {
  const _GuestLoginScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              Text(
                'Вход в приложение',
                style: AppTypography.sectionTitle(),
              ),
              const SizedBox(height: 8),
              Text(
                'Войдите или зарегистрируйтесь, чтобы записываться на соревнования и вносить результаты.',
                style: AppTypography.secondary(),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                  );
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Войти'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => RegistrationScreen()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Зарегистрироваться'),
              ),
              const SizedBox(height: 32),
            ],
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
