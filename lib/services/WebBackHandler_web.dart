import 'dart:html' as html;

import 'package:flutter/material.dart';

/// На web: синхронизирует History API с Navigator.
/// Жест «свайп назад» на iOS Safari вызывает popstate — вызываем Navigator.maybePop()
/// вместо перезагрузки страницы.
NavigatorObserver createWebBackObserver(GlobalKey<NavigatorState> navigatorKey) {
  return _WebBackObserver(navigatorKey);
}

class _WebBackObserver extends NavigatorObserver {
  _WebBackObserver(this._navigatorKey) {
    _setupPopStateListener();
  }

  final GlobalKey<NavigatorState> _navigatorKey;
  bool _programmaticPop = false;

  void _setupPopStateListener() {
    html.window.addEventListener('popstate', _onPopState);
  }

  void _onPopState(html.Event event) {
    if (_programmaticPop) {
      _programmaticPop = false;
      return;
    }
    _navigatorKey.currentState?.maybePop();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    html.window.history.pushState(
      {'route': route.hashCode},
      '',
      html.window.location.href,
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _programmaticPop = true;
    html.window.history.back();
  }
}
