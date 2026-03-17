import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../CompetitionScreen.dart';
import '../main.dart';
import '../models/Category.dart';
import '../models/NumberSets.dart';
import '../models/SportCategory.dart';
import '../services/ProfileService.dart';
import '../theme/app_theme.dart';
import '../utils/app_snackbar.dart';
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
  /// Сеты от available-sets?dob= (фильтр по возрасту на бэкенде)
  List<NumberSets>? _availableSetsFromApi;
  String? _availableSetsDob;
  /// Группа/категория от available-category?dob= (YEAR/AGE)
  String? _userCategoryFromApi;

  bool get _needBirthdayStep {
    final ac = _competition.auto_categories;
    return (ac == _AUTO_CATEGORIES_YEAR || ac == _AUTO_CATEGORIES_AGE) &&
        _competition.is_need_send_birthday;
  }

  bool get _needSetStep {
    return _competition.is_input_set == 0 &&
        _setsFilteredByAge.isNotEmpty;
  }

  /// Нет доступных сетов по возрасту — показать сообщение и заблокировать
  bool get _cannotParticipateByAge {
    if (_competition.is_input_set != 0) return false;
    if (_setsFilteredByAge.isEmpty) {
      if (_availableSetsFromApi != null) return true;
      final numberSets = _competition.number_sets;
      if (numberSets.isEmpty) return false;
      final allSets = numberSets
          .map((j) => NumberSets.fromJson(Map<String, dynamic>.from(j)))
          .toList();
      return allSets.any((s) => s.allow_years_from != null || s.allow_years_to != null);
    }
    return false;
  }

  bool get _needAgeNotSuitableStep => _cannotParticipateByAge;

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
    if (_availableSetsFromApi != null) return _availableSetsFromApi!;
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

  /// Номера сетов для add-to-list-pending (только занятые сеты — free <= 0)
  List<int> get _numberSetsForWaitlist {
    final busySets = _setsFilteredByAge.where((s) => s.free <= 0).toList();
    if (_competition.is_input_set == 0) {
      final s = _effectiveSelectedNumberSet;
      if (s != null && s.free <= 0) return [s.number_set];
      return [];
    }
    return busySets.map((s) => s.number_set).toList();
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
    if (_needAgeNotSuitableStep) list.add(_StepType.ageNotSuitable);
    if (_needCategoryStep || _needSportCategoryStep) list.add(_StepType.category);
    list.add(_StepType.confirm);
    return list;
  }

  @override
  void initState() {
    super.initState();
    _competition = widget.competition;
    if (_needBirthdayStep) _loadUserBirthday();
    else if (_competition.is_input_set == 0) _loadUserBirthday();
  }

  Future<void> _loadUserBirthday() async {
    try {
      final profile = await ProfileService(baseUrl: DOMAIN).getProfile(context);
      if (mounted && profile != null && profile.birthday.trim().isNotEmpty) {
        setState(() => _userBirthday = profile.birthday);
        _fetchAvailableSetsIfNeeded();
        _fetchAvailableCategoryIfNeeded();
      }
    } catch (_) {}
  }

  Future<void> _fetchAvailableSetsIfNeeded() async {
    final dob = _birthdayForTakePart;
    if (dob == null) return;
    final dobStr = DateFormat('yyyy-MM-dd').format(dob);
    if (_availableSetsDob == dobStr) return;
    try {
      final token = await getToken();
      final r = await http.get(
        Uri.parse('$DOMAIN/api/event/${_competition.id}/available-sets?dob=$dobStr'),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (!mounted || r.statusCode != 200) return;
      final body = json.decode(r.body);
      final raw = body['availableSets'] ?? body['available_sets'];
      final list = raw is List ? raw : [];
      if (list.isEmpty) {
        if (mounted) {
          setState(() {
            _availableSetsFromApi = [];
            _availableSetsDob = dobStr;
          });
        }
        return;
      }
      final numberSetsFull = _competition.number_sets
          .map((j) => Map<String, dynamic>.from(j is Map ? j as Map : {}))
          .toList();
      final merged = <NumberSets>[];
      for (final apiItem in list) {
        final m = apiItem is Map ? Map<String, dynamic>.from(apiItem as Map) : <String, dynamic>{};
        final id = m['id'] ?? m['number_set'];
        Map<String, dynamic>? base;
        for (final ns in numberSetsFull) {
          if ((ns['id'] ?? ns['number_set']).toString() == id.toString()) {
            base = Map<String, dynamic>.from(ns);
            break;
          }
        }
        base ??= <String, dynamic>{};
        base.addAll(m);
        merged.add(NumberSets.fromJson(base));
      }
      final birthYear = dob.year;
      final filtered = merged.where((s) => s.matchesBirthYear(birthYear)).toList();
      if (mounted) {
        setState(() {
          _availableSetsFromApi = filtered;
          _availableSetsDob = dobStr;
        });
        _fetchAvailableCategoryIfNeeded();
      }
    } catch (_) {}
  }

  Future<void> _fetchAvailableCategoryIfNeeded({int? numberSet}) async {
    final ac = _competition.auto_categories;
    if (ac != _AUTO_CATEGORIES_YEAR && ac != _AUTO_CATEGORIES_AGE) return;
    final dob = _birthdayForTakePart;
    if (dob == null) return;
    final dobStr = DateFormat('yyyy-MM-dd').format(dob);
    try {
      final token = await getToken();
      final uri = numberSet != null
          ? Uri.parse('$DOMAIN/api/event/${_competition.id}/available-category?dob=$dobStr&number_set=$numberSet')
          : Uri.parse('$DOMAIN/api/event/${_competition.id}/available-category?dob=$dobStr');
      final r = await http.get(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (!mounted || r.statusCode != 200) return;
      final body = json.decode(r.body);
      final list = body['availableCategory'] ?? body['available_category'] ?? body['availableCategories'] ?? [];
      final cats = list is List ? list : [];
      String? category;
      if (cats.isNotEmpty) {
        final first = cats.first;
        if (first is Map) {
          category = (first['category'] ?? first)?.toString();
        } else {
          category = first?.toString();
        }
      }
      if (mounted && category != null && category.isNotEmpty) {
        setState(() => _userCategoryFromApi = category);
      }
    } catch (_) {}
  }

  void _goNext() {
    if (!_validateCurrentStep()) return;
    if (_currentStepIndex < _effectiveSteps.length - 1) {
      final nextStep = _effectiveSteps[_currentStepIndex + 1];
      setState(() => _currentStepIndex++);
      if (nextStep == _StepType.set || nextStep == _StepType.ageNotSuitable) {
        _fetchAvailableSetsIfNeeded();
        _fetchAvailableCategoryIfNeeded();
      }
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
      case _StepType.ageNotSuitable:
        return false;
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
    if (isError) {
      showAppError(context, msg);
    } else {
      showAppSuccess(context, msg);
    }
  }

  Future<bool?> _showWaitlistConfirmDialog(String message) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Лист ожидания', style: unbounded(color: Colors.white)),
        content: Text(message, style: unbounded(color: Colors.white70)),
        backgroundColor: AppColors.cardDark,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Нет', style: unbounded(color: AppColors.mutedGold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.mutedGold),
            child: Text('Да', style: unbounded(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitParticipation() async {
    // Возраст не подходит — не показывать лист ожидания
    if (_cannotParticipateByAge) {
      _showSnack('В вашей группе ваш возраст не подходит для участия', isError: true);
      return;
    }

    // Лист ожидания применим только когда есть сеты (is_input_set == 0)
    if (_competition.is_input_set == 0 && _allSetsBusy) {
      final ok = await _showWaitlistConfirmDialog(
        'Все сеты заняты. Добавить вас в лист ожидания? Если освободится место, вы получите уведомление.',
      );
      if (ok == true && mounted) _showWaitlistSheet();
      return;
    }

    // Не регистрировать в сет без мест — диалог и лист ожидания
    if (_needSetStep &&
        _effectiveSelectedNumberSet != null &&
        (_effectiveSelectedNumberSet!.free) <= 0) {
      final ok = await _showWaitlistConfirmDialog(
        'Выбранный сет занят. Добавить вас в лист ожидания? Если освободится место, вы получите уведомление.',
      );
      if (ok == true && mounted) {
        _showWaitlistSheet();
      } else if (ok == false && mounted) {
        setState(() => _currentStepIndex = _effectiveSteps.indexOf(_StepType.set));
      }
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
          'category': '${_selectedCategory?.category ?? _userCategoryFromApi ?? ''}',
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
    if (_cannotParticipateByAge) {
      _showSnack('В вашей группе ваш возраст не подходит для участия', isError: true);
      return;
    }
    final busySets = _setsFilteredByAge.where((s) => s.free <= 0).toList();
    final categoryList = _competition.categories
        .map((json) => Category.fromJson(Map<String, dynamic>.from(json)))
        .toList();
    final sportCategoryList = _competition.sport_categories
        .map((json) => SportCategory.fromJson(Map<String, dynamic>.from(json)))
        .toList();

    List<NumberSets> sheetSelectedSets = [];
    if (busySets.isNotEmpty) {
      final selected = _selectedNumberSet != null &&
          busySets.any((s) => s.id == _selectedNumberSet!.id)
          ? _selectedNumberSet!
          : null;
      sheetSelectedSets = selected != null ? [selected] : [busySets.first];
    }
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
                      final catForApi = sheetSelectedCategory?.category ?? _userCategoryFromApi;
                      await _addToWaitlist(
                        numberSets,
                        catForApi,
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
    String? category,
    SportCategory? sportCategory,
  ) async {
    try {
      final token = await getToken();
      final serverDate = _birthdayForTakePart != null
          ? DateFormat('yyyy-MM-dd').format(_birthdayForTakePart!)
          : null;

      final body = <String, dynamic>{'number_sets': numberSets};
      if (serverDate != null) body['birthday'] = serverDate;
      if (category != null && category.isNotEmpty) body['category'] = category;
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
      _fetchAvailableSetsIfNeeded();
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
        case _StepType.ageNotSuitable:
          return 'Не подходит';
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
                      onPressed: (_isSubmitting ||
                              steps[_currentStepIndex] == _StepType.ageNotSuitable)
                          ? null
                          : _goNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: steps[_currentStepIndex] == _StepType.ageNotSuitable
                            ? AppColors.graphite
                            : AppColors.mutedGold,
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
                              _currentStepIndex < totalSteps - 1 ? 'Продолжить →' : 'Подтвердить',
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
      case _StepType.ageNotSuitable:
        return 'Участие недоступно';
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
      case _StepType.ageNotSuitable:
        return _buildAgeNotSuitableStep();
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

  Widget _buildAgeNotSuitableStep() {
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
                  'В вашей группе ваш возраст не подходит для участия. Измените дату рождения на предыдущем шаге.',
                  style: unbounded(fontSize: 14, color: Colors.white),
                ),
              ),
            ],
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
      onChanged: (s) {
        setState(() => _selectedNumberSet = s);
        if (s != null && _userCategoryFromApi == null) {
          _fetchAvailableCategoryIfNeeded(numberSet: s.number_set);
        }
      },
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
    final isYearOrAge = _competition.auto_categories == _AUTO_CATEGORIES_YEAR ||
        _competition.auto_categories == _AUTO_CATEGORIES_AGE;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_needSetStep && _effectiveSelectedNumberSet != null) ...[
          _buildSummaryRow(
            'Сет',
            formatSetFull(
              _effectiveSelectedNumberSet!,
              competitionTitle: _competition.title,
              startDateFormatted: DateFormat('dd.MM.yyyy').format(_competition.start_date),
            ),
          ),
        ],
        if (isYearOrAge && _userCategoryFromApi != null)
          _buildSummaryRow('Ваша группа', _userCategoryFromApi!),
        if (isYearOrAge && _userCategoryFromApi == null && _hasBirthdayFilled)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.orange.shade300),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Группа не определилась. Проверьте дату рождения или обратитесь к организатору.',
                    style: unbounded(fontSize: 13, color: Colors.orange.shade200),
                  ),
                ),
              ],
            ),
          ),
        if (_needCategoryStep && _selectedCategory != null)
          _buildSummaryRow('Категория', _selectedCategory!.category),
        if (_needSportCategoryStep && _selectedSportCategory != null)
          _buildSummaryRow('Разряд', _selectedSportCategory!.sport_category),
        if (_needBirthdayStep && _birthdayForTakePart != null)
          _buildSummaryRow(
            'Дата рождения',
            DateFormat('dd.MM.yyyy').format(_birthdayForTakePart!),
          ),
        if (_competition.is_input_set == 0 && _allSetsBusy)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Все сеты заняты. Нажмите «Подтвердить», чтобы добавиться в лист ожидания.',
              style: unbounded(fontSize: 14, color: Colors.white70),
            ),
          ),
        if (_competition.is_input_set == 0 &&
            !_allSetsBusy &&
            _needSetStep &&
            _effectiveSelectedNumberSet != null &&
            _effectiveSelectedNumberSet!.free <= 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, color: Colors.orange.shade300, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Выбранный сет занят. Вы будете добавлены в лист ожидания.',
                      style: unbounded(fontSize: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
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

enum _StepType { data, set, ageNotSuitable, category, confirm }
