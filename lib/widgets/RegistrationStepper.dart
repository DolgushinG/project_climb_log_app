import 'package:flutter/material.dart';
import 'package:login_app/theme/app_theme.dart';

/// Горизонтальный индикатор шагов: ───●───○───○───○
/// AppColors.mutedGold для активного шага, Colors.white54 для остальных.
class RegistrationStepper extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String>? stepLabels;

  const RegistrationStepper({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.stepLabels,
  })  : assert(currentStep >= 0 && currentStep < totalSteps),
        assert(totalSteps >= 1);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(totalSteps * 2 - 1, (i) {
            if (i.isOdd) {
              final stepIndex = i ~/ 2;
              final isActive = stepIndex <= currentStep;
              return Expanded(
                flex: 2,
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.mutedGold.withOpacity(0.6) : Colors.white24,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              );
            } else {
              final stepIndex = i ~/ 2;
              final isActive = stepIndex == currentStep;
              final isCompleted = stepIndex < currentStep;
              return Expanded(
                flex: 1,
                child: Center(
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? AppColors.mutedGold
                          : (isCompleted ? AppColors.mutedGold.withOpacity(0.5) : Colors.white24),
                      border: Border.all(
                        color: isActive ? AppColors.mutedGold : Colors.white38,
                        width: isActive ? 2 : 1,
                      ),
                    ),
                    child: isCompleted
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                ),
              );
            }
          }),
        ),
        if (stepLabels != null && stepLabels!.length >= totalSteps) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(totalSteps, (i) {
              return Expanded(
                child: Center(
                  child: Text(
                    stepLabels![i],
                    style: unbounded(
                      fontSize: 10,
                      fontWeight: i == currentStep ? FontWeight.w600 : FontWeight.w400,
                      color: i == currentStep ? AppColors.mutedGold : Colors.white54,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}
