import 'package:flutter/material.dart';

Widget buildPaymentIframe(String paymentUrl) {
  return Center(
    child: Text(
      'iframe только для web',
      style: TextStyle(color: Colors.white70),
    ),
  );
}

/// Подписка на postMessage от iframe (success/fail). Только web, на других платформах no-op.
void setupPaymentMessageListener(void Function(bool success) onResult) {}

/// Отписаться от postMessage. Только web.
void disposePaymentMessageListener() {}
