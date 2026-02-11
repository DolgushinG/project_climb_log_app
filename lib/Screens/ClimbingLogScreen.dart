import 'package:flutter/material.dart';

import 'package:login_app/Screens/ClimbingLogAddScreen.dart';
import 'package:login_app/Screens/ClimbingLogHistoryScreen.dart';
import 'package:login_app/Screens/ClimbingLogLandingScreen.dart';
import 'package:login_app/Screens/ClimbingLogProgressScreen.dart';

/// Объединяющий экран трекера трасс.
/// Для гостей — лендинг с «Доступно после авторизации».
/// Для авторизованных — вкладки: Тренировка, Прогресс, История.
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
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Тренировки'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: TabBar(
                  indicatorColor: Colors.transparent,
                  overlayColor: MaterialStateProperty.all(Colors.transparent),
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Colors.white.withOpacity(0.16),
                  ),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                  tabs: const [
                    Tab(text: 'Тренировка'),
                    Tab(text: 'Прогресс'),
                    Tab(text: 'История'),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            ClimbingLogAddScreen(),
            ClimbingLogProgressScreen(),
            ClimbingLogHistoryScreen(),
          ],
        ),
      ),
    );
  }
}
