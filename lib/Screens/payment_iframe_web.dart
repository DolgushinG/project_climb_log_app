import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'dart:ui_web' as ui_web;

int _iframeCounter = 0;

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
