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
  bool _tokenHandled = false;

  bool _isOurDomain(String url) {
    try {
      final uri = Uri.parse(url);
      final domainHost = Uri.parse(DOMAIN).host;
      return uri.host == domainHost ||
          uri.host.endsWith('.$domainHost') ||
          url.startsWith(DOMAIN) ||
          url.startsWith(DOMAIN.replaceFirst('https://', 'https://www.'));
    } catch (_) {
      return false;
    }
  }

  String? _extractTokenFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      String? token = uri.queryParameters['token'] ??
          uri.queryParameters['api_token'] ??
          uri.queryParameters['access_token'];
      if (token == null && uri.fragment.isNotEmpty) {
        final fp = Uri.splitQueryString(uri.fragment);
        token = fp['token'] ?? fp['api_token'] ?? fp['access_token'];
      }
      return (token != null && token.trim().isNotEmpty) ? token.trim() : null;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();

    // Инициализация WebViewController
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) async {
            if (!_isOurDomain(url) || _tokenHandled) return;
            final token = _extractTokenFromUrl(url);
            if (token != null && token.trim().isNotEmpty && mounted) {
              _tokenHandled = true;
              await saveToken(token);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => MainScreen()),
                (route) => false,
              );
            }
          },
          onNavigationRequest: (NavigationRequest request) async {
            final url = request.url;
            if (!_isOurDomain(url) || _tokenHandled) {
              return NavigationDecision.navigate;
            }
            final token = _extractTokenFromUrl(url);

            if (token != null && token.trim().isNotEmpty) {
              _tokenHandled = true;
              await saveToken(token);
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => MainScreen()),
                  (route) => false,
                );
              }
              return NavigationDecision.prevent;
            }

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
