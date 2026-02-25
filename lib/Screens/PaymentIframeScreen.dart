import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/services/PremiumSubscriptionService.dart';

import 'payment_iframe_stub.dart'
    if (dart.library.html) 'payment_iframe_web.dart' as impl;

/// Экран с формой оплаты PayAnyWay внутри приложения (web/PWA).
/// Использует iframe — если Moneta блокирует встраивание (X-Frame-Options), будет пустой экран.
/// Два способа узнать об успехе: postMessage от /premium/success + polling GET /api/premium/status.
class PaymentIframeScreen extends StatefulWidget {
  final String paymentUrl;

  const PaymentIframeScreen({super.key, required this.paymentUrl});

  @override
  State<PaymentIframeScreen> createState() => _PaymentIframeScreenState();
}

class _PaymentIframeScreenState extends State<PaymentIframeScreen> {
  Timer? _pollTimer;
  DateTime? _pollStartedAt;
  static const _pollInterval = Duration(milliseconds: 2500);
  static const _pollTimeout = Duration(minutes: 10);
  final PremiumSubscriptionService _premiumService = PremiumSubscriptionService();

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      impl.setupPaymentMessageListener(_onPaymentResult);
      _startPolling();
    }
  }

  /// Fallback: postMessage из iframe может не сработать (редирект в новом окне и т.п.).
  /// Опрашиваем API раз в 2.5 сек — webhook обновляет подписку при успешной оплате.
  /// Таймаут 10 мин — затем просто перестаём опрашивать, пользователь может закрыть вручную.
  void _startPolling() {
    _pollTimer?.cancel();
    _pollStartedAt = DateTime.now();
    _pollTimer = Timer.periodic(_pollInterval, (_) async {
      if (!mounted) return;
      if (DateTime.now().difference(_pollStartedAt!) > _pollTimeout) {
        _pollTimer?.cancel();
        return;
      }
      final status = await _premiumService.getStatus();
      if (!mounted) return;
      if (status.hasActiveSubscription) {
        _pollTimer?.cancel();
        await _premiumService.invalidateStatusCache();
        _onPaymentResult(true);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    if (kIsWeb) {
      impl.disposePaymentMessageListener();
    }
    super.dispose();
  }

  void _onPaymentResult(bool success) {
    if (!mounted) return;
    _pollTimer?.cancel();
    Navigator.pop(context, success);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.anthracite,
      appBar: AppBar(
        backgroundColor: AppColors.anthracite,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () async {
            // При ручном закрытии проверяем: оплатил ли пользователь (webhook мог успеть).
            // Если подписка активна — success, иначе — отмена.
            final status = await _premiumService.getStatus();
            if (!mounted) return;
            Navigator.pop(context, status.hasActiveSubscription);
          },
        ),
        title: Text(
          'Оплата подписки',
          style: unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      body: impl.buildPaymentIframe(widget.paymentUrl),
    );
  }
}
