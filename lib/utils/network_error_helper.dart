import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' show ClientException;

/// Преобразует исключение сети в понятное пользователю сообщение.
String networkErrorMessage(Object error, [String fallback = 'Ошибка загрузки']) {
  if (error is SocketException) {
    return 'Нет подключения к интернету. Проверьте сеть и повторите.';
  }
  if (error is TimeoutException) {
    return 'Превышено время ожидания. Проверьте интернет и повторите.';
  }
  if (error is HandshakeException) {
    return 'Ошибка соединения с сервером. Попробуйте позже.';
  }
  if (error is ClientException) {
    return 'Ошибка соединения. Проверьте интернет и повторите.';
  }
  final msg = error.toString().toLowerCase();
  if (msg.contains('socket') || msg.contains('connection') || msg.contains('network')) {
    return 'Нет подключения к интернету. Проверьте сеть и повторите.';
  }
  if (msg.contains('timeout')) {
    return 'Превышено время ожидания. Повторите попытку.';
  }
  return fallback;
}

/// Возвращает true, если ошибка похожа на отсутствие сети.
bool isLikelyOfflineError(Object error) {
  if (error is SocketException) return true;
  if (error is TimeoutException) return true;
  if (error is HandshakeException) return true;
  if (error is ClientException) return true;
  final msg = error.toString().toLowerCase();
  return msg.contains('socket') ||
      msg.contains('connection') ||
      msg.contains('network') ||
      msg.contains('timeout');
}
