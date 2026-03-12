import 'package:flutter/material.dart';

import '../services/ErrorReportService.dart';
import '../theme/app_theme.dart';

/// Кнопка «Отправить ошибку» для отправки отчёта об ошибке на бэкенд.
class ErrorReportButton extends StatefulWidget {
  final String errorMessage;
  final String? screen;
  final int? eventId;
  final String? stackTrace;
  final Map<String, dynamic>? extra;

  const ErrorReportButton({
    super.key,
    required this.errorMessage,
    this.screen,
    this.eventId,
    this.stackTrace,
    this.extra,
  });

  @override
  State<ErrorReportButton> createState() => _ErrorReportButtonState();
}

class _ErrorReportButtonState extends State<ErrorReportButton> {
  bool _isSending = false;
  bool _sent = false;

  Future<void> _onSend() async {
    if (_isSending || _sent) return;
    setState(() => _isSending = true);
    try {
      final ok = await ErrorReportService().reportError(
        message: widget.errorMessage,
        screen: widget.screen,
        eventId: widget.eventId,
        stackTrace: widget.stackTrace,
        extra: widget.extra,
      );
      if (mounted) {
        setState(() {
          _isSending = false;
          _sent = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok ? 'Ошибка отправлена' : 'Добавлено в очередь. Отправится при появлении сети.',
              style: unbounded(fontSize: 14),
            ),
            backgroundColor: ok ? Colors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось отправить', style: unbounded(fontSize: 14)),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return Text(
        'Отправлено',
        style: unbounded(fontSize: 13, color: Colors.green.shade300),
      );
    }
    return TextButton.icon(
      onPressed: _isSending ? null : _onSend,
      icon: _isSending
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.mutedGold,
              ),
            )
          : Icon(Icons.bug_report_outlined, size: 16, color: AppColors.mutedGold),
      label: Text(
        _isSending ? 'Отправка...' : 'Отправить ошибку',
        style: unbounded(fontSize: 13, color: AppColors.mutedGold),
      ),
    );
  }
}
