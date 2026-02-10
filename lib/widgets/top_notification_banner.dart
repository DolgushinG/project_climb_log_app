import 'package:flutter/material.dart';

/// Отступы по умолчанию для баннера (можно менять под дизайн).
const double kTopNotificationHorizontalMargin = 12.0;
const double kTopNotificationTopMargin = 8.0;
const double kTopNotificationPadding = 14.0;
const double kTopNotificationRadius = 12.0;
const double kTopNotificationElevation = 6.0;

/// Верхнее уведомление в стиле пуш-сообщения: скруглённая плашка с отступами от краёв.
class TopNotificationBanner extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final Color textColor;
  final bool showCloseButton;
  final VoidCallback? onClose;
  final Widget? trailing;
  /// Использовать SafeArea (true для баннера поверх всего экрана, false внутри контента).
  final bool useSafeArea;
  /// На всю ширину (без боковых отступов).
  final bool fullWidth;

  const TopNotificationBanner({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.backgroundColor = const Color(0xFF1C1917),
    this.iconColor = Colors.white70,
    this.textColor = Colors.white,
    this.showCloseButton = true,
    this.onClose,
    this.trailing,
    this.useSafeArea = true,
    this.fullWidth = false,
  });

  /// Офлайн: нет сети.
  factory TopNotificationBanner.offline({
    Key? key,
    required String message,
    VoidCallback? onClose,
  }) {
    return TopNotificationBanner(
      key: key,
      message: message,
      icon: Icons.wifi_off_rounded,
      backgroundColor: const Color(0xFF9A3412),
      iconColor: Colors.white,
      textColor: Colors.white,
      onClose: onClose,
    );
  }

  /// Ошибка / предупреждение (оранжевый тон).
  factory TopNotificationBanner.warning({
    Key? key,
    required String message,
    Widget? trailing,
    VoidCallback? onClose,
  }) {
    return TopNotificationBanner(
      key: key,
      message: message,
      icon: Icons.wifi_off_rounded,
      backgroundColor: const Color(0xFF78350F),
      iconColor: Colors.orange.shade200,
      textColor: Colors.white,
      trailing: trailing,
      onClose: onClose,
    );
  }

  /// Информация (нейтральный, например «данные из кэша»).
  factory TopNotificationBanner.info({
    Key? key,
    required String message,
    Widget? trailing,
    VoidCallback? onClose,
  }) {
    return TopNotificationBanner(
      key: key,
      message: message,
      icon: Icons.cloud_done_outlined,
      backgroundColor: const Color(0xFF27272A),
      iconColor: Colors.white70,
      textColor: Colors.white70,
      trailing: trailing,
      onClose: onClose,
    );
  }

  @override
  Widget build(BuildContext context) {
    final horizontalMargin = fullWidth ? 0.0 : kTopNotificationHorizontalMargin;
    final content = Padding(
      padding: EdgeInsets.only(
        left: horizontalMargin,
        right: horizontalMargin,
        top: kTopNotificationTopMargin,
      ),
      child: Material(
          elevation: kTopNotificationElevation,
          shadowColor: Colors.black45,
          borderRadius: BorderRadius.circular(kTopNotificationRadius),
          color: backgroundColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: kTopNotificationPadding,
              vertical: kTopNotificationPadding,
            ),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
                if (showCloseButton && onClose != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textColor.withOpacity(0.8), size: 20),
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    return useSafeArea
        ? SafeArea(bottom: false, child: content)
        : content;
  }
}
