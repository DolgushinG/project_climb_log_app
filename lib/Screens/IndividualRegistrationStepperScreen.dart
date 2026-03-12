import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../CompetitionScreen.dart';
import '../login.dart';
import '../main.dart';
import '../models/Category.dart';
import '../models/NumberSets.dart';
import '../models/SportCategory.dart';
import '../services/ProfileService.dart';
import '../theme/app_theme.dart';
import '../utils/display_helper.dart';
import '../utils/session_error_helper.dart';
import '../widgets/RegistrationStepper.dart';
import '../widgets/SetSelectionCards.dart';
import 'CheckoutScreen.dart';
import 'ProfileEditScreen.dart';

const int _MANUAL_CATEGORIES = 0;
const int _AUTO_CATEGORIES_YEAR = 2;
const int _AUTO_CATEGORIES_AGE = 3;

class IndividualRegistrationStepperScreen extends StatefulWidget {
  final Competition competition;
  final Map<String, dynamic>? checkoutData;
  final VoidCallback? onSuccess;

  const IndividualRegistrationStepperScreen({
    super.key,
    required this.competition,
    this.checkoutData,
    this.onSuccess,
  });

  @override
  State<IndividualRegistrationStepperScreen> createState() =>
      _IndividualRegistrationStepperScreenState();
}

