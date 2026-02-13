import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/services/PremiumSubscriptionService.dart';
import 'package:login_app/Screens/PremiumPaymentScreen.dart';

import 'package:login_app/Screens/ClimbingLogHistoryScreen.dart';
import 'package:login_app/Screens/ClimbingLogLandingScreen.dart';
import 'package:login_app/Screens/ClimbingLogProgressScreen.dart';
import 'package:login_app/Screens/ClimbingLogSummaryScreen.dart';
import 'package:login_app/Screens/ClimbingLogTestingScreen.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadPremiumStatus();
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

  Future<void> _loadPremiumStatus() async {
    if (widget.isGuest) return;
    await _premiumService.ensureTrialStarted();
    final status = await _premiumService.getStatus();
    if (mounted) setState(() => _premiumStatus = status);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isGuest) {
      return const ClimbingLogLandingScreen();
    }
    return Scaffold(
        backgroundColor: AppColors.anthracite,
        appBar: AppBar(
          backgroundColor: AppColors.anthracite,
          automaticallyImplyLeading: false,
          title: Text('Тренировки', style: GoogleFonts.unbounded(fontWeight: FontWeight.w500, fontSize: 18, color: Colors.white)),
          bottom: PreferredSize(
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
                    Tab(child: FittedBox(child: Text('Обзор', style: GoogleFonts.unbounded(fontSize: 13)))),
                    Tab(child: FittedBox(child: Text('Прогресс', style: GoogleFonts.unbounded(fontSize: 13)))),
                    Tab(child: FittedBox(child: Text('История', style: GoogleFonts.unbounded(fontSize: 13)))),
                    Tab(child: FittedBox(child: Text('Тестирование', style: GoogleFonts.unbounded(fontSize: 13)))),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: TabBarView(
                controller: _tabController,
                children: [
                  ClimbingLogSummaryScreen(
                    premiumStatus: _premiumStatus,
                    onPremiumTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PremiumPaymentScreen()),
                    ).then((_) => _loadPremiumStatus()),
                  ),
                  const ClimbingLogProgressScreen(),
                  const ClimbingLogHistoryScreen(),
                  const ClimbingLogTestingScreen(),
                ],
              ),
    );
  }

}
