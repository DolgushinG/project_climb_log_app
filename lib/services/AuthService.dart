import 'dart:convert';

import 'package:http/http.dart' as http;

/// Сервис аутентификации: логин и регистрация.
/// Для тестов можно подменить [instance] на FakeAuthService.
class AuthService {
  AuthService({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  static AuthService? _testInstance;

  /// Текущий экземпляр. В тестах установить [testInstance] для подмены.
  static AuthService get instance => _testInstance ?? _defaultInstance;
  static AuthService _defaultInstance = AuthService(baseUrl: _placeholder);

  static const String _placeholder = '__DOMAIN__';

  /// Подставить домен при первом обращении (DOMAIN из main.dart).
  static void init(String domain) {
    if (_defaultInstance.baseUrl == _placeholder) {
      _defaultInstance = AuthService(baseUrl: domain);
    }
  }

  /// Для тестов: подменить сервис на fake.
  static set testInstance(AuthService? value) {
    _testInstance = value;
  }

  /// POST /api/auth/token — вход по email и паролю.
  /// Возвращает токен при успехе. При ошибке — [AuthException].
  Future<String> login(String email, String password) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/auth/token'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final token = data['token'];
      if (token == null || token is! String) {
        throw AuthException('Неверный формат ответа сервера');
      }
      return token;
    }

    if (response.statusCode == 404 || response.statusCode >= 500) {
      throw AuthException('Сервер недоступен. Проверьте подключение к интернету.');
    }

    String message = 'Неверный email или пароль. Проверьте данные и попробуйте снова.';
    try {
      final body = json.decode(response.body);
      if (body is Map && body['message'] != null) {
        message = body['message'].toString();
      } else if (body is Map && body['error'] != null) {
        message = body['error'].toString();
      }
    } catch (_) {}
    throw AuthException(message);
  }

  /// POST /api/register — регистрация.
  /// Возвращает токен при успехе. При ошибке — [AuthException].
  Future<String> register({
    required String firstname,
    required String lastname,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? gender,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'firstname': firstname,
        'lastname': lastname,
        'email': email,
        'gender': gender,
        'password': password,
        'password_confirmation': passwordConfirmation,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final token = data['token'];
      if (token == null || token is! String) {
        throw AuthException('Неверный формат ответа сервера');
      }
      return token;
    }

    String message = 'Ошибка регистрации';
    try {
      final body = json.decode(response.body);
      if (body is Map && body['errors'] != null) {
        message = body['errors'].toString();
      } else if (body is Map && body['message'] != null) {
        message = body['message'].toString();
      }
    } catch (_) {}
    throw AuthException(message);
  }
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
}