class _IndividualRegistrationStepperScreenState
    extends State<IndividualRegistrationStepperScreen> {
  late Competition _competition;
  String? _userBirthday;
  DateTime? _selectedDate;
  Category? _selectedCategory;
  SportCategory? _selectedSportCategory;
  NumberSets? _selectedNumberSet;
  int _currentStepIndex = 0;
  bool _isSubmitting = false;

  bool get _needBirthdayStep {
    final ac = _competition.auto_categories;
    return (ac == _AUTO_CATEGORIES_YEAR || ac == _AUTO_CATEGORIES_AGE) &&
        _competition.is_need_send_birthday;
  }

  bool get _needSetStep {
    return _competition.is_input_set == 0 &&
        _setsFilteredByAge.isNotEmpty;
  }

  bool get _needCategoryStep {
    final ac = _competition.auto_categories;
    return ac != _AUTO_CATEGORIES_YEAR &&
        ac != _AUTO_CATEGORIES_AGE &&
        _competition.categories.isNotEmpty;
  }

  bool get _needSportCategoryStep {
    return _competition.is_need_sport_category == 1 &&
        _competition.sport_categories.isNotEmpty;
  }

  bool get _hasBirthdayFilled {
    if (_userBirthday != null && _userBirthday!.trim().isNotEmpty) return true;
    if (_selectedDate != null) return true;
    return false;
  }

  DateTime? get _birthdayForTakePart {
    if (_selectedDate != null) return _selectedDate;
    if (_userBirthday != null && _userBirthday!.trim().isNotEmpty) {
      try {
        return DateTime.parse(_userBirthday!);
      } catch (_) {}
    }
    return null;
  }

  int? get _userBirthYear {
    final b = _birthdayForTakePart;
    return b != null ? b.year : null;
  }

  (int?, int?) _getCategoryYearRange() {
    final yg = _competition.your_group;
    if (yg == null || yg.isEmpty) return (null, null);
    for (final c in _competition.categories) {
      final m = c is Map ? c : Map<String, dynamic>.from(c as Map);
      if ((m['category'] ?? '').toString().trim() == yg.trim()) {
        final from = m['allow_year_from'];
        final to = m['allow_year_to'];
        int? fromInt = from is int ? from : (from != null ? int.tryParse(from.toString()) : null);
        int? toInt = to is int ? to : (to != null ? int.tryParse(to.toString()) : null);
        return (fromInt, toInt);
      }
    }
    return (null, null);
  }

  List<NumberSets> get _setsFilteredByAge {
    final all = _competition.number_sets
        .map((j) => NumberSets.fromJson(Map<String, dynamic>.from(j)))
        .toList();
    final birthYear = _userBirthYear;
    if (birthYear != null) {
      return all.where((s) => s.matchesBirthYear(birthYear)).toList();
    }
    final (catFrom, catTo) = _getCategoryYearRange();
    if (catFrom != null || catTo != null) {
      return all.where((s) => s.matchesCategoryYearRange(catFrom, catTo)).toList();
    }
    return all;
  }

  bool get _allSetsBusy {
    final sets = _setsFilteredByAge;
    return sets.isNotEmpty && sets.every((s) => s.free <= 0);
  }

  bool get _hasAnyBusySet {
    final sets = _setsFilteredByAge;
    return sets.any((s) => s.free <= 0);
  }

  List<int> get _numberSetsForWaitlist {
    if (_competition.is_input_set == 0) {
      final s = _effectiveSelectedNumberSet;
      return s != null ? [s.number_set] : [];
    }
    return _competition.number_sets
        .map((j) => NumberSets.fromJson(j))
        .map((s) => s.number_set)
        .toList();
  }

  NumberSets? get _effectiveSelectedNumberSet {
    final s = _selectedNumberSet;
    if (s == null) return null;
    return _setsFilteredByAge.any((x) => x.id == s.id) ? s : null;
  }

  List<_StepType> get _effectiveSteps {
    final list = <_StepType>[];
    if (_needBirthdayStep) list.add(_StepType.data);
    if (_needSetStep) list.add(_StepType.set);
    if (_needCategoryStep || _needSportCategoryStep) list.add(_StepType.category);
    list.add(_StepType.confirm);
    return list;
  }

  @override
  void initState() {
    super.initState();
    _competition = widget.competition;
    if (_needBirthdayStep) _loadUserBirthday();
  }

  Future<void> _loadUserBirthday() async {
    try {
      final profile = await ProfileService(baseUrl: DOMAIN).getProfile(context);
      if (mounted && profile != null && profile.birthday.trim().isNotEmpty) {
        setState(() => _userBirthday = profile.birthday);
      }
    } catch (_) {}
  }

  void _goNext() {
    if (!_validateCurrentStep()) return;
    if (_currentStepIndex < _effectiveSteps.length - 1) {
      setState(() => _currentStepIndex++);
    } else {
      _submitParticipation();
    }
  }

  void _goBack() {
    if (_currentStepIndex > 0) {
      setState(() => _currentStepIndex--);
    } else {
      Navigator.pop(context);
    }
  }

  bool _validateCurrentStep() {
    final step = _effectiveSteps[_currentStepIndex];
    switch (step) {
      case _StepType.data:
        if (!_hasBirthdayFilled) {
          _showSnack('Укажите дату рождения', isError: true);
          return false;
        }
        return true;
      case _StepType.set:
        if (!_allSetsBusy && _effectiveSelectedNumberSet == null) {
          _showSnack('Выберите сет', isError: true);
          return false;
        }
        return true;
      case _StepType.category:
        if (_needCategoryStep && _selectedCategory == null) {
          _showSnack('Выберите категорию', isError: true);
          return false;
        }
        if (_needSportCategoryStep && _selectedSportCategory == null) {
          _showSnack('Выберите разряд', isError: true);
          return false;
        }
        return true;
      case _StepType.confirm:
        return true;
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _submitParticipation() async {
    if (_allSetsBusy) {
      _showWaitlistSheet();
      return;
    }

    if (_needCategoryStep && _selectedCategory == null) {
      _showSnack('Выберите категорию', isError: true);
      return;
    }
    if (_needSportCategoryStep && _selectedSportCategory == null) {
      _showSnack('Выберите разряд', isError: true);
      return;
    }
    if (_needSetStep && _effectiveSelectedNumberSet == null) {
      _showSnack('Выберите сет', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final token = await getToken();
      final serverDate = _birthdayForTakePart != null
          ? DateFormat('yyyy-MM-dd').format(_birthdayForTakePart!)
          : null;

      final response = await http.post(
        Uri.parse('$DOMAIN/api/event/take/part'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'event_id': '${_competition.id}',
          'birthday': serverDate,
          'category': '${_selectedCategory?.category ?? ''}',
          'sport_category': '${_selectedSportCategory?.sport_category ?? ''}',
          'number_set': '${_effectiveSelectedNumberSet?.number_set ?? ''}',
        }),
      );

      final data = json.decode(response.body);
      final message = data['message']?.toString() ?? '';
      final isSuccess = response.statusCode == 200 ||
          response.statusCode == 201 ||
          (data['success'] == true);

      if (!mounted) return;

      if (isSuccess) {
        _showSnack(message.isNotEmpty ? message : 'Вы успешно зарегистрированы!');
        widget.onSuccess?.call();
        if (widget.competition.is_need_pay_for_reg) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => CheckoutScreen(
                eventId: _competition.id,
                initialData: widget.checkoutData,
              ),
            ),
          );
        } else {
          Navigator.pop(context, true);
        }
      } else if (response.statusCode == 401) {
        redirectToLoginOnSessionError(context);
      } else {
        _showSnack(message.isNotEmpty ? message : 'Ошибка регистрации', isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Ошибка сети', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showWaitlistSheet() {
    final busySets = _setsFilteredByAge.where((s) => s.free <= 0).toList();
    final categoryList = _competition.categories
        .map((json) => Category.fromJson(Map<String, dynamic>.from(json)))
        .toList();
    final sportCategoryList = _competition.sport_categories
        .map((json) => SportCategory.fromJson(Map<String, dynamic>.from(json)))
        .toList();

    List<NumberSets> sheetSelectedSets = busySets.isNotEmpty ? [busySets.first] : [];
    Category? sheetSelectedCategory = _selectedCategory;
    SportCategory? sheetSelectedSportCategory = _selectedSportCategory;

    final needCategory = _competition.auto_categories != _AUTO_CATEGORIES_YEAR &&
        _competition.auto_categories != _AUTO_CATEGORIES_AGE &&
        categoryList.isNotEmpty;
    final needSportCategory = _competition.is_need_sport_category == 1 &&
        sportCategoryList.isNotEmpty;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Добавиться в лист ожидания',
                    style: unbounded(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_competition.is_input_set == 0 && busySets.isNotEmpty) ...[
                    Text('Занятый сет', style: unbounded(fontSize: 14, color: Colors.white70)),
                    const SizedBox(height: 6),
                    ...busySets.map((s) => CheckboxListTile(
                          title: Text(formatSetCompact(s), style: unbounded(color: Colors.white)),
                          value: sheetSelectedSets.contains(s),
                          activeColor: AppColors.mutedGold,
                          onChanged: (checked) {
                            setSheetState(() {
                              if (checked == true) {
                                if (!sheetSelectedSets.contains(s)) {
                                  sheetSelectedSets = [...sheetSelectedSets, s];
                                }
                              } else {
                                sheetSelectedSets =
                                    sheetSelectedSets.where((x) => x != s).toList();
                              }
                            });
                          },
                        )),
                    const SizedBox(height: 12),
                  ],
                  if (needCategory) ...[
                    Text('Категория', style: unbounded(fontSize: 14, color: Colors.white70)),
                    const SizedBox(height: 6),
                    ...categoryList.map((c) => RadioListTile<Category>(
                          title: Text(c.category, style: unbounded(color: Colors.white)),
                          value: c,
                          groupValue: sheetSelectedCategory,
                          activeColor: AppColors.mutedGold,
                          onChanged: (v) => setSheetState(() => sheetSelectedCategory = v),
                        )),
                    const SizedBox(height: 12),
                  ],
                  if (needSportCategory) ...[
                    Text('Разряд', style: unbounded(fontSize: 14, color: Colors.white70)),
                    const SizedBox(height: 6),
                    ...sportCategoryList.map((sc) => RadioListTile<SportCategory>(
                          title: Text(sc.sport_category, style: unbounded(color: Colors.white)),
                          value: sc,
                          groupValue: sheetSelectedSportCategory,
                          activeColor: AppColors.mutedGold,
                          onChanged: (v) =>
                              setSheetState(() => sheetSelectedSportCategory = v),
                        )),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      final numberSets = _competition.is_input_set == 0
                          ? sheetSelectedSets.map((s) => s.number_set).toList()
                          : busySets.map((s) => s.number_set).toList();

                      if (numberSets.isEmpty && _competition.is_input_set == 0) {
                        _showSnack('Выберите сет', isError: true);
                        return;
                      }
                      if (needCategory && sheetSelectedCategory == null) {
                        _showSnack('Выберите категорию', isError: true);
                        return;
                      }
                      if (needSportCategory && sheetSelectedSportCategory == null) {
                        _showSnack('Выберите разряд', isError: true);
                        return;
                      }

                      Navigator.pop(context);
                      await _addToWaitlist(
                        numberSets,
                        sheetSelectedCategory,
                        sheetSelectedSportCategory,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mutedGold,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Подтвердить', style: unbounded(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _addToWaitlist(
    List<int> numberSets,
    Category? category,
    SportCategory? sportCategory,
  ) async {
    try {
      final token = await getToken();
      final serverDate = _birthdayForTakePart != null
          ? DateFormat('yyyy-MM-dd').format(_birthdayForTakePart!)
          : null;

      final body = <String, dynamic>{'number_sets': numberSets};
      if (serverDate != null) body['birthday'] = serverDate;
      if (category?.category != null) body['category'] = category!.category;
      if (sportCategory?.sport_category != null) {
        body['sport_category'] = sportCategory!.sport_category;
      }

      final response = await http.post(
        Uri.parse('$DOMAIN/api/event/${_competition.id}/add-to-list-pending'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );
      final data = json.decode(response.body);
      final message = data['message']?.toString() ?? '';
      final success = response.statusCode == 200 && (data['success'] == true);

      if (!mounted) return;
      if (success) {
        _showSnack(message.isNotEmpty ? message : 'Вы добавлены в лист ожидания');
        widget.onSuccess?.call();
        Navigator.pop(context, true);
      } else {
        _showSnack(message.isNotEmpty ? message : 'Ошибка внесения в лист ожидания',
            isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Ошибка сети', isError: true);
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthdayForTakePart ?? now.subtract(const Duration(days: 365 * 15)),
      firstDate: now.subtract(const Duration(days: 365 * 80)),
      lastDate: now,
      helpText: 'Дата рождения',
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = _effectiveSteps;
    final totalSteps = steps.length;
    final stepLabels = steps.map((s) {
      switch (s) {
        case _StepType.data:
          return 'Данные';
        case _StepType.set:
          return 'Сет';
        case _StepType.category:
          return 'Категория';
        case _StepType.confirm:
          return 'Подтверждение';
      }
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.cardDark,
      appBar: AppBar(
        title: Text(
          _competition.title,
          style: unbounded(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white),
        ),
        backgroundColor: AppColors.cardDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => _goBack(),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Регистрация',
                    style: unbounded(fontSize: 14, color: Colors.white54),
                  ),
                  const SizedBox(height: 12),
                  RegistrationStepper(
                    currentStep: _currentStepIndex,
                    totalSteps: totalSteps,
                    stepLabels: stepLabels,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _stepTitle(steps[_currentStepIndex]),
                    style: unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  _buildStepContent(steps[_currentStepIndex]),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : _goBack,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.mutedGold,
                        side: const BorderSide(color: AppColors.mutedGold),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _currentStepIndex == 0 ? 'Отмена' : 'Назад',
                        style: unbounded(color: AppColors.mutedGold, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _goNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.mutedGold,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _currentStepIndex < totalSteps - 1 ? 'Продолжить →' : 'Принять участие',
                              style: unbounded(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _stepTitle(_StepType step) {
    switch (step) {
      case _StepType.data:
        return 'Проверьте данные';
      case _StepType.set:
        return 'Выберите ваш сет';
      case _StepType.category:
        return 'Категория и разряд';
      case _StepType.confirm:
        return 'Подтверждение';
    }
  }

  Widget _buildStepContent(_StepType step) {
    switch (step) {
      case _StepType.data:
        return _buildDataStep();
      case _StepType.set:
        return _buildSetStep();
      case _StepType.category:
        return _buildCategoryStep();
      case _StepType.confirm:
        return _buildConfirmStep();
    }
  }

  Widget _buildDataStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _selectDate(context),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.rowAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.graphite),
            ),
            child: Row(
              children: [
                const Icon(Icons.cake_outlined, color: AppColors.mutedGold, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Дата рождения',
                        style: unbounded(fontSize: 12, color: Colors.white54),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _birthdayForTakePart != null
                            ? DateFormat('dd.MM.yyyy').format(_birthdayForTakePart!)
                            : 'Нажмите, чтобы выбрать',
                        style: unbounded(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: _birthdayForTakePart != null ? Colors.white : Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_hasBirthdayFilled)
                  TextButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ProfileEditScreen()),
                      );
                      if (mounted) _loadUserBirthday();
                    },
                    child: Text(
                      'Заполнить в профиле',
                      style: unbounded(color: AppColors.mutedGold, fontSize: 14),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSetStep() {
    if (_allSetsBusy) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade300, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Все сеты заняты. На последнем шаге вы сможете добавиться в лист ожидания.',
                    style: unbounded(fontSize: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return SetSelectionCards(
      sets: _setsFilteredByAge,
      selected: _effectiveSelectedNumberSet,
      onChanged: (s) => setState(() => _selectedNumberSet = s),
    );
  }

  Widget _buildCategoryStep() {
    final categoryList = _competition.categories
        .map((json) => Category.fromJson(Map<String, dynamic>.from(json)))
        .toList();
    final sportCategoryList = _competition.sport_categories
        .map((json) => SportCategory.fromJson(Map<String, dynamic>.from(json)))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_needCategoryStep) ...[
          Text('Категория', style: unbounded(fontSize: 14, color: Colors.white70)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categoryList.map((c) {
              final isSelected = _selectedCategory?.category == c.category;
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = isSelected ? null : c),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.mutedGold.withOpacity(0.3) : AppColors.rowAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.mutedGold : AppColors.graphite,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    c.category,
                    style: unbounded(
                      fontSize: 14,
                      color: isSelected ? AppColors.mutedGold : Colors.white,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],
        if (_needSportCategoryStep) ...[
          Text('Разряд', style: unbounded(fontSize: 14, color: Colors.white70)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sportCategoryList.map((sc) {
              final isSelected = _selectedSportCategory?.sport_category == sc.sport_category;
              return GestureDetector(
                onTap: () =>
                    setState(() => _selectedSportCategory = isSelected ? null : sc),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.mutedGold.withOpacity(0.3) : AppColors.rowAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.mutedGold : AppColors.graphite,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    sc.sport_category,
                    style: unbounded(
                      fontSize: 14,
                      color: isSelected ? AppColors.mutedGold : Colors.white,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildConfirmStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_needSetStep && _effectiveSelectedNumberSet != null && !_allSetsBusy)
          _buildSummaryRow('Сет', formatSetCompact(_effectiveSelectedNumberSet!)),
        if (_needCategoryStep && _selectedCategory != null)
          _buildSummaryRow('Категория', _selectedCategory!.category),
        if (_needSportCategoryStep && _selectedSportCategory != null)
          _buildSummaryRow('Разряд', _selectedSportCategory!.sport_category),
        if (_needBirthdayStep && _birthdayForTakePart != null)
          _buildSummaryRow(
            'Дата рождения',
            DateFormat('dd.MM.yyyy').format(_birthdayForTakePart!),
          ),
        if (_allSetsBusy)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Все сеты заняты. Нажмите «Принять участие», чтобы добавиться в лист ожидания.',
              style: unbounded(fontSize: 14, color: Colors.white70),
            ),
          ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: unbounded(fontSize: 14, color: Colors.white54)),
          ),
          Expanded(
            child: Text(value, style: unbounded(fontSize: 14, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

enum _StepType { data, set, category, confirm }
