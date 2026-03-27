import 'dart:convert';

import 'package:http/http.dart' as http;

import '../main.dart';
import '../utils/network_error_helper.dart';

/// Scope для [TbankEventPaymentService.init].
enum TbankPaymentScope {
  individual,
  group,
}

String _scopeJson(TbankPaymentScope scope) {
  switch (scope) {
    case TbankPaymentScope.individual:
      return 'individual';
    case TbankPaymentScope.group:
      return 'group';
  }
}

/// Результат `POST .../payment/tbank/init`.
class TbankEventPaymentInitResult {
  final String? paymentUrl;
  /// Для `GET .../payment/tbank/status?order_id=` (polling после оплаты).
  final String? orderId;
  final int statusCode;
  final String userMessage;
  final bool needsAuthRedirect;

  const TbankEventPaymentInitResult._({
    this.paymentUrl,
    this.orderId,
    required this.statusCode,
    required this.userMessage,
    this.needsAuthRedirect = false,
  });

  factory TbankEventPaymentInitResult.success(String paymentUrl, {String? orderId}) {
    return TbankEventPaymentInitResult._(
      paymentUrl: paymentUrl,
      orderId: orderId,
      statusCode: 200,
      userMessage: '',
    );
  }

  factory TbankEventPaymentInitResult.failure({
    required int statusCode,
    required String userMessage,
    bool needsAuthRedirect = false,
  }) {
    return TbankEventPaymentInitResult._(
      statusCode: statusCode,
      userMessage: userMessage,
      needsAuthRedirect: needsAuthRedirect,
    );
  }

  bool get isSuccess => paymentUrl != null && paymentUrl!.isNotEmpty;
}

/// Инициализация оплаты T‑Банк для события (Bearer API).
class TbankEventPaymentService {
  TbankEventPaymentService._();

  /// Текст ошибки из JSON (Laravel: message / errors; кастом: error строкой или объектом).
  static String? _messageFromBody(String body) {
    if (body.isEmpty) return null;
    try {
      final raw = jsonDecode(body);
      if (raw is Map) {
        // Laravel validation: { "message": "...", "errors": { "field": ["..."] } }
        final errors = raw['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final parts = <String>[];
          for (final v in errors.values) {
            if (v is List) {
              for (final item in v) {
                if (item != null && item.toString().isNotEmpty) parts.add(item.toString());
              }
            } else if (v != null && v.toString().isNotEmpty) {
              parts.add(v.toString());
            }
          }
          if (parts.isNotEmpty) return parts.join(' ');
        }
        final errField = raw['error'];
        if (errField is String && errField.isNotEmpty) return errField;
        if (errField is List && errField.isNotEmpty) {
          final first = errField.first;
          if (first != null && first.toString().isNotEmpty) return first.toString();
        }
        if (errField is Map) {
          final nested = errField['message'] ?? errField['error'];
          if (nested != null && nested.toString().isNotEmpty) return nested.toString();
        }
        final m = raw['message'] ?? raw['detail'];
        if (m != null) {
          final s = m.toString();
          if (s.isEmpty) return null;
          if (s == 'The given data was invalid.') return null;
          return s;
        }
      }
    } catch (_) {}
    return null;
  }

  static String _defaultMessage(int statusCode) {
    switch (statusCode) {
      case 401:
        return 'Сессия истекла. Войдите снова.';
      case 403:
        return 'Онлайн-оплата недоступна или интеграция не настроена.';
      case 404:
        return 'Событие или регистрация не найдены.';
      case 422:
        return 'Не удалось начать оплату. Проверьте состав группы, пакеты участников и настройки события.';
      case 502:
        return 'Не удалось создать платёж. Попробуйте позже.';
      default:
        return 'Не удалось начать оплату. Попробуйте позже.';
    }
  }

