import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;

import 'dart:ui_web' as ui_web;

import '../theme/app_theme.dart';

int _seq = 0;

Widget buildTbankWebPaymentScreen(String initialUrl) {
  return _TbankPaymentWebScreen(initialUrl: initialUrl);
}

class _TbankPaymentWebScreen extends StatefulWidget {
  final String initialUrl;

  const _TbankPaymentWebScreen({required this.initialUrl});

  @override
  State<_TbankPaymentWebScreen> createState() => _TbankPaymentWebScreenState();
}

class _TbankPaymentWebScreenState extends State<_TbankPaymentWebScreen> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'tbank-iframe-${_seq++}';
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) {
        final iframe = web.HTMLIFrameElement()
          ..src = widget.initialUrl
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allow = 'payment; fullscreen';
        return iframe;
      },
    );
  }

  Future<void> _openExternal() async {
    final uri = Uri.tryParse(widget.initialUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.anthracite,
      appBar: AppBar(
        backgroundColor: AppColors.cardDark,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(null),
        ),
        title: Text(
          'Оплата',
          style: unbounded(fontWeight: FontWeight.w500, fontSize: 18, color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: _openExternal,
            child: Text(
              'В новой вкладке',
              style: unbounded(color: AppColors.mutedGold, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'После оплаты окно закроется само. Если видите логин — это нормально для банка; статус проверяется отдельно.',
              style: unbounded(fontSize: 12, color: Colors.white60),
            ),
          ),
          Expanded(child: HtmlElementView(viewType: _viewType)),
        ],
      ),
    );
  }
}
