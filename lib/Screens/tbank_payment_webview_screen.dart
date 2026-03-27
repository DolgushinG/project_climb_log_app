import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/app_theme.dart';
import '../utils/payment_return_url.dart';
import 'tbank_iframe_stub.dart'
    if (dart.library.html) 'tbank_iframe_web.dart' as tbank_iframe;

/// Имя маршрута полноэкранного iframe на web — чтобы снимать только его после оплаты, не закрывая checkout.
const String kTbankWebPaymentIframeRouteName = 'tbank_payment_iframe';

/// Закрыть экран iframe-оплаты (если ещё открыт) и дождаться снятия platform view с DOM.
/// Без этого следующий [showDialog] оказывается под iframe и клики уходят в банк.
Future<void> closeTbankWebPaymentIframeRouteIfOpen(BuildContext context) async {
  if (!kIsWeb) return;
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).popUntil((route) {
    return route.settings.name != kTbankWebPaymentIframeRouteName;
  });
  await WidgetsBinding.instance.endOfFrame;
  await Future<void>.delayed(const Duration(milliseconds: 120));
  await WidgetsBinding.instance.endOfFrame;
}

/// Web: полноэкранный iframe (параллельно polling закрывает экран при успехе).
/// Мобильные: WebView с возвратом по success/fail.
Future<void> openTbankPaymentUrl(BuildContext context, String paymentUrl) async {
  if (kIsWeb) {
    if (!context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push<bool?>(
      MaterialPageRoute<bool?>(
        settings: const RouteSettings(name: kTbankWebPaymentIframeRouteName),
        builder: (_) => tbank_iframe.buildTbankWebPaymentScreen(paymentUrl),
      ),
    );
    return;
  }
  if (!context.mounted) return;
  // rootNavigator: иначе при открытии из modal bottom sheet WebView уходит под модалку — «ничего не происходит».
  await Navigator.of(context, rootNavigator: true).push<bool?>(
    MaterialPageRoute<bool?>(
      builder: (_) => TbankPaymentWebViewScreen(initialUrl: paymentUrl),
    ),
  );
}

/// Оплата T‑Банк внутри приложения: перехват редиректа на success/fail сайта,
/// чтобы не оставаться во внешнем браузере и не попадать на веб-логин после оплаты.
class TbankPaymentWebViewScreen extends StatefulWidget {
  final String initialUrl;

  const TbankPaymentWebViewScreen({super.key, required this.initialUrl});

  @override
  State<TbankPaymentWebViewScreen> createState() => _TbankPaymentWebViewScreenState();
}

class _TbankPaymentWebViewScreenState extends State<TbankPaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _completed = false;
  /// После редиректа на return URL не показываем HTML страницы сайта — только Flutter.
  bool _awaitingBankConfirmation = false;

  void _finish(bool? success) {
    if (_completed || !mounted) return;
    _completed = true;
    Navigator.of(context).pop(success);
  }

  void _onReturnUrlDetected(bool? success) {
    if (_completed) return;
    setState(() => _awaitingBankConfirmation = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _finish(success);
    });
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final r = parsePaymentReturnUrl(request.url);
            if (r != null) {
              _onReturnUrlDetected(r);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageFinished: (String url) {
            final r = parsePaymentReturnUrl(url);
            if (r != null) _onReturnUrlDetected(r);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_awaitingBankConfirmation)
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
                        'Не закрывайте приложение',
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
