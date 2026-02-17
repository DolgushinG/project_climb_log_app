import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login_app/theme/app_theme.dart';

import 'payment_iframe_stub.dart'
    if (dart.library.html) 'payment_iframe_web.dart' as impl;

/// Экран с формой оплаты PayAnyWay внутри приложения (web/PWA).
/// Использует iframe — если Moneta блокирует встраивание (X-Frame-Options), будет пустой экран.
/// При редиректе на /premium/success или /premium/fail — лёгкие HTML-страницы шлют postMessage и закрывают экран.
class PaymentIframeScreen extends StatefulWidget {
  final String paymentUrl;

  const PaymentIframeScreen({super.key, required this.paymentUrl});

  @override
  State<PaymentIframeScreen> createState() => _PaymentIframeScreenState();
}

class _PaymentIframeScreenState extends State<PaymentIframeScreen> {
  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      impl.setupPaymentMessageListener(_onPaymentResult);
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      impl.disposePaymentMessageListener();
    }
    super.dispose();
  }

  void _onPaymentResult(bool success) {
    if (!mounted) return;
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
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Text(
          'Оплата подписки',
          style: GoogleFonts.unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      body: impl.buildPaymentIframe(widget.paymentUrl),
    );
  }
}
