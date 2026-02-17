import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:login_app/main.dart';
import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/services/PremiumSubscriptionService.dart';
import 'package:login_app/services/PayAnyWayNativeService.dart';
import 'package:login_app/Screens/PremiumPaymentHistoryScreen.dart';
import 'package:login_app/Screens/PaymentIframeScreen.dart';

/// URL оферты — публичный договор на премиум-подписку
const String offertaUrl = 'https://climbing-events.ru/offerta-premium';

/// Экран оплаты премиум-подписки.
/// Пояснение, подтверждение, ссылка на оферту, сумма, переход на платёж PayAnyWay.
class PremiumPaymentScreen extends StatefulWidget {
  const PremiumPaymentScreen({super.key});

  @override
  State<PremiumPaymentScreen> createState() => _PremiumPaymentScreenState();
}

/// URL для результата оплаты (PayAnyWay редирект).
/// Web: явно app subdomain (Uri.base.origin), чтобы пользователь вернулся в приложение, а не на основной сайт.
/// Mobile: deep link в нативное приложение.
String get _successUrl =>
    kIsWeb ? '${Uri.base.origin}/premium/success' : 'climbing-events://premium/success';
String get _failUrl =>
    kIsWeb ? '${Uri.base.origin}/premium/fail' : 'climbing-events://premium/fail';

/// Регулярка для валидации email (чек для чека самозанятого).
bool _isValidEmail(String s) {
  if (s.isEmpty) return false;
  final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
  return regex.hasMatch(s.trim());
}

class _PremiumPaymentScreenState extends State<PremiumPaymentScreen> {
  final PremiumSubscriptionService _service = PremiumSubscriptionService();
  final TextEditingController _emailController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  bool _isLoading = false;
  String? _error;
  String? _paymentUrlForCopy;
  PremiumStatus? _premiumStatus;
  bool _statusLoading = true;
  String _buildInfo = '';

