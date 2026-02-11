import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../login.dart';
import '../main.dart';
import '../utils/network_error_helper.dart';
import 'GroupCheckoutScreen.dart';
import 'ProfileEditScreen.dart';

const String _draftKeyPrefix = 'group_register_draft_';

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
      } else if (r.statusCode == 401 || r.statusCode == 419) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginScreen()),
          );
        }
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
    if (ru['is_participant'] == true || ru['already_registered'] == true) return;
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

  Future<void> _fetchSetsAndCategoriesForDob(String dob, int index) async {
    if (!mounted) return;
    final token = await getToken();
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
        availableSets = body['availableSets'] ?? [];
      }
      if (catR.statusCode == 200) {
        final body = jsonDecode(catR.body);
        availableCategories = body['availableCategory'] ?? [];
      }
      if (mounted && index < _newParticipants.length) {
        setState(() {
          _newParticipants[index] = _newParticipants[index].copyWith(
            availableSets: availableSets,
            availableCategories: availableCategories,
          );
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

  /// Категории для нового участника: если есть availableCategories (по dob) — используем их, иначе — категории события
  List<dynamic> _getCategoriesForNewParticipant(GroupNewParticipant p) {
    if (p.availableCategories != null && p.availableCategories!.isNotEmpty) {
      return p.availableCategories!;
    }
    final catRaw = _data?['event']?['categories'];
    return catRaw is List ? catRaw : [];
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
      if (_isInputBirthday && p.dob == null) {
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

      relatedUsers.add({
        'user_id': userId,
        'sets': p['sets'],
        'category': p['category'],
        'city': p['city'],
        'sport_category': p['sport_category'],
      });
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
        if (goToCheckout && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => GroupCheckoutScreen(eventId: widget.eventId),
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
      SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Заявить группу'),
          backgroundColor: const Color(0xFF0B1220),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Заявить группу'),
          backgroundColor: const Color(0xFF0B1220),
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
    final showContactDocumentsMsg = _data?['show_msg_about_need_contact_admin_documents'] == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Заявить группу'),
        backgroundColor: const Color(0xFF0B1220),
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
        color: const Color(0xFF050816),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (eventTitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  eventTitle,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            if (_hasUnpaidGroup) ...[
              Material(
                color: const Color(0xFF16A34A).withOpacity(0.2),
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
                        const Icon(Icons.payment, color: Color(0xFF16A34A), size: 32),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Есть неоплаченная групповая заявка',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Продолжить оплату',
                                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
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
            if (showContactDocumentsMsg)
              _buildWarningCard('Свяжитесь с администратором по поводу документов.'),
            const SizedBox(height: 20),
            const Text(
              'Ранее заявленные участники',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const SizedBox(height: 12),
            if (relatedUsers.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1220),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'У вас пока нет ранее заявленных участников. Добавьте новых участников ниже.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
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
                const Text(
                  'Новые участники',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                TextButton.icon(
                  onPressed: _addNewParticipant,
                  icon: const Icon(Icons.add, size: 20, color: Color(0xFF16A34A)),
                  label: const Text('Добавить', style: TextStyle(color: Color(0xFF16A34A))),
                ),
              ],
            ),
            if (_newParticipants.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1220),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Нажмите «Добавить», чтобы зарегистрировать нового участника.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
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
                  backgroundColor: const Color(0xFF16A34A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Зарегистрировать группу'),
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
            Text(text, style: const TextStyle(color: Colors.white)),
            if (actionText != null && onTap != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onTap,
                child: Text(actionText, style: const TextStyle(color: Colors.orange)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Статус участника: "Уже участвует" / "Не может участвовать"
  Widget _buildParticipantStatus(Map<String, dynamic> ru) {
    final isParticipant = ru['is_participant'] == true || ru['already_registered'] == true;
    final cannotParticipate = ru['cannot_participate'] == true || ru['participation_blocked'] == true;
    if (isParticipant) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF16A34A).withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF16A34A)),
        ),
        child: const Text('Уже участвует', style: TextStyle(color: Color(0xFF16A34A), fontSize: 12, fontWeight: FontWeight.w500)),
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
          child: const Text('Не может участвовать', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w500)),
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
      color: const Color(0xFF0B1220),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: isAlreadyParticipant ? null : () => _toggleRelatedUser(userId, ru),
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
                    onChanged: isAlreadyParticipant ? null : (v) => _toggleRelatedUser(userId, ru),
                    activeColor: const Color(0xFF16A34A),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        if (dob != null && dob.isNotEmpty)
                          Text('ДР: $dob', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        if (sportCat != null && sportCat.isNotEmpty)
                          Text('Разряд: $sportCat', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  _buildParticipantStatus(ru),
                ],
              ),
              if (isSelected) ...[
                const SizedBox(height: 16),
                _buildRelatedUserForm(ru, userId, data),
              ],
            ],
          ),
        ),
      ),
    );
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
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            value: data['sets'] is int ? data['sets'] as int? : int.tryParse(data['sets']?.toString() ?? ''),
            decoration: const InputDecoration(
              filled: true,
              fillColor: Color(0xFF1E293B),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            dropdownColor: const Color(0xFF1E293B),
            items: setsList.map((s) {
              final m = s is Map ? Map<String, dynamic>.from(s) : <String, dynamic>{};
              final n = m['number_set'];
              final numSet = n is int ? n : int.tryParse(n?.toString() ?? '');
              final time = m['time']?.toString() ?? '';
              final free = m['free'];
              return DropdownMenuItem<int>(
                value: numSet,
                child: Text('Сет №$numSet $time${free != null ? ' ($free мест)' : ''}', style: const TextStyle(color: Colors.white)),
              );
            }).toList(),
            onChanged: (v) {
              setState(() {
                _setRelatedParticipantData(userId, {...data, 'sets': v});
              });
            },
          ),
          const SizedBox(height: 12),
        ],
        if (needCategory) ...[
          const Text('Категория', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: (data['category']?.toString() ?? '').isEmpty ? null : data['category']?.toString(),
            decoration: const InputDecoration(
              filled: true,
              fillColor: Color(0xFF1E293B),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            dropdownColor: const Color(0xFF1E293B),
            items: categoriesList.map((c) {
              final cat = c is Map ? c['category']?.toString() ?? '' : c.toString();
              return DropdownMenuItem<String>(value: cat, child: Text(cat, style: const TextStyle(color: Colors.white)));
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
            value: (data['sport_category']?.toString() ?? '').isEmpty ? null : data['sport_category']?.toString(),
            decoration: const InputDecoration(
              filled: true,
              fillColor: Color(0xFF1E293B),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            dropdownColor: const Color(0xFF1E293B),
            items: ((_data?['sport_categories']) as List? ?? []).map((s) {
              final sc = s is Map ? (s['category'] ?? s['sport_category'] ?? '').toString() : s.toString();
              return DropdownMenuItem<String>(value: sc, child: Text(sc, style: const TextStyle(color: Colors.white)));
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
      color: const Color(0xFF0B1220),
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
                Text('Участник ${index + 1}', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
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
              decoration: const InputDecoration(
                labelText: 'Имя',
                filled: true,
                fillColor: Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              style: const TextStyle(color: Colors.white),
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
              decoration: const InputDecoration(
                labelText: 'Фамилия',
                filled: true,
                fillColor: Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            if (_isInputBirthday) ...[
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  p.dob != null ? DateFormat('dd.MM.yyyy').format(p.dob!) : 'Дата рождения',
                  style: TextStyle(color: p.dob != null ? Colors.white : Colors.white54),
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
            if (_needSet && _getSetsForNewParticipant(p).isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Сет', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              DropdownButtonFormField<int>(
                value: p.sets != null && _getSetsForNewParticipant(p).any((s) =>
                    s is Map && (s['number_set'] == p.sets || s['number_set'].toString() == p.sets.toString()))
                    ? p.sets
                    : null,
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: Color(0xFF1E293B),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                dropdownColor: const Color(0xFF1E293B),
                items: _getSetsForNewParticipant(p).map((s) {
                  final m = s is Map ? s : <String, dynamic>{};
                  final numSet = m['number_set'];
                  final val = numSet is int ? numSet : int.tryParse(numSet?.toString() ?? '');
                  final free = m['free'];
                  final listPending = m['list_pending'] == true;
                  final label = 'Сет №${numSet ?? ''} ${m['time'] ?? ''} ${listPending ? '(лист ожидания)' : '($free мест)'}';
                  return DropdownMenuItem<int>(
                    value: val ?? 0,
                    child: Text(label, style: const TextStyle(color: Colors.white)),
                  );
                }).toList(),
                onChanged: (v) {
                  bool listPendingVal = false;
                  for (final s in _getSetsForNewParticipant(p)) {
                    if (s is Map && (s['number_set'] == v || s['number_set'].toString() == v?.toString())) {
                      listPendingVal = s['list_pending'] == true;
                      break;
                    }
                  }
                  setState(() {
                    _newParticipants[index] = p.copyWith(
                      sets: v is int ? v : int.tryParse(v?.toString() ?? ''),
                      listPending: listPendingVal,
                    );
                    _saveDraft();
                  });
                },
              ),
            ],
            if (_isAutoCategories != 1 && _getCategoriesForNewParticipant(p).isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Категория', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: p.category.isEmpty ? null : p.category,
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: Color(0xFF1E293B),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                dropdownColor: const Color(0xFF1E293B),
                items: _getCategoriesForNewParticipant(p).map((c) {
                  final m = c is Map ? c : <String, dynamic>{};
                  final cat = m['category']?.toString() ?? '';
                  return DropdownMenuItem(value: cat, child: Text(cat, style: const TextStyle(color: Colors.white)));
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
              const Text('Разряд', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: p.sportCategory.isEmpty ? null : p.sportCategory,
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: Color(0xFF1E293B),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                dropdownColor: const Color(0xFF1E293B),
                items: ((_data?['sport_categories']) as List? ?? []).map((s) {
                  final sc = (s is Map ? s['category'] ?? s['sport_category'] ?? s.toString() : s.toString()).toString();
                  return DropdownMenuItem<String>(value: sc, child: Text(sc, style: const TextStyle(color: Colors.white)));
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
              decoration: const InputDecoration(
                labelText: 'Город',
                filled: true,
                fillColor: Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              style: const TextStyle(color: Colors.white),
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
        const Text('Пол', style: TextStyle(color: Colors.white70, fontSize: 12)),
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
              side: BorderSide(color: p.gender == 'male' ? const Color(0xFF16A34A) : Colors.white38),
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
              side: BorderSide(color: p.gender == 'female' ? const Color(0xFF16A34A) : Colors.white38),
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
