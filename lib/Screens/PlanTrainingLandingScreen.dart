import 'package:flutter/material.dart';

import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/services/PremiumSubscriptionService.dart';
import 'package:login_app/Screens/PlanOverviewScreen.dart';
import 'package:login_app/Screens/CustomSetLandingScreen.dart';
import 'package:login_app/Screens/TrainerMyAssignmentsScreen.dart';

/// Экран выбора: Планы или Свой сет.
/// Два блока — переход на соответствующие экраны.
class PlanTrainingLandingScreen extends StatefulWidget {
  final PremiumStatus? premiumStatus;
  final bool aiCoachEnabled;
  final VoidCallback? onPremiumTap;

  const PlanTrainingLandingScreen({
    super.key,
    this.premiumStatus,
    this.aiCoachEnabled = false,
    this.onPremiumTap,
  });

  @override
  State<PlanTrainingLandingScreen> createState() => _PlanTrainingLandingScreenState();
}

class _PlanTrainingLandingScreenState extends State<PlanTrainingLandingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade1;
  late Animation<double> _fade2;
  late Animation<double> _fade3;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fade1 = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.5, curve: Curves.easeOut)),
    );
    _fade2 = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.25, 0.75, curve: Curves.easeOut)),
    );
    _fade3 = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.4, 1, curve: Curves.easeOut)),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.anthracite,
      appBar: AppBar(
        backgroundColor: AppColors.anthracite,
        automaticallyImplyLeading: false,
        title: Text(
          'План тренировок',
          style: unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  Text(
                    'Выберите тип тренировки',
                    style: unbounded(fontSize: 15, color: Colors.white54),
                  ),
                  const SizedBox(height: 20),
                  Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: AnimatedBuilder(
                            animation: _controller,
                            builder: (_, child) => Opacity(opacity: _fade1.value, child: child),
                            child: _PlanChoiceBlock(
                              icon: Icons.calendar_month_rounded,
                              title: 'План',
                              description: 'Персональное расписание ОФП и СФП под ваши цели',
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PlanOverviewScreen(
                                      isTabVisible: true,
                                      premiumStatus: widget.premiumStatus,
                                      aiCoachEnabled: widget.aiCoachEnabled,
                                      onPremiumTap: widget.onPremiumTap,
                                      showBackButton: true,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AnimatedBuilder(
                            animation: _controller,
                            builder: (_, child) => Opacity(opacity: _fade2.value, child: child),
                            child: _PlanChoiceBlock(
                              icon: Icons.fitness_center,
                              title: 'Свой сет',
                              description: 'Выберите упражнения и создайте тренировку на сегодня',
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CustomSetLandingScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (_, child) => Opacity(opacity: _fade3.value, child: child),
                    child: _PlanChoiceBlockWide(
                      icon: Icons.assignment_ind,
                      title: 'Задания от тренера',
                      description: 'Упражнения, которые назначил ваш тренер',
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TrainerMyAssignmentsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
        ),
      ),
    );
  }
}

class _PlanChoiceBlockWide extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _PlanChoiceBlockWide({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.graphite),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.mutedGold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 24, color: AppColors.mutedGold),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: unbounded(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: unbounded(fontSize: 12, color: Colors.white54, height: 1.3),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.mutedGold),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanChoiceBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _PlanChoiceBlock({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.graphite),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.mutedGold.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 24, color: AppColors.mutedGold),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: unbounded(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: Text(
                    description,
                    style: unbounded(fontSize: 11, color: Colors.white54, height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.mutedGold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
