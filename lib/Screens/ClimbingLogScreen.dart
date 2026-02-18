import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/main.dart';
import 'package:login_app/services/PremiumSubscriptionService.dart';
import 'package:login_app/Screens/PremiumPaymentScreen.dart';

import 'package:login_app/Screens/ClimbingLogHistoryScreen.dart';
import 'package:login_app/Screens/ClimbingLogLandingScreen.dart';
import 'package:login_app/Screens/ClimbingLogPremiumStub.dart';
import 'package:login_app/Screens/ClimbingLogProgressScreen.dart';
import 'package:login_app/Screens/ClimbingLogSummaryScreen.dart';
import 'package:login_app/Screens/ClimbingLogTestingScreen.dart';
import 'package:login_app/Screens/PlanOverviewScreen.dart';
import 'package:login_app/utils/session_error_helper.dart';

/// Объединяющий экран трекера трасс.
/// Для гостей — лендинг с «Доступно после авторизации».
/// Для авторизованных — вкладки: Обзор, Прогресс, История, Тестирование.
/// Premium: пробный период 7 дней, далее платная подписка.
class ClimbingLogScreen extends StatefulWidget {
  final bool isGuest;
  /// true когда пользователь переключился на вкладку «Тренировки» в нижней навигации
  final bool isTabVisible;

  const ClimbingLogScreen({
    super.key,
    required this.isGuest,
    this.isTabVisible = true,
  });

  @override
  State<ClimbingLogScreen> createState() => _ClimbingLogScreenState();
}

