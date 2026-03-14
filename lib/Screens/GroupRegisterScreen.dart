import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../models/NumberSets.dart';
import '../theme/app_theme.dart';
import '../utils/app_snackbar.dart';
import '../utils/display_helper.dart';
import '../utils/network_error_helper.dart';
import '../utils/session_error_helper.dart';
import '../widgets/error_report_modal.dart';
import '../widgets/RegistrationStepper.dart';
import '../widgets/SetSelectionCards.dart';
import 'GroupCheckoutScreen.dart';
import 'GroupDocumentsScreen.dart';
import 'ProfileEditScreen.dart';

const String _draftKeyPrefix = 'group_register_draft_';

/// Константы is_auto_categories (по аналогии с CompetitionScreen)
const int _MANUAL_CATEGORIES = 0;
const int _AUTO_CATEGORIES_RESULT = 1;
const int _AUTO_CATEGORIES_YEAR = 2;
const int _AUTO_CATEGORIES_AGE = 3;

class GroupRegisterScreen extends StatefulWidget {
  final int eventId;

  const GroupRegisterScreen({Key? key, required this.eventId}) : super(key: key);

  @override
  State<GroupRegisterScreen> createState() => _GroupRegisterScreenState();
}

class _GroupRegisterScreenState extends State<GroupRegisterScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;
  String? _errorStackTrace;
  Map<String, dynamic>? _errorExtra;
  bool _hasUnpaidGroup = false;

  // Новые участники и выбранные related_users
  final List<GroupNewParticipant> _newParticipants = [];
  final Set<int> _selectedRelatedUserIds = {};

  Timer? _debounce;
  static const Duration _debounceDuration = Duration(milliseconds: 500);
  int _currentStep = 0;
  static const int _totalSteps = 4;
  bool _showingErrorModal = false;
  /// При переполнении сета: добавить избыточных участников в лист ожидания
  bool _addOverflowToListPending = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final token = await getToken();
      final r = await http.get(
        Uri.parse('$DOMAIN/api/event/${widget.eventId}/group-register'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (r.statusCode == 200) {
        final raw = jsonDecode(r.body);
        final data = raw is Map ? Map<String, dynamic>.from(raw) : null;
        if (data != null) {
          _loadDraft(data);
          _checkUnpaidGroup();
          setState(() {
            _data = data;
            _relatedUserSetsCache.clear();
            _dobSetsCategoriesCache.clear();
            _batchFetchingUserIds.clear();
            _batchFetchScheduled = false;
            _addOverflowToListPending = false;
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = 'Неверный формат ответа';
            _isLoading = false;
          });
        }
      } else if (r.statusCode == 401) {
        if (mounted) redirectToLoginOnSessionError(context);
      } else if (r.statusCode == 404) {
        setState(() {
          _error = 'Групповая регистрация недоступна для этого события';
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Ошибка загрузки';
          _isLoading = false;
        });
      }
    } catch (e, st) {
      setState(() {
        _error = networkErrorMessage(e, 'Не удалось загрузить данные');
        _errorStackTrace = st?.toString();
        _errorExtra = {'exception': e.toString(), 'type': e.runtimeType.toString()};
        _isLoading = false;
      });
    }
  }

  Future<void> _checkUnpaidGroup() async {
    try {
      final token = await getToken();
      if (token == null) return;
      final r = await http.get(
        Uri.parse('$DOMAIN/api/event/${widget.eventId}/group-checkout'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (r.statusCode == 200 && mounted) {
        final raw = jsonDecode(r.body);
        final data = raw is Map ? raw : null;
        setState(() => _hasUnpaidGroup = data?['group_is_not_paid'] == true);
      } else {
        if (mounted) setState(() => _hasUnpaidGroup = false);
      }
    } catch (_) {
      if (mounted) setState(() => _hasUnpaidGroup = false);
    }
  }

  Future<void> _loadDraft(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_draftKeyPrefix${widget.eventId}';
      final json = prefs.getString(key);
      if (json == null || json.isEmpty) return;
      final draft = jsonDecode(json);
      if (draft is! Map) return;

      // Очищаем перед загрузкой черновика, иначе при возврате из профиля участники дублируются
      _newParticipants.clear();
      _selectedRelatedUserIds.clear();
      _relatedParticipantData.clear();

      final newList = draft['new_participants'];
      if (newList is List) {
        for (final p in newList) {
          if (p is Map) {
            _newParticipants.add(GroupNewParticipant.fromJson(Map<String, dynamic>.from(p)));
          }
        }
      }
      // После загрузки черновика подгружаем сеты/категории для участников с dob
      for (var i = 0; i < _newParticipants.length; i++) {
        final p = _newParticipants[i];
        if (p.dob != null) {
          final dobStr = DateFormat('yyyy-MM-dd').format(p.dob!);
          _fetchSetsAndCategoriesForDob(dobStr, i);
        }
      }
      final selectedIds = draft['selected_related_ids'];
      final relatedList = data['related_users'] is List ? data['related_users'] as List : [];
      final isParticipantById = <int, bool>{};
      for (final ru in relatedList) {
        if (ru is! Map) continue;
        final uid = ru['id'];
        final id = uid is int ? uid : int.tryParse(uid?.toString() ?? '');
        if (id != null) isParticipantById[id] = ru['is_participant'] == true || ru['already_registered'] == true;
      }
      if (selectedIds is List) {
        for (final id in selectedIds) {
          final uid = id is int ? id : (id is num ? id.toInt() : null);
          if (uid != null && isParticipantById[uid] != true) {
            _selectedRelatedUserIds.add(uid);
          }
        }
      }
      final relatedData = draft['related_data'];
      if (relatedData is Map) {
        for (final e in relatedData.entries) {
          final k = int.tryParse(e.key.toString());
          if (k != null && e.value is Map) {
            _relatedParticipantData[k] = Map<String, dynamic>.from(e.value as Map);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_draftKeyPrefix${widget.eventId}';
      final draft = {
        'new_participants': _newParticipants.map((p) => p.toJson()).toList(),
        'selected_related_ids': _selectedRelatedUserIds.toList(),
        'related_data': _relatedParticipantData.map((k, v) => MapEntry(k.toString(), v)),
      };
      await prefs.setString(key, jsonEncode(draft));
    } catch (_) {}
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_draftKeyPrefix${widget.eventId}');
    } catch (_) {}
  }

  void _addNewParticipant() {
    setState(() {
      _newParticipants.add(GroupNewParticipant(
        firstname: '',
        lastname: '',
        dob: null,
        gender: null,
        city: '',
        team: '',
        sportCategory: '',
        category: '',
        sets: null,
        listPending: false,
        email: '',
      ));
    });
  }

  void _removeNewParticipant(int index) {
    setState(() {
      _newParticipants.removeAt(index);
      _saveDraft();
    });
  }

  void _toggleRelatedUser(int userId, Map<String, dynamic> ru) {
    if (_cannotSelectRelatedUser(ru)) return;
    setState(() {
      if (_selectedRelatedUserIds.contains(userId)) {
        _selectedRelatedUserIds.remove(userId);
        _relatedParticipantData.remove(userId);
        _relatedUserSetsCache.remove(userId);
      } else {
        _selectedRelatedUserIds.add(userId);
        if (!_relatedParticipantData.containsKey(userId)) {
          final setsList = _data?['sets'];
          final firstSet = setsList is List && setsList.isNotEmpty && setsList.first is Map
              ? (setsList.first as Map)['number_set']
              : null;
          final catList = _data?['event']?['categories'];
          final firstCat = catList is List && catList.isNotEmpty
              ? (catList.first is Map ? (catList.first as Map)['category']?.toString() : catList.first.toString())
              : '';
          _relatedParticipantData[userId] = {
            'sets': firstSet is int ? firstSet : int.tryParse(firstSet?.toString() ?? ''),
            'category': firstCat ?? '',
            'city': ru['city']?.toString() ?? '',
            'sport_category': ru['sport_category']?.toString() ?? '',
          };
        }
      }
      _saveDraft();
    });
  }

  bool _isFetchingSetsForIndex = false;
  int? _fetchingSetsIndex;

  Future<void> _fetchSetsAndCategoriesForDob(String dob, int index) async {
    if (!mounted) return;
    final cached = _dobSetsCategoriesCache[dob];
    if (cached != null && index < _newParticipants.length) {
      if (mounted) {
        setState(() {
          _newParticipants[index] = _newParticipants[index].copyWith(
            availableSets: cached['availableSets'] as List<dynamic>? ?? [],
            availableCategories: cached['availableCategories'] as List<dynamic>? ?? [],
            categoriesForSet: null,
            category: '',
          );
        });
      }
      return;
    }
    setState(() {
      _isFetchingSetsForIndex = true;
      _fetchingSetsIndex = index;
    });
    try {
      final data = await _fetchSetsAndCategoriesForDobCached(dob);
      if (!mounted || index >= _newParticipants.length) return;
      if (data != null) {
        setState(() {
          _newParticipants[index] = _newParticipants[index].copyWith(
            availableSets: data['availableSets'] as List<dynamic>? ?? [],
            availableCategories: data['availableCategories'] as List<dynamic>? ?? [],
            categoriesForSet: null,
            category: '',
          );
          _isFetchingSetsForIndex = false;
          _fetchingSetsIndex = null;
        });
      } else {
        setState(() {
          _isFetchingSetsForIndex = false;
          _fetchingSetsIndex = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isFetchingSetsForIndex = false;
          _fetchingSetsIndex = null;
        });
      }
    }
  }

  /// Получить данные по dob из API. Результат кэшируется по dob.
  Future<Map<String, dynamic>?> _fetchSetsAndCategoriesForDobCached(String dob) async {
    final cached = _dobSetsCategoriesCache[dob];
    if (cached != null) return cached;
    try {
      final token = await getToken();
      final futures = await Future.wait([
        http.get(
          Uri.parse('$DOMAIN/api/event/${widget.eventId}/available-sets?dob=$dob'),
          headers: {'Authorization': 'Bearer $token'},
        ),
        http.get(
          Uri.parse('$DOMAIN/api/event/${widget.eventId}/available-category?dob=$dob'),
          headers: {'Authorization': 'Bearer $token'},
        ),
      ]);
      final setsR = futures[0];
      final catR = futures[1];
      List<dynamic> availableSets = [];
      List<dynamic> availableCategories = [];
      if (setsR.statusCode == 200) {
        final body = jsonDecode(setsR.body);
        availableSets = body['availableSets'] ?? body['available_sets'] ?? [];
      }
      if (catR.statusCode == 200) {
        final body = jsonDecode(catR.body);
        availableCategories = body['availableCategory'] ?? body['available_category'] ?? body['availableCategories'] ?? [];
      }
      final result = {
        'availableSets': availableSets,
        'availableCategories': availableCategories,
        'categoriesForSet': null,
      };
      _dobSetsCategoriesCache[dob] = result;
      return result;
    } catch (_) {
      return null;
    }
  }

  /// Batch: загрузить сеты/категории для всех selected related users с dob. Один setState, минимум запросов.
  void _ensureRelatedUsersSetsFetched(List relatedList) {
    if (!_isYearOrAgeCategories || _batchFetchScheduled) return;
    final toFetch = <int, String>{}; // userId -> dob
    for (final ru in relatedList) {
      if (ru is! Map) continue;
      final id = ru['id'];
      final userId = id is int ? id : int.tryParse(id.toString());
      if (userId == null || !_selectedRelatedUserIds.contains(userId)) continue;
      if (ru['is_participant'] == true || ru['already_registered'] == true) continue;
      if (_relatedUserSetsCache.containsKey(userId)) continue;
      final birthdayRaw = ru['birthday']?.toString();
      if (birthdayRaw == null || birthdayRaw.isEmpty) continue;
      final parsed = DateTime.tryParse(birthdayRaw);
      if (parsed == null) continue;
      final dobStr = DateFormat('yyyy-MM-dd').format(parsed);
      toFetch[userId] = dobStr;
    }
    if (toFetch.isEmpty) return;
    _batchFetchScheduled = true;
    _batchFetchingUserIds.addAll(toFetch.keys);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final uniqueDobs = toFetch.values.toSet().toList();
      final dobToData = <String, Map<String, dynamic>>{};
      for (final dob in uniqueDobs) {
        final data = await _fetchSetsAndCategoriesForDobCached(dob);
        if (data != null) dobToData[dob] = data;
      }
      if (!mounted) return;
      setState(() {
        for (final e in toFetch.entries) {
          final data = dobToData[e.value];
          if (data != null) {
            _relatedUserSetsCache[e.key] = Map<String, dynamic>.from(data);
          }
        }
        _batchFetchingUserIds.clear();
        _batchFetchScheduled = false;
      });
    });
  }

  Future<void> _fetchSetsAndCategoriesForRelatedUser(int userId, String dob) async {
    if (!mounted) return;
    if (_relatedUserSetsCache.containsKey(userId)) return;
    final cached = _dobSetsCategoriesCache[dob];
    if (cached != null) {
      if (mounted) {
        setState(() {
          _relatedUserSetsCache[userId] = Map<String, dynamic>.from(cached);
        });
      }
      return;
    }
    setState(() {
      _fetchingSetsForRelatedUserId = userId;
    });
    try {
      final data = await _fetchSetsAndCategoriesForDobCached(dob);
      if (!mounted) return;
      if (data != null) {
        setState(() {
          _relatedUserSetsCache[userId] = Map<String, dynamic>.from(data);
          _fetchingSetsForRelatedUserId = null;
        });
      } else {
        setState(() => _fetchingSetsForRelatedUserId = null);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _fetchingSetsForRelatedUserId = null);
      }
    }
  }

  Future<void> _fetchCategoriesForSetForRelatedUser(int userId, String dob, int numberSet) async {
    if (!mounted) return;
    try {
      final token = await getToken();
      final r = await http.get(
        Uri.parse('$DOMAIN/api/event/${widget.eventId}/available-category?dob=$dob&number_set=$numberSet'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted || r.statusCode != 200) return;
      final body = jsonDecode(r.body);
      final list = body['availableCategory'] ?? body['availableCategories'] ?? [];
      final cats = list is List ? list : [];
      if (mounted) {
        setState(() {
          final cache = _relatedUserSetsCache[userId] ?? {};
          _relatedUserSetsCache[userId] = {
            ...cache,
            'categoriesForSet': cats.isNotEmpty ? cats : null,
          };
        });
      }
    } catch (_) {}
  }

  /// Сеты для нового участника: если есть availableSets (по dob) — используем их, иначе — основные сеты события
  List<dynamic> _getSetsForNewParticipant(GroupNewParticipant p) {
    if (p.availableSets != null && p.availableSets!.isNotEmpty) {
      return p.availableSets!;
    }
    final setsRaw = _data?['sets'];
    return setsRaw is List ? setsRaw : [];
  }

  /// Преобразует сырые сеты (Map) в NumberSets для SetSelectionCards. Единообразие с одиночной регистрацией.
  List<NumberSets> _mapSetsToNumberSets(List<dynamic> raw) {
    return raw.map((s) {
      final m = s is Map ? Map<String, dynamic>.from(s as Map) : <String, dynamic>{};
      if (m['max_participants'] == null ||
          (m['max_participants'] is int && m['max_participants'] == 0)) {
        final free = (m['free'] is int ? m['free'] as int : int.tryParse(m['free']?.toString() ?? '0')) ?? 0;
        m['max_participants'] = free;
        m['participants_count'] = 0;
      }
      return NumberSets.fromJson(m);
    }).toList();
  }

  /// Категории для нового участника: фильтруем по выбранному сету (если есть), иначе — по dob или событию
  List<dynamic> _getCategoriesForNewParticipant(GroupNewParticipant p) {
    if (p.categoriesForSet != null && p.categoriesForSet!.isNotEmpty) {
      return p.categoriesForSet!;
    }
    if (p.availableCategories != null && p.availableCategories!.isNotEmpty) {
      return p.availableCategories!;
    }
    final catRaw = _data?['event']?['categories'];
    return catRaw is List ? catRaw : [];
  }

  Future<void> _fetchCategoriesForSet(String dob, int? numberSet, int index) async {
    if (!mounted || numberSet == null) return;
    final token = await getToken();
    try {
      final r = await http.get(
        Uri.parse('$DOMAIN/api/event/${widget.eventId}/available-category?dob=$dob&number_set=$numberSet'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted || r.statusCode != 200 || index >= _newParticipants.length) return;
      final body = jsonDecode(r.body);
      final list = body['availableCategory'] ?? body['availableCategories'] ?? [];
      final cats = list is List ? list : [];
      setState(() {
        _newParticipants[index] = _newParticipants[index].copyWith(
          categoriesForSet: cats.isNotEmpty ? cats : null,
        );
      });
    } catch (_) {}
  }

  void _onDobChanged(String dob, GroupNewParticipant p, int index) {
    _debounce?.cancel();
    if (dob.isEmpty) return;

    _debounce = Timer(_debounceDuration, () {
      _fetchSetsAndCategoriesForDob(dob, index);
    });
  }

  bool get _hasContact {
    return _data?['has_contact'] == true;
  }

  /// Событие требует оплаты для регистрации. Не показываем «неоплаченная заявка» для бесплатных событий.
  bool get _isNeedPayForReg {
    final v = _data?['event']?['is_need_pay_for_reg'];
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v.toInt() != 0;
    return v.toString() == '1' || v.toString().toLowerCase() == 'true';
  }

  bool get _isInputBirthday {
    return _data?['event']?['is_input_birthday'] == true;
  }

  bool get _isNeedSportCategory {
    return _data?['event']?['is_need_sport_category'] == true;
  }

  /// Когда is_input_set == 0 — нужно выбирать сет
  bool get _needSet {
    return (_data?['event']?['is_input_set'] ?? 1) == 0;
  }

  int get _isAutoCategories {
    final v = _data?['event']?['is_auto_categories'];
    return v is int ? v : 0;
  }

  /// MANUAL — выбирать категорию вручную; YEAR/AGE — категория по дате рождения; RESULT — не нужна
  bool get _isManualCategories => _isAutoCategories == _MANUAL_CATEGORIES;
  bool get _isYearOrAgeCategories =>
      _isAutoCategories == _AUTO_CATEGORIES_YEAR || _isAutoCategories == _AUTO_CATEGORIES_AGE;

  /// Сеты для related user. YEAR/AGE: из available-sets по dob; иначе из sets[] group-register.
  List<dynamic> _getSetsForRelatedUser(Map<String, dynamic> ru, int userId) {
    if (_isYearOrAgeCategories) {
      final cache = _relatedUserSetsCache[userId];
      final sets = cache?['availableSets'];
      if (sets is List && sets.isNotEmpty) return sets;
    }
    final setsRaw = _data?['sets'];
    return setsRaw is List ? setsRaw : [];
  }

  /// Категории для related user. YEAR/AGE: из available-category по dob/сету; иначе из event.categories.
  List<dynamic> _getCategoriesForRelatedUser(Map<String, dynamic> ru, int userId, Map<String, dynamic> data) {
    if (_isYearOrAgeCategories) {
      final cache = _relatedUserSetsCache[userId];
      final catsForSet = cache?['categoriesForSet'];
      if (catsForSet is List && catsForSet.isNotEmpty) return catsForSet;
      final availCats = cache?['availableCategories'];
      if (availCats is List && availCats.isNotEmpty) return availCats;
    }
    final catRaw = _data?['event']?['categories'] ?? _data?['categories'];
    return catRaw is List ? catRaw : [];
  }

  /// Есть ли хотя бы один свободный сет (free > 0 или list_pending != true) для этого участника
  bool _hasAnyFreeSetForRelatedUser(Map<String, dynamic> ru, int userId) {
    if (_isYearOrAgeCategories) {
      final cache = _relatedUserSetsCache[userId];
      final sets = cache?['availableSets'];
      if (sets is! List || sets.isEmpty) return true;
      return sets.any((s) => s is Map && s['list_pending'] != true);
    }
    final setsRaw = _data?['sets'];
    final setsList = setsRaw is List ? setsRaw : [];
    return setsList.any((s) => s is Map && s['list_pending'] != true);
  }

  /// Получить сеты для листа ожидания. MANUAL/RESULT: из sets[] group-register. YEAR/AGE: из available-sets?dob=
  List<Map<String, dynamic>> _getValidListPendingSetsSync() {
    final setsRaw = _data?['sets'];
    final setsList = setsRaw is List ? setsRaw : [];
    return setsList
        .where((s) => s is Map && s['list_pending'] == true)
        .map((s) => Map<String, dynamic>.from(s is Map ? s : {}))
        .toList();
  }

  /// Для YEAR/AGE — загрузить валидные сеты по дате рождения
  Future<List<Map<String, dynamic>>> _fetchValidListPendingSetsForDob(String dob) async {
    try {
      final token = await getToken();
      final r = await http.get(
        Uri.parse('$DOMAIN/api/event/${widget.eventId}/available-sets?dob=$dob'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (r.statusCode != 200) return _getValidListPendingSetsSync();
      final body = jsonDecode(r.body);
      final list = body['availableSets'] ?? body['available_sets'] ?? [];
      final sets = list is List ? list : [];
      return sets
          .where((s) => s is Map && s['list_pending'] == true)
          .map((s) => Map<String, dynamic>.from(s is Map ? s : {}))
          .toList();
    } catch (_) {
      return _getValidListPendingSetsSync();
    }
  }

  /// Категория по дате рождения (для YEAR/AGE)
  Future<String?> _fetchCategoryForDob(String dob) async {
    try {
      final token = await getToken();
      final r = await http.get(
        Uri.parse('$DOMAIN/api/event/${widget.eventId}/available-category?dob=$dob'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (r.statusCode != 200) return null;
      final body = jsonDecode(r.body);
      final list = body['availableCategory'] ?? body['available_category'] ?? body['availableCategories'] ?? [];
      final cats = list is List ? list : [];
      if (cats.isNotEmpty) {
        final first = cats.first;
        return first is Map ? (first['category'] ?? first)?.toString() : first.toString();
      }
    } catch (_) {}
    return null;
  }

  /// Возвращает количество свободных мест в сете. Берёт из всех доступных источников, минимум — самый консервативный.
  int _getFreeForSet(int numberSet) {
    int? free;
    void trySet(dynamic s) {
      if (s is! Map) return;
      final numSet = s['number_set'];
      final n = numSet is int ? numSet : int.tryParse(numSet?.toString() ?? '');
      if (n != numberSet) return;
      final f = s['free'];
      final v = f is int ? f : int.tryParse(f?.toString() ?? '0');
      if (v != null && (free == null || v < free!)) free = v;
    }
    final setsRaw = _data?['sets'];
    if (setsRaw is List) {
      for (final s in setsRaw) trySet(s);
    }
    for (final p in _newParticipants) {
      final list = _getSetsForNewParticipant(p);
      if (list is List) for (final s in list) trySet(s);
    }
    for (final userId in _selectedRelatedUserIds) {
      final cache = _relatedUserSetsCache[userId];
      final list = cache?['availableSets'];
      if (list is List) for (final s in list) trySet(s);
    }
    return free ?? 0;
  }

  /// Информация о переполнении: какие участники «лишние» в каждом сете (по порядку: новые, потом related).
  ({bool hasOverflow, String message, Set<int> overflowNewIndices, Set<int> overflowRelatedIds}) _getOverflowInfo() {
    final overflowNew = <int>{};
    final overflowRelated = <int>{};
    final Map<int, List<({bool isNew, int indexOrId})>> setToParticipants = {};

    for (var i = 0; i < _newParticipants.length; i++) {
      final p = _newParticipants[i];
      if (p.listPending) continue;
      final n = p.sets is int ? p.sets as int? : int.tryParse(p.sets?.toString() ?? '');
      if (n == null || n == 0) continue;
      setToParticipants.putIfAbsent(n, () => []).add((isNew: true, indexOrId: i));
    }
    final relatedList = _data?['related_users'] is List ? _data!['related_users'] as List : [];
    for (final ru in relatedList) {
      if (ru is! Map) continue;
      if (ru['is_participant'] == true || ru['already_registered'] == true) continue;
      final id = ru['id'];
      final userId = id is int ? id : int.tryParse(id.toString());
      if (userId == null || !_selectedRelatedUserIds.contains(userId)) continue;
      final p = _getRelatedParticipantData(userId);
      if (p == null) continue;
      if ((p['list_pending'] == true || p['list_pending'] == 'true')) continue;
      final n = p['sets'] is int ? p['sets'] as int? : int.tryParse(p['sets']?.toString() ?? '');
      if (n == null || n == 0) continue;
      setToParticipants.putIfAbsent(n, () => []).add((isNew: false, indexOrId: userId));
    }

    String? firstMessage;
    for (final e in setToParticipants.entries) {
      final free = _getFreeForSet(e.key);
      final list = e.value;
      if (list.length <= free) continue;
      firstMessage ??= 'Сет №${e.key}: свободно $free ${placeWord(free)}, а вы записали туда ${list.length} участников.';
      final overflowCount = list.length - free;
      for (var i = list.length - overflowCount; i < list.length; i++) {
        final item = list[i];
        if (item.isNew) {
          overflowNew.add(item.indexOrId);
        } else {
          overflowRelated.add(item.indexOrId);
        }
      }
    }
    return (
      hasOverflow: firstMessage != null,
      message: firstMessage ?? '',
      overflowNewIndices: overflowNew,
      overflowRelatedIds: overflowRelated,
    );
  }

  /// Проверяет переполнение. Если есть и не выбран чекбокс — блокирует. При выбранном чекбоксе — overflow уйдёт в list_pending.
  String? _checkSetOverbooking(List<Map<String, dynamic>> participants, List<Map<String, dynamic>> relatedUsers) {
    final info = _getOverflowInfo();
    if (!info.hasOverflow) return null;
    if (_addOverflowToListPending) return null; // разрешаем — overflow уйдёт в лист ожидания
    return info.message;
  }

  Future<void> _submitRegistration() async {
    if (!_hasContact) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Заполните контакты'),
          content: const Text(
            'Для групповой регистрации необходимо заполнить контактные данные в профиле.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Перейти в профиль'),
            ),
          ],
        ),
      );
      if (go == true && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ProfileEditScreen()),
        );
        if (mounted) _loadData();
      }
      return;
    }

    final participants = <Map<String, dynamic>>[];
    final relatedUsers = <Map<String, dynamic>>[];
    final overflowInfo = _needSet ? _getOverflowInfo() : null;

    for (var i = 0; i < _newParticipants.length; i++) {
      final p = _newParticipants[i];
      if (p.firstname.trim().isEmpty || p.lastname.trim().isEmpty) {
        _showSnack('Заполните имя и фамилию участников', isError: true, isValidation: true);
        return;
      }
      if (p.gender == null) {
        _showSnack('Укажите пол участника: ${p.firstname} ${p.lastname}', isError: true, isValidation: true);
        return;
      }
      if ((_isInputBirthday || _needSet) && p.dob == null) {
        _showSnack('Укажите дату рождения: ${p.firstname} ${p.lastname}', isError: true, isValidation: true);
        return;
      }
      if (_needSet && (p.sets == null || p.sets == 0)) {
        _showSnack('Выберите сет: ${p.firstname} ${p.lastname}', isError: true, isValidation: true);
        return;
      }
      if (_isAutoCategories != 1 && p.category.isEmpty) {
        _showSnack('Выберите категорию: ${p.firstname} ${p.lastname}', isError: true, isValidation: true);
        return;
      }
      if (_isNeedSportCategory && p.sportCategory.isEmpty) {
        _showSnack('Выберите разряд: ${p.firstname} ${p.lastname}', isError: true, isValidation: true);
        return;
      }

      final forceListPending = overflowInfo != null &&
          overflowInfo.hasOverflow &&
          _addOverflowToListPending &&
          overflowInfo.overflowNewIndices.contains(i);
      final listPending = forceListPending || p.listPending;

      participants.add({
        'firstname': p.firstname.trim(),
        'lastname': p.lastname.trim(),
        'dob': p.dob != null ? DateFormat('yyyy-MM-dd').format(p.dob!) : null,
        'gender': p.gender,
        'sets': p.sets ?? 0,
        'category': p.category,
        'list_pending': listPending ? 'true' : 'false',
        'city': p.city.trim(),
        'team': p.team.trim(),
        'sport_category': p.sportCategory,
        'email': p.email.trim(),
      });
    }

    final relatedUsersRaw = _data?['related_users'];
    final relatedList = relatedUsersRaw is List ? relatedUsersRaw : [];
    for (final ru in relatedList) {
      if (ru is! Map) continue;
      if (ru['is_participant'] == true || ru['already_registered'] == true) continue;
      final id = ru['id'];
      if (id == null) continue;
      final userId = id is int ? id : int.tryParse(id.toString());
      if (userId == null || !_selectedRelatedUserIds.contains(userId)) continue;

      final p = _getRelatedParticipantData(userId);
      if (p == null) continue;
      if (_needSet && (p['sets'] == null || p['sets'] == 0)) {
        _showSnack('Выберите сет для: ${ru['firstname']} ${ru['lastname']}', isError: true, isValidation: true);
        return;
      }
      if (_isAutoCategories != 1 && (p['category'] ?? '').toString().isEmpty) {
        _showSnack('Выберите категорию для: ${ru['firstname']} ${ru['lastname']}', isError: true, isValidation: true);
        return;
      }
      if (_isNeedSportCategory && (p['sport_category'] ?? '').toString().isEmpty) {
        _showSnack('Выберите разряд для: ${ru['firstname']} ${ru['lastname']}', isError: true, isValidation: true);
        return;
      }

      final forceListPending = overflowInfo != null &&
          overflowInfo.hasOverflow &&
          _addOverflowToListPending &&
          overflowInfo.overflowRelatedIds.contains(userId);
      final listPending = forceListPending || (p['list_pending'] == true || p['list_pending'] == 'true');
      String? dobStr;
      if (listPending) {
        final birthdayRaw = ru['birthday']?.toString();
        if (birthdayRaw == null || birthdayRaw.isEmpty) {
          _showSnack('Укажите дату рождения участника: ${ru['firstname']} ${ru['lastname']}', isError: true, isValidation: true);
          return;
        }
        final parsed = DateTime.tryParse(birthdayRaw);
        if (parsed == null) {
          _showSnack('Укажите дату рождения участника: ${ru['firstname']} ${ru['lastname']}', isError: true, isValidation: true);
          return;
        }
        dobStr = DateFormat('yyyy-MM-dd').format(parsed);
      }

      final entry = <String, dynamic>{
        'user_id': userId,
        'sets': p['sets'],
        'category': p['category'],
        'city': p['city'],
        'sport_category': p['sport_category'],
        'list_pending': listPending ? 'true' : 'false',
      };
      if (listPending && dobStr != null) {
        entry['dob'] = dobStr;
      }
      relatedUsers.add(entry);
    }

    if (participants.isEmpty && relatedUsers.isEmpty) {
      _showSnack('Добавьте хотя бы одного участника', isError: true, isValidation: true);
      return;
    }

    // Проверка: не превышаем ли свободные места в сетах (только для обычной регистрации, не list_pending)
    if (_needSet) {
      final overbook = _checkSetOverbooking(participants, relatedUsers);
      if (overbook != null) {
        _showSnack(overbook, isError: true, isValidation: true);
        return;
      }
    }

    try {
      final token = await getToken();
      final r = await http.post(
        Uri.parse('$DOMAIN/api/event/${widget.eventId}/group-register'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          if (participants.isNotEmpty) 'participants': participants,
          if (relatedUsers.isNotEmpty) 'related_users': relatedUsers,
        }),
      );

      final raw = r.body.isNotEmpty ? jsonDecode(r.body) : null;
      if (r.statusCode == 201 || r.statusCode == 200) {
        await _clearDraft();
        final goToCheckout = raw is Map && raw['go_to_group_checkout'] == true;
        final goToDocuments = raw is Map && raw['go_to_group_documents'] == true;
        if (goToCheckout && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => GroupCheckoutScreen(eventId: widget.eventId),
            ),
          );
        } else if (goToDocuments && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => GroupDocumentsScreen(eventId: widget.eventId, eventTitle: _data?['event']?['title']?.toString()),
            ),
          );
        } else {
          _showSnack(raw is Map ? (raw['message']?.toString() ?? 'Группа зарегистрирована') : 'Группа зарегистрирована');
          if (mounted) Navigator.pop(context, true);
        }
      } else if (r.statusCode == 422) {
        final messages = raw is Map ? raw['message'] : null;
        String msg = 'Ошибка регистрации';
        if (messages is List && messages.isNotEmpty) {
          msg = messages.map((e) => e.toString()).join('\n');
        } else if (messages is String) {
          msg = messages;
        }
        _showSnack(msg, isError: true);
      } else {
        _showSnack(raw is Map ? (raw['message']?.toString() ?? 'Ошибка') : 'Ошибка', isError: true);
      }
    } catch (e) {
      _showSnack(networkErrorMessage(e, 'Ошибка сети'), isError: true);
    }
  }

  Map<String, dynamic>? _getRelatedParticipantData(int userId) {
    return _relatedParticipantData[userId];
  }

  final Map<int, Map<String, dynamic>> _relatedParticipantData = {};
  /// Кэш сетов/категорий для related users (YEAR/AGE). userId -> {availableSets, availableCategories, categoriesForSet}.
  final Map<int, Map<String, dynamic>> _relatedUserSetsCache = {};
  /// Кэш по дате рождения — один запрос на dob, результат переиспользуется для всех участников с этой датой.
  final Map<String, Map<String, dynamic>> _dobSetsCategoriesCache = {};
  int? _fetchingSetsForRelatedUserId;
  final Set<int> _batchFetchingUserIds = {};
  bool _batchFetchScheduled = false;

  void _setRelatedParticipantData(int userId, Map<String, dynamic> data) {
    _relatedParticipantData[userId] = data;
    _saveDraft();
  }

  void _showSnack(String msg, {bool isError = false, bool isValidation = false}) {
    if (!mounted) return;
    if (isError) {
      if (isValidation) {
        showAppWarning(context, msg);
      } else {
        showAppError(context, msg);
      }
    } else {
      showAppSuccess(context, msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Заявить группу', style: unbounded(fontWeight: FontWeight.w500, fontSize: 18, color: Colors.white)),
          backgroundColor: AppColors.cardDark,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      if (!_showingErrorModal) {
        _showingErrorModal = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _error == null) return;
          showErrorReportModal(
            context,
            message: _error!,
            screen: 'group-register',
            eventId: widget.eventId,
            stackTrace: _errorStackTrace,
            extra: _errorExtra,
            onRetry: () {
              setState(() {
                _error = null;
                _errorStackTrace = null;
                _errorExtra = null;
                _isLoading = true;
                _showingErrorModal = false;
              });
              _loadData();
            },
            onSecondary: () => Navigator.pop(context),
            secondaryLabel: 'Назад',
          ).then((_) {
            if (mounted) setState(() => _showingErrorModal = false);
          });
        });
      }
      return Scaffold(
        appBar: AppBar(
          title: Text('Заявить группу', style: unbounded(fontWeight: FontWeight.w500, fontSize: 18, color: Colors.white)),
          backgroundColor: AppColors.cardDark,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final event = _data?['event'];
    final eventTitle = event is Map ? (event['title']?.toString() ?? '') : '';
    final relatedUsersRaw = _data?['related_users'];
    final relatedUsers = relatedUsersRaw is List ? relatedUsersRaw : [];
    final showContactMsg = !_hasContact;
    final groupDocumentsAlready = _data?['group_documents_already'] == true;

    return Scaffold(
      appBar: AppBar(
        title: Text('Заявить группу', style: unbounded(fontWeight: FontWeight.w500, fontSize: 18, color: Colors.white)),
        backgroundColor: AppColors.cardDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_newParticipants.isNotEmpty || _selectedRelatedUserIds.isNotEmpty) {
              _saveDraft();
            }
            Navigator.pop(context);
          },
        ),
        actions: const [],
      ),
      body: Container(
        color: AppColors.anthracite,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (eventTitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        eventTitle,
                        style: unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: RegistrationStepper(
                      currentStep: _currentStep,
                      totalSteps: _totalSteps,
                      stepLabels: const ['Участники', 'Данные', 'Сеты', 'Проверка'],
                    ),
                  ),
                  Text(
                    _stepTitle(_currentStep),
                    style: unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  _buildStepContent(_currentStep),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _stepBack,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.mutedGold,
                            side: const BorderSide(color: AppColors.mutedGold),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            _currentStep > 0 ? 'Назад' : 'Отмена',
                            style: unbounded(color: AppColors.mutedGold, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _currentStep < _totalSteps - 1 ? _stepForward : _submitRegistration,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.mutedGold,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            _currentStep < _totalSteps - 1 ? 'Продолжить →' : 'Зарегистрировать группу',
                            style: unbounded(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _stepTitle(int step) {
    switch (step) {
      case 0:
        return 'Выберите участников';
      case 1:
        return 'Данные участников';
      case 2:
        return 'Сеты и категории';
      case 3:
        return 'Проверка и отправка';
      default:
        return '';
    }
  }

  void _stepBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      if (_newParticipants.isNotEmpty || _selectedRelatedUserIds.isNotEmpty) _saveDraft();
      Navigator.pop(context);
    }
  }

  void _stepForward() {
    if (_validateStep(_currentStep)) {
      if (_currentStep < _totalSteps - 1) {
        setState(() => _currentStep++);
      } else {
        _submitRegistration();
      }
    }
  }

  bool _validateStep(int step) {
    switch (step) {
      case 0:
        if (_newParticipants.isEmpty && _selectedRelatedUserIds.isEmpty) {
          _showSnack('Добавьте хотя бы одного участника', isError: true, isValidation: true);
          return false;
        }
        for (final p in _newParticipants) {
          if (p.firstname.trim().isEmpty || p.lastname.trim().isEmpty) {
            _showSnack('Заполните имя и фамилию участников', isError: true, isValidation: true);
            return false;
          }
        }
        return true;
      case 1:
        for (final p in _newParticipants) {
          if ((_isInputBirthday || _needSet) && p.dob == null) {
            _showSnack('Укажите дату рождения: ${p.firstname} ${p.lastname}', isError: true, isValidation: true);
            return false;
          }
          if (p.gender == null) {
            _showSnack('Укажите пол: ${p.firstname} ${p.lastname}', isError: true, isValidation: true);
            return false;
          }
        }
        return true;
      case 2:
        for (final p in _newParticipants) {
          if (_needSet && (p.sets == null || p.sets == 0)) {
            _showSnack('Выберите сет: ${p.firstname} ${p.lastname}', isError: true, isValidation: true);
            return false;
          }
          if (_isAutoCategories != 1 && p.category.isEmpty) {
            _showSnack('Выберите категорию: ${p.firstname} ${p.lastname}', isError: true, isValidation: true);
            return false;
          }
          if (_isNeedSportCategory && p.sportCategory.isEmpty) {
            _showSnack('Выберите разряд: ${p.firstname} ${p.lastname}', isError: true, isValidation: true);
            return false;
          }
        }
        final relatedUsersRaw = _data?['related_users'];
        final relatedList = relatedUsersRaw is List ? relatedUsersRaw : [];
        for (final ru in relatedList) {
          if (ru is! Map) continue;
          if (ru['is_participant'] == true || ru['already_registered'] == true) continue;
          final id = ru['id'];
          final userId = id is int ? id : int.tryParse(id.toString());
          if (userId == null || !_selectedRelatedUserIds.contains(userId)) continue;
          final p = _getRelatedParticipantData(userId);
          if (p == null) continue;
          if (_needSet && (p['sets'] == null || p['sets'] == 0)) {
            _showSnack('Выберите сет для: ${ru['firstname']} ${ru['lastname']}', isError: true, isValidation: true);
            return false;
          }
          if (_isAutoCategories != 1 && (p['category'] ?? '').toString().isEmpty) {
            _showSnack('Выберите категорию для: ${ru['firstname']} ${ru['lastname']}', isError: true, isValidation: true);
            return false;
          }
          if (_isNeedSportCategory && (p['sport_category'] ?? '').toString().isEmpty) {
            _showSnack('Выберите разряд для: ${ru['firstname']} ${ru['lastname']}', isError: true, isValidation: true);
            return false;
          }
        }
        return true;
      case 3:
        return true;
      default:
        return true;
    }
  }

  Widget _buildStepContent(int step) {
    final event = _data?['event'];
    final eventTitle = event is Map ? (event['title']?.toString() ?? '') : '';
    final relatedUsersRaw = _data?['related_users'];
    final relatedList = relatedUsersRaw is List ? relatedUsersRaw : [];
    final showContactMsg = !_hasContact;
    final groupDocumentsAlready = _data?['group_documents_already'] == true;
    // Показываем «неоплаченная заявка» только если событие требует оплаты
    final hasUnpaidGroup = _hasUnpaidGroup && _isNeedPayForReg;

    if (step == 0) {
      return _buildStep0Participants(relatedList, showContactMsg, groupDocumentsAlready, hasUnpaidGroup);
    }
    if (step == 1) {
      return _buildStep1Data(relatedList);
    }
    if (step == 2) {
      return _buildStep2SetsCategories(relatedList);
    }
    return _buildStep3Review(relatedList);
  }

  Widget _buildStep0Participants(List relatedList, bool showContactMsg, bool groupDocumentsAlready, bool hasUnpaidGroup) {
    _ensureRelatedUsersSetsFetched(relatedList);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasUnpaidGroup) ...[
          Material(
            color: AppColors.mutedGold.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GroupCheckoutScreen(eventId: widget.eventId),
                  ),
                );
                if (mounted) _checkUnpaidGroup();
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.payment, color: AppColors.mutedGold, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Есть неоплаченная групповая заявка',
                            style: unbounded(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Продолжить оплату',
                            style: unbounded(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (groupDocumentsAlready || hasUnpaidGroup)
          Material(
            color: const Color(0xFF1E3A5F).withOpacity(0.4),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GroupDocumentsScreen(
                      eventId: widget.eventId,
                      eventTitle: _data?['event']?['title']?.toString(),
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.description, color: AppColors.mutedGold, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Документы участников',
                            style: unbounded(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Загрузить документы для участников группы',
                            style: unbounded(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                  ],
                ),
              ),
            ),
          ),
        if (groupDocumentsAlready || hasUnpaidGroup) const SizedBox(height: 20),
        if (showContactMsg)
          _buildWarningCard(
            'Заполните контактные данные в профиле для групповой регистрации.',
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileEditScreen()),
              );
              if (mounted) _loadData();
            },
            actionText: 'Заполнить профиль',
          ),
        if (showContactMsg) const SizedBox(height: 20),
        Text(
          'Ранее заявленные участники',
          style: unbounded(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        const SizedBox(height: 12),
        if (relatedList.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'У вас пока нет ранее заявленных участников. Добавьте новых участников ниже.',
              style: unbounded(color: Colors.white70, fontSize: 14),
            ),
          )
        else
          ...relatedList.map((ru) {
            if (ru is! Map) return const SizedBox.shrink();
            final id = ru['id'];
            final userId = id is int ? id : int.tryParse(id.toString() ?? '');
            if (userId == null) return const SizedBox.shrink();
            final name = '${ru['lastname'] ?? ''} ${ru['firstname'] ?? ''}'.trim();
            final isSelected = _selectedRelatedUserIds.contains(userId);
            return _buildRelatedUserCard(Map<String, dynamic>.from(ru), userId, name, isSelected, compact: true);
          }),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Новые участники',
                style: unbounded(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              onPressed: _addNewParticipant,
              icon: const Icon(Icons.add, size: 20, color: AppColors.mutedGold),
              label: Text('Добавить', style: unbounded(color: AppColors.mutedGold, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        if (_newParticipants.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Нажмите «Добавить», чтобы зарегистрировать нового участника.',
              style: unbounded(color: Colors.white70, fontSize: 14),
            ),
          )
        else ...[
          const SizedBox(height: 12),
          ...List.generate(_newParticipants.length, (i) => _buildNewParticipantCard(i, dataOnly: true)),
        ],
      ],
    );
  }

  Widget _buildStep1Data(List relatedList) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...relatedList.map((ru) {
          if (ru is! Map) return const SizedBox.shrink();
          final id = ru['id'];
          final userId = id is int ? id : int.tryParse(id.toString() ?? '');
          if (userId == null || !_selectedRelatedUserIds.contains(userId)) return const SizedBox.shrink();
          if (ru['is_participant'] == true || ru['already_registered'] == true) return const SizedBox.shrink();
          final name = '${ru['lastname'] ?? ''} ${ru['firstname'] ?? ''}'.trim();
          final data = _relatedParticipantData[userId] ?? {};
          return Card(
            color: AppColors.cardDark,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: unbounded(color: Colors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Text('Данные загружены из профиля. При необходимости измените город ниже.', style: unbounded(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: data['city']?.toString() ?? '',
                    onChanged: (v) => _setRelatedParticipantData(userId, {...data, 'city': v ?? ''}),
                    decoration: InputDecoration(
                      labelText: 'Город',
                      labelStyle: unbounded(color: AppColors.graphite),
                      filled: true,
                      fillColor: AppColors.rowAlt,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                    style: unbounded(color: Colors.white),
                  ),
                ],
              ),
            ),
          );
        }),
        ...List.generate(_newParticipants.length, (i) => _buildNewParticipantCard(i, dataOnly: true)),
      ],
    );
  }

  Widget _buildStep2SetsCategories(List relatedList) {
    _ensureRelatedUsersSetsFetched(relatedList);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...relatedList.map((ru) {
          if (ru is! Map) return const SizedBox.shrink();
          final ruMap = Map<String, dynamic>.from(ru);
          final id = ruMap['id'];
          final userId = id is int ? id : int.tryParse(id.toString() ?? '');
          if (userId == null || !_selectedRelatedUserIds.contains(userId)) return const SizedBox.shrink();
          if (ruMap['is_participant'] == true || ruMap['already_registered'] == true) return const SizedBox.shrink();
          final name = '${ruMap['lastname'] ?? ''} ${ruMap['firstname'] ?? ''}'.trim();
          final data = _relatedParticipantData[userId] ?? <String, dynamic>{};
          return Card(
            color: AppColors.cardDark,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: unbounded(color: Colors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _buildRelatedUserForm(ruMap, userId, data),
                  if (!_cannotSelectRelatedUser(ruMap)) _buildListPendingBlock(ruMap, userId),
                ],
              ),
            ),
          );
        }),
        ...List.generate(_newParticipants.length, (i) => _buildNewParticipantCard(i, setsOnly: true)),
      ],
    );
  }

  Widget _buildStep3Review(List relatedList) {
    final overflowInfo = _needSet ? _getOverflowInfo() : null;
    final hasOverflow = overflowInfo != null && overflowInfo.hasOverflow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Проверьте данные перед отправкой',
          style: unbounded(fontSize: 14, color: Colors.white70),
        ),
        const SizedBox(height: 16),
        if (hasOverflow && overflowInfo != null) ...[
          Card(
            color: Colors.orange.withOpacity(0.25),
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.orange, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange.shade300, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          overflowInfo.message,
                          style: unbounded(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Участники, отмеченные ниже, превышают доступные места. Их можно внести в лист ожидания.',
                    style: unbounded(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: _addOverflowToListPending,
                    onChanged: (v) => setState(() => _addOverflowToListPending = v ?? false),
                    title: Text(
                      'Внести избыточных участников в лист ожидания',
                      style: unbounded(color: Colors.white, fontSize: 14),
                    ),
                    activeColor: AppColors.mutedGold,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
          ),
        ],
        ...relatedList.map((ru) {
          if (ru is! Map) return const SizedBox.shrink();
          final ruMap = Map<String, dynamic>.from(ru);
          final id = ruMap['id'];
          final userId = id is int ? id : int.tryParse(id.toString() ?? '');
          if (userId == null || !_selectedRelatedUserIds.contains(userId)) return const SizedBox.shrink();
          if (ruMap['is_participant'] == true || ruMap['already_registered'] == true) return const SizedBox.shrink();
          final name = '${ruMap['lastname'] ?? ''} ${ruMap['firstname'] ?? ''}'.trim();
          final data = _getRelatedParticipantData(userId);
          final isOverflow = hasOverflow && (overflowInfo?.overflowRelatedIds.contains(userId) ?? false);
          return _buildReviewParticipantCard(name, data, ruMap, isOverflow: isOverflow);
        }),
        ...List.generate(_newParticipants.length, (i) {
          final p = _newParticipants[i];
          final isOverflow = hasOverflow && (overflowInfo?.overflowNewIndices.contains(i) ?? false);
          return _buildReviewParticipantCard('${p.firstname} ${p.lastname}'.trim(), {
            'sets': p.sets,
            'category': p.category,
            'sport_category': p.sportCategory,
          }, null, isOverflow: isOverflow);
        }),
      ],
    );
  }

  Widget _buildReviewParticipantCard(String name, Map<String, dynamic>? data, Map<String, dynamic>? ru, {bool isOverflow = false}) {
    final setsRaw = _data?['sets'];
    final setsList = setsRaw is List ? setsRaw : [];
    final setVal = data?['sets'];
    String setLabel = '—';
    if (setVal != null && setsList.isNotEmpty) {
      for (final s in setsList) {
        if (s is Map && (s['number_set'] == setVal || s['number_set'].toString() == setVal.toString())) {
          final ns = NumberSets.fromJson(Map<String, dynamic>.from(s as Map));
          final event = _data?['event'];
          final eventTitle = event is Map ? (event['title']?.toString() ?? '') : '';
          final startDateStr = event is Map ? event['start_date']?.toString() : null;
          final startDateFormatted = startDateStr != null
              ? (DateTime.tryParse(startDateStr) != null
                  ? DateFormat('dd.MM.yyyy').format(DateTime.parse(startDateStr))
                  : null)
              : null;
          setLabel = formatSetFull(
            ns,
            competitionTitle: eventTitle.isNotEmpty ? eventTitle : null,
            startDateFormatted: startDateFormatted,
          );
          break;
        }
      }
    }
    if (isOverflow && _addOverflowToListPending) {
      setLabel = '$setLabel (лист ожидания)';
    }
    return Card(
      color: AppColors.cardDark,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isOverflow
            ? BorderSide(color: Colors.orange.withOpacity(0.8), width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: unbounded(color: Colors.white, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(children: [
              Text('Сет: ', style: unbounded(color: Colors.white54, fontSize: 12)),
              Text(setLabel, style: unbounded(color: Colors.white, fontSize: 12)),
            ]),
            if ((data?['category'] ?? '').toString().isNotEmpty)
              Row(children: [
                Text('Категория: ', style: unbounded(color: Colors.white54, fontSize: 12)),
                Text((data?['category'] ?? '').toString(), style: unbounded(color: Colors.white, fontSize: 12)),
              ]),
            if ((data?['sport_category'] ?? '').toString().isNotEmpty)
              Row(children: [
                Text('Разряд: ', style: unbounded(color: Colors.white54, fontSize: 12)),
                Text((data?['sport_category'] ?? '').toString(), style: unbounded(color: Colors.white, fontSize: 12)),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningCard(String text, {VoidCallback? onTap, String? actionText}) {
    return Card(
      color: Colors.orange.withOpacity(0.2),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: unbounded(color: Colors.white)),
            if (actionText != null && onTap != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onTap,
                child: Text(actionText, style: unbounded(color: AppColors.mutedGold, fontWeight: FontWeight.w500)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Есть ли у участника статус для отображения (участвует, не может, в листе ожидания)
  bool _hasParticipantStatus(Map<String, dynamic> ru) {
    if (ru['is_participant'] == true || ru['already_registered'] == true) return true;
    if (ru['cannot_participate'] == true || ru['participation_blocked'] == true || ru['category_not_suitable'] == true) return true;
    if (ru['is_in_list_pending'] == true) return true;
    return false;
  }

  /// Участник не подходит для выбора (категория не подходит, уже участвует и т.д.)
  bool _cannotSelectRelatedUser(Map<String, dynamic> ru) {
    if (ru['is_participant'] == true || ru['already_registered'] == true) return true;
    if (ru['cannot_participate'] == true || ru['participation_blocked'] == true) return true;
    if (ru['category_not_suitable'] == true) return true;
    return false;
  }

  /// Статус участника: "Уже участвует" / "Не может участвовать"
  Widget _buildParticipantStatus(Map<String, dynamic> ru) {
    final isParticipant = ru['is_participant'] == true || ru['already_registered'] == true;
    final isPaid = ru['is_paid'] == true;
    final cannotParticipate = ru['cannot_participate'] == true || ru['participation_blocked'] == true || ru['category_not_suitable'] == true;
    if (isParticipant) {
      return Tooltip(
        message: isPaid ? 'Уже участвует. Оплата подтверждена' : 'Уже участвует',
        triggerMode: TooltipTriggerMode.tap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.mutedGold.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.mutedGold),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Уже участвует', style: unbounded(color: AppColors.mutedGold, fontSize: 12, fontWeight: FontWeight.w500)),
              if (isPaid) ...[
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Оплата подтверждена',
                  triggerMode: TooltipTriggerMode.tap,
                  child: const Icon(Icons.payments, color: Colors.green, size: 16),
                ),
              ],
            ],
          ),
        ),
      );
    }
    if (cannotParticipate) {
      final reason = ru['cannot_participate_reason']?.toString();
      return Tooltip(
        message: reason ?? 'Участник не может быть заявлен на это событие',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange),
          ),
          child: Text('Не может участвовать', style: unbounded(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w500)),
        ),
      );
    }
    final isInListPending = ru['is_in_list_pending'] == true;
    if (isInListPending) {
      final numberSets = ru['list_pending_number_sets'];
      final setsStr = numberSets is List && numberSets.isNotEmpty
          ? numberSets.map((n) => n?.toString() ?? '').join(', ')
          : '';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule, color: Colors.amber.shade300, size: 14),
            const SizedBox(width: 6),
            Text(
              'В листе ожидания${setsStr.isNotEmpty ? ' (Сет $setsStr)' : ''}',
              style: unbounded(color: Colors.amber.shade300, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildRelatedUserCard(Map<String, dynamic> ru, int userId, String name, bool isSelected, {bool compact = false}) {
    final dob = ru['birthday']?.toString();
    final sportCat = ru['sport_category']?.toString();
    final city = ru['city']?.toString();
    var data = _relatedParticipantData[userId] ?? {};
    if (data.isEmpty && isSelected) {
      final setsList = _data?['sets'];
      final firstSet = setsList is List && setsList.isNotEmpty && setsList.first is Map
          ? (setsList.first as Map)['number_set']
          : null;
      final catList = _data?['event']?['categories'];
      final firstCat = catList is List && catList.isNotEmpty
          ? (catList.first is Map ? (catList.first as Map)['category']?.toString() : catList.first.toString())
          : '';
      data = {
        'sets': firstSet is int ? firstSet : int.tryParse(firstSet?.toString() ?? ''),
        'category': firstCat ?? '',
        'city': city ?? '',
        'sport_category': sportCat ?? '',
      };
    }

    final isAlreadyParticipant = ru['is_participant'] == true || ru['already_registered'] == true;
    return Card(
      color: AppColors.cardDark,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: (isAlreadyParticipant || _cannotSelectRelatedUser(ru)) ? null : () => _toggleRelatedUser(userId, ru),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: isSelected,
                    onChanged: isAlreadyParticipant || _cannotSelectRelatedUser(ru) ? null : (v) => _toggleRelatedUser(userId, ru),
                    activeColor: AppColors.mutedGold,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: unbounded(color: Colors.white, fontWeight: FontWeight.w600)),
                        if (dob != null && dob.isNotEmpty)
                          Text('ДР: $dob', style: unbounded(color: Colors.white70, fontSize: 12)),
                        if (sportCat != null && sportCat.isNotEmpty)
                          Text('Разряд: $sportCat', style: unbounded(color: Colors.white70, fontSize: 12)),
                        if (city != null && city.isNotEmpty)
                          Text('Город: $city', style: unbounded(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              if (_hasParticipantStatus(ru)) ...[
                const SizedBox(height: 10),
                _buildParticipantStatus(ru),
              ],
              if (isSelected && !compact) ...[
                const SizedBox(height: 16),
                _buildRelatedUserForm(ru, userId, data),
              ],
              if (!isAlreadyParticipant && !compact) _buildListPendingBlock(ru, userId),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListPendingBlock(Map<String, dynamic> ru, int userId) {
    if (_cannotSelectRelatedUser(ru)) return const SizedBox.shrink();

    final isInListPending = ru['is_in_list_pending'] == true;
    final numberSets = ru['list_pending_number_sets'];
    final hasBirthday = (ru['birthday']?.toString() ?? '').isNotEmpty;
    final validSetsSync = _getValidListPendingSetsSync();
    final hasAnyFreeSet = _hasAnyFreeSetForRelatedUser(ru, userId);
    final hasListPendingSets = _isYearOrAgeCategories
        ? (hasBirthday && !hasAnyFreeSet)
        : (validSetsSync.isNotEmpty && !hasAnyFreeSet);

    if (isInListPending) {
      final setsStr = numberSets is List && numberSets.isNotEmpty
          ? numberSets.map((n) => n?.toString() ?? '').join(', ')
          : '';
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Row(
          children: [
            Icon(Icons.schedule, color: Colors.amber.shade300, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Уже в листе ожидания${setsStr.isNotEmpty ? ' (Сет $setsStr)' : ''}',
                style: unbounded(color: Colors.amber.shade300, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: () => _showAddToListPendingSheet(ru, userId, isEdit: true),
              child: Text('Изменить', style: unbounded(fontSize: 12, color: AppColors.mutedGold)),
            ),
            TextButton(
              onPressed: () => _removeFromListPending(userId),
              child: Text('Удалить', style: unbounded(color: Colors.red.shade300, fontSize: 12)),
            ),
          ],
        ),
      );
    }
    if (hasListPendingSets) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: OutlinedButton.icon(
          onPressed: () => _showAddToListPendingSheet(ru, userId, isEdit: false),
          icon: const Icon(Icons.add, size: 18),
          label: Text('Добавить в лист ожидания', style: unbounded(fontSize: 13)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.mutedGold,
            side: const BorderSide(color: AppColors.mutedGold),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _showAddToListPendingSheet(Map<String, dynamic> ru, int userId, {required bool isEdit}) async {
    final birthdayRaw = ru['birthday']?.toString();
    if (birthdayRaw == null || birthdayRaw.isEmpty) {
      _showSnack('Укажите дату рождения участника в профиле', isError: true, isValidation: true);
      return;
    }
    final parsedBirthday = DateTime.tryParse(birthdayRaw);
    if (parsedBirthday == null) {
      _showSnack('Укажите дату рождения участника в профиле', isError: true, isValidation: true);
      return;
    }
    final birthdayStr = DateFormat('yyyy-MM-dd').format(parsedBirthday);

    List<Map<String, dynamic>> listPendingSets;
    String? categoryByDob;
    if (_isYearOrAgeCategories) {
      listPendingSets = await _fetchValidListPendingSetsForDob(birthdayStr);
      categoryByDob = await _fetchCategoryForDob(birthdayStr);
    } else {
      listPendingSets = _getValidListPendingSetsSync();
    }

    if (listPendingSets.isEmpty) {
      _showSnack('Нет сетов для листа ожидания', isError: true, isValidation: true);
      return;
    }

    final categoriesRaw = _data?['event']?['categories'] ?? _data?['categories'];
    final categoriesList = categoriesRaw is List ? categoriesRaw : [];
    final sportCategoriesRaw = _data?['sport_categories'] ?? _data?['event']?['sport_categories'];
    final sportCategoriesList = sportCategoriesRaw is List ? sportCategoriesRaw : [];
    final needCategorySelect = _isManualCategories && categoriesList.isNotEmpty;
    final needSportCategory = _isNeedSportCategory && sportCategoriesList.isNotEmpty;
    final gender = ru['gender']?.toString();

    final initialNumberSets = ru['list_pending_number_sets'] is List
        ? (ru['list_pending_number_sets'] as List).map((n) => int.tryParse(n?.toString() ?? '')).whereType<int>().toList()
        : <int>[];
    final pData = _getRelatedParticipantData(userId);

    Set<int> sheetSelectedNumberSets = {};
    if (isEdit && initialNumberSets.isNotEmpty) {
      sheetSelectedNumberSets = initialNumberSets.toSet();
    } else if (listPendingSets.isNotEmpty) {
      final first = listPendingSets.first;
      final n = first['number_set'] is int ? first['number_set'] as int? : int.tryParse(first['number_set']?.toString() ?? '');
      if (n != null) sheetSelectedNumberSets = {n};
    }

    String? sheetCategory = categoryByDob ?? pData?['category']?.toString();
    if ((sheetCategory == null || sheetCategory.isEmpty) && needCategorySelect) {
      sheetCategory = categoriesList.isNotEmpty
          ? (categoriesList.first is Map ? (categoriesList.first as Map)['category']?.toString() : categoriesList.first.toString())
          : null;
    }
    String? sheetSportCategory = pData?['sport_category']?.toString();
    if (sheetSportCategory == null || sheetSportCategory.isEmpty) {
      sheetSportCategory = sportCategoriesList.isNotEmpty
          ? (sportCategoriesList.first is Map
              ? ((sportCategoriesList.first as Map)['category'] ?? (sportCategoriesList.first as Map)['sport_category'])?.toString()
              : sportCategoriesList.first.toString())
          : null;
    }

    if (!mounted) return;
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
                    isEdit ? 'Изменить данные в листе ожидания' : 'Добавить в лист ожидания',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  Text(
                    '${ru['firstname']} ${ru['lastname']}',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Если все места в интересующих вас сетах заняты, участник будет добавлен в лист ожидания.',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  if (birthdayStr.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Text('Дата рождения: ', style: TextStyle(color: Colors.white70, fontSize: 14)),
                          Text(DateFormat('dd.MM.yyyy').format(parsedBirthday), style: const TextStyle(color: Colors.white, fontSize: 14)),
                        ],
                      ),
                    ),
                  if (gender != null && gender.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Text('Пол: ', style: TextStyle(color: Colors.white70, fontSize: 14)),
                          Text(gender == 'male' ? 'Мужской' : gender == 'female' ? 'Женский' : gender, style: const TextStyle(color: Colors.white, fontSize: 14)),
                        ],
                      ),
                    ),
                  if (_isYearOrAgeCategories && categoryByDob != null && categoryByDob.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Text('Категория: ', style: TextStyle(color: Colors.white70, fontSize: 14)),
                          Text(categoryByDob, style: const TextStyle(color: Colors.white, fontSize: 14)),
                        ],
                      ),
                    ),
                  const Text('Сеты', style: TextStyle(fontSize: 14, color: Colors.white70)),
                  const SizedBox(height: 6),
                  ...listPendingSets.where((s) {
                    final m = s is Map ? s : {};
                    final n = m['number_set'] is int ? m['number_set'] as int? : int.tryParse(m['number_set']?.toString() ?? '');
                    return n != null;
                  }).map((s) {
                    final m = s is Map ? s : {};
                    final numSet = (m['number_set'] is int ? m['number_set'] as int : int.tryParse(m['number_set']?.toString() ?? ''))!;
                    final time = m['time']?.toString() ?? '';
                    final label = 'Сет №$numSet $time';
                    return CheckboxListTile(
                      title: Text(label, style: const TextStyle(color: Colors.white)),
                      value: sheetSelectedNumberSets.contains(numSet),
                      activeColor: AppColors.mutedGold,
                      onChanged: (v) {
                        setSheetState(() {
                          if (v == true) {
                            sheetSelectedNumberSets = {...sheetSelectedNumberSets, numSet};
                          } else {
                            sheetSelectedNumberSets = {...sheetSelectedNumberSets}..remove(numSet);
                          }
                        });
                      },
                    );
                  }),
                  if (needCategorySelect) ...[
                    const SizedBox(height: 12),
                    const Text('Категория', style: TextStyle(fontSize: 14, color: Colors.white70)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categoriesList.map((c) {
                        final cat = c is Map ? (c['category'] ?? c)?.toString() ?? '' : c.toString();
                        final isSelected = (sheetCategory ?? '') == cat;
                        return GestureDetector(
                          onTap: () => setSheetState(() => sheetCategory = isSelected ? null : cat),
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
                              cat,
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
                  if (needSportCategory) ...[
                    const SizedBox(height: 12),
                    const Text('Разряд', style: TextStyle(fontSize: 14, color: Colors.white70)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: sportCategoriesList.map((s) {
                        final sc = s is Map ? (s['category'] ?? s['sport_category'] ?? '')?.toString() ?? '' : s.toString();
                        final isSelected = (sheetSportCategory ?? '') == sc;
                        return GestureDetector(
                          onTap: () => setSheetState(() => sheetSportCategory = isSelected ? null : sc),
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
                              sc,
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
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      final numberSets = sheetSelectedNumberSets.toList()..sort();
                      if (numberSets.isEmpty) {
                        _showSnack('Выберите хотя бы один сет', isError: true, isValidation: true);
                        return;
                      }
                      if (needCategorySelect && (sheetCategory == null || sheetCategory!.isEmpty)) {
                        _showSnack('Выберите категорию', isError: true, isValidation: true);
                        return;
                      }
                      if (needSportCategory && (sheetSportCategory == null || sheetSportCategory!.isEmpty)) {
                        _showSnack('Выберите разряд', isError: true, isValidation: true);
                        return;
                      }
                      final categoryToSend = _isYearOrAgeCategories ? (categoryByDob ?? sheetCategory) : sheetCategory;
                      Navigator.pop(context);
                      await _addToListPending(userId, numberSets, birthdayStr, categoryToSend, sheetSportCategory, gender);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mutedGold,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Подтвердить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
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

  Future<void> _addToListPending(int userId, List<int> numberSets, String birthday, String? category, String? sportCategory, [String? gender]) async {
    try {
      final token = await getToken();
      final body = <String, dynamic>{
        'user_id': userId,
        'number_sets': numberSets,
        'birthday': birthday,
      };
      if (category != null && category.isNotEmpty) body['category'] = category;
      if (sportCategory != null && sportCategory.isNotEmpty) body['sport_category'] = sportCategory;
      if (gender != null && gender.isNotEmpty) body['gender'] = gender;

      final r = await http.post(
        Uri.parse('$DOMAIN/api/event/${widget.eventId}/add-to-list-pending'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      final raw = r.body.isNotEmpty ? jsonDecode(r.body) : null;
      final success = r.statusCode == 200 && (raw is Map && raw['success'] == true);
      final message = raw is Map ? raw['message']?.toString() ?? '' : '';

      if (!mounted) return;
      if (success) {
        _showSnack(message.isNotEmpty ? message : 'Участник добавлен в лист ожидания');
        _loadData();
      } else {
        _showSnack(message.isNotEmpty ? message : 'Ошибка добавления в лист ожидания', isError: true);
      }
    } catch (e) {
      if (mounted) _showSnack(networkErrorMessage(e, 'Ошибка сети'), isError: true);
    }
  }

  Future<void> _removeFromListPending(int userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить из листа ожидания'),
        content: const Text('Участник будет удалён из листа ожидания. Продолжить?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final token = await getToken();
      final r = await http.post(
        Uri.parse('$DOMAIN/api/event/${widget.eventId}/remove-from-list-pending'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'user_id': userId}),
      );
      final raw = r.body.isNotEmpty ? jsonDecode(r.body) : null;
      final success = r.statusCode == 200 && (raw is Map && raw['success'] == true);
      final message = raw is Map ? raw['message']?.toString() ?? '' : '';

      if (!mounted) return;
      if (success) {
        _showSnack(message.isNotEmpty ? message : 'Участник удалён из листа ожидания');
        _loadData();
      } else {
        _showSnack(message.isNotEmpty ? message : 'Ошибка удаления', isError: true);
      }
    } catch (e) {
      if (mounted) _showSnack(networkErrorMessage(e, 'Ошибка сети'), isError: true);
    }
  }

  Widget _buildRelatedUserForm(Map<String, dynamic> ru, int userId, Map<String, dynamic> data) {
    final birthdayRaw = ru['birthday']?.toString();
    final hasBirthday = birthdayRaw != null && birthdayRaw.isNotEmpty;
    final dobParsed = hasBirthday ? DateTime.tryParse(birthdayRaw) : null;
    final dobStr = dobParsed != null ? DateFormat('yyyy-MM-dd').format(dobParsed) : null;

    final setsList = _getSetsForRelatedUser(ru, userId);
    final categoriesList = _getCategoriesForRelatedUser(ru, userId, data);
    final isFetching = _batchFetchingUserIds.contains(userId) || _fetchingSetsForRelatedUserId == userId;
    final needSet = _needSet && (setsList.isNotEmpty || isFetching);
    final needCategory = _isAutoCategories != 1 && (categoriesList.isNotEmpty || isFetching);
    final needSportCategory = _isNeedSportCategory && (_data?['sport_categories'] is List);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (needSet) ...[
          const Text('Сет', style: TextStyle(color: Colors.white70, fontSize: 12)),
          if (setsList.isNotEmpty && setsList.any((s) => s is Map && s['list_pending'] == true))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Если все места в сете заняты (лист ожидания), участник будет добавлен в список ожидания.',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ),
          const SizedBox(height: 8),
          if (isFetching)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text('Загрузка сетов по дате рождения...', style: unbounded(color: Colors.white54, fontSize: 12)),
              ),
            )
          else
          SetSelectionCards(
            sets: _mapSetsToNumberSets(setsList),
            selected: () {
              final numSets = _mapSetsToNumberSets(setsList);
              final val = data['sets'] is int ? data['sets'] as int? : int.tryParse(data['sets']?.toString() ?? '');
              if (val == null) return null;
              for (final ns in numSets) {
                if (ns.number_set == val) return ns;
              }
              return null;
            }(),
            onChanged: (NumberSets? ns) async {
              if (ns == null) return;
              bool listPending = false;
              for (final s in setsList) {
                if (s is Map && (s['number_set'] == ns.number_set || s['number_set']?.toString() == ns.number_set.toString())) {
                  listPending = s['list_pending'] == true;
                  break;
                }
              }
              setState(() {
                _setRelatedParticipantData(userId, {...data, 'sets': ns.number_set, 'list_pending': listPending, 'category': ''});
              });
              if (_isYearOrAgeCategories && dobStr != null) {
                await _fetchCategoriesForSetForRelatedUser(userId, dobStr, ns.number_set is int ? ns.number_set as int : int.tryParse(ns.number_set?.toString() ?? '') ?? 0);
              }
            },
          ),
          const SizedBox(height: 12),
        ],
        if (needCategory && !isFetching) ...[
          const Text('Категория', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categoriesList.map((c) {
              final cat = c is Map ? c['category']?.toString() ?? '' : c.toString();
              final isSelected = (data['category']?.toString() ?? '') == cat;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _setRelatedParticipantData(userId, {...data, 'category': isSelected ? '' : cat});
                  });
                },
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
                    cat,
                    style: unbounded(
                      fontSize: 14,
                      color: isSelected ? AppColors.mutedGold : Colors.white,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
        if (needSportCategory) ...[
          const Text('Разряд', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ((_data?['sport_categories']) as List? ?? []).map((s) {
              final sc = s is Map ? (s['category'] ?? s['sport_category'] ?? '').toString() : s.toString();
              final isSelected = (data['sport_category']?.toString() ?? '') == sc;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _setRelatedParticipantData(userId, {...data, 'sport_category': isSelected ? '' : sc});
                  });
                },
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
                    sc,
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

  Widget _buildNewParticipantCard(int index, {bool dataOnly = false, bool setsOnly = false}) {
    final p = _newParticipants[index];
    return Card(
      color: AppColors.cardDark,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    setsOnly ? '${p.firstname} ${p.lastname}'.trim().isEmpty ? 'Участник ${index + 1}' : '${p.firstname} ${p.lastname}'.trim() : 'Участник ${index + 1}',
                    style: unbounded(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                  onPressed: () => _removeNewParticipant(index),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!setsOnly) TextFormField(
              initialValue: p.firstname,
              onChanged: (v) {
                setState(() {
                  _newParticipants[index] = p.copyWith(firstname: v);
                  _saveDraft();
                });
              },
              decoration: InputDecoration(
                labelText: 'Имя',
                labelStyle: unbounded(color: AppColors.graphite),
                filled: true,
                fillColor: AppColors.rowAlt,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              style: unbounded(color: Colors.white),
            ),
            if (!setsOnly) const SizedBox(height: 12),
            if (!setsOnly) TextFormField(
              initialValue: p.lastname,
              onChanged: (v) {
                setState(() {
                  _newParticipants[index] = p.copyWith(lastname: v);
                  _saveDraft();
                });
              },
              decoration: InputDecoration(
                labelText: 'Фамилия',
                labelStyle: unbounded(color: AppColors.graphite),
                filled: true,
                fillColor: AppColors.rowAlt,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              style: unbounded(color: Colors.white),
            ),
            if (!setsOnly && (_isInputBirthday || _needSet)) ...[
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  p.dob != null ? DateFormat('dd.MM.yyyy').format(p.dob!) : 'Дата рождения',
                  style: unbounded(color: p.dob != null ? Colors.white : Colors.white54),
                ),
                trailing: const Icon(Icons.calendar_today, color: Colors.white70),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: p.dob ?? DateTime.now().subtract(const Duration(days: 365 * 10)),
                    firstDate: DateTime(1990),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() {
                      _newParticipants[index] = p.copyWith(dob: date);
                      _onDobChanged(DateFormat('yyyy-MM-dd').format(date), p.copyWith(dob: date), index);
                      _saveDraft();
                    });
                  }
                },
              ),
            ],
            if (!setsOnly) const SizedBox(height: 12),
            if (!setsOnly) _buildGenderSelector(p, index),
            if (!dataOnly && _needSet && (_getSetsForNewParticipant(p).isNotEmpty || _fetchingSetsIndex == index)) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('Сет', style: unbounded(color: Colors.white70, fontSize: 12)),
                  if (_fetchingSetsIndex == index) ...[
                    const SizedBox(width: 8),
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ],
              ),
              if (_getSetsForNewParticipant(p).isNotEmpty && _getSetsForNewParticipant(p).any((s) => s is Map && s['list_pending'] == true))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Если все места в сете заняты (лист ожидания), участник будет добавлен в список ожидания.',
                    style: unbounded(color: Colors.white54, fontSize: 11),
                  ),
                ),
              const SizedBox(height: 4),
              if (_fetchingSetsIndex == index)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: Text('Загрузка сетов по дате рождения...', style: unbounded(color: Colors.white54, fontSize: 12))),
                )
              else
              SetSelectionCards(
                sets: _mapSetsToNumberSets(_getSetsForNewParticipant(p)),
                selected: () {
                  final numSets = _mapSetsToNumberSets(_getSetsForNewParticipant(p));
                  if (p.sets == null) return null;
                  for (final ns in numSets) {
                    if (ns.number_set == p.sets) return ns;
                  }
                  return null;
                }(),
                onChanged: (NumberSets? ns) async {
                  if (ns == null) return;
                  bool listPendingVal = false;
                  for (final s in _getSetsForNewParticipant(p)) {
                    if (s is Map && (s['number_set'] == ns.number_set || s['number_set'].toString() == ns.number_set.toString())) {
                      listPendingVal = s['list_pending'] == true;
                      break;
                    }
                  }
                  setState(() {
                    _newParticipants[index] = p.copyWith(
                      sets: ns.number_set,
                      listPending: listPendingVal,
                      categoriesForSet: null,
                      category: '',
                    );
                    _saveDraft();
                  });
                  if (p.dob != null) {
                    await _fetchCategoriesForSet(DateFormat('yyyy-MM-dd').format(p.dob!), ns.number_set, index);
                  }
                },
              ),
            ],
            if (!dataOnly && _isAutoCategories != 1 && _getCategoriesForNewParticipant(p).isNotEmpty && _fetchingSetsIndex != index) ...[
              const SizedBox(height: 12),
              Text('Категория', style: unbounded(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _getCategoriesForNewParticipant(p).map((c) {
                  final m = c is Map ? c : <String, dynamic>{};
                  final cat = m['category']?.toString() ?? '';
                  final isSelected = p.category == cat;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _newParticipants[index] = p.copyWith(category: isSelected ? '' : cat);
                        _saveDraft();
                      });
                    },
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
                        cat,
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
            if (!dataOnly && _isNeedSportCategory && (_data?['sport_categories'] is List)) ...[
              const SizedBox(height: 12),
              Text('Разряд', style: unbounded(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ((_data?['sport_categories']) as List? ?? []).map((s) {
                  final sc = (s is Map ? s['category'] ?? s['sport_category'] ?? s.toString() : s.toString()).toString();
                  final isSelected = p.sportCategory == sc;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _newParticipants[index] = p.copyWith(sportCategory: isSelected ? '' : sc);
                        _saveDraft();
                      });
                    },
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
                        sc,
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
            if (!setsOnly) const SizedBox(height: 12),
            if (!setsOnly) TextFormField(
              initialValue: p.city,
              onChanged: (v) {
                setState(() {
                  _newParticipants[index] = p.copyWith(city: v);
                  _saveDraft();
                });
              },
              decoration: InputDecoration(
                labelText: 'Город',
                labelStyle: unbounded(color: AppColors.graphite),
                filled: true,
                fillColor: AppColors.rowAlt,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              style: unbounded(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderSelector(GroupNewParticipant p, int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Пол', style: unbounded(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
            onPressed: () {
              setState(() {
                _newParticipants[index] = p.copyWith(gender: 'male');
                _saveDraft();
              });
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: p.gender == 'male' ? Colors.white : Colors.white54,
              side: BorderSide(color: p.gender == 'male' ? AppColors.mutedGold : Colors.white38),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('М'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              setState(() {
                _newParticipants[index] = p.copyWith(gender: 'female');
                _saveDraft();
              });
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: p.gender == 'female' ? Colors.white : Colors.white54,
              side: BorderSide(color: p.gender == 'female' ? AppColors.mutedGold : Colors.white38),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Ж'),
          ),
        ),
          ],
        ),
      ],
    );
  }
}

class GroupNewParticipant {
  final String firstname;
  final String lastname;
  final DateTime? dob;
  final String? gender;
  final String city;
  final String team;
  final String sportCategory;
  final String category;
  final int? sets;
  final bool listPending;
  final String email;
  final List<dynamic>? availableSets;
  final List<dynamic>? availableCategories;
  final List<dynamic>? categoriesForSet;

  GroupNewParticipant({
    required this.firstname,
    required this.lastname,
    this.dob,
    this.gender,
    this.city = '',
    this.team = '',
    this.sportCategory = '',
    this.category = '',
    this.sets,
    this.listPending = false,
    this.email = '',
    this.availableSets,
    this.availableCategories,
    this.categoriesForSet,
  });

  GroupNewParticipant copyWith({
    String? firstname,
    String? lastname,
    DateTime? dob,
    String? gender,
    String? city,
    String? team,
    String? sportCategory,
    String? category,
    int? sets,
    bool? listPending,
    String? email,
    List<dynamic>? availableSets,
    List<dynamic>? availableCategories,
    List<dynamic>? categoriesForSet,
  }) {
    return GroupNewParticipant(
      firstname: firstname ?? this.firstname,
      lastname: lastname ?? this.lastname,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      city: city ?? this.city,
      team: team ?? this.team,
      sportCategory: sportCategory ?? this.sportCategory,
      category: category ?? this.category,
      sets: sets ?? this.sets,
      listPending: listPending ?? this.listPending,
      email: email ?? this.email,
      availableSets: availableSets ?? this.availableSets,
      availableCategories: availableCategories ?? this.availableCategories,
      categoriesForSet: categoriesForSet ?? this.categoriesForSet,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'firstname': firstname,
      'lastname': lastname,
      'dob': dob != null ? DateFormat('yyyy-MM-dd').format(dob!) : null,
      'gender': gender,
      'city': city,
      'team': team,
      'sport_category': sportCategory,
      'category': category,
      'sets': sets,
      'list_pending': listPending,
      'email': email,
    };
  }

  static GroupNewParticipant fromJson(Map<String, dynamic> json) {
    DateTime? dob;
    if (json['dob'] != null) {
      dob = DateTime.tryParse(json['dob'].toString());
    }
    return GroupNewParticipant(
      firstname: json['firstname']?.toString() ?? '',
      lastname: json['lastname']?.toString() ?? '',
      dob: dob,
      gender: json['gender']?.toString(),
      city: json['city']?.toString() ?? '',
      team: json['team']?.toString() ?? '',
      sportCategory: json['sport_category']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      sets: json['sets'] is int ? json['sets'] : int.tryParse(json['sets']?.toString() ?? ''),
      listPending: json['list_pending'] == true || json['list_pending'] == 'true',
      email: json['email']?.toString() ?? '',
    );
  }
}
