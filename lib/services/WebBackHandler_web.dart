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
  bool _programmaticPop = false; // popstate от нашего history.back() — не вызывать maybePop
  bool _handlingUserSwipe = false; // pop от жеста — браузер уже сделал back, не дублировать

  void _setupPopStateListener() {
    html.window.addEventListener('popstate', _onPopState);
  }

  void _onPopState(html.Event event) {
    if (_programmaticPop) {
      _programmaticPop = false;
      return;
    }
    _handlingUserSwipe = true;
    _navigatorKey.currentState?.maybePop().then((_) {
      _handlingUserSwipe = false; // сброс, если maybePop не выполнил pop
    });
  }

  /// Синхронизируем только полноэкранные страницы (PageRoute).
  /// Bottom sheet, dialog, popup — не трогаем.
  bool _isPageRoute(Route<dynamic> route) => route is PageRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!_isPageRoute(route)) return;
    html.window.history.pushState(
      {'route': route.hashCode},
      '',
      html.window.location.href,
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_handlingUserSwipe) {
      _handlingUserSwipe = false;
      return; // свайп — браузер уже перешёл назад, не дублировать
    }
    if (!_isPageRoute(route)) return; // только страницы
    _programmaticPop = true;
    html.window.history.back();
  }
}
