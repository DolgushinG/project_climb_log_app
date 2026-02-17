import 'package:flutter/material.dart';

import '../login.dart';
import '../main.dart';

/// При 401/419 с сессией — очищаем токен и сразу перекидываем на логин (pushAndRemoveUntil).
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
