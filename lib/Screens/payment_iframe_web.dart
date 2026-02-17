import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

int _iframeCounter = 0;

void _handleMessage(web.Event event, void Function(bool success) onResult) {
  final e = event as web.MessageEvent;
  // Только от своих страниц success/fail (same-origin)
  final origin = e.origin;
  final selfOrigin = web.window.location.origin;
  if (origin != selfOrigin) return;
  final data = e.data;
  final s = data is String ? data : data?.toString();
  if (s == 'payment_success') {
    onResult(true);
  } else if (s == 'payment_fail') {
    onResult(false);
  }
}

void setupPaymentMessageListener(void Function(bool success) onResult) {
  void handler(web.Event e) => _handleMessage(e, onResult);
  final jsHandler = handler.toJS;
  web.window.addEventListener('message', jsHandler);
  _messageHandler = jsHandler;
}

JSFunction? _messageHandler;

void disposePaymentMessageListener() {
  final h = _messageHandler;
  if (h != null) {
    web.window.removeEventListener('message', h);
    _messageHandler = null;
  }
}

Widget buildPaymentIframe(String paymentUrl) {
  final viewType = 'payment-iframe-${_iframeCounter++}';
  ui_web.platformViewRegistry.registerViewFactory(
    viewType,
    (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = paymentUrl
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      return iframe;
    },
  );
  return HtmlElementView(viewType: viewType);
}
