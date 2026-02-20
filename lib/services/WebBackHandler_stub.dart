import 'package:flutter/material.dart';

/// Заглушка для мобильных платформ — обработка жеста «назад» на web не требуется.
NavigatorObserver createWebBackObserver(GlobalKey<NavigatorState> navigatorKey) {
  return _StubWebBackObserver();
}

class _StubWebBackObserver extends NavigatorObserver {}
