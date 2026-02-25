import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'package:login_app/Screens/AuthSettingScreen.dart';
import 'dart:convert';

import 'Screens/AnalyticsScreen.dart';
import 'services/RustorePushService.dart';
import 'Screens/FranceResultScreen.dart';
import 'Screens/ProfileEditScreen.dart';
import 'Screens/RelatedUsersScreen.dart';
import 'Screens/ChangePasswordScreen.dart';
import 'Screens/ParticipationHistoryScreen.dart';
import 'Screens/AboutScreen.dart';
import 'Screens/PremiumPaymentScreen.dart';
import 'services/PremiumSubscriptionService.dart';
import 'login.dart';
import 'main.dart';
import 'utils/display_helper.dart';
import 'utils/session_error_helper.dart';
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
  PremiumStatus? _premiumStatus;
  bool _isRefreshing = false;
  String? _pushToken;

  bool _pushTokenLoading = false;

  Widget _buildPushTestCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () async {
          final token = _pushToken;
          if (token != null) {
            Clipboard.setData(ClipboardData(text: token));
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Токен скопирован. Вставьте в RuStore Консоль → Push → Тестовая отправка', style: unbounded()),
                  backgroundColor: AppColors.cardDark,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } else if (!_pushTokenLoading) {
            setState(() => _pushTokenLoading = true);
            final ok = await RustorePushService.requestToken();
            if (mounted) {
              setState(() => _pushTokenLoading = false);
              if (ok) {
                final t = await RustorePushService.getStoredToken();
                if (mounted) setState(() => _pushToken = t);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok ? 'Токен получен' : 'Не удалось (RuStore установлен? Войдите в него)',
                    style: unbounded(),
                  ),
                  backgroundColor: ok ? AppColors.cardDark : Colors.orange.shade900,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.mutedGold.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.mutedGold.withOpacity(0.3)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(Icons.notifications_active, color: AppColors.mutedGold, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Тест пушей RuStore', style: unbounded(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.mutedGold)),
                    const SizedBox(height: 4),
                    Text(
                      _pushToken != null
                          ? 'Нажмите, чтобы скопировать токен. Отправка: console.rustore.ru → приложение → Push → Тестовая отправка'
                          : _pushTokenLoading
                              ? 'Запрос токена...'
                              : 'Токен не получен. Нажмите, чтобы запросить (нужен RuStore, вход в него)',
                      style: unbounded(fontSize: 11, color: Colors.white70, height: 1.3),
                    ),
                  ],
                ),
              ),
              if (_pushTokenLoading)
                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.mutedGold))
              else if (_pushToken != null)
                Icon(Icons.copy_rounded, color: AppColors.mutedGold, size: 20)
              else
                Icon(Icons.refresh_rounded, color: AppColors.mutedGold, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard() {
    final s = _premiumStatus;
    String subtitle = 'Оформить подписку';
    if (s != null) {
      if (s.networkUnavailable) {
        subtitle = 'Нет подключения. Проверьте интернет';
      } else if (s.hasActiveSubscription) {
        final days = s.subscriptionDaysLeft;
        if (days != null && s.subscriptionEndsAt != null) {
          final d = s.subscriptionEndsAt!;
          final prefix = s.subscriptionCancelled ? 'Отменена, действует до ' : 'Активна до ';
          subtitle = '$prefix${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} (осталось $days ${_dayWord(days)})';
        } else {
          subtitle = s.subscriptionCancelled ? 'Подписка отменена' : 'Подписка оформлена';
        }
      } else if (s.isInTrial) {
        subtitle = 'Пробный период: ${s.trialDaysLeft} ${_dayWord(s.trialDaysLeft)}';
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () async {
          if (_premiumStatus?.networkUnavailable == true) {
            _showNetworkUnavailableDialog();
            return;
          }
          final paymentSuccess = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const PremiumPaymentScreen()),
          );
          if (mounted && paymentSuccess == true) {
            await _onPaymentSuccessReturn();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.mutedGold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.workspace_premium, color: AppColors.mutedGold, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Подписка',
                      style: AppTypography.athleteName().copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: unbounded(fontSize: 12, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.5), size: 22),
            ],
          ),
        ),
      ),
    );
  }

  String _dayWord(int n) {
    if (n == 1) return 'день';
    if (n >= 2 && n <= 4) return 'дня';
    return 'дней';
  }

  /// Вызывается после возврата из PremiumPaymentScreen с paymentSuccess=true.
  /// Сразу обновляет статус, при ожидании webhook — опрашивает и показывает сообщение об активации.
  Future<void> _onPaymentSuccessReturn() async {
    final service = PremiumSubscriptionService();
    await service.invalidateStatusCache();
    final hadSubscription = _premiumStatus?.hasActiveSubscription ?? false;
    var st = await service.getStatus();
    if (!mounted) return;
    setState(() => _premiumStatus = st);
    if (st.hasActiveSubscription && !hadSubscription) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Подписка оформлена! Спасибо за поддержку.', style: unbounded(color: Colors.white)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.successMuted,
        ),
      );
      return;
    }
    // Webhook ещё не обработан — показываем ожидание и опрашиваем
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Оплата получена. Подписка активируется в течение минуты.', style: unbounded(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.mutedGold.withOpacity(0.9),
      ),
    );
    for (var i = 0; i < 8 && mounted; i++) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      st = await service.getStatus();
      if (!mounted) return;
      setState(() => _premiumStatus = st);
      if (st.hasActiveSubscription) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Подписка оформлена! Спасибо за поддержку.', style: unbounded(color: Colors.white)),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.successMuted,
          ),
        );
        return;
      }
    }
  }

  void _showNetworkUnavailableDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: Colors.white54, size: 28),
            const SizedBox(width: 12),
            Text(
              'Нет подключения',
              style: unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ],
        ),
        content: Text(
          'Проверьте подключение к интернету и нажмите «Повторить», чтобы обновить статус подписки.',
          style: unbounded(fontSize: 14, color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Закрыть', style: unbounded(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final st = await PremiumSubscriptionService().getStatus();
              if (mounted) setState(() => _premiumStatus = st);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.mutedGold),
            child: Text('Повторить', style: unbounded(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

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
      if (response.statusCode == 401) {
        if (mounted) {
          setState(() => isLoading = false);
          redirectToLoginOnSessionError(context);
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

  static const String _keyWelcomeShown = 'profile_welcome_shown';

  @override
  void initState() {
    super.initState();
    _loadProfileAndPremium();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowWelcomeModal());
    if (kDebugMode) {
      RustorePushService.getStoredToken().then((token) {
        if (mounted) setState(() => _pushToken = token);
      });
    }
  }

  Future<void> _loadProfileAndPremium() async {
    final results = await Future.wait([
      fetchProfileData(),
      PremiumSubscriptionService().getStatus(),
    ]);
    if (mounted) setState(() => _premiumStatus = results[1] as PremiumStatus?);
  }

  /// Обновление без кэшей: сброс кэша профиля и подписки, загрузка свежих данных.
  Future<void> _refreshWithoutCache() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await CacheService.remove(CacheService.keyProfile);
    final results = await Future.wait([
      fetchProfileData(),
      PremiumSubscriptionService().getStatus(forceRefresh: true),
    ]);
    String? pushToken;
    if (kDebugMode) pushToken = await RustorePushService.getStoredToken();
    if (mounted) {
      setState(() {
        _premiumStatus = results[1] as PremiumStatus?;
        if (pushToken != null) _pushToken = pushToken;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _maybeShowWelcomeModal() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_keyWelcomeShown) == true) return;
    if (!mounted) return;
    await _showWelcomeModal();
    if (mounted) await prefs.setBool(_keyWelcomeShown, true);
  }

  Future<void> _showWelcomeModal() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.waving_hand_rounded, size: 56, color: AppColors.mutedGold),
              const SizedBox(height: 20),
              Text(
                'Добро пожаловать!',
                style: unbounded(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'В приложении вы можете:\n\n'
                '• Записываться на соревнования и вносить результаты\n'
                '• Отслеживать тренировки и прогресс в скалолазании\n'
                '• Искать скалодромы и соревнования рядом\n'
                '• Вести историю залов и трасс',
                style: unbounded(
                  fontSize: 14,
                  color: Colors.white70,
                  height: 1.5,
                ),
                textAlign: TextAlign.left,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.mutedGold,
                    foregroundColor: AppColors.anthracite,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Начать',
                    style: unbounded(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Профиль', style: unbounded(fontWeight: FontWeight.w500, fontSize: 18)),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.mutedGold),
                  )
                : Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _isRefreshing ? null : () => _refreshWithoutCache(),
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: isLoading && avatar.isEmpty && firstName == 'Имя'
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshWithoutCache,
              color: AppColors.mutedGold,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
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
                    backgroundColor: AppColors.graphite,
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
                    backgroundColor: AppColors.graphite,
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
                          style: AppTypography.sectionTitle().copyWith(fontSize: 22),
                        ),
                        SizedBox(height: 8),
                        Text('Город: ${displayValue(city)}', style: AppTypography.secondary()),
                        Text('Разряд: ${displayValue(rank)}', style: AppTypography.secondary()),
                        Text('День рождения: ${displayValue(birthYear)}', style: AppTypography.secondary()),
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
                  if (kDebugMode) _buildPushTestCard(),
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
                  _buildSubscriptionCard(),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.mutedGold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.mutedGold, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.athleteName().copyWith(fontSize: 15),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.5), size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

