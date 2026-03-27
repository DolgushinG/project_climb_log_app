/// Редиректы бэкенда после оплаты (T‑Банк / Точка) внутри WebView или iframe.
bool? parsePaymentReturnUrl(String url) {
  try {
    final uri = Uri.parse(url);
    final p = uri.path.toLowerCase();
    if (p.contains('/payment/tbank/success') || p.contains('/payment/tochka/success')) {
      return true;
    }
    if (p.contains('/payment/tbank/fail') || p.contains('/payment/tochka/fail')) {
      return false;
    }
  } catch (_) {}
  return null;
}
