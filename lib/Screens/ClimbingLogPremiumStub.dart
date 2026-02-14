import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/Screens/PremiumPaymentScreen.dart';

/// Заглушка при отсутствии подписки: возможности раздела и кнопка «Купить подписку».
class ClimbingLogPremiumStub extends StatelessWidget {
  /// Вызывается при возврате из экрана оплаты. [paymentSuccess] — true если оплата прошла.
  final void Function(bool paymentSuccess)? onPurchased;

  const ClimbingLogPremiumStub({super.key, this.onPurchased});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.mutedGold.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.workspace_premium, size: 28, color: AppColors.mutedGold),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Premium',
                              style: GoogleFonts.unbounded(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Полный доступ к разделу «Тренировки»',
                              style: GoogleFonts.unbounded(color: Colors.white70, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.mutedGold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.mutedGold.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, color: AppColors.mutedGold, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Оформите подписку, чтобы пользоваться всеми функциями',
                        style: GoogleFonts.unbounded(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Text(
                'Возможности',
                style: GoogleFonts.unbounded(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _FeatureTile(
                  icon: Icons.calendar_month,
                  title: 'План тренировок',
                  subtitle: 'Персональное расписание ОФП и СФП. Календарь, упражнения, прогресс по дням.',
                ),
                _FeatureTile(
                  icon: Icons.add_chart,
                  title: 'Тренировки',
                  subtitle: 'Записывайте трассы по грейдам, выбирайте зал, сохраняйте сессии.',
                ),
                _FeatureTile(
                  icon: Icons.fitness_center,
                  title: 'Замеры силы',
                  subtitle: 'Пальцы, щипок, тяга. Тест, топ недели, ачивки.',
                ),
                _FeatureTile(
                  icon: Icons.trending_up,
                  title: 'Прогресс',
                  subtitle: 'Статистика, графики, история тренировок.',
                ),
              ]),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (_) => const PremiumPaymentScreen()),
                    );
                    onPurchased?.call(result == true);
                  },
                  icon: const Icon(Icons.shopping_cart_outlined, size: 20),
                  label: Text('Купить подписку', style: GoogleFonts.unbounded(fontSize: 16, fontWeight: FontWeight.w600)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.mutedGold,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.graphite),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.mutedGold.withOpacity(0.8), size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.unbounded(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.unbounded(color: Colors.white70, fontSize: 13, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
