import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:passkeys/authenticator.dart';
import 'package:passkeys/exceptions.dart';
import 'package:passkeys_platform_interface/types/mediation.dart';
import 'package:passkeys_platform_interface/types/types.dart';

import '../main.dart';

/// Результат входа по Passkey (Face ID / Touch ID).
class WebAuthnLoginResult {
  final String token;

  WebAuthnLoginResult({required this.token});
}

/// Результат регистрации Passkey.
class WebAuthnRegisterResult {
  final String credentialId;

  WebAuthnRegisterResult({required this.credentialId});
}

/// Ошибка WebAuthn с понятным сообщением для пользователя.
class WebAuthnLoginException implements Exception {
  final String userMessage;
  final String? debugMessage;

  WebAuthnLoginException(this.userMessage, [this.debugMessage]);

  @override
  String toString() => userMessage;
}

/// Сервис входа по Face ID / Touch ID (WebAuthn Passkey).
/// Использует эндпоинты: POST /api/auth/webauthn/options и POST /api/auth/webauthn/login.
class WebAuthnService {
  WebAuthnService({required this.baseUrl});

  final String baseUrl;

  /// Полный flow входа по Passkey:
  /// 1) Запрос опций с бэкенда (POST /api/auth/webauthn/options),
  /// 2) Вызов биометрии/Passkey на устройстве,
  /// 3) Отправка результата на бэкенд (POST /api/auth/webauthn/login).
  /// В случае успеха возвращает [WebAuthnLoginResult] с токеном.
  Future<WebAuthnLoginResult> loginWithPasskey() async {
    // 1. Получить опции (challenge) с бэкенда (пустое тело — resident key)
    final optionsResponse = await http.post(
      Uri.parse('$baseUrl/api/auth/webauthn/options'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({}),
    );

    if (optionsResponse.statusCode != 200) {
      throw WebAuthnLoginException(
        'Не удалось получить параметры входа. Попробуйте позже.',
        'webauthn/options ${optionsResponse.statusCode}: ${optionsResponse.body}',
      );
    }

    final optionsJson = json.decode(optionsResponse.body) as Map<String, dynamic>?;
    if (optionsJson == null) {
      throw WebAuthnLoginException('Неверный ответ сервера.');
    }

    // 2. Создать опции для плагина и вызвать биометрию/Passkey
    final authRequest = AuthenticateRequestType.fromJson(
      optionsJson,
      mediation: MediationType.Optional,
      preferImmediatelyAvailableCredentials: true,
    );
    final credential = await _authenticateWithPasskey(authRequest);

    // 3. Тело для /api/auth/webauthn/login — toJson() даёт формат с response { ... }
    final loginBody = credential.toJson();
    final loginResponse = await http.post(
      Uri.parse('$baseUrl/api/auth/webauthn/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(loginBody),
    );

    if (loginResponse.statusCode == 200) {
      final data = json.decode(loginResponse.body) as Map<String, dynamic>?;
      final token = data?['token']?.toString();
      if (token != null && token.isNotEmpty) {
        return WebAuthnLoginResult(token: token);
      }
    }

    if (loginResponse.statusCode == 401) {
      throw WebAuthnLoginException(
        'Вход не выполнен. Добавьте Passkey в настройках профиля на сайте.',
      );
    }

    throw WebAuthnLoginException(
      'Вход по Face ID / Touch ID не удался. Попробуйте другой способ входа.',
      'webauthn/login ${loginResponse.statusCode}: ${loginResponse.body}',
    );
  }

  Future<AuthenticateResponseType> _authenticateWithPasskey(
    AuthenticateRequestType request,
  ) async {
    final authenticator = PasskeyAuthenticator();
    try {
      return await authenticator.authenticate(request);
    } on PasskeyAuthCancelledException {
      throw WebAuthnLoginException('Вход отменён.');
    } on NoCredentialsAvailableException {
      throw WebAuthnLoginException(
        'Нет сохранённого Passkey. Войдите на сайте и добавьте Face ID / Touch ID в настройках профиля.',
      );
    } on DeviceNotSupportedException {
      throw WebAuthnLoginException(
        'Face ID / Touch ID не поддерживается на этом устройстве.',
      );
    } on DomainNotAssociatedException catch (e) {
      throw WebAuthnLoginException(
        'Домен приложения не настроен для Passkey. Обратитесь в поддержку.',
        e.message,
      );
    } on AuthenticatorException catch (e) {
      throw WebAuthnLoginException(
        'Ошибка входа по биометрии: ${e.toString()}',
        e.toString(),
      );
    }
  }

  /// Регистрация Passkey (Face ID / Touch ID) для текущего пользователя.
  /// Требуется [token] — Bearer токен авторизованного пользователя.
  /// 1) Запрос опций: POST /api/profile/webauthn/register/options (тело {})
  /// 2) Вызов регистрации на устройстве
  /// 3) Отправка результата: POST /api/profile/webauthn/register
  Future<WebAuthnRegisterResult> registerPasskey(String token) async {
    if (token.isEmpty) {
      throw WebAuthnLoginException('Нужна авторизация для добавления Passkey.');
    }

    // 1. Получить опции создания с бэкенда (POST — бэкенд не принимает GET, 405)
    final optionsUrl = '$baseUrl/api/profile/webauthn/register/options';
    final optionsResponse = await http.post(
      Uri.parse(optionsUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(<String, dynamic>{}),
    );

    if (optionsResponse.statusCode != 200) {
      throw WebAuthnLoginException(
        'Не удалось получить параметры для добавления Passkey.',
        'register/options ${optionsResponse.statusCode}: ${optionsResponse.body}',
      );
    }

    final optionsJson = json.decode(optionsResponse.body) as Map<String, dynamic>?;
    if (optionsJson == null) {
      throw WebAuthnLoginException('Неверный ответ сервера.');
    }

    // Нормализация ответа бэкенда: passkeys требует rp.id и user.displayName (строка)
    _normalizeRegisterOptions(optionsJson);

    final registerRequest = RegisterRequestType.fromJson(optionsJson);
    final credential = await _registerPasskeyOnDevice(registerRequest);

    // 3. Отправить результат на бэкенд — только поля из спецификации бэка (без clientExtensionResults и лишнего в response)
    final registerBody = _buildRegisterRequestBody(credential);
    final registerUrl = '$baseUrl/api/profile/webauthn/register';
    final registerResponse = await http.post(
      Uri.parse(registerUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(registerBody),
    );

    if (registerResponse.statusCode == 201) {
      final data = json.decode(registerResponse.body) as Map<String, dynamic>?;
      final id = data?['id']?.toString() ?? credential.id;
      return WebAuthnRegisterResult(credentialId: id);
    }

    if (registerResponse.statusCode == 401) {
      throw WebAuthnLoginException('Сессия истекла. Войдите снова.');
    }
    if (registerResponse.statusCode == 422) {
      throw WebAuthnLoginException(
        'Не удалось зарегистрировать Passkey. Возможно, он уже добавлен.',
        registerResponse.body,
      );
    }

    throw WebAuthnLoginException(
      'Ошибка при добавлении Passkey.',
      'register ${registerResponse.statusCode}: ${registerResponse.body}',
    );
  }

  /// Тело для POST /api/profile/webauthn/register — только поля из контракта бэкенда.
  Map<String, dynamic> _buildRegisterRequestBody(RegisterResponseType credential) {
    return {
      'id': credential.id,
      'rawId': credential.rawId,
      'type': 'public-key',
      'response': {
        'clientDataJSON': credential.clientDataJSON,
        'attestationObject': credential.attestationObject,
      },
    };
  }

  /// Подставляет rp.id и user.displayName, если бэкенд не отдал (passkeys требует).
  void _normalizeRegisterOptions(Map<String, dynamic> options) {
    final rp = options['rp'];
    if (rp is Map<String, dynamic>) {
      if (rp['id'] == null || (rp['id'] as String).isEmpty) {
        rp['id'] = Uri.parse(baseUrl).host;
      }
    }
    final user = options['user'];
    if (user is Map<String, dynamic>) {
      if (user['displayName'] == null) {
        user['displayName'] = user['name'] ?? '';
      }
    }
  }

  Future<RegisterResponseType> _registerPasskeyOnDevice(
    RegisterRequestType request,
  ) async {
    final authenticator = PasskeyAuthenticator();
    try {
      return await authenticator.register(request);
    } on PasskeyAuthCancelledException {
      throw WebAuthnLoginException('Регистрация отменена.');
    } on ExcludeCredentialsCanNotBeRegisteredException {
      throw WebAuthnLoginException('Такой Passkey уже зарегистрирован.');
    } on DeviceNotSupportedException {
      throw WebAuthnLoginException(
        'Face ID / Touch ID не поддерживается на этом устройстве.',
      );
    } on DomainNotAssociatedException catch (e) {
      throw WebAuthnLoginException(
        'Домен приложения не настроен для Passkey.',
        e.message,
      );
    } on AuthenticatorException catch (e) {
      throw WebAuthnLoginException(
        'Ошибка при добавлении Passkey: ${e.toString()}',
        e.toString(),
      );
    } on PlatformException catch (e) {
      if (e.message != null && (e.message!.contains('RP ID cannot be validated') || e.message!.contains('DOM_EXCEPTION'))) {
        throw WebAuthnLoginException(
          'Домен не привязан к приложению. Для Passkey на Android нужен файл assetlinks.json на сервере (см. настройку в документации).',
          e.message,
        );
      }
      rethrow;
    }
  }

  /// Удалить все Passkey пользователя.
  /// Требуется [token] — Bearer токен.
  /// POST /api/profile/webauthn/delete
  Future<void> deletePasskeys(String token) async {
    if (token.isEmpty) {
      throw WebAuthnLoginException('Нужна авторизация для удаления Passkey.');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/profile/webauthn/delete'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return;
    }

    if (response.statusCode == 401) {
      throw WebAuthnLoginException('Сессия истекла. Войдите снова.');
    }

    throw WebAuthnLoginException(
      'Не удалось удалить Passkey.',
      'delete ${response.statusCode}: ${response.body}',
    );
  }
}
