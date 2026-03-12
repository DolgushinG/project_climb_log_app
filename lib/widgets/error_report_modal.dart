import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'error_report_button.dart';

/// Показывает модальное окно с ошибкой, кнопками «Повторить» и «Отправить ошибку».
Future<void> showErrorReportModal(
  BuildContext context, {
  required String message,
  required VoidCallback onRetry,
  String? screen,
  int? eventId,
  String? stackTrace,
  Map<String, dynamic>? extra,
  String retryLabel = 'Повторить',
  VoidCallback? onSecondary,
  String? secondaryLabel,
  String? title,
}) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.cardDark,
      title: Text(
        title ?? 'Ошибка',
        style: unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              message,
              style: unbounded(fontSize: 14, color: Colors.white70, height: 1.5),
            ),
            const SizedBox(height: 20),
            ErrorReportButton(
              errorMessage: message,
              screen: screen,
              eventId: eventId,
              stackTrace: stackTrace,
              extra: extra,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('Закрыть', style: unbounded(color: Colors.white54)),
        ),
        if (onSecondary != null)
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onSecondary();
            },
            child: Text(secondaryLabel ?? 'Назад', style: unbounded(color: AppColors.mutedGold)),
          ),
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            onRetry();
          },
          child: Text(retryLabel, style: unbounded(color: AppColors.mutedGold, fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}
