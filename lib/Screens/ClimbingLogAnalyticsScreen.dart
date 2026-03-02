import 'package:flutter/material.dart';
import 'package:login_app/Screens/ClimbingLogSummaryScreen.dart';
import 'package:login_app/Screens/ClimbingLogProgressScreen.dart';
import 'package:login_app/services/PremiumSubscriptionService.dart';
import 'package:login_app/theme/app_theme.dart';

/// Экран аналитики (Обзор + Прогресс) внутри ClimbingLogScreen.
/// Содержит вложенный TabBar с двумя подвкладками.
class ClimbingLogAnalyticsScreen extends StatefulWidget {
  final PremiumStatus? premiumStatus;
  final VoidCallback? onPremiumTap;

  const ClimbingLogAnalyticsScreen({
    super.key,
    this.premiumStatus,
    this.onPremiumTap,
  });

  @override
  State<ClimbingLogAnalyticsScreen> createState() => _ClimbingLogAnalyticsScreenState();
}

class _ClimbingLogAnalyticsScreenState extends State<ClimbingLogAnalyticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Вложенный TabBar
        Container(
          decoration: BoxDecoration(
            color: AppColors.rowAlt,
            borderRadius: BorderRadius.circular(999),
          ),
          margin: const EdgeInsets.all(12),
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
              Tab(child: FittedBox(child: Text('Обзор', style: unbounded(fontSize: 13)))),
              Tab(child: FittedBox(child: Text('Прогресс', style: unbounded(fontSize: 13)))),
            ],
          ),
        ),
        // Содержимое
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              ClimbingLogSummaryScreen(
                premiumStatus: widget.premiumStatus,
                onPremiumTap: widget.onPremiumTap,
              ),
              const ClimbingLogProgressScreen(),
            ],
          ),
        ),
      ],
    );
  }
}
