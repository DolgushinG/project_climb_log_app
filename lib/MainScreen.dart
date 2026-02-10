import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'CompetitionScreen.dart';
import 'ProfileScreen.dart';
import 'Screens/AuthSettingScreen.dart';
import 'Screens/ParticipationHistoryScreen.dart';
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

  @override
  void initState() {
    super.initState();
    _screens = widget.isGuest
        ? [CompetitionsScreen(isGuest: true), const _GuestLoginScreen()]
        : [CompetitionsScreen(), const ParticipationHistoryScreen(), ProfileScreen()];
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
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.fingerprint, size: 48, color: Theme.of(ctx).colorScheme.primary),
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
    final int tabCount = widget.isGuest ? 2 : 3;
    final List<Color> navGradientColors;
    if (widget.isGuest) {
      navGradientColors = _selectedIndex == 0
          ? [accentNavColor, baseNavColor]
          : [baseNavColor, accentNavColor];
    } else {
      switch (_selectedIndex) {
        case 0:
          navGradientColors = [accentNavColor, baseNavColor, baseNavColor];
          break;
        case 1:
          navGradientColors = [baseNavColor, accentNavColor, baseNavColor];
          break;
        default:
          navGradientColors = [baseNavColor, baseNavColor, accentNavColor];
          break;
      }
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
                    icon: _buildNavIcon(
                      widget.isGuest ? Icons.login : Icons.history,
                      false,
                    ),
                    activeIcon: _buildNavIcon(
                      widget.isGuest ? Icons.login : Icons.history_rounded,
                      true,
                    ),
                    label: widget.isGuest ? 'Войти' : 'История',
                  ),
                  if (!widget.isGuest)
                    BottomNavigationBarItem(
                      icon: _buildNavIcon(Icons.person_outline_rounded, false),
                      activeIcon: _buildNavIcon(Icons.person_rounded, true),
                      label: 'Профиль',
                    ),
                ],
                currentIndex: _selectedIndex,
                onTap: (index) {
                  if (index < tabCount) _onItemTapped(index);
                },
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
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Войдите или зарегистрируйтесь, чтобы записываться на соревнования и вносить результаты.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
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
