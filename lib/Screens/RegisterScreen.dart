import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login_app/login.dart';
import 'package:login_app/theme/app_theme.dart';
import 'package:http/http.dart' as http;
import '../MainScreen.dart';
import '../main.dart';

class RegistrationScreen extends StatefulWidget {
  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isPrivacyAccepted = false;
  String? _selectedGender;

  void _showSnackBar(String message, [Color? backgroundColor]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor ?? AppColors.mutedGold),
    );
  }

  void _selectGender() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Прозрачный фон
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.3, // Начальная высота окна
          minChildSize: 0.2, // Минимальная высота
          maxChildSize: 0.4, // Максимальная высота
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.male, color: AppColors.mutedGold),
                    title: Text(
                      'Мужской',
                      style: GoogleFonts.unbounded(fontSize: 16, color: Colors.white),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedGender = 'Мужской';
                      });
                      Navigator.pop(context);
                    },
                  ),
                  Divider(color: Colors.white24),
                  ListTile(
                    leading: const Icon(Icons.female, color: AppColors.mutedGold),
                    title: Text(
                      'Женский',
                      style: GoogleFonts.unbounded(fontSize: 16, color: Colors.white),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedGender = 'Женский';
                      });
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.unbounded(color: AppColors.graphite),
        filled: true,
        fillColor: AppColors.rowAlt,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      style: GoogleFonts.unbounded(color: Colors.white),
      keyboardType: keyboardType,
      validator: validator,
    );
  }


  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.unbounded(color: AppColors.graphite),
        filled: true,
        fillColor: AppColors.rowAlt,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        suffixIcon: Icon(Icons.visibility, color: AppColors.mutedGold),
      ),
      style: GoogleFonts.unbounded(color: Colors.white),
      keyboardType: keyboardType,
      validator: validator,
    );
  }

    Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final String _surname = _surnameController.text;
      final String _name = _nameController.text;
      final String _email = _emailController.text;
      final String _password = _passwordController.text;
      final String _confirmPassword = _confirmPasswordController.text;
      final String apiUrl = DOMAIN + '/api/register';

      if (!_isPrivacyAccepted) {
        _showSnackBar(
            'Необходимо согласиться с обработкой данных', Colors.red);
        return;
      }

      try {
        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'firstname': _name,
            'lastname': _surname,
            'email': _email,
            'gender': _selectedGender,
            'password': _password,
            'password_confirmation': _confirmPassword,
          }),
        );
        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          final token = responseData['token'];
          saveToken(token);
          _showSnackBar(
              'Регистрация успешно выполнена', AppColors.successMuted);
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MainScreen(showPasskeyPrompt: true)),
            (route) => false,
          );
        } else {
          final responseData = json.decode(response.body);
          _showSnackBar(
              '${responseData['errors']}', Colors.red);
        }
      } catch (e) {
        _showSnackBar('Что-то пошло не так', Colors.red);
      }
    }
    }
    @override
    Widget build(BuildContext context) {
      return Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: AppColors.anthracite,
        appBar: AppBar(
          backgroundColor: AppColors.cardDark,
          title: Text('Регистрация', style: GoogleFonts.unbounded(fontWeight: FontWeight.w500, fontSize: 18, color: Colors.white)),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildTextField(
                            controller: _nameController,
                            label: 'Имя',
                            validator: (value) =>
                            value!.isEmpty ? 'Введите имя' : null,
                          ),
                          const SizedBox(height: 15),
                          _buildTextField(
                            controller: _surnameController,
                            label: 'Фамилия',
                            validator: (value) =>
                            value!.isEmpty ? 'Введите фамилию' : null,
                          ),
                          const SizedBox(height: 15),
                          _buildTextField(
                            controller: _emailController,
                            label: 'E-mail',
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Введите e-mail';
                              }
                              final emailRegex = RegExp(
                                  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                              if (!emailRegex.hasMatch(value)) {
                                return 'Введите корректный e-mail';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 15),
                          GestureDetector(
                            onTap: _selectGender,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: AppColors.rowAlt,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _selectedGender ?? 'Выберите пол',
                                    style: GoogleFonts.unbounded(color: Colors.white),
                                  ),
                                  Icon(Icons.arrow_drop_down, color: AppColors.mutedGold),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          _buildPasswordField(
                            controller: _passwordController,
                            label: 'Пароль',
                          ),
                          const SizedBox(height: 15),
                          _buildPasswordField(
                            controller: _confirmPasswordController,
                            label: 'Подтвердите пароль',
                            validator: (value) {
                              if (value!.isEmpty) {
                                return 'Подтвердите пароль';
                              }
                              if (value != _passwordController.text) {
                                return 'Пароли не совпадают';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Checkbox(
                                value: _isPrivacyAccepted,
                                onChanged: (value) {
                                  setState(() {
                                    _isPrivacyAccepted = value!;
                                  });
                                },
                                activeColor: AppColors.mutedGold,
                                checkColor: Colors.white,
                              ),
                              Expanded(
                                child: Text(
                                  'Я соглашаюсь на обработку персональных данных',
                                  style: GoogleFonts.unbounded(color: Colors.white, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _submitForm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.mutedGold,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
                                'Создать аккаунт',
                                style: GoogleFonts.unbounded(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => LoginScreen()),
                                );
                              },
                              child: Text(
                                'Назад в логин',
                                style: GoogleFonts.unbounded(color: AppColors.mutedGold, fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      );
    }
  }


