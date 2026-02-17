import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/Screens/RegisterScreen.dart';
import 'package:login_app/services/AuthConfigService.dart';
import 'package:login_app/services/WebAuthnService.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'MainScreen.dart';
import 'Screens/LoginByCodeScreen.dart';
import 'Screens/PasswordRecoveryScreen.dart';
import 'Screens/WebViewScreen.dart';
import 'main.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}



class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasskeyLoading = false;
  SocialLoginFlags? _socialFlags;

  @override
  void initState() {
    super.initState();
    _loadSocialFlags();
  }

  Future<void> _loadSocialFlags() async {
    final flags = await AuthConfigService().getSocialLoginFlags();
    if (mounted) setState(() => _socialFlags = flags);
  }

  Future<void> _login() async {
    final email = _emailController.text;
    final password = _passwordController.text;

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final response = await http.post(
        Uri.parse(DOMAIN + '/api/auth/token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final token = responseData['token'];
        saveToken(token);

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen(showPasskeyPrompt: true, openOnProfile: true)),
          (route) => false,
        );
      } else {
        String message = 'Неверный email или пароль. Проверьте данные и попробуйте снова.';
        try {
          final body = json.decode(response.body);
          if (body is Map && body['message'] != null) {
            message = body['message'].toString();
          } else if (body is Map && body['error'] != null) {
            message = body['error'].toString();
          }
        } catch (_) {}
        _showError(message);
      }
    } catch (error) {
      _showError('Ошибка соединения. Проверьте интернет и попробуйте снова.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: Text('Ошибка входа', style: GoogleFonts.unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
        content: Text(message, style: GoogleFonts.unbounded(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK', style: GoogleFonts.unbounded(color: AppColors.mutedGold, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _loginWithPasskey() async {
    if (_isPasskeyLoading) return;
    setState(() => _isPasskeyLoading = true);
    try {
      final service = WebAuthnService(baseUrl: DOMAIN);
      final result = await service.loginWithPasskey();
      await saveToken(result.token);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen(showPasskeyPrompt: false, openOnProfile: true)),
        (route) => false,
      );
    } on WebAuthnLoginException catch (e) {
      if (mounted) _showError(e.userMessage);
    } catch (e) {
      if (mounted) _showError('Ошибка входа по Face ID / Touch ID. Попробуйте другой способ.');
    } finally {
      if (mounted) setState(() => _isPasskeyLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.anthracite,
      appBar: AppBar(
        backgroundColor: AppColors.cardDark,
        automaticallyImplyLeading: true,
        title: Text('Вход', style: GoogleFonts.unbounded(fontWeight: FontWeight.w500, fontSize: 18, color: Colors.white)),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'CLIMBING EVENTS.',
                  style: GoogleFonts.unbounded(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      TextFormField(
                        controller: _emailController,
                        style: GoogleFonts.unbounded(color: Colors.white),
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: GoogleFonts.unbounded(color: AppColors.graphite),
                          prefixIcon: Icon(Icons.email_outlined, color: AppColors.mutedGold, size: 22),
                          filled: true,
                          fillColor: AppColors.rowAlt,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        style: GoogleFonts.unbounded(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Пароль',
                          labelStyle: GoogleFonts.unbounded(color: AppColors.graphite),
                          prefixIcon: Icon(Icons.lock_outline, color: AppColors.mutedGold, size: 22),
                          filled: true,
                          fillColor: AppColors.rowAlt,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PasswordRecoveryScreen(),
                              ),
                            );
                          },
                          child: Text(
                            'Забыл пароль?',
                            style: GoogleFonts.unbounded(color: AppColors.mutedGold, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.mutedGold,
                            foregroundColor: AppColors.anthracite,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.anthracite),
                                )
                              : Text('Вход', style: GoogleFonts.unbounded(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const MainScreen(isGuest: true),
                              ),
                              (route) => false,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.mutedGold,
                            side: const BorderSide(color: AppColors.mutedGold),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Гостевой режим', style: GoogleFonts.unbounded(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginByCodeScreen(),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.mutedGold,
                            side: const BorderSide(color: AppColors.mutedGold),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Вход по коду', style: GoogleFonts.unbounded(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isPasskeyLoading ? null : _loginWithPasskey,
                          icon: _isPasskeyLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.mutedGold),
                                )
                              : const Icon(Icons.fingerprint, color: AppColors.mutedGold, size: 22),
                          label: Text(
                            'Войти по Face ID / Touch ID',
                            style: GoogleFonts.unbounded(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.mutedGold,
                            side: const BorderSide(color: AppColors.mutedGold),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => RegistrationScreen()),
                          );
                        },
                        child: Text(
                          'Регистрация',
                          style: GoogleFonts.unbounded(color: AppColors.mutedGold, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (_socialFlags?.hasAny == true) ...[
                        const SizedBox(height: 28),
                        Text(
                          'Или войти с помощью',
                          style: GoogleFonts.unbounded(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_socialFlags!.vkontakte)
                              SocialLoginButton(
                                imageUrl: "assets/icon-vk.png",
                                loginUrl: "$DOMAIN/auth/vkontakte/redirect?client=${kIsWeb ? 'webapp' : 'mobile'}",
                              ),
                            if (_socialFlags!.vkontakte && (_socialFlags!.telegram || _socialFlags!.yandex))
                              const SizedBox(width: 16),
                            if (_socialFlags!.telegram)
                              SocialLoginButton(
                                imageUrl: "assets/icon-telegram.png",
                                loginUrl: "https://oauth.telegram.org/auth?bot_id=6378620522&origin=${Uri.parse(DOMAIN).host}&embed=1&request_access=write&return_to=${Uri.encodeComponent('$DOMAIN/auth/telegram/redirect?client=${kIsWeb ? 'webapp' : 'mobile'}')}",
                              ),
                            if (_socialFlags!.telegram && _socialFlags!.yandex)
                              const SizedBox(width: 16),
                            if (_socialFlags!.yandex)
                              SocialLoginButton(
                                imageUrl: "assets/yandex-icon.png",
                                loginUrl: "$DOMAIN/auth/yandex/redirect?client=${kIsWeb ? 'webapp' : 'mobile'}",
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SocialLoginButton extends StatelessWidget {
  final String imageUrl;
  final String loginUrl;

  const SocialLoginButton({
    Key? key,
    required this.imageUrl,
    required this.loginUrl,
  }) : super(key: key);

  void _openLoginUrl(BuildContext context) async {
    if (kIsWeb) {
      // webview_flutter не поддерживает web — открываем OAuth в той же вкладке.
      // Бэкенд должен редиректить на app.climbing-events.ru с ?token=...
      final uri = Uri.parse(loginUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WebViewScreen(url: loginUrl),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openLoginUrl(context),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.rowAlt,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(10),
        child: Image.asset(
          imageUrl,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
