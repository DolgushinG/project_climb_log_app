import 'dart:io';
import 'package:flutter/services.dart';

/// Вызов нативного PayAnyWay SDK (MONETA.RU) на Android.
/// Использует Method Channel для запуска PayAnyWayActivity с WebView.
class PayAnyWayNativeService {
  static const MethodChannel _channel = MethodChannel('com.climbingevents.app/payanyway');

  /// Показывает платёжную форму в нативном WebView.
  /// Только Android. На iOS возвращает false.
  static Future<bool> showPayment({
    String? orderId,
    required double amount,
    String currency = 'RUB',
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('showPayment', {
        if (orderId != null) 'orderId': orderId,
        'amount': amount,
        'currency': currency,
      });
      return result == true;
    } on PlatformException catch (_) {
      return false;
    }
  }
}
