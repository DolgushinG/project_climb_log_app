import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:login_app/utils/network_error_helper.dart';

void main() {
  group('networkErrorMessage', () {
    test('SocketException returns connection message', () {
      expect(
        networkErrorMessage(SocketException('test')),
        'Нет подключения к интернету. Проверьте сеть и повторите.',
      );
    });

    test('TimeoutException returns timeout message', () {
      expect(
        networkErrorMessage(TimeoutException('test')),
        'Превышено время ожидания. Проверьте интернет и повторите.',
      );
    });

    test('HandshakeException returns server message', () {
      expect(
        networkErrorMessage(HandshakeException('test')),
        'Ошибка соединения с сервером. Попробуйте позже.',
      );
    });

    test('ClientException returns connection message', () {
      expect(
        networkErrorMessage(ClientException('test')),
        'Ошибка соединения. Проверьте интернет и повторите.',
      );
    });

    test('generic error with socket in message returns connection message', () {
      expect(
        networkErrorMessage(Exception('socket error')),
        'Нет подключения к интернету. Проверьте сеть и повторите.',
      );
    });

    test('generic error with timeout in message returns timeout message', () {
      // Must not contain 'connection'/'socket'/'network' — those are checked first
      expect(
        networkErrorMessage(Exception('request timeout')),
        'Превышено время ожидания. Повторите попытку.',
      );
    });

    test('generic error returns fallback', () {
      expect(
        networkErrorMessage(Exception('unknown')),
        'Ошибка загрузки',
      );
    });

    test('custom fallback is used', () {
      expect(
        networkErrorMessage(Exception('unknown'), 'Custom msg'),
        'Custom msg',
      );
    });
  });

  group('isLikelyOfflineError', () {
    test('SocketException returns true', () {
      expect(isLikelyOfflineError(SocketException('test')), isTrue);
    });

    test('TimeoutException returns true', () {
      expect(isLikelyOfflineError(TimeoutException('test')), isTrue);
    });

    test('HandshakeException returns true', () {
      expect(isLikelyOfflineError(HandshakeException('test')), isTrue);
    });

    test('ClientException returns true', () {
      expect(isLikelyOfflineError(ClientException('test')), isTrue);
    });

    test('error message with network returns true', () {
      expect(isLikelyOfflineError(Exception('network unavailable')), isTrue);
    });

    test('error message with socket returns true', () {
      expect(isLikelyOfflineError(Exception('socket closed')), isTrue);
    });

    test('error message with timeout returns true', () {
      expect(isLikelyOfflineError(Exception('timeout')), isTrue);
    });

    test('unrelated error returns false', () {
      expect(isLikelyOfflineError(Exception('parse error')), isFalse);
    });
  });
}
