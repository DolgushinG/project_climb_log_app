import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../login.dart';
import '../theme/app_theme.dart';
import '../main.dart';

class ChangePasswordScreen extends StatefulWidget {
  ChangePasswordScreen({Key? key}) : super(key: key);

  @override
  _ChangePasswordScreenState createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final String newPassword = _newPasswordController.text;
    final String apiUrl = DOMAIN + '/api/profile/change/password';

    try {
      final String? token = await getToken();
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'new_password': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        _showSnackBar('Пароль успешно изменен!', Colors.green);
      } else {
        _showSnackBar('Ошибка при изменении пароля: ${response.body}', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Что-то пошло не так', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  void _showSnackBar(String message, [Color backgroundColor = Colors.blue]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: Text(
          'Изменение пароля',
          style: unbounded(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildChangePasswordForm(),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildChangePasswordForm() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Изменить пароль',
              style: unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _newPasswordController,
              obscureText: true,
              style: unbounded(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Новый пароль',
                labelStyle: unbounded(color: AppColors.graphite),
                filled: true,
                fillColor: AppColors.rowAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.lock, color: AppColors.mutedGold),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Пожалуйста введите пароль';
                }
                if (value.length < 6) {
                  return 'Минимальная длина пароля 6 символов';
                }
                return null;
              },
            ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                style: unbounded(color: Colors.white),
                decoration: InputDecoration(
                labelText: 'Подтверждение пароля',
                labelStyle: unbounded(color: AppColors.graphite),
                filled: true,
                fillColor: AppColors.rowAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.lock_outline, color: AppColors.mutedGold),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Пожалуйста введите подтверждение пароля';
                }
                if (value != _newPasswordController.text) {
                  return 'Пароли не совпадают';
                }
                return null;
              },
            ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mutedGold,
                    foregroundColor: AppColors.anthracite,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text('Изменить пароль', style: unbounded(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.anthracite)),
                ),
              ),
            ],
          ),
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
