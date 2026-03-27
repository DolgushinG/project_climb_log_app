import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Перекрывает экран оформления на время polling после WebView T‑Банка.
class TbankPaymentConfirmingOverlay extends StatelessWidget {
  const TbankPaymentConfirmingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AbsorbPointer(
        child: ColoredBox(
          color: AppColors.anthracite.withOpacity(0.94),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.mutedGold),
                const SizedBox(height: 24),
                Text(
                  'Подтверждаем оплату…',
                  textAlign: TextAlign.center,
                  style: unbounded(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ждём ответ банка. Обычно это несколько секунд, иногда дольше.',
                  textAlign: TextAlign.center,
                  style: unbounded(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
