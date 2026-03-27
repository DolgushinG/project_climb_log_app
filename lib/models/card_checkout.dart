/// Поля `card_checkout_*` в ответах checkout / group-checkout (и смежных API).

enum CardPaymentProvider {
  tbank,
  tochka,
}

extension CardPaymentProviderX on CardPaymentProvider {
  String get apiPathSegment => switch (this) {
        CardPaymentProvider.tbank => 'tbank',
        CardPaymentProvider.tochka => 'tochka',
      };
}

/// Показывать ли онлайн-оплату картой: новое поле или обратная совместимость с `tbank_checkout_available`.
bool isCardCheckoutAvailable(Map<String, dynamic>? data) {
  if (data == null) return false;
  final c = data['card_checkout_available'];
  if (c == true || c == 1) return true;
  final t = data['tbank_checkout_available'];
  return t == true || t == 1;
}

/// Какой провайдер вызывать для `POST/GET .../payment/{provider}/...`.
CardPaymentProvider resolveCardPaymentProvider(Map<String, dynamic>? data) {
  final raw = data?['card_checkout_provider']?.toString().trim().toLowerCase();
  if (raw == 'tochka') return CardPaymentProvider.tochka;
  if (raw == 'tbank') return CardPaymentProvider.tbank;
  final tbank = data?['tbank_checkout_available'] == true || data?['tbank_checkout_available'] == 1;
  if (tbank) return CardPaymentProvider.tbank;
  final cardAvail = data?['card_checkout_available'] == true || data?['card_checkout_available'] == 1;
  if (cardAvail && !tbank) return CardPaymentProvider.tochka;
  return CardPaymentProvider.tbank;
}
