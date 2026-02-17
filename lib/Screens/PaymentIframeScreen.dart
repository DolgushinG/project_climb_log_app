import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login_app/theme/app_theme.dart';

import 'payment_iframe_stub.dart'
    if (dart.library.html) 'payment_iframe_web.dart' as impl;

/// Экран с формой оплаты PayAnyWay внутри приложения (web/PWA).
/// Использует iframe — если Moneta блокирует встраивание (X-Frame-Options), будет пустой экран.
class PaymentIframeScreen extends StatelessWidget {
  final String paymentUrl;

  const PaymentIframeScreen({super.key, required this.paymentUrl});

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
      body: impl.buildPaymentIframe(paymentUrl),
    );
  }
}
