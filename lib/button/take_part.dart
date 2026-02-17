import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:login_app/main.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:login_app/models/NumberSets.dart';
import 'dart:convert';

import 'package:google_fonts/google_fonts.dart';
import '../login.dart';
import '../models/Category.dart';
import '../utils/session_error_helper.dart';
import '../models/SportCategory.dart';
import '../theme/app_theme.dart';

class TakePartButtonScreen extends StatefulWidget {
  final int event_id;
  final bool is_participant;
  final bool is_need_pay_for_reg;
  Category? category;
  SportCategory? sport_category;
  DateTime? birthday;
  NumberSets? number_set;
  final VoidCallback onParticipationStatusChanged;
  final void Function(int eventId)? onNeedCheckout;
  /// Все сеты заняты — скрываем «Принять участие», только «Добавиться в лист ожидания»
  final bool allSetsBusy;
  /// Есть хотя бы один занятый сет — показываем кнопку «Добавиться в лист ожидания»
  final bool hasAnyBusySet;
  /// Номера сетов для add-to-list-pending
  final List<int> numberSetsForWaitlist;
  /// При нажатии «Добавиться в лист ожидания» — показать sheet вместо прямого запроса
  final VoidCallback? onWaitlistTap;
  /// Пользователь уже в листе ожидания — не показывать кнопку «Добавиться»
  final bool is_in_list_pending;
  /// Требуется выбор категории (если доступна)
  final bool needCategory;
  /// Требуется выбор разряда (если доступен)
  final bool needSportCategory;
  /// Требуется выбор сета (если доступны)
  final bool needNumberSet;

  TakePartButtonScreen(
      this.event_id,
      this.is_participant,
      this.birthday,
      this.category,
      this.sport_category,
      this.number_set,
      this.onParticipationStatusChanged, {
      this.is_need_pay_for_reg = false,
      this.onNeedCheckout,
      this.allSetsBusy = false,
      this.hasAnyBusySet = false,
      this.numberSetsForWaitlist = const [],
      this.onWaitlistTap,
      this.is_in_list_pending = false,
      this.needCategory = false,
      this.needSportCategory = false,
      this.needNumberSet = false,
    });

  @override
  _MyButtonScreenState createState() => _MyButtonScreenState();
}

class _MyButtonScreenState extends State<TakePartButtonScreen> {
  bool _isButtonDisabled = false;
  String _buttonText = 'Принять участие';
  bool success = false;
  bool _waitlistButtonDisabled = false;
  String _waitlistButtonText = 'Добавиться в лист ожидания';

  @override
  void initState() {
    super.initState();
    _fetchParticipationStatus();
  }