class _ClimbingLogScreenState extends State<ClimbingLogScreen> with SingleTickerProviderStateMixin {
  final PremiumSubscriptionService _premiumService = PremiumSubscriptionService();
  PremiumStatus? _premiumStatus;
  late TabController _tabController;
  /// Если true — родитель передал isGuest=false, но токена нет (устаревшая сессия/рассинхрон). Показываем landing.
  bool _effectivelyGuest = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_onTabChanged);
    _verifyTokenAndLoadPremium();
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  bool _firstTimeTrialShown = false;

  @override
  void didUpdateWidget(covariant ClimbingLogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isTabVisible && widget.isTabVisible) {
      _maybeShowTrialModal();
    }
  }

  Future<void> _onReturnFromPremiumPayment(bool paymentSuccess) async {
    if (!paymentSuccess || !mounted) return;
    final hadAccess = _premiumStatus?.hasAccess ?? false;
    await _premiumService.invalidateStatusCache();
    await _loadPremiumStatus();
    if (!mounted) return;
    if (_premiumStatus?.hasActiveSubscription == true && !hadAccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Подписка оформлена! Спасибо за поддержку.', style: GoogleFonts.unbounded(color: Colors.white)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.successMuted,
        ),
      );
      return;
    }
    // Webhook ещё не обработан — показываем ожидание и опрашиваем
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Оплата получена. Подписка активируется в течение минуты.', style: GoogleFonts.unbounded(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.mutedGold.withOpacity(0.9),
      ),
    );
    for (var i = 0; i < 8 && mounted; i++) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      await _loadPremiumStatus();
      if (!mounted) return;
      if (_premiumStatus?.hasActiveSubscription == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Подписка оформлена! Спасибо за поддержку.', style: GoogleFonts.unbounded(color: Colors.white)),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.successMuted,
          ),
        );
        return;
      }
    }
  }

  Future<void> _verifyTokenAndLoadPremium() async {
    if (widget.isGuest) return;
    final token = await getToken();
    if ((token == null || token.trim().isEmpty) && mounted) {
      setState(() => _effectivelyGuest = true);
      return;
    }
    await _loadPremiumStatus();
  }

  Future<void> _loadPremiumStatus() async {
    if (widget.isGuest) return;
    final status = await _premiumService.getStatus();
    if (!mounted) return;
    if (status.isUnauthorized) {
      await redirectToLoginOnSessionError(context, 'Сессия истекла. Войдите снова.');
      return;
    }
    setState(() => _premiumStatus = status);
    if (widget.isTabVisible) _maybeShowTrialModal();
  }

  void _maybeShowTrialModal() {
    if (widget.isGuest || _effectivelyGuest || _premiumStatus?.isUnauthorized == true) return;
    if (_firstTimeTrialShown) return;
    if (_premiumStatus == null || _premiumStatus!.trialStarted || _premiumStatus!.hasActiveSubscription) return;
    _firstTimeTrialShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showFirstTimeTrialModal();
    });
  }

  Future<void> _showFirstTimeTrialModal() async {
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Пробный период',
          style: GoogleFonts.unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        content: Text(
          'У вас 7 дней бесплатного доступа ко всем функциям раздела «Тренировки»: план, замеры, история. Нажмите «Начать», чтобы активировать.',
          style: GoogleFonts.unbounded(fontSize: 14, color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Позже', style: GoogleFonts.unbounded(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.mutedGold, foregroundColor: Colors.white),
            child: Text('Начать', style: GoogleFonts.unbounded(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      final result = await _premiumService.startTrial();
      if (mounted) {
        await _loadPremiumStatus();
        if (result.success) {
          final endsAt = _premiumStatus?.trialEndsAt;
          final dateStr = endsAt != null
              ? DateFormat('d MMMM yyyy', 'ru').format(endsAt)
              : null;
          final msg = dateStr != null
              ? 'Ваша пробная подписка активирована до $dateStr'
              : 'Ваша пробная подписка активирована на 7 дней';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg, style: GoogleFonts.unbounded(color: Colors.white)),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.successMuted,
            ),
          );
        } else {
          // Обрабатываем разные типы ошибок
          String errorMessage;
          switch (result.errorCode) {
            case 'trial_already_used':
              // Пробный период уже активирован, показываем информацию об оставшемся времени
              final daysLeft = _premiumStatus?.trialDaysLeft ?? 0;
              if (daysLeft > 0) {
                final endsAt = _premiumStatus?.trialEndsAt;
                final dateStr = endsAt != null
                    ? DateFormat('d MMMM yyyy', 'ru').format(endsAt)
                    : null;
                errorMessage = dateStr != null
                    ? 'Пробный период уже активирован. Доступ до $dateStr'
                    : 'Пробный период уже активирован. Осталось $daysLeft дней';
              } else {
                errorMessage = 'Пробный период уже был активирован ранее';
              }
              break;
            case 'network_error':
              errorMessage = 'Нет подключения к интернету. Проверьте соединение.';
              break;
            case 'no_token':
              errorMessage = 'Требуется авторизация';
              break;
            default:
              errorMessage = 'Не удалось активировать. Попробуйте позже.';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage, style: GoogleFonts.unbounded(color: Colors.white)),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.graphite,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isGuest || _effectivelyGuest) {
      return const ClimbingLogLandingScreen();
    }
    final networkUnavailable = _premiumStatus?.networkUnavailable == true;
    final showPaywall = _premiumStatus != null && !_premiumStatus!.hasAccess && !networkUnavailable;

    return Scaffold(
        backgroundColor: AppColors.anthracite,
        appBar: AppBar(
          backgroundColor: AppColors.anthracite,
          automaticallyImplyLeading: false,
          title: Text('Тренировки', style: GoogleFonts.unbounded(fontWeight: FontWeight.w500, fontSize: 18, color: Colors.white)),
          bottom: showPaywall
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.rowAlt,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicatorColor: Colors.transparent,
                        overlayColor: MaterialStateProperty.all(Colors.transparent),
                        labelColor: AppColors.mutedGold,
                        unselectedLabelColor: Colors.white70,
                        indicator: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: AppColors.mutedGold.withOpacity(0.3),
                        ),
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        tabs: [
                          Tab(child: FittedBox(child: Text('План', style: GoogleFonts.unbounded(fontSize: 13)))),
                          Tab(child: FittedBox(child: Text('Обзор', style: GoogleFonts.unbounded(fontSize: 13)))),
                          Tab(child: FittedBox(child: Text('Прогресс', style: GoogleFonts.unbounded(fontSize: 13)))),
                          Tab(child: FittedBox(child: Text('История', style: GoogleFonts.unbounded(fontSize: 13)))),
                          Tab(child: FittedBox(child: Text('Тест', style: GoogleFonts.unbounded(fontSize: 13)))),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
        body: networkUnavailable
            ? _buildNetworkUnavailableState()
            : showPaywall
                ? ClimbingLogPremiumStub(onPurchased: _onReturnFromPremiumPayment)
                : TabBarView(
                controller: _tabController,
                children: [
                  PlanOverviewScreen(
                    isTabVisible: _tabController.index == 0,
                    premiumStatus: _premiumStatus,
                    onPremiumTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PremiumPaymentScreen()),
                    ).then((paymentSuccess) => _onReturnFromPremiumPayment(paymentSuccess == true)),
                  ),
                  ClimbingLogSummaryScreen(
                    premiumStatus: _premiumStatus,
                    onPremiumTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PremiumPaymentScreen()),
                    ).then((paymentSuccess) => _onReturnFromPremiumPayment(paymentSuccess == true)),
                  ),
                  const ClimbingLogProgressScreen(),
                  const ClimbingLogHistoryScreen(),
                  const ClimbingLogTestingScreen(),
                ],
              ),
    );
  }

  Widget _buildNetworkUnavailableState() {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 64, color: Colors.white38),
              const SizedBox(height: 20),
              Text(
                'Нет подключения к интернету',
                style: GoogleFonts.unbounded(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Проверьте соединение и нажмите «Повторить»',
                style: GoogleFonts.unbounded(fontSize: 14, color: Colors.white54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadPremiumStatus,
                icon: const Icon(Icons.refresh, size: 20),
                label: const Text('Повторить'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.mutedGold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