  @override
  void initState() {
    super.initState();
    _loadStatus();
    if (kIsWeb) {
      PackageInfo.fromPlatform().then((info) {
        if (mounted) setState(() => _buildInfo = '${info.version}+${info.buildNumber}');
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final status = await _service.getStatus();
    if (mounted) setState(() {
      _premiumStatus = status;
      _statusLoading = false;
    });
  }

  /// Стоимость подписки — из бэкенда (GET /api/premium/status), fallback 199.
  int get _price => _premiumStatus?.subscriptionPriceRub ?? 199;

  String _dayWord(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'день';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) return 'дня';
    return 'дней';
  }

  Future<bool> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      // PWA: вкладок нет. _blank → откроется в системном браузере (Safari).
      // _self → замена экрана (могут блокировать). Пробуем _blank.
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: kIsWeb ? '_blank' : null,
      );
    }
    return false;
  }

  Future<void> _onPayPressed() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Введите email для чека');
      _emailFocusNode.requestFocus();
      return;
    }
    if (!_isValidEmail(email)) {
      setState(() => _error = 'Введите корректный email');
      _emailFocusNode.requestFocus();
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Android: нативный PayAnyWay SDK (WebView в приложении)
      if (!kIsWeb && Platform.isAndroid) {
        final token = await getToken();
        if (token == null) {
          setState(() {
            _error = 'Необходимо войти в аккаунт';
            _isLoading = false;
          });
          return;
        }
        final amount = _price.toDouble();
        final orderId = await _service.registerOrder(
          token,
          amount: amount,
          email: email,
          successUrl: _successUrl,
          failUrl: _failUrl,
        );
        if (orderId == null) {
          setState(() {
            _error = 'Не удалось создать заказ. Проверьте интернет и попробуйте позже.';
            _isLoading = false;
          });
          return;
        }
        final ok = await PayAnyWayNativeService.showPayment(orderId: orderId, amount: amount, currency: 'RUB');
        if (!mounted) return;
        if (ok) {
          Navigator.pop(context, true);
          return;
        }
        // Пользователь нажал «Назад» — остаёмся на экране, не открываем браузер
        setState(() => _isLoading = false);
        return;
      }
      // Fallback: backend возвращает payment_url (или iOS / web / не сконфигурирован SDK)
      final token = await getToken();
      if (token == null) {
        setState(() {
          _error = 'Необходимо войти в аккаунт';
          _isLoading = false;
        });
        return;
      }
      final paymentUrl = await _service.createPayment(
        token,
        email: email,
        amount: _price.toDouble(),
        successUrl: _successUrl,
        failUrl: _failUrl,
      );
      if (!mounted) return;
      if (paymentUrl != null && paymentUrl.isNotEmpty) {
        if (kIsWeb) {
          // Web/PWA: открываем форму оплаты ВНУТРИ приложения через iframe.
          setState(() => _isLoading = false);
          if (!mounted) return;
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => PaymentIframeScreen(paymentUrl: paymentUrl),
              fullscreenDialog: true,
            ),
          );
          if (mounted && result == true) Navigator.pop(context, true);
          return;
        }
        final opened = await _openUrl(paymentUrl);
        if (!mounted) return;
        if (!opened) {
          setState(() {
            _error = 'Не удалось открыть страницу оплаты.';
            _paymentUrlForCopy = paymentUrl;
            _isLoading = false;
          });
          return;
        }
        setState(() => _isLoading = false);
        if (mounted) Navigator.pop(context, true);
      } else {
        setState(() {
          _error = (!kIsWeb && Platform.isAndroid)
              ? 'Настройте PayAnyWay в android/app/src/main/assets/android_basic_settings.ini (monetasdk_account_id)'
              : 'Платёжная система временно недоступна. Попробуйте позже.';
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Ошибка при создании платежа';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.anthracite,
      appBar: AppBar(
        backgroundColor: AppColors.anthracite,
        title: Text(
          'Premium подписка',
          style: GoogleFonts.unbounded(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_buildInfo.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 16),
              child: Text(_buildInfo, style: GoogleFonts.unbounded(fontSize: 11, color: Colors.white38)),
            ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PremiumPaymentHistoryScreen()),
            ),
            child: Text(
              'История',
              style: GoogleFonts.unbounded(color: AppColors.mutedGold, fontSize: 14),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _statusLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.mutedGold))
            : _premiumStatus?.hasActiveSubscription == true
                ? _buildSubscriptionActiveContent()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 24),
                        _buildBenefits(),
                        const SizedBox(height: 24),
                        _buildPriceCard(),
                        const SizedBox(height: 24),
                        _buildOffertaLink(),
                        const SizedBox(height: 24),
                        _buildEmailField(),
                        const SizedBox(height: 24),
                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: Colors.redAccent),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: GoogleFonts.unbounded(color: Colors.redAccent, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_paymentUrlForCopy != null) ...[
                                  const SizedBox(height: 12),
                                  TextButton.icon(
                                    onPressed: () async {
                                      await Clipboard.setData(ClipboardData(text: _paymentUrlForCopy!));
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Ссылка скопирована', style: GoogleFonts.unbounded(color: Colors.white))),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.copy, size: 18, color: AppColors.mutedGold),
                                    label: Text('Скопировать ссылку и открыть в Safari', style: GoogleFonts.unbounded(fontSize: 13, color: AppColors.mutedGold)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        _buildPayButton(),
                      ],
                    ),
                  ),
      ),
    );
  }

  static const List<Map<String, String>> _cancelReasons = [
    {'code': 'expensive', 'label': 'Дорого'},
    {'code': 'rarely_use', 'label': 'Редко пользуюсь'},
    {'code': 'need_other_features', 'label': 'Нужны другие функции'},
    {'code': 'temporary_pause', 'label': 'Временно приостановлю'},
    {'code': 'other', 'label': 'Другое'},
    {'code': 'prefer_not_say', 'label': 'Не хочу указывать'},
  ];

  Future<void> _onCancelSubscriptionPressed() async {
    String? reasonCode;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            backgroundColor: AppColors.cardDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Почему отменяете подписку?',
              style: GoogleFonts.unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ..._cancelReasons.map((r) => RadioListTile<String>(
                    title: Text(
                      r['label']!,
                      style: GoogleFonts.unbounded(fontSize: 14, color: Colors.white),
                    ),
                    value: r['code']!,
                    groupValue: reasonCode,
                    onChanged: (v) => setState(() => reasonCode = v),
                    activeColor: AppColors.mutedGold,
                  )),
                  const SizedBox(height: 12),
                  Text(
                    'Подписка останется активной до конца оплаченного периода.',
                    style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white54, height: 1.3),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: Text('Не отменять', style: GoogleFonts.unbounded(color: Colors.white54)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, {'confirmed': true, 'reason': reasonCode ?? 'prefer_not_say'}),
                child: Text('Отменить подписку', style: GoogleFonts.unbounded(color: Colors.redAccent)),
              ),
            ],
          );
        },
      ),
    );
    if (result == null || result['confirmed'] != true || !mounted) return;
    final reason = result['reason'] as String?;
    final ok = await _service.cancelSubscription(reason: reason);
    if (!mounted) return;
    await _loadStatus();
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Подписка отменена. Доступ сохранится до конца оплаченного периода.',
            style: GoogleFonts.unbounded(color: Colors.white),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.successMuted,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Не удалось отменить. Попробуйте позже.',
            style: GoogleFonts.unbounded(color: Colors.white),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.graphite,
        ),
      );
    }
  }

  Widget _buildSubscriptionActiveContent() {
    final days = _premiumStatus!.subscriptionDaysLeft ?? 0;
    final cancelled = _premiumStatus!.subscriptionCancelled;
    final endsAt = _premiumStatus!.subscriptionEndsAt;
    final dateStr = endsAt != null ? DateFormat('d MMMM yyyy', 'ru').format(endsAt) : null;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cancelled
                  ? AppColors.graphite.withOpacity(0.5)
                  : AppColors.successMuted.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: cancelled
                    ? AppColors.graphite
                    : AppColors.successMuted.withOpacity(0.5),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  cancelled ? Icons.cancel_outlined : Icons.check_circle_rounded,
                  size: 64,
                  color: cancelled ? Colors.white54 : AppColors.successMuted,
                ),
                const SizedBox(height: 20),
                Text(
                  cancelled ? 'Подписка отменена' : 'У вас действует подписка',
                  style: GoogleFonts.unbounded(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  cancelled
                      ? (dateStr != null ? 'Действует до $dateStr' : 'Осталось $days ${_dayWord(days)}')
                      : 'Осталось $days ${_dayWord(days)}',
                  style: GoogleFonts.unbounded(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: cancelled ? Colors.white70 : AppColors.successMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Text(
                  cancelled
                      ? 'Доступ к Premium сохранится до конца оплаченного периода.'
                      : 'Спасибо за поддержку! Все функции Premium доступны — продолжайте отслеживать тренировки и прогресс.',
                  style: GoogleFonts.unbounded(
                    fontSize: 14,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.mutedGold,
              side: BorderSide(color: AppColors.mutedGold.withOpacity(0.6)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Вернуться',
              style: GoogleFonts.unbounded(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PremiumPaymentHistoryScreen()),
            ),
            child: Text(
              'История оплат',
              style: GoogleFonts.unbounded(color: AppColors.mutedGold, fontSize: 14),
            ),
          ),
          if (!cancelled) ...[
            const SizedBox(height: 24),
            TextButton(
              onPressed: _onCancelSubscriptionPressed,
              child: Text(
                'Отменить подписку',
                style: GoogleFonts.unbounded(color: Colors.white54, fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.mutedGold.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.mutedGold.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Icon(Icons.star_rounded, size: 48, color: AppColors.mutedGold),
          const SizedBox(height: 12),
          Text(
            'Расширенный функционал тренировок',
            style: GoogleFonts.unbounded(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Отслеживание прогресса, силовые замеры, персональные рекомендации',
            style: GoogleFonts.unbounded(
              fontSize: 14,
              color: Colors.white70,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBenefits() {
    const items = [
      ('Отслеживание тренировок и упражнений', 'Рекомендации на основе ваших замеров'),
      ('Замеры силовых показателей', 'История изменений и прогресс'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Что входит в Premium',
          style: GoogleFonts.unbounded(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        ...items.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, color: AppColors.successMuted, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.$1,
                          style: GoogleFonts.unbounded(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          e.$2,
                          style: GoogleFonts.unbounded(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildPriceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.graphite),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Подписка на 1 месяц',
                  style: GoogleFonts.unbounded(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ежемесячная оплата, отмена в любой момент',
                  style: GoogleFonts.unbounded(
                    fontSize: 12,
                    color: Colors.white60,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$_price ₽',
            style: GoogleFonts.unbounded(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.mutedGold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOffertaLink() {
    return InkWell(
      onTap: () => _openUrl(offertaUrl),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.rowAlt,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.description_outlined, color: AppColors.mutedGold, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Публичная оферта',
                    style: GoogleFonts.unbounded(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Условия оказания услуг',
                    style: GoogleFonts.unbounded(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.open_in_new, color: AppColors.mutedGold, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Email для чека',
          style: GoogleFonts.unbounded(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          focusNode: _emailFocusNode,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          style: GoogleFonts.unbounded(fontSize: 16, color: Colors.white),
          decoration: InputDecoration(
            hintText: 'user@example.com',
            hintStyle: GoogleFonts.unbounded(color: Colors.white38),
            filled: true,
            fillColor: AppColors.cardDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.graphite),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.graphite),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.mutedGold, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            prefixIcon: Icon(Icons.email_outlined, color: AppColors.mutedGold, size: 22),
          ),
          onChanged: (_) {
            if (_error != null || _paymentUrlForCopy != null) {
              setState(() {
                _error = null;
                _paymentUrlForCopy = null;
              });
            }
          },
        ),
        const SizedBox(height: 6),
        Text(
          'На этот адрес придёт чек об оплате',
          style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white54),
        ),
      ],
    );
  }

  Widget _buildPayButton() {
    return FilledButton(
      onPressed: _isLoading ? null : _onPayPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.mutedGold,
        foregroundColor: AppColors.anthracite,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.anthracite,
              ),
            )
          : Text(
              'Оплатить $_price ₽',
              style: GoogleFonts.unbounded(fontSize: 16, fontWeight: FontWeight.w600),
            ),
    );
  }
}
