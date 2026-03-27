import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// После подтверждённой онлайн-оплаты: затемнённый фон + модальное окно.
/// На web iframe должен быть уже закрыт ([closeTbankWebPaymentIframeRouteIfOpen]), иначе клики уходят в банк.
/// По кнопке закрывает текущий маршрут (checkout) с результатом `true`, чтобы родитель обновил данные.
Future<void> showTbankPaymentSuccessDialog(BuildContext checkoutContext) async {
  await showDialog<void>(
    context: checkoutContext,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.72),
    builder: (ctx) {
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Material(
            color: AppColors.cardDark,
            elevation: 16,
            shadowColor: Colors.black.withOpacity(0.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Оплата прошла успешно',
                    style: unbounded(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Регистрация обновится на странице события.',
                    style: unbounded(fontSize: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      if (checkoutContext.mounted) {
                        Navigator.of(checkoutContext).pop(true);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.mutedGold,
                      foregroundColor: AppColors.anthracite,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'К событию',
                      style: unbounded(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Отказ банка / финальная ошибка оплаты: закрыть iframe до вызова (web), затем этот диалог.
/// Только закрывает диалог — пользователь остаётся на экране оформления.
Future<void> showTbankPaymentFailureDialog(
  BuildContext context, {
  required String message,
}) async {
  await showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.72),
    builder: (ctx) {
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Material(
            color: AppColors.cardDark,
            elevation: 16,
            shadowColor: Colors.black.withOpacity(0.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Оплата не прошла',
                    style: unbounded(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: unbounded(fontSize: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.mutedGold,
                      foregroundColor: AppColors.anthracite,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Понятно',
                      style: unbounded(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
