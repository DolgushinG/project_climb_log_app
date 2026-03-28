import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Переключатель фискального чека и поля email/телефон (T‑Банк init: `send_receipt`).
class TbankFiscalReceiptBlock extends StatelessWidget {
  final bool sendReceipt;
  final ValueChanged<bool> onSendReceiptChanged;
  final TextEditingController emailController;
  final TextEditingController phoneController;

  const TbankFiscalReceiptBlock({
    super.key,
    required this.sendReceipt,
    required this.onSendReceiptChanged,
    required this.emailController,
    required this.phoneController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Фискальный чек',
              style: unbounded(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Чек от T‑Банка на email или по SMS',
              style: unbounded(color: Colors.white54, fontSize: 12),
            ),
            value: sendReceipt,
            activeColor: AppColors.mutedGold,
            onChanged: onSendReceiptChanged,
          ),
          if (sendReceipt) ...[
            const SizedBox(height: 8),
            Text(
              'Укажите email или телефон (хотя бы одно)',
              style: unbounded(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              style: unbounded(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: unbounded(color: Colors.white54),
                hintText: 'name@example.com',
                hintStyle: unbounded(color: Colors.white38),
                filled: true,
                fillColor: AppColors.rowAlt,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              style: unbounded(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Телефон',
                labelStyle: unbounded(color: Colors.white54),
                hintText: '+7… или 9…',
                hintStyle: unbounded(color: Colors.white38),
                filled: true,
                fillColor: AppColors.rowAlt,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
