import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:login_app/main.dart';

/// Статус премиум-подписки и пробного периода.
class PremiumStatus {
  final bool hasActiveSubscription;
  final int trialDaysLeft;
  final DateTime? trialEndsAt;

  PremiumStatus({
    required this.hasActiveSubscription,
    required this.trialDaysLeft,
    this.trialEndsAt,
  });

  bool get isInTrial => trialDaysLeft > 0 && !hasActiveSubscription;
  bool get hasAccess => hasActiveSubscription || isInTrial;
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
    );
  }

  /// Вызывать при первом входе на страницу тренировок — стартует пробный период.
  Future<void> ensureTrialStarted() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_keyTrialStart) == null) {
      await prefs.setString(
        _keyTrialStart,
        DateTime.now().toUtc().toIso8601String(),
      );
    }
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
