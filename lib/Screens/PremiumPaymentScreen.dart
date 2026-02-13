import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:login_app/main.dart';
import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/services/PremiumSubscriptionService.dart';
import 'package:login_app/services/PayAnyWayNativeService.dart';

/// URL оферты — публичный договор на премиум-подписку
const String offertaUrl = 'https://climbing-events.ru/offerta-premium';

/// Стоимость подписки (из оферты)
const int subscriptionPriceRub = 199;

/// Экран оплаты премиум-подписки.
/// Пояснение, подтверждение, ссылка на оферту, сумма, переход на платёж PayAnyWay.
class PremiumPaymentScreen extends StatefulWidget {
  const PremiumPaymentScreen({super.key});

  @override
  State<PremiumPaymentScreen> createState() => _PremiumPaymentScreenState();
}

class _PremiumPaymentScreenState extends State<PremiumPaymentScreen> {
  final PremiumSubscriptionService _service = PremiumSubscriptionService();
  bool _isLoading = false;
  String? _error;

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _onPayPressed() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Android: нативный PayAnyWay SDK (WebView в приложении)
      if (Platform.isAndroid) {
        final ok = await PayAnyWayNativeService.showPayment(
          orderId: null, // SDK сгенерирует сам
          amount: subscriptionPriceRub.toDouble(),
          currency: 'RUB',
        );
        if (!mounted) return;
        if (ok) {
          Navigator.pop(context);
          return;
        }
      }
      // Fallback: backend возвращает payment_url (или iOS / не сконфигурирован SDK)
      final token = await getToken();
      if (token == null) {
        setState(() {
          _error = 'Необходимо войти в аккаунт';
          _isLoading = false;
        });
        return;
      }
      final paymentUrl = await _service.createPayment(token);
      if (!mounted) return;
      if (paymentUrl != null && paymentUrl.isNotEmpty) {
        await _openUrl(paymentUrl);
        if (mounted) Navigator.pop(context);
      } else {
        setState(() {
          _error = Platform.isAndroid
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
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
              const SizedBox(height: 32),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
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
            '$subscriptionPriceRub ₽',
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
              'Оплатить $subscriptionPriceRub ₽',
              style: GoogleFonts.unbounded(fontSize: 16, fontWeight: FontWeight.w600),
            ),
    );
  }
}