  Future<void> _fetchParticipationStatus() async {
    final String? token = await getToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    try {
      final response = await http.get(
        Uri.parse('${DOMAIN}/api/competitions?event_id=${widget.event_id}'),
        headers: headers,
      );
      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        bool isParticipant = responseData['is_participant'];
        if (mounted) {
          setState(() {
            _isButtonDisabled = isParticipant;
            _buttonText = isParticipant ? 'Вы участник' : 'Принять участие';
            success = isParticipant;
          });
        }
      } else if (response.statusCode == 401) {
        redirectToLoginOnSessionError(context);
      } else {
        _showNotification('Ошибка при получении статуса', Colors.red);
      }
    } catch (e) {
      _showNotification('Ошибка сети', Colors.red);
    }
  }

  Future<void> _makeRequest() async {
    // Проверка: если категория/сет/разряд требуются, но не выбраны
    if (widget.needCategory && (widget.category == null || widget.category!.category.isEmpty)) {
      _showNotification('Выберите категорию для участия', Colors.orange);
      return;
    }
    if (widget.needSportCategory && (widget.sport_category == null || widget.sport_category!.sport_category.isEmpty)) {
      _showNotification('Выберите разряд для участия', Colors.orange);
      return;
    }
    if (widget.needNumberSet && (widget.number_set == null)) {
      _showNotification('Выберите сет для участия', Colors.orange);
      return;
    }

    if (mounted) {
      setState(() {
        _isButtonDisabled = true;
        _buttonText = 'Загрузка...';
      });
    }

    try {
      final String? token = await getToken();
      final String? serverDate;
      if(widget.birthday != null){
        serverDate = DateFormat('yyyy-MM-dd').format(widget.birthday!);
      } else {
        serverDate = null;
      }

      final response = await http.post(
        Uri.parse('${DOMAIN}/api/event/take/part'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'event_id': '${widget.event_id}',
          'birthday': serverDate,
          'category': '${widget.category?.category}',
          'sport_category': '${widget.sport_category?.sport_category}',
          'number_set': '${widget.number_set?.number_set}',

        }),
      );
      final responseData = json.decode(response.body);
      final message = responseData['message']?.toString() ?? '';
      final isSuccess = response.statusCode == 200 ||
          response.statusCode == 201 ||
          (responseData['success'] == true);
      if (isSuccess) {
        _showNotification(message.isNotEmpty ? message : 'Вы успешно зарегистрированы!', Colors.green);
        if (mounted) {
          setState(() {
            _isButtonDisabled = true;
            _buttonText = 'Вы участник';
            success = true;
          });
        }
        widget.onParticipationStatusChanged();
        if (widget.is_need_pay_for_reg && widget.onNeedCheckout != null) {
          widget.onNeedCheckout!(widget.event_id);
        }
      } else if (response.statusCode == 401) {
        redirectToLoginOnSessionError(context);
      } else {
        _handleError(message.isNotEmpty ? message : 'Ошибка регистрации');
      }
    } catch (e) {
      _handleError('Ошибка сети');
    } finally {
      _resetButtonStateAfterDelay();
    }
  }

  void _showNotification(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _handleError(String message) {
    if (mounted) {
      setState(() {
        success = false;
        _isButtonDisabled = false;
        _buttonText = 'Принять участие';
      });
    }
    _showNotification(message, Colors.red);
  }

  void _handleWaitlistError(String message) {
    if (mounted) {
      setState(() {
        _waitlistButtonDisabled = false;
        _waitlistButtonText = 'Добавиться в лист ожидания';
      });
    }
    _showNotification(message, Colors.red);
  }

  Future<void> _makeAddToListPendingRequest() async {
    if (widget.numberSetsForWaitlist.isEmpty) {
      _showNotification('Выберите сет для добавления в лист ожидания', Colors.orange);
      return;
    }
    if (mounted) {
      setState(() {
        _waitlistButtonDisabled = true;
        _waitlistButtonText = 'Загрузка...';
      });
    }

    try {
      final String? token = await getToken();
      final String? serverDate = widget.birthday != null
          ? DateFormat('yyyy-MM-dd').format(widget.birthday!)
          : null;

      final body = <String, dynamic>{
        'number_sets': widget.numberSetsForWaitlist,
      };
      if (serverDate != null) body['birthday'] = serverDate;
      if (widget.category?.category != null) body['category'] = widget.category!.category;
      if (widget.sport_category?.sport_category != null) body['sport_category'] = widget.sport_category!.sport_category;

      final response = await http.post(
        Uri.parse('${DOMAIN}/api/event/${widget.event_id}/add-to-list-pending'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );
      final responseData = json.decode(response.body);
      final message = responseData['message']?.toString() ?? '';
      final isSuccess = response.statusCode == 200 && (responseData['success'] == true);

      if (isSuccess) {
        _showNotification(message.isNotEmpty ? message : 'Вы добавлены в лист ожидания', Colors.green);
        if (mounted) {
          setState(() {
            _waitlistButtonDisabled = true;
            _waitlistButtonText = 'В листе ожидания';
          });
        }
        widget.onParticipationStatusChanged();
      } else if (response.statusCode == 401) {
        redirectToLoginOnSessionError(context);
      } else {
        _handleWaitlistError(message.isNotEmpty ? message : 'Ошибка внесения в лист ожидания');
      }
    } catch (e) {
      _handleWaitlistError('Ошибка сети');
    } finally {
      if (mounted && !_waitlistButtonDisabled) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _waitlistButtonDisabled = false;
              _waitlistButtonText = 'Добавиться в лист ожидания';
            });
          }
        });
      }
    }
  }

  void _resetButtonStateAfterDelay() {
    Future.delayed(Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isButtonDisabled = widget.is_participant;
          _buttonText = widget.is_participant ? 'Вы участник' : 'Принять участие';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool showTakePart = !widget.allSetsBusy;
    final bool showWaitlist = widget.hasAnyBusySet && !widget.is_participant && !widget.is_in_list_pending;
    final bool canPressTakePart = !widget.is_participant;

    if (showTakePart && showWaitlist) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.mutedGold,
                side: const BorderSide(color: AppColors.mutedGold),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _waitlistButtonDisabled ? null : (widget.onWaitlistTap ?? _makeAddToListPendingRequest),
              child: Text(
                _waitlistButtonText,
                style: GoogleFonts.unbounded(color: AppColors.mutedGold, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.is_participant ? AppColors.graphite : AppColors.mutedGold,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: widget.is_participant ? null : (canPressTakePart ? _makeRequest : null),
              child: Text(
                _buttonText,
                style: GoogleFonts.unbounded(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      );
    }

    if (showWaitlist)
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.mutedGold,
            side: const BorderSide(color: AppColors.mutedGold),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _waitlistButtonDisabled ? null : (widget.onWaitlistTap ?? _makeAddToListPendingRequest),
          child: Text(
            _waitlistButtonText,
            style: GoogleFonts.unbounded(color: AppColors.mutedGold, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showWaitlist)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.mutedGold,
                side: const BorderSide(color: AppColors.mutedGold),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _waitlistButtonDisabled ? null : _makeAddToListPendingRequest,
              child: Text(
                _waitlistButtonText,
                style: GoogleFonts.unbounded(color: AppColors.mutedGold, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        if (showTakePart)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.is_participant ? AppColors.graphite : AppColors.mutedGold,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: widget.is_participant ? null : (canPressTakePart ? _makeRequest : null),
              child: Text(
                _buttonText,
                style: GoogleFonts.unbounded(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }
}

// Экран для внесения результатов


