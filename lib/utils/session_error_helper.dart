import 'package:flutter/material.dart';

import '../login.dart';
import '../main.dart';

/// При 401 (не авторизован) — очищаем токен и сразу перекидываем на логин. 419 (rate limit) — не редиректим, не поможет.
Future<void> redirectToLoginOnSessionError(BuildContext? context,
    [String message = 'Ошибка сессии']) async {
  await clearToken();
  final ctx = context ?? navigatorKey.currentContext;
  if (ctx != null && ctx.mounted) {
    Navigator.of(ctx).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginScreen()),
      (route) => false,
    );
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Для сервисов без BuildContext: при 401 — редирект на логин. 419 (rate limit) — не редиректим.
Future<bool> redirectIfUnauthorized(int? statusCode) async {
  if (statusCode == 401) {
    await redirectToLoginOnSessionError(null, 'Сессия истекла. Войдите снова.');
    return true;
  }
  return false;
}
