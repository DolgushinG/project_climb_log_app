import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../MainScreen.dart';
import '../main.dart';

class WebViewScreen extends StatefulWidget {
  final String url;

  const WebViewScreen({required this.url, Key? key}) : super(key: key);

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();

    // Инициализация WebViewController
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted) // Разрешение JavaScript
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {},
          onNavigationRequest: (NavigationRequest request) async {
            // Проверяем редирект-URL
            if (request.url.startsWith('$DOMAIN/auth/callback')) {
              // Извлекаем токен из URL
              final Uri uri = Uri.parse(request.url);
              final token = uri.queryParameters['token'];

              if (token != null) {
                saveToken(token);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => MainScreen()),
                );
              }

              // Запрещаем дальнейшую загрузку этого URL
              return NavigationDecision.prevent;
            }

            // Разрешаем все остальные запросы
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url)); // Загружаем начальный URL
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Авторизация'),
      ),
      body: WebViewWidget(
        controller: _controller, // Контроллер для управления WebView
      ),
    );
  }
}
