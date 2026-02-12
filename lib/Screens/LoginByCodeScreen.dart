import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../MainScreen.dart';
import '../main.dart';
import '../theme/app_theme.dart';

class LoginByCodeScreen extends StatefulWidget {
  const LoginByCodeScreen({Key? key}) : super(key: key);

  @override
  State<LoginByCodeScreen> createState() => _LoginByCodeScreenState();
}

class _LoginByCodeScreenState extends State<LoginByCodeScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _codeFocusNode = FocusNode();

  bool _isEmailStep = true;
  bool _isRequestingCode = false;
  bool _isVerifying = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  static const int _codeLength = 6;
  static const int _resendDelaySeconds = 30;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _codeFocusNode.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  String _parseErrorMessage(dynamic body) {
    if (body is Map) {
      final errors = body['errors'];
      if (errors is Map) {
        for (final key in errors.keys) {
          final list = errors[key];
          if (list is List && list.isNotEmpty) {
            return list.first.toString();
          }
        }
      }
      if (body['message'] != null) return body['message'].toString();
      if (body['error'] != null) return body['error'].toString();
    }
    return 'Произошла ошибка. Попробуйте снова.';
  }

  Future<void> _requestCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('Введите email');
      return;
    }
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      _showError('Введите корректный email');
      return;
    }

    if (_isRequestingCode) return;
    setState(() => _isRequestingCode = true);

    try {
      final response = await http.post(
        Uri.parse(DOMAIN + '/api/auth/code/request'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );

      if (response.statusCode == 200) {
        setState(() {
          if (_isEmailStep) {
            _isEmailStep = false;
            _codeController.clear();
            _codeFocusNode.requestFocus();
          } else {
            _codeController.clear();
          }
          _resendCooldown = _resendDelaySeconds;
          _startCooldownTimer();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Код отправлен на указанный email')),
          );
        }
      } else {
        String message = 'Не удалось отправить код';
        try {
          final body = jsonDecode(response.body);
          message = _parseErrorMessage(body);
        } catch (_) {}
        _showError(message);
      }
    } catch (_) {
      _showError('Ошибка соединения. Проверьте интернет и попробуйте снова.');
    } finally {
      if (mounted) setState(() => _isRequestingCode = false);
    }
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_resendCooldown > 0) _resendCooldown--;
      });
    });
  }

  Future<void> _verifyCode() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.replaceAll(RegExp(r'\D'), '');
    if (code.length != _codeLength) {
      _showError('Введите код из 6 цифр');
      return;
    }

    if (_isVerifying) return;
    setState(() => _isVerifying = true);

    try {
      final response = await http.post(
        Uri.parse(DOMAIN + '/api/auth/code/verify'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'code': code}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        if (token != null && token.toString().isNotEmpty) {
          await saveToken(token.toString());
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const MainScreen(showPasskeyPrompt: true)),
            (route) => false,
          );
        } else {
          _showError('Не удалось получить токен');
        }
      } else {
        String message = 'Неверный или истёкший код';
        try {
          final body = jsonDecode(response.body);
          message = _parseErrorMessage(body);
        } catch (_) {}
        _showError(message);
      }
    } catch (_) {
      _showError('Ошибка соединения. Проверьте интернет и попробуйте снова.');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  void _onCodeChanged(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final truncated = digits.length > _codeLength ? digits.substring(0, _codeLength) : digits;
    if (truncated != value) {
      _codeController
        ..text = truncated
        ..selection = TextSelection.collapsed(offset: truncated.length);
    }
    if (truncated.length == _codeLength) {
      _verifyCode();
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ошибка', style: GoogleFonts.unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
        content: Text(message, style: GoogleFonts.unbounded(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK', style: GoogleFonts.unbounded(color: AppColors.mutedGold, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/poster.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Text(
                  'Вход по коду',
                  style: GoogleFonts.unbounded(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isEmailStep
                      ? 'Введите email, на который придёт код'
                      : 'Введите код из письма',
                  style: GoogleFonts.unbounded(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
                if (_isEmailStep) _buildEmailStep() else _buildCodeStep(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailStep() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: GoogleFonts.unbounded(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              labelText: 'Email',
              labelStyle: GoogleFonts.unbounded(color: AppColors.graphite),
              filled: true,
              fillColor: AppColors.rowAlt,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(Icons.email_outlined, color: AppColors.mutedGold),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isRequestingCode ? null : _requestCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mutedGold,
                foregroundColor: AppColors.anthracite,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isRequestingCode
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text('Отправить код', style: GoogleFonts.unbounded(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeStep() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _emailController.text.trim(),
            style: GoogleFonts.unbounded(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 20),
          _CodeInputField(
            controller: _codeController,
            focusNode: _codeFocusNode,
            codeLength: _codeLength,
            onChanged: _onCodeChanged,
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isVerifying ? null : _verifyCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mutedGold,
                foregroundColor: AppColors.anthracite,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isVerifying
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text('Подтвердить', style: GoogleFonts.unbounded(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _resendCooldown > 0 ? null : _requestCode,
            child: Center(
              child: Text(
                _resendCooldown > 0
                    ? 'Перезапросить код через $_resendCooldown сек'
                    : 'Перезапросить код',
                style: GoogleFonts.unbounded(
                  color: _resendCooldown > 0 ? Colors.white54 : Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => setState(() => _isEmailStep = true),
            child: Center(
              child: Text(
                'Изменить email',
                style: GoogleFonts.unbounded(color: AppColors.mutedGold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeInputField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final int codeLength;
  final ValueChanged<String> onChanged;

  const _CodeInputField({
    required this.controller,
    required this.focusNode,
    required this.codeLength,
    required this.onChanged,
  });

  @override
  State<_CodeInputField> createState() => _CodeInputFieldState();
}

class _CodeInputFieldState extends State<_CodeInputField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleChange);
    super.dispose();
  }

  void _handleChange() {
    setState(() {}); // только перерисовка цифр, onChanged вызывается из TextField
  }

  static const double _boxWidth = 44;
  static const double _boxGap = 8;

  @override
  Widget build(BuildContext context) {
    final boxesRow = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.codeLength, (i) {
        final text = widget.controller.text;
        final digit = i < text.length ? text[i] : '';
        return Container(
          width: _boxWidth,
          height: 52,
          margin: EdgeInsets.only(right: i < widget.codeLength - 1 ? _boxGap : 0),
          decoration: BoxDecoration(
            color: AppColors.rowAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: digit.isNotEmpty ? AppColors.mutedGold : AppColors.graphite,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              digit,
              style: GoogleFonts.unbounded(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }),
    );

    final totalWidth = widget.codeLength * _boxWidth + (widget.codeLength - 1) * _boxGap;

    return GestureDetector(
      onTap: () => widget.focusNode.requestFocus(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(child: boxesRow),
          SizedBox(
            width: totalWidth,
            height: 52,
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              showCursor: false,
              cursorColor: Colors.transparent,
              cursorWidth: 0,
              keyboardType: TextInputType.number,
              maxLength: widget.codeLength,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(widget.codeLength),
              ],
              textAlign: TextAlign.center,
              style: GoogleFonts.unbounded(color: Colors.transparent, fontSize: 22),
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: widget.onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
