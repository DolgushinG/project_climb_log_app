import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:login_app/main.dart';

/// Статус премиум-подписки и пробного периода.
class PremiumStatus {
  final bool hasActiveSubscription;
  final int trialDaysLeft;
  final DateTime? trialEndsAt;
  /// true — пользователь уже нажал «Начать пробный» (бэкенд запомнил, второй раз нельзя).
  final bool trialStarted;
  /// Подписка активна до (для «остаток N дней» в профиле).
  final DateTime? subscriptionEndsAt;
  /// true — пользователь отменил подписку, доступ до конца периода.
  final bool subscriptionCancelled;

  PremiumStatus({
    required this.hasActiveSubscription,
    required this.trialDaysLeft,
    this.trialEndsAt,
    this.trialStarted = true,
    this.subscriptionEndsAt,
    this.subscriptionCancelled = false,
  });

  bool get isInTrial => trialDaysLeft > 0 && !hasActiveSubscription;
  bool get hasAccess => hasActiveSubscription || isInTrial;
  bool get trialEndsIn3OrLess =>
      trialEndsAt != null &&
      !hasActiveSubscription &&
      trialDaysLeft > 0 &&
      trialDaysLeft <= 3;
  int? get subscriptionDaysLeft {
    if (subscriptionEndsAt == null || !hasActiveSubscription) return null;
    final days = subscriptionEndsAt!.difference(DateTime.now()).inDays;
    return days > 0 ? days : 0;
  }
}

/// Один платёж из истории.
class PremiumPayment {
  final String orderId;
  final double amount;
  final String currency;
  final String status; // paid, pending, failed
  final DateTime createdAt;
  final DateTime? paidAt;

  PremiumPayment({
    required this.orderId,
    required this.amount,
    this.currency = 'RUB',
    required this.status,
    required this.createdAt,
    this.paidAt,
  });
}

/// Сервис премиум-подписки на раздел тренировок.
/// Пробный период — 7 дней. Оплата через PayAnyWay (MONETA.RU).
class PremiumSubscriptionService {
  static const String _keyTrialStart = 'premium_trial_start_iso';
  static const int trialDaysTotal = 7;

  Future<PremiumStatus> getStatus() async {
    try {
      final token = await getToken();
      if (token != null) {
        final status = await _fetchFromBackend(token);
        if (status != null) return status;
      }
    } catch (_) {
      // Fallback to local
    }
    return _getLocalStatus();
  }

  Future<PremiumStatus?> _fetchFromBackend(String token) async {
    try {
      final resp = await http.get(
        Uri.parse('$DOMAIN/api/premium/status'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>?;
        if (data == null) return null;
        return PremiumStatus(
          hasActiveSubscription: data['has_active_subscription'] == true,
          trialDaysLeft: (data['trial_days_left'] as num?)?.toInt() ?? 0,
          trialEndsAt: data['trial_ends_at'] != null
              ? DateTime.tryParse(data['trial_ends_at'].toString())
              : null,
          trialStarted: data['trial_started'] != false,
          subscriptionEndsAt: data['subscription_ends_at'] != null
              ? DateTime.tryParse(data['subscription_ends_at'].toString())
              : null,
          subscriptionCancelled: data['subscription_cancelled'] == true,
        );
      }
    } catch (_) {}
    return null;
  }

  Future<PremiumStatus> _getLocalStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final startStr = prefs.getString(_keyTrialStart);
    DateTime trialStart;
    if (startStr == null || startStr.isEmpty) {
      trialStart = DateTime.now().toUtc();
      await prefs.setString(_keyTrialStart, trialStart.toIso8601String());
    } else {
      trialStart = DateTime.parse(startStr);
    }
    final now = DateTime.now().toUtc();
    final end = trialStart.add(const Duration(days: trialDaysTotal));
    int daysLeft = end.difference(now).inDays;
    if (daysLeft < 0) daysLeft = 0;
    return PremiumStatus(
      hasActiveSubscription: false,
      trialDaysLeft: daysLeft,
      trialEndsAt: end,
      trialStarted: true,
    );
  }

  /// Вызывать при первом входе на страницу тренировок — стартует пробный период локально (fallback).
  Future<void> ensureTrialStarted() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_keyTrialStart) == null) {
      await prefs.setString(
        _keyTrialStart,
        DateTime.now().toUtc().toIso8601String(),
      );
    }
  }

  /// POST /api/premium/start-trial — активация пробного периода по нажатию пользователя.
  /// Бэкенд запоминает: второй раз вернёт 400 (пробный уже использован).
  Future<bool> startTrial() async {
    final token = await getToken();
    if (token == null) return false;
    try {
      final resp = await http.post(
        Uri.parse('$DOMAIN/api/premium/start-trial'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: '{}',
      );
      return resp.statusCode == 200 || resp.statusCode == 201;
    } catch (_) {}
    return false;
  }

  /// Регистрирует заказ на бэкенде перед открытием PayAnyWay.
  /// Бэкенд сохраняет (order_id, user_id) — когда придёт webhook, активирует подписку.
  /// Returns order_id или null при ошибке.
  Future<String?> registerOrder(String token, {required double amount, String currency = 'RUB'}) async {
    try {
      final resp = await http.post(
        Uri.parse('$DOMAIN/api/premium/register-order'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: '{"amount": $amount, "currency": "$currency"}',
      );
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>?;
        return data?['order_id']?.toString();
      }
    } catch (_) {}
    return null;
  }

  /// POST /api/premium/cancel-subscription — отмена подписки.
  /// [reason] — причина отмены (код для аналитики).
  Future<bool> cancelSubscription({String? reason}) async {
    final token = await getToken();
    if (token == null) return false;
    try {
      final body = reason != null && reason.isNotEmpty
          ? jsonEncode({'cancel_reason': reason})
          : '{}';
      final resp = await http.post(
        Uri.parse('$DOMAIN/api/premium/cancel-subscription'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: body,
      );
      return resp.statusCode == 200;
    } catch (_) {}
    return false;
  }

  /// GET /api/premium/payment-history — история платежей пользователя.
  Future<List<PremiumPayment>> getPaymentHistory() async {
    final token = await getToken();
    if (token == null) return [];
    try {
      final resp = await http.get(
        Uri.parse('$DOMAIN/api/premium/payment-history'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>?;
        final list = data?['payments'] as List?;
        if (list == null) return [];
        return list.map((e) {
          final m = e as Map<String, dynamic>;
          return PremiumPayment(
            orderId: m['order_id']?.toString() ?? '',
            amount: (m['amount'] as num?)?.toDouble() ?? 0,
            currency: m['currency']?.toString() ?? 'RUB',
            status: m['status']?.toString() ?? 'pending',
            createdAt: m['created_at'] != null
                ? DateTime.tryParse(m['created_at'].toString()) ?? DateTime.now()
                : DateTime.now(),
            paidAt: m['paid_at'] != null
                ? DateTime.tryParse(m['paid_at'].toString())
                : null,
          );
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Создать платёж — возвращает URL для перехода в WebView/браузер.
  /// Backend должен вернуть payment_url от PayAnyWay.
  Future<String?> createPayment(String token) async {
    try {
      final resp = await http.post(
        Uri.parse('$DOMAIN/api/premium/create-payment'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: '{}',
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>?;
        return data?['payment_url']?.toString();
      }
    } catch (_) {}
    return null;
  }
}
