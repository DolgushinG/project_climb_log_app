import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login_app/theme/app_theme.dart';

import 'package:login_app/Screens/ClimbingLogAddScreen.dart';
import 'package:login_app/Screens/ClimbingLogHistoryScreen.dart';
import 'package:login_app/Screens/ClimbingLogLandingScreen.dart';
import 'package:login_app/Screens/ClimbingLogProgressScreen.dart';
import 'package:login_app/Screens/ClimbingLogSummaryScreen.dart';

/// Объединяющий экран трекера трасс.
/// Для гостей — лендинг с «Доступно после авторизации».
/// Для авторизованных — вкладки: Обзор, Тренировка, Прогресс, История.
/// Структура как у CompetitionScreen: AppBar + TabBar.
class ClimbingLogScreen extends StatelessWidget {
  final bool isGuest;

  const ClimbingLogScreen({super.key, required this.isGuest});

  @override
  Widget build(BuildContext context) {
    if (isGuest) {
      return const ClimbingLogLandingScreen();
    }
    return DefaultTabController(
      length: 4,
      child: Scaffold(
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
                    Tab(child: FittedBox(child: Text('Тренировка', style: GoogleFonts.unbounded(fontSize: 13)))),
                    Tab(child: FittedBox(child: Text('Прогресс', style: GoogleFonts.unbounded(fontSize: 13)))),
                    Tab(child: FittedBox(child: Text('История', style: GoogleFonts.unbounded(fontSize: 13)))),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            ClimbingLogSummaryScreen(),
            ClimbingLogAddScreen(),
            ClimbingLogProgressScreen(),
            ClimbingLogHistoryScreen(),
          ],
        ),
      ),
    );
  }
}
