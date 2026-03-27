import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../utils/payment_return_url.dart';

int _seq = 0;

Widget buildTbankWebPaymentScreen(String initialUrl) {
  return _TbankWebPaymentScreen(initialUrl: initialUrl);
}

class _TbankWebPaymentScreen extends StatefulWidget {
  final String initialUrl;

  const _TbankWebPaymentScreen({required this.initialUrl});

  @override
  State<_TbankWebPaymentScreen> createState() => _TbankWebPaymentScreenState();
}

class _TbankWebPaymentScreenState extends State<_TbankWebPaymentScreen> {
  late final String _viewType;
  StreamSubscription<html.MessageEvent>? _messageSub;
  /// Не показываем HTML страницы return URL — только Flutter-лоадер до pop.
  bool _flutterConfirming = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'tbank-iframe-${_seq++}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = widget.initialUrl
        ..style.border = 'none'
        ..width = '100%'
        ..height = '100%'
        ..allow = 'payment; fullscreen';
      iframe.onLoad.listen((_) => _onIframeLoad(iframe));
      return iframe;
    });

    /// Опционально: success/fail страница может вызвать `postMessage` до/вместо смены URL.
    _messageSub = html.window.onMessage.listen((html.MessageEvent e) {
      if (!mounted) return;
      final data = e.data;
      if (data is Map) {
        final t = data['type']?.toString();
        if (t == 'climb_payment_return' || t == 'payment_return') {
          final ok = data['success'] == true || data['status'] == 'success';
          _popWithFlutterOverlay(ok);
        }
      }
    });
  }

  void _popWithFlutterOverlay(bool? success) {
    if (!mounted) return;
    setState(() => _flutterConfirming = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(success);
    });
  }

  void _onIframeLoad(html.IFrameElement iframe) {
    if (!mounted) return;
    try {
      final loc = iframe.contentWindow?.location;
      final href = loc is html.Location ? loc.href : loc?.toString();
      if (href == null || href.isEmpty) return;
      final r = parsePaymentReturnUrl(href);
      if (r != null) {
        _popWithFlutterOverlay(r);
      }
    } catch (_) {
      /// Cross-origin: href недоступен — ждём закрытия пользователем или polling закроет по paid.
    }
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    super.dispose();
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
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'После оплаты экран закроется; подтверждение покажем здесь, без страницы сайта.',
                  style: unbounded(fontSize: 12, color: Colors.white60),
                ),
              ),
              Expanded(child: HtmlElementView(viewType: _viewType)),
            ],
          ),
          if (_flutterConfirming)
            Positioned.fill(
              child: ColoredBox(
                color: AppColors.anthracite.withOpacity(0.96),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppColors.mutedGold),
                      const SizedBox(height: 20),
                      Text(
                        'Подтверждаем оплату…',
                        textAlign: TextAlign.center,
                        style: unbounded(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ждём ответ банка',
                        textAlign: TextAlign.center,
                        style: unbounded(fontSize: 12, color: Colors.white60),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
