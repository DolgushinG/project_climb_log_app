import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../login.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../utils/network_error_helper.dart';
import '../utils/session_error_helper.dart';
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
  bool _hasUnpaidGroup = false;

  // Новые участники и выбранные related_users
  final List<GroupNewParticipant> _newParticipants = [];
  final Set<int> _selectedRelatedUserIds = {};

  Timer? _debounce;
  static const Duration _debounceDuration = Duration(milliseconds: 500);
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
    } catch (e) {
      setState(() {
        _error = networkErrorMessage(e, 'Не удалось загрузить данные');
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
    final token = await getToken();
    setState(() {
      _isFetchingSetsForIndex = true;
      _fetchingSetsIndex = index;
    });
    try {
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
      if (!mounted) return;
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
      if (mounted && index < _newParticipants.length) {
        setState(() {
          _newParticipants[index] = _newParticipants[index].copyWith(
            availableSets: availableSets,
            availableCategories: availableCategories,
            categoriesForSet: null,
            category: '',
          );
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

  /// Сеты для нового участника: если есть availableSets (по dob) — используем их, иначе — основные сеты события
  List<dynamic> _getSetsForNewParticipant(GroupNewParticipant p) {
    if (p.availableSets != null && p.availableSets!.isNotEmpty) {
      return p.availableSets!;
    }
    final setsRaw = _data?['sets'];
    return setsRaw is List ? setsRaw : [];
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

    for (final p in _newParticipants) {
      if (p.firstname.trim().isEmpty || p.lastname.trim().isEmpty) {
        _showSnack('Заполните имя и фамилию участников', isError: true);
        return;
      }
      if (p.gender == null) {
        _showSnack('Укажите пол участника: ${p.firstname} ${p.lastname}', isError: true);
        return;
      }
      if ((_isInputBirthday || _needSet) && p.dob == null) {
        _showSnack('Укажите дату рождения: ${p.firstname} ${p.lastname}', isError: true);
        return;
      }
      if (_needSet && (p.sets == null || p.sets == 0)) {
        _showSnack('Выберите сет: ${p.firstname} ${p.lastname}', isError: true);
        return;
      }
      if (_isAutoCategories != 1 && p.category.isEmpty) {
        _showSnack('Выберите категорию: ${p.firstname} ${p.lastname}', isError: true);
        return;
      }
      if (_isNeedSportCategory && p.sportCategory.isEmpty) {
        _showSnack('Выберите разряд: ${p.firstname} ${p.lastname}', isError: true);
        return;
      }

      participants.add({
        'firstname': p.firstname.trim(),
        'lastname': p.lastname.trim(),
        'dob': p.dob != null ? DateFormat('yyyy-MM-dd').format(p.dob!) : null,
        'gender': p.gender,
        'sets': p.sets ?? 0,
        'category': p.category,
        'list_pending': p.listPending ? 'true' : 'false',
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
        _showSnack('Выберите сет для: ${ru['firstname']} ${ru['lastname']}', isError: true);
        return;
      }
      if (_isAutoCategories != 1 && (p['category'] ?? '').toString().isEmpty) {
        _showSnack('Выберите категорию для: ${ru['firstname']} ${ru['lastname']}', isError: true);
        return;
      }
      if (_isNeedSportCategory && (p['sport_category'] ?? '').toString().isEmpty) {
        _showSnack('Выберите разряд для: ${ru['firstname']} ${ru['lastname']}', isError: true);
        return;
      }

      final listPending = (p['list_pending'] == true || p['list_pending'] == 'true');
      String? dobStr;
      if (listPending) {
        final birthdayRaw = ru['birthday']?.toString();
        if (birthdayRaw == null || birthdayRaw.isEmpty) {
          _showSnack('Укажите дату рождения участника: ${ru['firstname']} ${ru['lastname']}', isError: true);
          return;
        }
        final parsed = DateTime.tryParse(birthdayRaw);
        if (parsed == null) {
          _showSnack('Укажите дату рождения участника: ${ru['firstname']} ${ru['lastname']}', isError: true);
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
      _showSnack('Добавьте хотя бы одного участника', isError: true);
      return;
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

  void _setRelatedParticipantData(int userId, Map<String, dynamic> data) {
    _relatedParticipantData[userId] = data;
    _saveDraft();
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Заявить группу', style: GoogleFonts.unbounded(fontWeight: FontWeight.w500, fontSize: 18, color: Colors.white)),
          backgroundColor: AppColors.cardDark,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Заявить группу', style: GoogleFonts.unbounded(fontWeight: FontWeight.w500, fontSize: 18, color: Colors.white)),
          backgroundColor: AppColors.cardDark,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Назад')),
              ],
            ),
          ),
        ),
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
        title: Text('Заявить группу', style: GoogleFonts.unbounded(fontWeight: FontWeight.w500, fontSize: 18, color: Colors.white)),
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
      ),
      body: Container(
        color: AppColors.anthracite,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (eventTitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  eventTitle,
                  style: GoogleFonts.unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            if (_hasUnpaidGroup) ...[
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
                                style: GoogleFonts.unbounded(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Продолжить оплату',
                                style: GoogleFonts.unbounded(color: Colors.white70, fontSize: 14),
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
            if (groupDocumentsAlready || _hasUnpaidGroup)
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
                          eventTitle: eventTitle,
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
                                style: GoogleFonts.unbounded(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Загрузить документы для участников группы',
                                style: GoogleFonts.unbounded(color: Colors.white70, fontSize: 14),
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
            if (groupDocumentsAlready || _hasUnpaidGroup) const SizedBox(height: 20),
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
            const SizedBox(height: 20),
            Text(
              'Ранее заявленные участники',
              style: GoogleFonts.unbounded(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const SizedBox(height: 12),
            if (relatedUsers.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'У вас пока нет ранее заявленных участников. Добавьте новых участников ниже.',
                  style: GoogleFonts.unbounded(color: Colors.white70, fontSize: 14),
                ),
              )
            else
              ...relatedUsers.map((ru) {
                if (ru is! Map) return const SizedBox.shrink();
                final id = ru['id'];
                final userId = id is int ? id : int.tryParse(id.toString() ?? '');
                if (userId == null) return const SizedBox.shrink();
                final name = '${ru['lastname'] ?? ''} ${ru['firstname'] ?? ''}'.trim();
                final isSelected = _selectedRelatedUserIds.contains(userId);
                return _buildRelatedUserCard(Map<String, dynamic>.from(ru), userId, name, isSelected);
              }),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Новые участники',
                    style: GoogleFonts.unbounded(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: _addNewParticipant,
                  icon: const Icon(Icons.add, size: 20, color: AppColors.mutedGold),
                  label: Text('Добавить', style: GoogleFonts.unbounded(color: AppColors.mutedGold, fontWeight: FontWeight.w500)),
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
                  style: GoogleFonts.unbounded(color: Colors.white70, fontSize: 14),
                ),
              )
            else ...[
              const SizedBox(height: 12),
              ...List.generate(_newParticipants.length, (i) {
                return _buildNewParticipantCard(i);
              }),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitRegistration,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mutedGold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Зарегистрировать группу', style: GoogleFonts.unbounded(fontWeight: FontWeight.w600, color: AppColors.anthracite)),
              ),
            ),
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
            Text(text, style: GoogleFonts.unbounded(color: Colors.white)),
            if (actionText != null && onTap != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onTap,
                child: Text(actionText, style: GoogleFonts.unbounded(color: AppColors.mutedGold, fontWeight: FontWeight.w500)),
              ),
            ],
          ],
        ),
      ),
    );
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
    final cannotParticipate = ru['cannot_participate'] == true || ru['participation_blocked'] == true || ru['category_not_suitable'] == true;
    if (isParticipant) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.mutedGold.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.mutedGold),
        ),
        child: Text('Уже участвует', style: GoogleFonts.unbounded(color: AppColors.mutedGold, fontSize: 12, fontWeight: FontWeight.w500)),
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
          child: Text('Не может участвовать', style: GoogleFonts.unbounded(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w500)),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildRelatedUserCard(Map<String, dynamic> ru, int userId, String name, bool isSelected) {
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
                        Text(name, style: GoogleFonts.unbounded(color: Colors.white, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                        if (dob != null && dob.isNotEmpty)
                          Text('ДР: $dob', style: GoogleFonts.unbounded(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis),
                        if (sportCat != null && sportCat.isNotEmpty)
                          Text('Разряд: $sportCat', style: GoogleFonts.unbounded(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Flexible(child: _buildParticipantStatus(ru)),
                ],
              ),
              if (isSelected) ...[
                const SizedBox(height: 16),
                _buildRelatedUserForm(ru, userId, data),
              ],
              if (!isAlreadyParticipant) _buildListPendingBlock(ru, userId),
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
    final hasListPendingSets = _isYearOrAgeCategories ? hasBirthday : validSetsSync.isNotEmpty;

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
                style: GoogleFonts.unbounded(color: Colors.amber.shade300, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: () => _showAddToListPendingSheet(ru, userId, isEdit: true),
              child: Text('Изменить', style: GoogleFonts.unbounded(fontSize: 12, color: AppColors.mutedGold)),
            ),
            TextButton(
              onPressed: () => _removeFromListPending(userId),
              child: Text('Удалить', style: GoogleFonts.unbounded(color: Colors.red.shade300, fontSize: 12)),
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
          label: Text('Добавить в лист ожидания', style: GoogleFonts.unbounded(fontSize: 13)),
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
      _showSnack('Укажите дату рождения участника в профиле', isError: true);
      return;
    }
    final parsedBirthday = DateTime.tryParse(birthdayRaw);
    if (parsedBirthday == null) {
      _showSnack('Укажите дату рождения участника в профиле', isError: true);
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
      _showSnack('Нет сетов для листа ожидания', isError: true);
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
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: (sheetCategory ?? '').isEmpty ? null : sheetCategory,
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: AppColors.graphite,
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                      ),
                      dropdownColor: AppColors.graphite,
                      items: categoriesList.map((c) {
                        final cat = c is Map ? (c['category'] ?? c)?.toString() ?? '' : c.toString();
                        return DropdownMenuItem(value: cat, child: Text(cat, style: const TextStyle(color: Colors.white)));
                      }).toList(),
                      onChanged: (v) => setSheetState(() => sheetCategory = v),
                    ),
                  ],
                  if (needSportCategory) ...[
                    const SizedBox(height: 12),
                    const Text('Разряд', style: TextStyle(fontSize: 14, color: Colors.white70)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: (sheetSportCategory ?? '').isEmpty ? null : sheetSportCategory,
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: AppColors.graphite,
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                      ),
                      dropdownColor: AppColors.graphite,
                      items: sportCategoriesList.map((s) {
                        final sc = s is Map ? (s['category'] ?? s['sport_category'] ?? '')?.toString() ?? '' : s.toString();
                        return DropdownMenuItem(value: sc, child: Text(sc, style: const TextStyle(color: Colors.white)));
                      }).toList(),
                      onChanged: (v) => setSheetState(() => sheetSportCategory = v),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      final numberSets = sheetSelectedNumberSets.toList()..sort();
                      if (numberSets.isEmpty) {
                        _showSnack('Выберите хотя бы один сет', isError: true);
                        return;
                      }
                      if (needCategorySelect && (sheetCategory == null || sheetCategory!.isEmpty)) {
                        _showSnack('Выберите категорию', isError: true);
                        return;
                      }
                      if (needSportCategory && (sheetSportCategory == null || sheetSportCategory!.isEmpty)) {
                        _showSnack('Выберите разряд', isError: true);
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
    final setsRaw = _data?['sets'];
    final setsList = setsRaw is List ? setsRaw : [];
    final categoriesRaw = _data?['event']?['categories'] ?? _data?['event']?['categories'];
    final categoriesList = categoriesRaw is List ? categoriesRaw : [];
    final needSet = _needSet && setsList.isNotEmpty;
    final needCategory = _isAutoCategories != 1 && categoriesList.isNotEmpty;
    final needSportCategory = _isNeedSportCategory && (_data?['sport_categories'] is List);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (needSet) ...[
          const Text('Сет', style: TextStyle(color: Colors.white70, fontSize: 12)),
          if (setsList.any((s) => s is Map && s['list_pending'] == true))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Если все места в сете заняты (лист ожидания), участник будет добавлен в список ожидания.',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            isExpanded: true,
            value: data['sets'] is int ? data['sets'] as int? : int.tryParse(data['sets']?.toString() ?? ''),
            decoration: const InputDecoration(
              filled: true,
              fillColor: AppColors.graphite,
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            dropdownColor: AppColors.graphite,
            items: setsList.map((s) {
              final m = s is Map ? Map<String, dynamic>.from(s) : <String, dynamic>{};
              final n = m['number_set'];
              final numSet = n is int ? n : int.tryParse(n?.toString() ?? '');
              final time = m['time']?.toString() ?? '';
              final free = m['free'];
              final listPending = m['list_pending'] == true;
              final label = 'Сет №$numSet $time${listPending ? ' (лист ожид.)' : free != null ? ' ($free)' : ''}';
              return DropdownMenuItem<int>(
                value: numSet,
                child: Text(label, style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (v) {
              bool listPending = false;
              for (final s in setsList) {
                if (s is Map && (s['number_set'] == v || s['number_set']?.toString() == v?.toString())) {
                  listPending = s['list_pending'] == true;
                  break;
                }
              }
              setState(() {
                _setRelatedParticipantData(userId, {...data, 'sets': v, 'list_pending': listPending});
              });
            },
          ),
          const SizedBox(height: 12),
        ],
        if (needCategory) ...[
          const Text('Категория', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: (data['category']?.toString() ?? '').isEmpty ? null : data['category']?.toString(),
            decoration: const InputDecoration(
              filled: true,
              fillColor: AppColors.graphite,
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            dropdownColor: AppColors.graphite,
            items: categoriesList.map((c) {
              final cat = c is Map ? c['category']?.toString() ?? '' : c.toString();
              return DropdownMenuItem<String>(value: cat, child: Text(cat, style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis));
            }).toList(),
            onChanged: (v) {
              setState(() {
                _setRelatedParticipantData(userId, {...data, 'category': v ?? ''});
              });
            },
          ),
          const SizedBox(height: 12),
        ],
        if (needSportCategory) ...[
          const Text('Разряд', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: (data['sport_category']?.toString() ?? '').isEmpty ? null : data['sport_category']?.toString(),
            decoration: const InputDecoration(
              filled: true,
              fillColor: AppColors.graphite,
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            dropdownColor: AppColors.graphite,
            items: ((_data?['sport_categories']) as List? ?? []).map((s) {
              final sc = s is Map ? (s['category'] ?? s['sport_category'] ?? '').toString() : s.toString();
              return DropdownMenuItem<String>(value: sc, child: Text(sc, style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis));
            }).toList(),
            onChanged: (v) {
              setState(() {
                _setRelatedParticipantData(userId, {...data, 'sport_category': v ?? ''});
              });
            },
          ),
        ],
      ],
    );
  }

  Widget _buildNewParticipantCard(int index) {
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
                  child: Text('Участник ${index + 1}', style: GoogleFonts.unbounded(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                  onPressed: () => _removeNewParticipant(index),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: p.firstname,
              onChanged: (v) {
                setState(() {
                  _newParticipants[index] = p.copyWith(firstname: v);
                  _saveDraft();
                });
              },
              decoration: InputDecoration(
                labelText: 'Имя',
                labelStyle: GoogleFonts.unbounded(color: AppColors.graphite),
                filled: true,
                fillColor: AppColors.rowAlt,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              style: GoogleFonts.unbounded(color: Colors.white),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: p.lastname,
              onChanged: (v) {
                setState(() {
                  _newParticipants[index] = p.copyWith(lastname: v);
                  _saveDraft();
                });
              },
              decoration: InputDecoration(
                labelText: 'Фамилия',
                labelStyle: GoogleFonts.unbounded(color: AppColors.graphite),
                filled: true,
                fillColor: AppColors.rowAlt,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              style: GoogleFonts.unbounded(color: Colors.white),
            ),
            if (_isInputBirthday || _needSet) ...[
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  p.dob != null ? DateFormat('dd.MM.yyyy').format(p.dob!) : 'Дата рождения',
                  style: GoogleFonts.unbounded(color: p.dob != null ? Colors.white : Colors.white54),
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
            const SizedBox(height: 12),
            _buildGenderSelector(p, index),
            if (_needSet && (_getSetsForNewParticipant(p).isNotEmpty || _fetchingSetsIndex == index)) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('Сет', style: GoogleFonts.unbounded(color: Colors.white70, fontSize: 12)),
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
                    style: GoogleFonts.unbounded(color: Colors.white54, fontSize: 11),
                  ),
                ),
              const SizedBox(height: 4),
              if (_fetchingSetsIndex == index)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: Text('Загрузка сетов по дате рождения...', style: GoogleFonts.unbounded(color: Colors.white54, fontSize: 12))),
                )
              else
              DropdownButtonFormField<int>(
                isExpanded: true,
                value: p.sets != null && _getSetsForNewParticipant(p).any((s) =>
                    s is Map && (s['number_set'] == p.sets || s['number_set'].toString() == p.sets.toString()))
                    ? p.sets
                    : null,
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: AppColors.graphite,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                dropdownColor: AppColors.graphite,
                items: _getSetsForNewParticipant(p).map((s) {
                  final m = s is Map ? s : <String, dynamic>{};
                  final numSet = m['number_set'];
                  final val = numSet is int ? numSet : int.tryParse(numSet?.toString() ?? '');
                  final free = m['free'];
                  final listPending = m['list_pending'] == true;
                  final label = 'Сет №${numSet ?? ''} ${m['time'] ?? ''}${listPending ? ' (лист ожид.)' : free != null ? ' ($free)' : ''}';
                  return DropdownMenuItem<int>(
                    value: val ?? 0,
                    child: Text(label, style: GoogleFonts.unbounded(color: Colors.white), overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (v) async {
                  bool listPendingVal = false;
                  for (final s in _getSetsForNewParticipant(p)) {
                    if (s is Map && (s['number_set'] == v || s['number_set'].toString() == v?.toString())) {
                      listPendingVal = s['list_pending'] == true;
                      break;
                    }
                  }
                  final newSet = v is int ? v : int.tryParse(v?.toString() ?? '');
                  setState(() {
                    _newParticipants[index] = p.copyWith(
                      sets: newSet,
                      listPending: listPendingVal,
                      categoriesForSet: null,
                      category: '',
                    );
                    _saveDraft();
                  });
                  if (p.dob != null && newSet != null) {
                    await _fetchCategoriesForSet(DateFormat('yyyy-MM-dd').format(p.dob!), newSet, index);
                  }
                },
              ),
            ],
            if (_isAutoCategories != 1 && _getCategoriesForNewParticipant(p).isNotEmpty && _fetchingSetsIndex != index) ...[
              const SizedBox(height: 12),
              Text('Категория', style: GoogleFonts.unbounded(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: p.category.isEmpty ? null : p.category,
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: AppColors.graphite,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                dropdownColor: AppColors.graphite,
                items: _getCategoriesForNewParticipant(p).map((c) {
                  final m = c is Map ? c : <String, dynamic>{};
                  final cat = m['category']?.toString() ?? '';
                  return DropdownMenuItem(value: cat, child: Text(cat, style: GoogleFonts.unbounded(color: Colors.white), overflow: TextOverflow.ellipsis));
                }).toList(),
                onChanged: (v) {
                  setState(() {
                    _newParticipants[index] = p.copyWith(category: v ?? '');
                    _saveDraft();
                  });
                },
              ),
            ],
            if (_isNeedSportCategory && (_data?['sport_categories'] is List)) ...[
              const SizedBox(height: 12),
              Text('Разряд', style: GoogleFonts.unbounded(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: p.sportCategory.isEmpty ? null : p.sportCategory,
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: AppColors.graphite,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                dropdownColor: AppColors.graphite,
                items: ((_data?['sport_categories']) as List? ?? []).map((s) {
                  final sc = (s is Map ? s['category'] ?? s['sport_category'] ?? s.toString() : s.toString()).toString();
                  return DropdownMenuItem<String>(value: sc, child: Text(sc, style: GoogleFonts.unbounded(color: Colors.white), overflow: TextOverflow.ellipsis));
                }).toList(),
                onChanged: (v) {
                  setState(() {
                    _newParticipants[index] = p.copyWith(sportCategory: v ?? '');
                    _saveDraft();
                  });
                },
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              initialValue: p.city,
              onChanged: (v) {
                setState(() {
                  _newParticipants[index] = p.copyWith(city: v);
                  _saveDraft();
                });
              },
              decoration: InputDecoration(
                labelText: 'Город',
                labelStyle: GoogleFonts.unbounded(color: AppColors.graphite),
                filled: true,
                fillColor: AppColors.rowAlt,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              style: GoogleFonts.unbounded(color: Colors.white),
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
        Text('Пол', style: GoogleFonts.unbounded(color: Colors.white70, fontSize: 12)),
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
