import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../login.dart';
import '../theme/app_theme.dart';
import '../main.dart';
import '../utils/session_error_helper.dart';
import '../services/WebAuthnService.dart';

class AuthSettingScreen extends StatefulWidget {
  String? socialite;
  String? rememberToken;

  AuthSettingScreen({this.socialite, this.rememberToken});

  @override
  _AuthSettingScreenState createState() => _AuthSettingScreenState();
}

class _AuthSettingScreenState extends State<AuthSettingScreen> {
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _passkeyLoading = false;
  /// true = добавлен, false = удалён/нет, null = неизвестно (пока не удаляли и не добавляли в этой сессии)
  bool? _hasPasskey;

  @override
  void initState() {
    super.initState();
    fetchProfileData();
  }

  // Загрузка данных профиля с сервера
  Future<void> fetchProfileData() async {
    final String? token = await getToken();

    final response = await http.get(
      Uri.parse(DOMAIN + '/api/profile/auth'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (mounted) {
        setState(() {
          widget.socialite = data['socialite'] ?? '';
          widget.rememberToken = data['rememberToken'] ?? null;
        });
      }
    } else if (response.statusCode == 401 || response.statusCode == 419) {
      _navigateToLoginScreen('Ошибка сессии');
    } else {
      _showSnackBar('Не удалось загрузить данные профиля');
    }
  }

  Future<void> _logout() async {
    final confirmation = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выход из аккаунта'),
        content: const Text('Вы уверены, что хотите выйти?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );

    if (confirmation == true) {
      final String? token = await getToken();
      final response = await http.post(
        Uri.parse(DOMAIN + '/api/profile/logout'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        await clearToken();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => StartPage()),
            (route) => false,
          );
        }
      } else {
        _showSnackBar('Ошибка при выходе из аккаунта', Colors.red);
      }
    }
  }

  void _navigateToLoginScreen(String message) {
    redirectToLoginOnSessionError(context, message);
  }

  void _showSnackBar(String message, [Color? backgroundColor]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor ?? AppColors.mutedGold),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: Text(
          'Авторизация',
          style: GoogleFonts.unbounded(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileCard(),
              const SizedBox(height: 20),
              _buildPasskeyCard(),
              const SizedBox(height: 20),
              _buildLogoutCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Информация о входе',
            style: GoogleFonts.unbounded(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 12),
          if (widget.socialite != '')
            Row(
              children: [
                Icon(Icons.account_circle, color: AppColors.mutedGold, size: 22),
                const SizedBox(width: 12),
                Text('Соц-сеть: ${widget.socialite}', style: GoogleFonts.unbounded(fontSize: 14, color: Colors.white70)),
              ],
            ),
          if (widget.rememberToken != null)
            Row(
              children: [
                Icon(Icons.email, color: AppColors.mutedGold, size: 22),
                const SizedBox(width: 12),
                Text('Email и пароль', style: GoogleFonts.unbounded(fontSize: 14, color: Colors.white70)),
              ],
            ),
        ],
      ),
    );
  }


  Widget _buildPasskeyCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fingerprint, color: AppColors.mutedGold, size: 24),
              const SizedBox(width: 12),
              Text(
                'Face ID / Touch ID (Passkey)',
                style: GoogleFonts.unbounded(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ],
          ),
            const SizedBox(height: 10),
            Text(
              _hasPasskey == false
                  ? 'Passkey не добавлен. Добавьте для входа по Face ID / Touch ID.'
                  : 'Добавьте Passkey для входа по биометрии или удалите его.',
              style: GoogleFonts.unbounded(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 16),
            if (_passkeyLoading)
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: CircularProgressIndicator(),
              ))
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addPasskey,
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Добавить Passkey'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _hasPasskey == false ? null : _deletePasskey,
                      icon: const Icon(Icons.delete_outline, size: 20),
                      label: Text(_hasPasskey == false ? 'Нет Passkey' : 'Удалить Passkey'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
    );
  }

  Future<void> _addPasskey() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      _showSnackBar('Войдите в аккаунт', Colors.red);
      return;
    }
    setState(() => _passkeyLoading = true);
    try {
      final service = WebAuthnService(baseUrl: DOMAIN);
      await service.registerPasskey(token);
      if (mounted) {
        setState(() => _hasPasskey = true);
        await setPasskeyPromptDeclined(false);
        _showSnackBar('Passkey успешно добавлен');
      }
    } on WebAuthnLoginException catch (e) {
      if (mounted) _showSnackBar(e.userMessage, Colors.red);
    } catch (e) {
      if (mounted) _showSnackBar('Ошибка при добавлении Passkey', Colors.red);
    } finally {
      if (mounted) setState(() => _passkeyLoading = false);
    }
  }

  Future<void> _deletePasskey() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      _showSnackBar('Войдите в аккаунт', Colors.red);
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить Passkey'),
        content: const Text(
          'Удалить все Passkey (Face ID / Touch ID) для этого аккаунта? '
          'Вход по биометрии станет недоступен до повторного добавления.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _passkeyLoading = true);
    try {
      final service = WebAuthnService(baseUrl: DOMAIN);
      await service.deletePasskeys(token);
      if (mounted) {
        setState(() => _hasPasskey = false);
        _showSnackBar('Passkey удалён');
      }
    } on WebAuthnLoginException catch (e) {
      if (mounted) _showSnackBar(e.userMessage, Colors.red);
    } catch (e) {
      if (mounted) _showSnackBar('Ошибка при удалении Passkey', Colors.red);
    } finally {
      if (mounted) setState(() => _passkeyLoading = false);
    }
  }

  Widget _buildLogoutCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Выход из аккаунта',
            style: GoogleFonts.unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(
            'Нажмите кнопку ниже, чтобы выйти из текущего аккаунта.',
            style: GoogleFonts.unbounded(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text('Выйти', style: GoogleFonts.unbounded(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
