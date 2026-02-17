import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

int _iframeCounter = 0;

void _handleMessage(web.Event event, void Function(bool success) onResult) {
  final e = event as web.MessageEvent;
  final data = e.data;
  if (data == 'payment_success') {
    onResult(true);
  } else if (data == 'payment_fail') {
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
