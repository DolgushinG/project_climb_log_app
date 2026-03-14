import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Тип уведомления snackbar.
enum AppSnackBarType {
  error,
  success,
  warning,
  info,
}

/// Единый стиль snackbar в дизайне приложения.
/// Использует AppColors, Unbounded, иконки и плавающий вид.
void showAppSnackBar(
  BuildContext context, {
  required String message,
  AppSnackBarType type = AppSnackBarType.info,
  Duration? duration,
  SnackBarAction? action,
}) {
  // В стиле TopNotificationBanner: graphite/cardDark, приглушённые иконки из палитры
  final (IconData icon, Color iconColor) = switch (type) {
    AppSnackBarType.error => (
        Icons.error_outline_rounded,
        AppColors.mutedGold, // внимание — в тон акцента, без яркого red
      ),
    AppSnackBarType.success => (
        Icons.check_circle_outline_rounded,
        AppColors.successMuted,
      ),
    AppSnackBarType.warning => (
        Icons.warning_amber_rounded,
        AppColors.mutedGold,
      ),
    AppSnackBarType.info => (
        Icons.info_outline_rounded,
        AppColors.graphiteLight,
      ),
  };

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: unbounded(
                fontSize: 14,
                color: Colors.white.withOpacity(0.95),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: AppColors.graphite,
      behavior: SnackBarBehavior.floating,
      duration: duration ?? const Duration(seconds: 3),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.graphiteLight.withOpacity(0.2), width: 0.5),
      ),
      action: action != null
          ? SnackBarAction(
              label: action.label,
              onPressed: action.onPressed,
              textColor: AppColors.mutedGold,
            )
          : null,
    ),
  );
}

/// Удобные обёртки для частых случаев.
void showAppError(BuildContext context, String message, {Duration? duration}) {
  showAppSnackBar(context, message: message, type: AppSnackBarType.error, duration: duration ?? const Duration(seconds: 4));
}

void showAppSuccess(BuildContext context, String message, {Duration? duration}) {
  showAppSnackBar(context, message: message, type: AppSnackBarType.success, duration: duration);
}

void showAppWarning(BuildContext context, String message, {Duration? duration}) {
  showAppSnackBar(context, message: message, type: AppSnackBarType.warning, duration: duration);
}

void showAppInfo(BuildContext context, String message, {Duration? duration}) {
  showAppSnackBar(context, message: message, type: AppSnackBarType.info, duration: duration);
}
