import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/services/PremiumSubscriptionService.dart';

/// Экран истории оплат Premium-подписки.
class PremiumPaymentHistoryScreen extends StatefulWidget {
  const PremiumPaymentHistoryScreen({super.key});

  @override
  State<PremiumPaymentHistoryScreen> createState() => _PremiumPaymentHistoryScreenState();
}

class _PremiumPaymentHistoryScreenState extends State<PremiumPaymentHistoryScreen> {
  final PremiumSubscriptionService _service = PremiumSubscriptionService();
  bool _loading = true;
  String? _error;
  List<PremiumPayment> _payments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.getPaymentHistory();
      if (mounted) {
        setState(() {
          _payments = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Не удалось загрузить историю';
        });
      }
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'Оплачено';
      case 'pending':
        return 'Ожидает оплаты';
      case 'failed':
        return 'Ошибка';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return AppColors.successMuted;
      case 'pending':
        return AppColors.mutedGold;
      case 'failed':
        return Colors.redAccent;
      default:
        return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.anthracite,
      appBar: AppBar(
        backgroundColor: AppColors.anthracite,
        title: Text(
          'История оплат',
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
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.mutedGold))
            : RefreshIndicator(
                onRefresh: _load,
                color: AppColors.mutedGold,
                child: _error != null
                    ? _buildError()
                    : _payments.isEmpty
                        ? _buildEmpty()
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(20),
                            itemCount: _payments.length,
                            itemBuilder: (context, i) => _buildPaymentCard(_payments[i]),
                          ),
              ),
      ),
    );
  }

  Widget _buildError() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.redAccent.withOpacity(0.7)),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: GoogleFonts.unbounded(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: _load,
            child: Text(
              'Повторить',
              style: GoogleFonts.unbounded(color: AppColors.mutedGold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.white24),
          const SizedBox(height: 20),
          Text(
            'Платежей пока нет',
            style: GoogleFonts.unbounded(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'После оплаты подписки здесь появится история платежей',
            style: GoogleFonts.unbounded(fontSize: 14, color: Colors.white54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(PremiumPayment p) {
    final date = p.paidAt ?? p.createdAt;
    final dateStr = DateFormat('d MMM yyyy', 'ru').format(date);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.graphite),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _statusColor(p.status).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                p.status == 'paid' ? Icons.check_circle : Icons.payment,
                color: _statusColor(p.status),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${p.amount.toInt()} ₽',
                    style: GoogleFonts.unbounded(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    dateStr,
                    style: GoogleFonts.unbounded(fontSize: 13, color: Colors.white60),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(p.status).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _statusLabel(p.status),
                style: GoogleFonts.unbounded(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _statusColor(p.status),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
