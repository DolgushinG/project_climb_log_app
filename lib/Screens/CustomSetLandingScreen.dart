import 'package:flutter/material.dart';

import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/models/SavedCustomSet.dart';
import 'package:login_app/services/CustomExerciseSetService.dart';
import 'package:login_app/Screens/CustomSetBuilderScreen.dart';
import 'package:login_app/Screens/SavedSetsScreen.dart';

/// Промежуточный экран: Создать сет или История моих сетов.
class CustomSetLandingScreen extends StatelessWidget {
  const CustomSetLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.anthracite,
      appBar: AppBar(
        backgroundColor: AppColors.anthracite,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Собственный сет',
          style: unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.mutedGold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.mutedGold.withOpacity(0.4), width: 2),
                  ),
                  child: Icon(Icons.fitness_center, size: 40, color: AppColors.mutedGold),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Собственный сет упражнений',
                style: unbounded(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Создайте сет или выберите из сохранённых',
                style: unbounded(fontSize: 14, color: Colors.white54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              FilledButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomSetBuilderScreen(popOnReturn: true),
                    ),
                  );
                },
                icon: const Icon(Icons.add_circle_outline, size: 22),
                label: Text(
                  'Создать сет',
                  style: unbounded(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.mutedGold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                  shadowColor: AppColors.mutedGold.withOpacity(0.3),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await Navigator.push<SavedCustomSet>(
                    context,
                    MaterialPageRoute(builder: (_) => const SavedSetsScreen()),
                  );
                  if (picked != null && context.mounted) {
                    final full = await CustomExerciseSetService().getSet(picked.id);
                    if (full != null && context.mounted) {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CustomSetBuilderScreen(
                            initialSet: full,
                            popOnReturn: true,
                          ),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.history, size: 20),
                label: Text(
                  'История моих сетов',
                  style: unbounded(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.mutedGold,
                  side: const BorderSide(color: AppColors.mutedGold),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