  /// [token] — JWT; при null вернётся ошибка.
  ///
  /// **Групповая оплата** (один плательщик за нескольких): передайте [groupPayment] = true,
  /// [participantUserIds] — id участников из `group-checkout` (обычно неоплаченные),
  /// при наличии — [groupRegistrationId] из ответа group-checkout.
  ///
  /// **Веб (PWA, в т.ч. iOS Safari):** [clientOrigin] — `Uri.base.origin` SPA (например `https://app.climbing-events.ru`).
  /// Нужен бэкенду, чтобы success/fail редиректы T‑Банка вели на тот же origin, где открыто приложение
  /// (иначе после оплаты открывается другой домен → «логин», пока в исходной вкладке уже «оплачено»).
  static Future<TbankEventPaymentInitResult> init({
    required int eventId,
    required TbankPaymentScope scope,
    required String? token,
    bool groupPayment = false,
    List<int>? participantUserIds,
    int? groupRegistrationId,
    String? clientOrigin,
  }) async {
    if (token == null || token.isEmpty) {
      return TbankEventPaymentInitResult.failure(
        statusCode: 401,
        userMessage: _defaultMessage(401),
        needsAuthRedirect: true,
      );
    }
    final uri = Uri.parse('$DOMAIN/api/event/$eventId/payment/tbank/init');
    final body = <String, dynamic>{
      'scope': _scopeJson(scope),
    };
    if (groupPayment) {
      body['group_payment'] = true;
    }
    if (groupRegistrationId != null) {
      body['group_registration_id'] = groupRegistrationId;
    }
    if (participantUserIds != null && participantUserIds.isNotEmpty) {
      body['participant_user_ids'] = participantUserIds;
    }
    final origin = clientOrigin?.trim();
    if (origin != null && origin.isNotEmpty) {
      body['client_origin'] = origin;
    }
    try {
      final r = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      if (r.statusCode == 200) {
        dynamic raw;
        try {
          raw = r.body.isNotEmpty ? jsonDecode(r.body) : null;
        } catch (_) {
          raw = null;
        }
        if (raw is Map) {
          final url = raw['payment_url']?.toString();
          final orderId = raw['order_id']?.toString();
          if (url != null && url.isNotEmpty) {
            return TbankEventPaymentInitResult.success(url, orderId: orderId);
          }
        }
        return TbankEventPaymentInitResult.failure(
          statusCode: r.statusCode,
          userMessage: _messageFromBody(r.body) ?? 'Некорректный ответ сервера.',
        );
      }
      if (r.statusCode == 401) {
        return TbankEventPaymentInitResult.failure(
          statusCode: 401,
          userMessage: _messageFromBody(r.body) ?? _defaultMessage(401),
          needsAuthRedirect: true,
        );
      }
      final fromBody = _messageFromBody(r.body);
      return TbankEventPaymentInitResult.failure(
        statusCode: r.statusCode,
        userMessage: fromBody ?? _defaultMessage(r.statusCode),
      );
    } catch (e) {
      return TbankEventPaymentInitResult.failure(
        statusCode: 0,
        userMessage: networkErrorMessage(e, 'Не удалось связаться с сервером'),
      );
    }
  }

  /// Один запрос `GET .../payment/tbank/status?order_id=`.
  /// При 200: `paid == true` — оплачено; `bank.status` в терминальном отказе (REJECTED и т.д.) — [TbankStatusOnceResult.paymentFailed].
  /// 401 — needsAuthRedirect, 404 — notFound.
  static Future<TbankStatusOnceResult> fetchStatusOnce({
    required int eventId,
    required String orderId,
    required String? token,
  }) async {
    if (token == null || token.isEmpty) {
      return TbankStatusOnceResult(needsAuthRedirect: true);
    }
    final uri = Uri.parse('$DOMAIN/api/event/$eventId/payment/tbank/status').replace(
      queryParameters: {'order_id': orderId},
    );
    try {
      final r = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (r.statusCode == 200) {
        dynamic raw;
        try {
          raw = r.body.isNotEmpty ? jsonDecode(r.body) : null;
        } catch (_) {
          raw = null;
        }
        if (raw is! Map) {
          return TbankStatusOnceResult(paid: false);
        }
        final paid = raw['paid'] == true;
        final bank = raw['bank'];
        String? bankStatus;
        String? statusLabel;
        if (bank is Map) {
          bankStatus = bank['status']?.toString();
          statusLabel = bank['status_label']?.toString();
        }
        final bankErr = raw['bank_error'];
        String? bankErrorStr;
        if (bankErr is String && bankErr.trim().isNotEmpty) {
          bankErrorStr = bankErr.trim();
        }
        final terminalFailure = !paid && _isTerminalBankFailureStatus(bankStatus);
        String? failureMessage;
        if (terminalFailure) {
          final parts = <String>[];
          if (statusLabel != null && statusLabel.trim().isNotEmpty) {
            parts.add(statusLabel.trim());
          } else if (bankStatus != null && bankStatus.trim().isNotEmpty) {
            parts.add('Статус банка: ${bankStatus.trim()}');
          }
          if (bankErrorStr != null) parts.add(bankErrorStr);
          failureMessage = parts.isEmpty ? 'Оплата не прошла.' : parts.join('\n');
        }
        return TbankStatusOnceResult(
          paid: paid,
          paymentFailed: terminalFailure,
          failureMessage: failureMessage,
        );
      }
      if (r.statusCode == 401) {
        return TbankStatusOnceResult(needsAuthRedirect: true);
      }
      if (r.statusCode == 404) {
        return TbankStatusOnceResult(notFound: true);
      }
      return TbankStatusOnceResult(paid: false);
    } catch (e) {
      return TbankStatusOnceResult(networkError: true);
    }
  }

  /// Терминальные статусы банка: оплата не будет завершена (отлично от pending/ожидания).
  static bool _isTerminalBankFailureStatus(String? status) {
    if (status == null || status.trim().isEmpty) return false;
    const failures = {
      'REJECTED',
      'CANCELLED',
      'FAILED',
      'DECLINED',
      'REVOKED',
      'DEADLINE_EXPIRED',
    };
    return failures.contains(status.trim().toUpperCase());
  }
}

/// Снимок ответа status (для одного шага polling).
class TbankStatusOnceResult {
  final bool? paid;
  /// Банк вернул финальный отказ (например REJECTED), [paid] == false.
  final bool paymentFailed;
  final String? failureMessage;
  final bool needsAuthRedirect;
  final bool notFound;
  final bool networkError;

  TbankStatusOnceResult({
    this.paid,
    this.paymentFailed = false,
    this.failureMessage,
    this.needsAuthRedirect = false,
    this.notFound = false,
    this.networkError = false,
  });

  bool get isPaid => paid == true;
}
