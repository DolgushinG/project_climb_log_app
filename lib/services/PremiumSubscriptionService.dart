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
  /// true — не удалось получить статус (нет интернета). Показать «Проверьте подключение», не «Оформите подписку».
  final bool networkUnavailable;

  PremiumStatus({
    required this.hasActiveSubscription,
    required this.trialDaysLeft,
    this.trialEndsAt,
    this.trialStarted = true,
    this.subscriptionEndsAt,
    this.subscriptionCancelled = false,
    this.networkUnavailable = false,
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
  /// Можно ли запросить возврат по этому платежу.
  final bool canRequestRefund;
  /// Заявка на возврат уже создана.
  final bool refundRequested;
  /// Статус заявки: pending, approved, rejected, completed.
  final String? refundStatus;

  PremiumPayment({
    required this.orderId,
    required this.amount,
    this.currency = 'RUB',
    required this.status,
    required this.createdAt,
    this.paidAt,
    this.canRequestRefund = false,
    this.refundRequested = false,
    this.refundStatus,
  });
}

/// Предпросмотр возврата до создания заявки.
class RefundPreview {
  final String orderId;
  final int daysUsed;
  final int daysTotal;
  final int daysRemaining;
  final double refundAmountRub;

  RefundPreview({
    required this.orderId,
    required this.daysUsed,
    required this.daysTotal,
    required this.daysRemaining,
    required this.refundAmountRub,
  });
}

/// Сервис премиум-подписки на раздел тренировок.
/// Пробный период — 7 дней. Оплата через PayAnyWay (MONETA.RU).
class PremiumSubscriptionService {
  static const String _keyTrialStart = 'premium_trial_start_iso';
  static const String _keyStatusCache = 'premium_status_cache';
  static const int trialDaysTotal = 7;
  /// Кэш статуса: использовать при отсутствии сети. TTL 24 часа.
  static const Duration _cacheTtl = Duration(hours: 24);

  Future<PremiumStatus> getStatus() async {
    try {
      final token = await getToken();
      if (token != null) {
        final status = await _fetchFromBackend(token);
        if (status != null) {
          _saveStatusCache(status);
          return status;
        }
      }
    } catch (_) {
      // Сеть недоступна — не показывать «оформите подписку», использовать кэш или оптимистичный статус
    }
    final cached = await _getStatusCache();
    if (cached != null) return cached;
    /// Нет кэша — честно показываем «Нет подключения к интернету».
    return PremiumStatus(
      hasActiveSubscription: false,
      trialDaysLeft: 0,
      trialStarted: true,
      networkUnavailable: true,
    );
  }

  void _saveStatusCache(PremiumStatus s) {
    SharedPreferences.getInstance().then((prefs) {
      final json = {
        'has_active_subscription': s.hasActiveSubscription,
        'trial_days_left': s.trialDaysLeft,
        'trial_ends_at': s.trialEndsAt?.toIso8601String(),
        'trial_started': s.trialStarted,
        'subscription_ends_at': s.subscriptionEndsAt?.toIso8601String(),
        'subscription_cancelled': s.subscriptionCancelled,
        'cached_at': DateTime.now().toUtc().toIso8601String(),
      };
      prefs.setString(_keyStatusCache, jsonEncode(json));
    });
  }

  Future<PremiumStatus?> _getStatusCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyStatusCache);
      if (raw == null || raw.isEmpty) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>?;
      if (json == null) return null;
      final cachedAt = json['cached_at']?.toString();
      if (cachedAt != null) {
        final at = DateTime.tryParse(cachedAt);
        if (at != null && DateTime.now().toUtc().difference(at) > _cacheTtl) return null;
      }
      return PremiumStatus(
        hasActiveSubscription: json['has_active_subscription'] == true,
        trialDaysLeft: (json['trial_days_left'] as num?)?.toInt() ?? 0,
        trialEndsAt: json['trial_ends_at'] != null ? DateTime.tryParse(json['trial_ends_at'].toString()) : null,
        trialStarted: json['trial_started'] != false,
        subscriptionEndsAt: json['subscription_ends_at'] != null ? DateTime.tryParse(json['subscription_ends_at'].toString()) : null,
        subscriptionCancelled: json['subscription_cancelled'] == true,
      );
    } catch (_) {}
    return null;
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
  /// [email] — обязателен для чека самозанятого (PayAnyWay отправит его на этот адрес).
  /// Returns order_id или null при ошибке.
  Future<String?> registerOrder(
    String token, {
    required double amount,
    required String email,
    String currency = 'RUB',
    String? successUrl,
    String? failUrl,
  }) async {
    try {
      final body = <String, dynamic>{
        'amount': amount,
        'currency': currency,
        'email': email,
      };
      if (successUrl != null && successUrl.isNotEmpty) body['success_url'] = successUrl;
      if (failUrl != null && failUrl.isNotEmpty) body['fail_url'] = failUrl;
      final resp = await http.post(
        Uri.parse('$DOMAIN/api/premium/register-order'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
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
            canRequestRefund: m['can_request_refund'] == true,
            refundRequested: m['refund_requested'] == true,
            refundStatus: m['refund_status']?.toString(),
          );
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  /// GET /api/premium/refund-preview — расчёт возврата до создания заявки.
  Future<RefundPreview?> getRefundPreview(String orderId) async {
    final token = await getToken();
    if (token == null) return null;
    try {
      final uri = Uri.parse('$DOMAIN/api/premium/refund-preview')
          .replace(queryParameters: {'order_id': orderId});
      final resp = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>?;
        if (data == null) return null;
        return RefundPreview(
          orderId: data['order_id']?.toString() ?? orderId,
          daysUsed: (data['days_used'] as num?)?.toInt() ?? 0,
          daysTotal: (data['days_total'] as num?)?.toInt() ?? 30,
          daysRemaining: (data['days_remaining'] as num?)?.toInt() ?? 0,
          refundAmountRub: (data['refund_amount_rub'] as num?)?.toDouble() ?? 0,
        );
      }
    } catch (_) {}
    return null;
  }

  /// POST /api/premium/request-refund — создание заявки на возврат.
  /// Returns message или null при ошибке.
  Future<String?> requestRefund({
    required String orderId,
    String? reason,
  }) async {
    final token = await getToken();
    if (token == null) return null;
    try {
      final body = <String, dynamic>{'order_id': orderId};
      if (reason != null && reason.isNotEmpty) body['reason'] = reason;
      final resp = await http.post(
        Uri.parse('$DOMAIN/api/premium/request-refund'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>?;
        return data?['message']?.toString() ??
            'Заявка создана. Возврат будет выполнен в течение 10 рабочих дней.';
      }
    } catch (_) {}
    return null;
  }

  /// Создать платёж — возвращает URL для перехода в WebView/браузер.
  /// [email] — обязателен для чека самозанятого.
  /// Backend должен вернуть payment_url от PayAnyWay.
  Future<String?> createPayment(
    String token, {
    required String email,
    double amount = 199,
    String currency = 'RUB',
    String? successUrl,
    String? failUrl,
  }) async {
    final url = '$DOMAIN/api/premium/create-payment';
    final body = <String, dynamic>{
      'amount': amount,
      'currency': currency,
      'email': email,
    };
    if (successUrl != null && successUrl.isNotEmpty) body['success_url'] = successUrl;
    if (failUrl != null && failUrl.isNotEmpty) body['fail_url'] = failUrl;
    try {
      final resp = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>?;
        return data?['payment_url']?.toString();
      }
      return null;
    } catch (_) {}
    return null;
  }
}
