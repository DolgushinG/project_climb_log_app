import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:login_app/Screens/FranceResultScreen.dart';
import 'package:login_app/login.dart';
import 'package:login_app/models/NumberSets.dart';
import 'package:login_app/models/SportCategory.dart';
import 'package:login_app/result_festival.dart';
import 'dart:convert';
import 'button/result_entry_button.dart';
import 'button/take_part.dart';
import 'list_participants.dart';
import 'main.dart';
import 'Screens/CheckoutScreen.dart';
import 'Screens/GymProfileScreen.dart';
import 'Screens/ProfileEditScreen.dart';
import 'Screens/GroupRegisterScreen.dart';
import 'services/GymService.dart';
import 'models/Category.dart';
import 'services/ProfileService.dart';
import 'utils/display_helper.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:login_app/services/cache_service.dart';
import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/utils/network_error_helper.dart';
import 'package:login_app/widgets/top_notification_banner.dart';
String _normalizePosterPath(String path) {
  if (path.isEmpty) return path;
  if (path.startsWith('http')) return path;
  return path.startsWith('/') ? path : '/$path';
}

const int MANUAL_CATEGORIES = 0;
const int AUTO_CATEGORIES_RESULT = 1;
const int AUTO_CATEGORIES_YEAR = 2;
const int AUTO_CATEGORIES_AGE = 3;

bool _jsonToBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final v = value.toLowerCase();
    return v == 'true' || v == '1';
  }
  return false;
}

List<int>? _parseListPendingNumberSets(dynamic value) {
  if (value == null) return null;
  if (value is List) {
    return value.map((e) => e is int ? e : int.tryParse(e?.toString() ?? '') ?? 0).where((e) => e > 0).toList();
  }
  if (value is String) {
    return value.split(',').map((e) => int.tryParse(e.trim()) ?? 0).where((e) => e > 0).toList();
  }
  return null;
}

int? _parseIntNullable(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  final parsed = int.tryParse(value.toString());
  return parsed;
}

class Competition {
  final int id;
  final String title;
  final String description;
  final String city;
  final String contact;
  final bool is_participant;
  final bool? is_participant_active;
  final bool is_routes_exists;
  final String poster;
  final String info_payment;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> sport_categories;
  final List<Map<String, dynamic>> number_sets;
  final String address;
  final String climbing_gym_name;
  final int? climbing_gym_id;
  final DateTime start_date;
  final bool isCompleted;
  final int is_auto_categories;
  final int auto_categories;
  final String? your_group;
  final int amount_routes_in_qualification;
  final int amount_routes_in_final;
  final int amount_routes_in_semifinal;
  final int is_input_set;
  final bool is_need_send_birthday;
  final bool is_semifinal;
  final bool is_result_in_final_exists;
  final int is_need_sport_category;
  final bool is_participant_paid;
  final int is_access_user_cancel_take_part;
  final int is_france_system_qualification;
  final bool? is_access_user_edit_result;
  final bool? is_send_result_state;
  final bool? is_open_send_result_state;
  final bool is_need_pay_for_reg;
  final bool is_in_list_pending;
  final List<int>? list_pending_number_sets;

  Competition({
    required this.id,
    required this.title,
    required this.city,
    required this.contact,
    required this.is_participant,
    this.is_participant_active,
    required this.is_result_in_final_exists,
    required this.amount_routes_in_qualification,
    required this.amount_routes_in_final,
    required this.amount_routes_in_semifinal,
    required this.is_routes_exists,
    required this.address,
    required this.climbing_gym_name,
    this.climbing_gym_id,
    required this.poster,
    required this.description,
    required this.is_participant_paid,
    required this.is_access_user_cancel_take_part,
    required this.is_auto_categories,
    required this.auto_categories,
    this.your_group,
    required this.is_input_set,
    required this.is_semifinal,
    required this.is_france_system_qualification,
    this.is_access_user_edit_result,
    this.is_send_result_state,
    this.is_open_send_result_state,
    this.is_need_pay_for_reg = false,
    this.is_in_list_pending = false,
    this.list_pending_number_sets,
    required this.is_need_send_birthday,
    required this.is_need_sport_category,
    required this.info_payment,
    required this.categories,
    required this.sport_categories,
    required this.number_sets,
    required this.start_date,
    required this.isCompleted,
  });

  factory Competition.fromJson(Map<String, dynamic> json) {
    final startDate = DateTime.parse(json['start_date']);
    final isCompletedRaw = json['isCompleted'] ?? json['is_completed'] ?? json['is_finished'];
    final isCompleted = isCompletedRaw != null
        ? _jsonToBool(isCompletedRaw)
        : startDate.isBefore(DateTime.now().subtract(const Duration(days: 1)));

    final categoriesRaw = json['categories'];
    final sportCategoriesRaw = json['sport_categories'];
    final setsRaw = json['sets'];
    final List<Map<String, dynamic>> setsList;
    if (setsRaw is List) {
      setsList = setsRaw.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } else if (setsRaw is Map && setsRaw['sets'] is List) {
      setsList = (setsRaw['sets'] as List).map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } else {
      setsList = [];
    }

    return Competition(
      id: json['id'],
      title: json['title'] ?? '',
      city: json['city'] ?? '',
      is_participant: _jsonToBool(json['is_participant']),
      is_participant_active: _jsonToBool(json['is_participant_active']),
      is_result_in_final_exists: _jsonToBool(json['is_result_in_final_exists']),
      amount_routes_in_qualification: json['amount_routes_in_qualification'] ?? json['count_routes'] ?? 0,
      amount_routes_in_final: json['amount_routes_in_final'] ?? 0,
      amount_routes_in_semifinal: json['amount_routes_in_semifinal'] ?? 0,
      is_semifinal: _jsonToBool(json['is_semifinal']),
      is_need_send_birthday: _jsonToBool(json['is_need_send_birthday']),
      is_need_sport_category: json['is_need_sport_category'] ?? 0,
      is_routes_exists: _jsonToBool(json['is_routes_exists']),
      is_participant_paid: _jsonToBool(json['is_participant_paid']),
      contact: json['contact'] ?? '',
      poster: _normalizePosterPath((json['poster'] ?? json['image'] ?? '').toString()),
      is_access_user_cancel_take_part: json['is_access_user_cancel_take_part'] ?? 0,
      is_auto_categories: json['is_auto_categories'] ?? 0,
      auto_categories: json['auto_categories'] ?? 0,
      your_group: json['your_group']?.toString(),
      is_input_set: json['is_input_set'] ?? 0,
      is_france_system_qualification: json['is_france_system_qualification'] ?? 0,
      is_access_user_edit_result: _jsonToBool(json['is_access_user_edit_result']),
      is_send_result_state: _jsonToBool(json['is_send_result_state']),
      is_open_send_result_state: _jsonToBool(json['is_open_send_result_state']),
      is_need_pay_for_reg: _jsonToBool(json['is_need_pay_for_reg']),
      is_in_list_pending: _jsonToBool(json['is_in_list_pending']),
      list_pending_number_sets: _parseListPendingNumberSets(json['list_pending_number_sets']),
      description: json['description'] ?? '',
      categories: (categoriesRaw is List)
          ? categoriesRaw.map((item) => Map<String, dynamic>.from(item as Map)).toList()
          : [],
      sport_categories: (sportCategoriesRaw is List)
          ? sportCategoriesRaw.map((item) => Map<String, dynamic>.from(item as Map)).toList()
          : [],
      number_sets: setsList,
      info_payment: json['info_payment'] ?? '',
      address: json['address'] ?? '',
      climbing_gym_name: (json['climbing_gym_name'] ?? json['climbing_gym'] ?? '').toString(),
      climbing_gym_id: _parseIntNullable(json['climbing_gym_id']),
      start_date: startDate,
      isCompleted: isCompleted,
    );
  }
}

class CompetitionsScreen extends StatefulWidget {
  /// Гостевой режим: запросы без токена, в детали передаётся isGuest.
  final bool isGuest;

  const CompetitionsScreen({super.key, this.isGuest = false});

  @override
  _CompetitionsScreenState createState() => _CompetitionsScreenState();
}

class _CompetitionsScreenState extends State<CompetitionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Competition> _currentCompetitions = [];
  List<Competition> _completedCompetitions = [];
  List<Competition> _allCurrent = [];
  List<Competition> _allCompleted = [];
  bool _isLoading = true;
  String? _selectedCity;
  String? _error;
  bool _fromCache = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCompetitions();
  }

  /// Сначала показываем кэш (если есть), затем подгружаем с сети.
  Future<void> _loadCompetitions() async {
    final cached = await CacheService.getStale(CacheService.keyCompetitions);
    if (cached != null && cached.isNotEmpty && mounted) {
      try {
        final List<dynamic> data = json.decode(cached);
        final List<Competition> competitions =
            data.map((j) => Competition.fromJson(Map<String, dynamic>.from(j as Map))).toList();
        setState(() {
          _allCurrent = competitions.where((c) => !c.isCompleted).toList();
          _allCompleted = competitions.where((c) => c.isCompleted).toList();
          _isLoading = false;
          _error = null;
          _fromCache = true;
        });
      } catch (_) {}
    }
    await fetchCompetitions();
  }

  List<String> get _uniqueCities {
    final cities = <String>{};
    for (final c in _allCurrent) {
      if (c.city.isNotEmpty) cities.add(c.city);
    }
    for (final c in _allCompleted) {
      if (c.city.isNotEmpty) cities.add(c.city);
    }
    return cities.toList()..sort();
  }

  List<Competition> _filterAndSortCurrent() {
    var list = _allCurrent;
    if (_selectedCity != null) {
      list = list.where((c) => c.city == _selectedCity).toList();
    }
    list = List.from(list)..sort((a, b) => a.start_date.compareTo(b.start_date));
    return list;
  }

  List<Competition> _filterAndSortCompleted() {
    var list = _allCompleted;
    if (_selectedCity != null) {
      list = list.where((c) => c.city == _selectedCity).toList();
    }
    list = List.from(list)..sort((a, b) => b.start_date.compareTo(a.start_date));
    return list;
  }

  Future<void> fetchCompetitions() async {
    final String? token = await getToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    try {
      final response = await http.get(
        Uri.parse(DOMAIN + '/api/competitions'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        List<Competition> competitions =
            data.map((j) => Competition.fromJson(Map<String, dynamic>.from(j as Map))).toList();
        await CacheService.set(
          CacheService.keyCompetitions,
          response.body,
          ttl: CacheService.ttlCompetitions,
        );
        if (mounted) {
          setState(() {
            _allCurrent = competitions.where((c) => !c.isCompleted).toList();
            _allCompleted = competitions.where((c) => c.isCompleted).toList();
            _isLoading = false;
            _error = null;
            _fromCache = false;
          });
        }
        return;
      }
      if ((response.statusCode == 401 || response.statusCode == 419) && !widget.isGuest) {
        if (mounted) {
          setState(() => _isLoading = false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LoginScreen(),
            ),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Ошибка сессии', style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_allCurrent.isEmpty && _allCompleted.isEmpty) _error = 'Не удалось загрузить данные';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_allCurrent.isEmpty && _allCompleted.isEmpty) {
            _error = networkErrorMessage(e, 'Не удалось загрузить данные');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_error ?? '', style: const TextStyle(color: Colors.white)),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
      }
    }
  }

  Future<void> _refreshCompetitions() async {
    await fetchCompetitions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseNavColor = AppColors.surfaceDark;
    final accentNavColor = AppColors.mutedGold.withOpacity(0.35);

    List<Color> detailNavGradientColors(int index) {
      switch (index) {
        case 0: // Информация
          return [accentNavColor, baseNavColor, baseNavColor];
        case 1: // Результаты
          return [baseNavColor, accentNavColor, baseNavColor];
        case 2: // Статистика
        default:
          return [baseNavColor, baseNavColor, accentNavColor];
      }
    }
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Соревнования', style: GoogleFonts.unbounded(fontWeight: FontWeight.w500, fontSize: 18)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(999),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: Colors.transparent,
                overlayColor:
                    MaterialStateProperty.all(Colors.transparent),
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: AppColors.mutedGold.withOpacity(0.25),
                ),
                labelPadding:
                    const EdgeInsets.symmetric(horizontal: 8.0),
                tabs: const [
                  Tab(text: 'Текущие'),
                  Tab(text: 'Завершенные'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading && _allCurrent.isEmpty && _allCompleted.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_error != null || _fromCache)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 4),
                    child: _error != null
                        ? TopNotificationBanner(
                            message: _error!,
                            icon: Icons.wifi_off_rounded,
                            backgroundColor: AppColors.graphite,
                            iconColor: Colors.orange.shade200,
                            textColor: Colors.white,
                            useSafeArea: false,
                            showCloseButton: true,
                            onClose: () => setState(() => _error = null),
                            trailing: TextButton(
                              onPressed: () {
                                setState(() => _error = null);
                                fetchCompetitions();
                              },
                              child: const Text('Повторить'),
                            ),
                          )
                        : TopNotificationBanner(
                            message: 'Данные из кэша. Потяните для обновления.',
                            icon: Icons.cloud_done_outlined,
                            backgroundColor: AppColors.graphite,
                            iconColor: Colors.white70,
                            textColor: Colors.white70,
                            useSafeArea: false,
                            showCloseButton: true,
                            onClose: () => setState(() => _fromCache = false),
                          ),
                  ),
                if (_uniqueCities.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 8),
                    child: Row(
                      children: [
                        Text(
                          'Город:',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.15)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: _selectedCity,
                                isExpanded: true,
                                hint: Text(
                                  'Все города',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 14,
                                  ),
                                ),
                                dropdownColor: AppColors.graphite,
                                icon: Icon(Icons.arrow_drop_down, color: Colors.white.withOpacity(0.7)),
                                items: [
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text(
                                      'Все города',
                                      style: TextStyle(color: Colors.white.withOpacity(0.9)),
                                    ),
                                  ),
                                  ..._uniqueCities.map((city) => DropdownMenuItem<String?>(
                                    value: city,
                                    child: Text(
                                      city,
                                      style: TextStyle(color: Colors.white.withOpacity(0.9)),
                                    ),
                                  )),
                                ],
                                onChanged: (value) {
                                  setState(() => _selectedCity = value);
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      RefreshIndicator(
                        onRefresh: _refreshCompetitions,
                        child: buildCompetitionList(
                          _filterAndSortCurrent(),
                          emptyMessage: _selectedCity != null
                              ? 'Нет соревнований в выбранном городе'
                              : 'Текущих соревнований пока нет',
                        ),
                      ),
                      RefreshIndicator(
                        onRefresh: _refreshCompetitions,
                        child: buildCompetitionList(
                          _filterAndSortCompleted(),
                          emptyMessage: _selectedCity != null
                              ? 'Нет соревнований в выбранном городе'
                              : 'Завершённых соревнований пока нет',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget buildCompetitionList(List<dynamic> competitions, {String emptyMessage = 'Соревнований пока нет'}) {
    if (competitions.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: Text(
                emptyMessage,
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: competitions.length,
      itemBuilder: (context, index) {
        final Competition competition = competitions[index];
        final String dateLabel = formatDatePremium(competition.start_date);
        final bool isCurrent = !competition.isCompleted;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CompetitionDetailScreen(competition, isGuest: widget.isGuest),
                ),
              );
            },
            child: Card(
              color: AppColors.cardDark,
              surfaceTintColor: Colors.transparent,
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                height: 108,
                child: Row(
                  children: [
                    // Постер
                    AspectRatio(
                      aspectRatio: 3 / 4,
                      child: CachedNetworkImage(
                        imageUrl: '$DOMAIN${competition.poster}',
                        fit: BoxFit.cover,
                        alignment: Alignment.centerRight,
                        placeholder: (context, url) => Container(
                          color: Colors.black12,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) =>
                            Container(
                          color: Colors.black26,
                          child: const Icon(
                            Icons.landscape_rounded,
                            color: Colors.white38,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    competition.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.unbounded(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isCurrent
                                        ? Colors.green.withOpacity(0.18)
                                        : Colors.grey.withOpacity(0.18),
                                    borderRadius:
                                        BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    isCurrent ? 'Идут' : 'Завершены',
                                    style: GoogleFonts.unbounded(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: isCurrent
                                          ? Colors.greenAccent
                                          : Colors.grey[300],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 14,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${competition.city}, ${competition.address}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white70),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                Text(
                                  dateLabel,
                                  style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white70),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
class AlwaysDisabledFocusNode extends FocusNode {
  @override
  bool get hasFocus => false;
}

class CompetitionDetailScreen extends StatefulWidget {
  late Competition competition; // Локальная переменная состояния
  final bool isGuest;

  CompetitionDetailScreen(this.competition, {this.isGuest = false});

  @override
  _CompetitionDetailScreenState createState() =>
      _CompetitionDetailScreenState();
}

class _CompetitionDetailScreenState extends State<CompetitionDetailScreen> {
  int _selectedIndex = 0;
  Category? selectedCategory;
  SportCategory? selectedSportCategory;
  NumberSets? selectedNumberSet;
  late Competition _competitionDetails; // Хранит обновленные данные соревнования
  DateTime? _selectedDate;
  bool _receiptPending = false; // Чек загружен, ожидает подтверждения
  int _checkoutRemainingSeconds = 0;
  Map<String, dynamic>? _checkoutData;
  Timer? _paymentTimer;
  bool _checkout404Received = false; // предотвращает цикл при 404
  bool _isRefreshing = false;
  Map<String, dynamic>? _competitionStats;
  bool _statsLoading = false;
  String? _statsError;
  String? _userBirthday; // день рождения из профиля
  final TextEditingController _textEditingController = TextEditingController();
  final FocusNode _focusNode = AlwaysDisabledFocusNode();

  @override
  void dispose() {
    _paymentTimer?.cancel();
    _textEditingController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Есть хотя бы один занятый сет (из доступных по возрасту)
  bool get _hasAnyBusySet {
    final sets = _setsFilteredByAge;
    return sets.any((s) => (s.free) <= 0);
  }

  /// Все сеты заняты (из доступных по возрасту)
  bool get _allSetsBusy {
    final sets = _setsFilteredByAge;
    return sets.isNotEmpty && sets.every((s) => (s.free) <= 0);
  }

  /// Номера сетов для add-to-list-pending
  List<int> get _numberSetsForWaitlist {
    if (_competitionDetails.is_input_set == 0) {
      final s = _effectiveSelectedNumberSet;
      return s != null ? [s.number_set] : [];
    }
    return _competitionDetails.number_sets
        .map((j) => NumberSets.fromJson(j))
        .map((s) => s.number_set)
        .toList();
  }

  void _showSetSelectionDialog() {
    final numberSetList = _setsFilteredByAge;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Локальная переменная для временного хранения выбора (только если сет ещё в списке по возрасту)
        NumberSets? tempSelectedNumberSet = numberSetList.any((s) => s.id == selectedNumberSet?.id)
            ? selectedNumberSet
            : null;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Выберите сет', style: GoogleFonts.unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  children: numberSetList.map((numberSet) {
                    return RadioListTile<NumberSets>(
                      title: Text(formatSetCompact(numberSet), style: GoogleFonts.unbounded(color: Colors.white)),
                      value: numberSet,
                      groupValue: tempSelectedNumberSet,
                      onChanged: (NumberSets? value) {
                        setDialogState(() {
                          tempSelectedNumberSet = value; // Обновляем локальную переменную в диалоге
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Отмена', style: GoogleFonts.unbounded(color: AppColors.mutedGold)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (mounted) setState(() => selectedNumberSet = tempSelectedNumberSet);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.mutedGold, foregroundColor: AppColors.anthracite),
                  child: Text('Сохранить', style: GoogleFonts.unbounded(fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
  }
  void _showCategorySelectionDialog() {
    List<Category> categoryList = _competitionDetails.categories.map((json) => Category.fromJson(json)).toList();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Локальная переменная для временного хранения выбора
        Category? tempSelectedCategory = selectedCategory;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Выберите категорию', style: GoogleFonts.unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  children: categoryList.map((category) {
                    return RadioListTile<Category>(
                      title: Text(category.category, style: GoogleFonts.unbounded(color: Colors.white)),
                      value: category,
                      groupValue: tempSelectedCategory,
                      onChanged: (Category? value) {
                        setDialogState(() {
                          tempSelectedCategory = value; // Обновляем локальную переменную в диалоге
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Отмена', style: GoogleFonts.unbounded(color: AppColors.mutedGold)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (mounted) setState(() => selectedCategory = tempSelectedCategory);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.mutedGold, foregroundColor: AppColors.anthracite),
                  child: Text('Сохранить', style: GoogleFonts.unbounded(fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
  }
  void _showSportCategorySelectionDialog() {
    List<SportCategory> categoryList = _competitionDetails.sport_categories.map((json) => SportCategory.fromJson(json)).toList();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Локальная переменная для временного хранения выбора
        SportCategory? tempSelectedSportCategory = selectedSportCategory;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Выберите разряд', style: GoogleFonts.unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  children: categoryList.map((sport_category) {
                    return RadioListTile<SportCategory>(
                      title: Text(sport_category.sport_category, style: GoogleFonts.unbounded(color: Colors.white)),
                      value: sport_category,
                      groupValue: tempSelectedSportCategory,
                      onChanged: (SportCategory? value) {
                        setDialogState(() {
                          tempSelectedSportCategory = value; // Обновляем локальную переменную в диалоге
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Отмена', style: GoogleFonts.unbounded(color: AppColors.mutedGold)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (mounted) setState(() => selectedSportCategory = tempSelectedSportCategory);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.mutedGold, foregroundColor: AppColors.anthracite),
                  child: Text('Сохранить', style: GoogleFonts.unbounded(fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showWaitlistBottomSheet({List<int>? initialNumberSets}) {
    final busySets = _setsFilteredByAge.where((s) => s.free <= 0).toList();
    final categoryList = _competitionDetails.categories
        .map((json) => Category.fromJson(Map<String, dynamic>.from(json)))
        .toList();
    final sportCategoryList = _competitionDetails.sport_categories
        .map((json) => SportCategory.fromJson(Map<String, dynamic>.from(json)))
        .toList();

    List<NumberSets> sheetSelectedSets = [];
    Category? sheetSelectedCategory;
    SportCategory? sheetSelectedSportCategory;

    // Предзаполнение
    if (initialNumberSets != null && initialNumberSets.isNotEmpty) {
      sheetSelectedSets = busySets.where((s) => initialNumberSets.contains(s.number_set)).toList();
    }
    if (sheetSelectedSets.isEmpty && busySets.isNotEmpty && selectedNumberSet != null && busySets.any((s) => s.id == selectedNumberSet!.id)) {
      sheetSelectedSets = [selectedNumberSet!];
    } else if (sheetSelectedSets.isEmpty && busySets.isNotEmpty) {
      sheetSelectedSets = [busySets.first];
    }
    sheetSelectedCategory = selectedCategory;
    sheetSelectedSportCategory = selectedSportCategory;

    final needCategory = _competitionDetails.auto_categories != AUTO_CATEGORIES_YEAR &&
        _competitionDetails.auto_categories != AUTO_CATEGORIES_AGE &&
        categoryList.isNotEmpty;
    final needSportCategory = _competitionDetails.is_need_sport_category == 1 && sportCategoryList.isNotEmpty;

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
                    initialNumberSets != null ? 'Изменить данные в листе ожидания' : 'Добавиться в лист ожидания',
                    style: GoogleFonts.unbounded(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_competitionDetails.is_input_set == 0 && busySets.isNotEmpty) ...[
                    Text('Занятый сет', style: GoogleFonts.unbounded(fontSize: 14, color: Colors.white70)),
                    const SizedBox(height: 6),
                    ...busySets.map((s) => CheckboxListTile(
                      title: Text(formatSetCompact(s), style: GoogleFonts.unbounded(color: Colors.white)),
                      value: sheetSelectedSets.contains(s),
                      activeColor: Colors.orange,
                      onChanged: (checked) {
                        setSheetState(() {
                          if (checked == true) {
                            if (!sheetSelectedSets.contains(s)) sheetSelectedSets = [...sheetSelectedSets, s];
                          } else {
                            sheetSelectedSets = sheetSelectedSets.where((x) => x != s).toList();
                          }
                        });
                      },
                    )),
                    const SizedBox(height: 12),
                  ],
                  if (needCategory) ...[
                    Text('Категория', style: GoogleFonts.unbounded(fontSize: 14, color: Colors.white70)),
                    const SizedBox(height: 6),
                    ...categoryList.map((c) => RadioListTile<Category>(
                      title: Text(c.category, style: GoogleFonts.unbounded(color: Colors.white)),
                      value: c,
                      groupValue: sheetSelectedCategory,
                      onChanged: (v) => setSheetState(() => sheetSelectedCategory = v),
                    )),
                    const SizedBox(height: 12),
                  ],
                  if (needSportCategory) ...[
                    Text('Разряд', style: GoogleFonts.unbounded(fontSize: 14, color: Colors.white70)),
                    const SizedBox(height: 6),
                    ...sportCategoryList.map((sc) => RadioListTile<SportCategory>(
                      title: Text(sc.sport_category, style: GoogleFonts.unbounded(color: Colors.white)),
                      value: sc,
                      groupValue: sheetSelectedSportCategory,
                      onChanged: (v) => setSheetState(() => sheetSelectedSportCategory = v),
                    )),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      final numberSets = _competitionDetails.is_input_set == 0
                          ? sheetSelectedSets.map((s) => s.number_set).toList()
                          : busySets.map((s) => s.number_set).toList();

                      if (numberSets.isEmpty && _competitionDetails.is_input_set == 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Выберите сет', style: TextStyle(color: Colors.white)),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      if (needCategory && sheetSelectedCategory == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Выберите категорию', style: TextStyle(color: Colors.white)),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      if (needSportCategory && sheetSelectedSportCategory == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Выберите разряд', style: TextStyle(color: Colors.white)),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      Navigator.pop(context);
                      await _addToWaitlistFromSheet(
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
                    child: Text('Подтвердить', style: GoogleFonts.unbounded(fontSize: 14, fontWeight: FontWeight.w600)),
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

  Future<void> _addToWaitlistFromSheet(
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
      if (sportCategory?.sport_category != null) body['sport_category'] = sportCategory!.sport_category;

      final response = await http.post(
        Uri.parse('$DOMAIN/api/event/${_competitionDetails.id}/add-to-list-pending'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message.isNotEmpty ? message : 'Вы добавлены в лист ожидания',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
          ),
        );
        _refreshParticipationStatus();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message.isNotEmpty ? message : 'Ошибка внесения в лист ожидания',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Ошибка сети', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeFromListPending() async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$DOMAIN/api/event/${_competitionDetails.id}/remove-from-list-pending'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({}),
      );
      final data = json.decode(response.body);
      final message = data['message']?.toString() ?? '';
      final success = response.statusCode == 200 && (data['success'] == true);

      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message.isNotEmpty ? message : 'Успешно удалено из листа ожидания',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
          ),
        );
        _refreshParticipationStatus();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message.isNotEmpty ? message : 'Ошибка удаления',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Ошибка сети', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildListPendingBlock() {
    final pendingSets = _competitionDetails.list_pending_number_sets ?? [];
    final allSets = _competitionDetails.number_sets.map((j) => NumberSets.fromJson(j)).toList();
    final setLabels = pendingSets.map((n) {
      final list = allSets.where((x) => x.number_set == n).toList();
      final s = list.isEmpty ? null : list.first;
      return s != null ? formatSetCompact(s) : '№$n';
    }).join(', ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, color: Colors.orange, size: 24),
              const SizedBox(width: 8),
              Text(
                'Лист ожидания',
                style: GoogleFonts.unbounded(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ],
          ),
          if (setLabels.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Сеты: $setLabels',
              style: GoogleFonts.unbounded(fontSize: 14, color: Colors.white70),
            ),
          ],
          if (selectedCategory != null) ...[
            const SizedBox(height: 4),
            Text(
              'Категория: ${selectedCategory!.category}',
              style: GoogleFonts.unbounded(fontSize: 14, color: Colors.white70),
            ),
          ],
          if (selectedSportCategory != null) ...[
            const SizedBox(height: 4),
            Text(
              'Разряд: ${selectedSportCategory!.sport_category}',
              style: GoogleFonts.unbounded(fontSize: 14, color: Colors.white70),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showWaitlistBottomSheet(
                    initialNumberSets: _competitionDetails.list_pending_number_sets,
                  ),
                  icon: const Icon(Icons.edit, size: 18, color: AppColors.mutedGold),
                  label: Text('Изменить', style: GoogleFonts.unbounded(fontSize: 14, color: AppColors.mutedGold, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.mutedGold,
                    side: const BorderSide(color: AppColors.mutedGold),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Удалить из листа ожидания?', style: GoogleFonts.unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                        content: Text(
                          'Вы будете удалены из листа ожидания. Освободившееся место смогут занять другие.',
                          style: GoogleFonts.unbounded(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text('Отмена', style: GoogleFonts.unbounded(color: AppColors.mutedGold)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text('Удалить', style: GoogleFonts.unbounded(color: Colors.red, fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) await _removeFromListPending();
                  },
                  icon: const Icon(Icons.person_remove, size: 18),
                  label: Text('Удалить', style: GoogleFonts.unbounded(fontSize: 14, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Блок сетов: компактные чипы с номером, счётчиком и прогресс-баром (отфильтрованы по возрасту)
  Widget _buildSetsBlock() {
    final sets = _setsFilteredByAge;
    final allSets = _competitionDetails.number_sets
        .map((j) => NumberSets.fromJson(Map<String, dynamic>.from(j)))
        .toList();
    final hasAgeRestrictedSets = allSets.any((s) => s.allow_years_from != null || s.allow_years_to != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.grid_view_rounded, size: 14, color: AppColors.mutedGold),
            const SizedBox(width: 6),
            Text(
              'Сеты',
              style: GoogleFonts.unbounded(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (sets.isEmpty && hasAgeRestrictedSets)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Нет сетов для вашей возрастной группы',
              style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white70),
            ),
          )
        else
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final spacing = 3.0;
            final count = w < 320 ? 4 : (w < 400 ? 5 : 6);
            final itemW = (w - spacing * (count - 1)) / count;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: sets.map((s) => SizedBox(
                width: itemW,
                child: _buildSetCompactItem(s),
              )).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSetCompactItem(NumberSets s) {
    final progressClass = s.progress_class;
    final textClass = s.text_class;
    final progressColor = _getProgressColor(progressClass);
    final textColor = _getTextColor(textClass);
    final procent = s.procent.clamp(0.0, 100.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.rowAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.graphite, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '№${s.number_set}',
                  style: GoogleFonts.unbounded(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.mutedGold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  '${s.participants_count}/${s.max_participants}',
                  style: GoogleFonts.unbounded(fontSize: 9, fontWeight: FontWeight.w500, color: textColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: procent / 100,
              minHeight: 4,
              backgroundColor: AppColors.graphite,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          if (s.time.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              s.time,
              style: GoogleFonts.unbounded(fontSize: 9, color: AppColors.graphite),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ],
      ),
    );
  }

  Color _getProgressColor(String progressClass) {
    switch (progressClass) {
      case 'custom-progress-high':
        return const Color(0xFFDC3545);
      case 'custom-progress-medium':
        return const Color(0xFFFD7E14);
      case 'custom-progress-low':
      default:
        return const Color(0xFF28A745);
    }
  }

  Color _getTextColor(String textClass) {
    switch (textClass) {
      case 'text-high':
        return const Color(0xFFDC3545);
      case 'text-medium':
        return const Color(0xFFFD7E14);
      case 'text-low':
      default:
        return const Color(0xFF28A745);
    }
  }

  void _openPosterFullScreen(String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: Colors.white70),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(Icons.error, color: Colors.red, size: 50),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openGymProfile() async {
    final gymId = _competitionDetails.climbing_gym_id;
    if (gymId != null && gymId > 0) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GymProfileScreen(gymId: gymId),
        ),
      );
      return;
    }
    final name = _competitionDetails.climbing_gym_name.trim();
    if (name.isEmpty) return;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Поиск скалодрома...', style: TextStyle(color: Colors.white)),
          backgroundColor: AppColors.graphite,
          duration: const Duration(seconds: 1),
        ),
      );
    }
    final results = await searchGyms(name);
    if (!mounted) return;
    if (results.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GymProfileScreen(gymId: results.first.id),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Профиль скалодрома временно недоступен', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildGymCard(BuildContext context) {
    const linkColor = AppColors.mutedGold;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openGymProfile(),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: linkColor.withOpacity(0.4),
              width: 1.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: linkColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Icon(
                Icons.sports,
                size: 18,
                color: linkColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Скалодром',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.85),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _competitionDetails.climbing_gym_name,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.mutedGold,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.mutedGold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: linkColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Нажмите для перехода в профиль скалодрома',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildInformationSection() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => _openPosterFullScreen('$DOMAIN${_competitionDetails.poster}'),
              child: Container(
                width: double.infinity,
                height: 260,
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: '$DOMAIN${_competitionDetails.poster}',
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      errorWidget: (context, url, error) => const Center(
                        child: Icon(
                          Icons.error,
                          color: Colors.red,
                          size: 50,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: Colors.white70),
                const SizedBox(width: 8),
                Text(
                  'О соревновании',
                  style: GoogleFonts.unbounded(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _competitionDetails.title,
                    style: GoogleFonts.unbounded(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_competitionDetails.climbing_gym_name.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildGymCard(context),
                    ),
                  CompetitionInfoCard(
                    icon: Icons.place_outlined,
                    label: 'Адрес',
                    value: _competitionDetails.address,
                  ),
                  const SizedBox(height: 8),
                  CompetitionInfoCard(
                    icon: Icons.phone_outlined,
                    label: 'Контакты',
                    value: _competitionDetails.contact,
                  ),
                  const SizedBox(height: 8),
                  CompetitionInfoCard(
                    icon: Icons.location_city_outlined,
                    label: 'Город',
                    value: _competitionDetails.city,
                  ),
                ],
              ),
            ),
            if (_competitionDetails.number_sets.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildSetsBlock(),
            ],
            const SizedBox(height: 20),
            if (!_competitionDetails.isCompleted && !_competitionDetails.is_participant && !widget.isGuest &&
                _competitionDetails.is_need_send_birthday &&
                _competitionDetails.auto_categories != AUTO_CATEGORIES_YEAR &&
                _competitionDetails.auto_categories != AUTO_CATEGORIES_AGE)
              Row(
                  children: [
                    Expanded(
                      child: TextField(
                        focusNode: _focusNode,
                        controller: _textEditingController,
                        readOnly: true,
                        onTap: () => _selectDate(context),
                        decoration: InputDecoration(
                          labelText: 'Выберите дату',
                          labelStyle: GoogleFonts.unbounded(color: AppColors.graphite),
                          filled: true,
                          fillColor: AppColors.rowAlt,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ]),
            const SizedBox(height: 12),
            if (!_competitionDetails.isCompleted && !_competitionDetails.is_participant && !widget.isGuest)
              if(_competitionDetails.is_need_sport_category == 1)
                Row(
                    children: [
                      Expanded( // Используем Flexible для более гибкого контроля
                        child:  ElevatedButton(
                          onPressed: _showSportCategorySelectionDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.mutedGold,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            selectedSportCategory == null
                                ? 'Выберите разряд'
                                : 'Разряд: ${displayValue(selectedSportCategory!.sport_category)}',
                            style: GoogleFonts.unbounded(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.anthracite),
                          ),
                        ),
                      ),
                    ]),
            if (!_competitionDetails.isCompleted && !_competitionDetails.is_participant && !widget.isGuest)
              if ((_competitionDetails.auto_categories == AUTO_CATEGORIES_YEAR ||
                      _competitionDetails.auto_categories == AUTO_CATEGORIES_AGE) &&
                  !_hasBirthdayFilled)
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.amber.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.cake_outlined,
                              size: 22,
                              color: Colors.amber.shade300,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Для участия необходимо заполнить день рождения',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.9),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton.icon(
                                    onPressed: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ProfileEditScreen(),
                                        ),
                                      );
                                      if (mounted) fetchCompetition();
                                    },
                                    icon: const Icon(Icons.edit, size: 18, color: AppColors.mutedGold),
                                    label: Text(
                                      'Заполнить в профиле',
                                      style: GoogleFonts.unbounded(color: AppColors.mutedGold, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            if (!_competitionDetails.isCompleted && !_competitionDetails.is_participant && !widget.isGuest)
              if (_hasBirthdayFilled &&
                  (_competitionDetails.auto_categories == AUTO_CATEGORIES_YEAR ||
                      _competitionDetails.auto_categories == AUTO_CATEGORIES_AGE))
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.mutedGold.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.mutedGold.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.group_rounded,
                              size: 22,
                              color: AppColors.mutedGold,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Ваша группа',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _competitionDetails.your_group ?? '—',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            if (!_competitionDetails.isCompleted && !_competitionDetails.is_participant && !widget.isGuest)
              if (_competitionDetails.auto_categories == MANUAL_CATEGORIES)
                Row(
                children: [
                  Expanded( // Используем Flexible для более гибкого контроля
                      child:  ElevatedButton(
                        onPressed: _showCategorySelectionDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.mutedGold,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          selectedCategory == null
                              ? 'Выберите категорию'
                              : 'Категория: ${displayValue(selectedCategory!.category)}',
                          style: GoogleFonts.unbounded(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.anthracite),
                        ),
                      ),
                  ),
                ]),
            const SizedBox(height: 8),
            if (!_competitionDetails.isCompleted && !_competitionDetails.is_participant && !widget.isGuest)
              if(_competitionDetails.is_input_set == 0)
                Row(children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _showSetSelectionDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mutedGold,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _effectiveSelectedNumberSet == null
                          ? 'Выберите сет'
                          : 'Сет: ${formatSetCompact(_effectiveSelectedNumberSet!)}',
                      style: GoogleFonts.unbounded(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.anthracite),
                    ),
                ),
                )
              ]),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.hiking_rounded, size: 18, color: Colors.white70),
                const SizedBox(width: 8),
                Text(
                  'Ваше участие',
                  style: GoogleFonts.unbounded(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_competitionDetails.isCompleted) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: Center(
                  child: Text(
                    'Соревнование завершено',
                    style: GoogleFonts.unbounded(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white70),
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ParticipantListScreen(
                          _competitionDetails.id,
                          _competitionDetails.categories,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.graphite,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'Список участников',
                    style: GoogleFonts.unbounded(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ] else ...[
              Builder(
                builder: (context) {
                  // Показывать «Продолжить оплату» только после загрузки checkout и только если сервер вернул, что оплата нужна (есть время и нет чека).
                  final needsPayment = _checkoutData != null &&
                      _checkoutRemainingSeconds > 0 &&
                      _competitionDetails.is_participant &&
                      _competitionDetails.is_need_pay_for_reg &&
                      !_competitionDetails.is_participant_paid &&
                      !_receiptPending;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (needsPayment && _checkoutRemainingSeconds > 0)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: _checkoutRemainingSeconds <= 300
                                ? Colors.red.withOpacity(0.2)
                                : Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _checkoutRemainingSeconds <= 300
                                  ? Colors.red.withOpacity(0.5)
                                  : Colors.orange.withOpacity(0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.timer,
                                color: _checkoutRemainingSeconds <= 300 ? Colors.red : Colors.orange,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Осталось времени на оплату: ${_checkoutRemainingSeconds ~/ 60}:${(_checkoutRemainingSeconds % 60).toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    color: _checkoutRemainingSeconds <= 300 ? Colors.red : Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_competitionDetails.is_in_list_pending) _buildListPendingBlock(),
                          if (_competitionDetails.is_in_list_pending) const SizedBox(height: 8),
                          if (!_needsBirthdayButNotFilled)
                            widget.isGuest
                                ? ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => LoginScreen(),
                                        ),
                                      ).then((_) => fetchCompetition());
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.mutedGold,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    child: Text(
                                      'Войти чтобы принять участие',
                                      style: GoogleFonts.unbounded(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                  )
                                : needsPayment
                                    ? ElevatedButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => CheckoutScreen(
                                                eventId: _competitionDetails.id,
                                                initialData: _checkoutData,
                                              ),
                                            ),
                                          ).then((_) => fetchCompetition());
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.mutedGold,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                        ),
                                    child: Text(
                                      'Продолжить оплату',
                                      style: GoogleFonts.unbounded(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                                    ),
                                      )
                                    : TakePartButtonScreen(
                                        _competitionDetails.id,
                                        _checkout404Received ? false : _competitionDetails.is_participant,
                                        _birthdayForTakePart,
                                        selectedCategory,
                                        selectedSportCategory,
                                        _effectiveSelectedNumberSet,
                                        _refreshParticipationStatus,
                                        is_need_pay_for_reg: _competitionDetails.is_need_pay_for_reg,
                                        onNeedCheckout: (eventId) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => CheckoutScreen(
                                                eventId: eventId,
                                                initialData: _checkoutData,
                                              ),
                                            ),
                                          ).then((_) => fetchCompetition());
                                        },
                                        allSetsBusy: _allSetsBusy,
                                        hasAnyBusySet: _hasAnyBusySet,
                                        numberSetsForWaitlist: _numberSetsForWaitlist,
                                        onWaitlistTap: _showWaitlistBottomSheet,
                                        is_in_list_pending: _competitionDetails.is_in_list_pending,
                                        needCategory: _competitionDetails.auto_categories == MANUAL_CATEGORIES &&
                                            _competitionDetails.categories.isNotEmpty,
                                        needSportCategory: _competitionDetails.is_need_sport_category == 1 &&
                                            _competitionDetails.sport_categories.isNotEmpty,
                                        needNumberSet: _competitionDetails.is_input_set == 0 &&
                                            _setsFilteredByAge.isNotEmpty,
                                      ),
                          if (!_needsBirthdayButNotFilled) const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ParticipantListScreen(
                                      _competitionDetails.id,
                                      _competitionDetails.categories,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.graphite,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: Text(
                                'Список участников',
                                style: GoogleFonts.unbounded(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          if (!widget.isGuest) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () async {
                                  final result = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => GroupRegisterScreen(eventId: _competitionDetails.id),
                                    ),
                                  );
                                  if (result == true && mounted) {
                                    fetchCompetition();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.mutedGold,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: Text(
                                  'Заявить группу',
                                  style: GoogleFonts.unbounded(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  );
                },
              ),
              if (_receiptPending &&
                  _competitionDetails.is_participant &&
                  _competitionDetails.is_need_pay_for_reg &&
                  !_competitionDetails.is_participant_paid) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(top: 16, bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.5)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.receipt_long, color: Colors.orange, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Чек проверяется. Ожидайте подтверждения администратором. Результаты можно будет вносить после подтверждения оплаты.',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Кнопка внесения/обновления результатов
              if (_competitionDetails.is_participant) ...[
                // Условия показа по бизнес-логике:
                // 1) Глобальный запрет выключен (is_open_send_result_state == true)
                // 2) Пользователь зарегистрирован (is_participant == true)
                // 3) Оплата подтверждена (для платных событий) или не требуется (для бесплатных)
                // 4) Если результат уже есть и редактирование запрещено — кнопку не показываем.
                Builder(
                  builder: (context) {
                    final bool globalAllowed =
                        _jsonToBool(_competitionDetails.is_open_send_result_state);
                    final bool registered = _competitionDetails.is_participant;
                    // для платных: нужна подтверждённая оплата; для бесплатных: считаем, что ок
                    final bool paymentConfirmed = !_competitionDetails.is_need_pay_for_reg ||
                        _competitionDetails.is_participant_paid;
                    // есть ли уже результат
                    final bool resultExists =
                        _jsonToBool(_competitionDetails.is_participant_active);
                    // флаг разрешения редактировать существующий результат
                    final bool editAllowed =
                        _jsonToBool(_competitionDetails.is_access_user_edit_result);

                    final bool baseConditionsOk =
                        globalAllowed && registered && paymentConfirmed;

                    // по правилам:
                    // - если нет результата → достаточно baseConditionsOk
                    // - если есть результат → нужен ещё editAllowed
                    final bool canShowResultButton = baseConditionsOk &&
                        (!resultExists || (resultExists && editAllowed));

                    if (widget.isGuest) return const SizedBox.shrink();

                    return Column(
                      children: [
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            if (canShowResultButton && _competitionDetails.is_routes_exists)
                              ResultEntryButton(
                                eventId: _competitionDetails.id,
                                // is_participant_active: true → результат существует
                                isParticipantActive: resultExists,
                                isAccessUserEditResult: editAllowed,
                                isOpenSendResultState: globalAllowed,
                                isRoutesExists: _competitionDetails.is_routes_exists,
                                onResultSubmitted: _refreshParticipationStatus,
                              ),
                            if (_competitionDetails.is_routes_exists &&
                                _competitionDetails.is_access_user_cancel_take_part == 1 &&
                                !_competitionDetails.is_participant_paid)
                              const SizedBox(width: 10),
                            if (_competitionDetails.is_access_user_cancel_take_part == 1 &&
                                !_competitionDetails.is_participant_paid)
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    side: const BorderSide(color: Colors.redAccent),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () async {
                                    bool? confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          backgroundColor: AppColors.cardDark,
                                          title: Text(
                                            'Подтверждение отмены регистрации',
                                            style: GoogleFonts.unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                                          ),
                                          content: Text(
                                            'Вы уверены, что хотите отменить регистрацию?',
                                            style: GoogleFonts.unbounded(color: Colors.white70),
                                          ),
                                          actions: <Widget>[
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(context).pop(false),
                                              child: Text('Отмена', style: GoogleFonts.unbounded(color: AppColors.mutedGold)),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(context).pop(true),
                                              child: Text('Подтвердить', style: GoogleFonts.unbounded(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                    if (confirm == true) {
                                      _cancelRegistration();
                                      _refreshParticipationStatus();
                                    }
                                  },
                                  child: Text(
                                    'Отменить регистрацию',
                                    style: GoogleFonts.unbounded(fontSize: 14, fontWeight: FontWeight.w600),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  _selectDate(BuildContext context) async {
    DateTime? newSelectedDate = await showDatePicker(
        context: context,
        initialDate: _selectedDate != null ? _selectedDate : DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2040),
        builder: (BuildContext context, Widget? child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: Colors.blue,
                onPrimary: Colors.white,
                surface: Colors.blueGrey,
                onSurface: Colors.white,
              ),
              dialogBackgroundColor: Colors.grey[500],
            ),
            child: child ?? const SizedBox.shrink(),
          );
        });
    if (newSelectedDate != null) {
      if(mounted){
        setState(() {
          _selectedDate = newSelectedDate;
          _textEditingController.text = DateFormat('dd MMMM yyyy', 'ru').format(_selectedDate!);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseNavColor = AppColors.surfaceDark;
    final accentNavColor = AppColors.mutedGold.withOpacity(0.35);

    List<Color> detailNavGradientColors(int index) {
      switch (index) {
        case 0: // Информация
          return [accentNavColor, baseNavColor, baseNavColor];
        case 1: // Результаты
          return [baseNavColor, accentNavColor, baseNavColor];
        case 2: // Статистика
        default:
          return [baseNavColor, baseNavColor, accentNavColor];
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Детали соревнования', style: GoogleFonts.unbounded(fontWeight: FontWeight.w500, fontSize: 18, color: Colors.white)),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _onRefreshPressed,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildContent(),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_isRefreshing,
              child: AnimatedOpacity(
                opacity: _isRefreshing ? 0.3 : 0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: detailNavGradientColors(_selectedIndex),
              ),
            ),
            child: BottomNavigationBar(
              backgroundColor: Colors.transparent,
              items: const <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                  icon: Icon(Icons.info),
                  label: 'Информация',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.emoji_events),
                  label: 'Результаты',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.bar_chart),
                  label: 'Статистика',
                ),
              ],
              currentIndex: _selectedIndex,
              selectedItemColor: AppColors.mutedGold,
              unselectedItemColor: Colors.grey,
              onTap: _onItemTapped,
              selectedFontSize: 12,
              unselectedFontSize: 11,
              showUnselectedLabels: false,
              type: BottomNavigationBarType.fixed,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return RefreshIndicator(
          onRefresh: () async => fetchCompetition(),
          child: _buildInformationSection(),
        );
      case 1:
        return buildResults(context);
      case 2:
        return RefreshIndicator(
          onRefresh: () async {
            await fetchCompetition();
            await _fetchCompetitionStatistics();
          },
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: _buildStatisticsSection(),
              ),
            ),
          ),
        );
      default:
        return RefreshIndicator(
          onRefresh: () async => fetchCompetition(),
          child: _buildInformationSection(),
        );
    }
  }

  Widget buildResults(BuildContext context) {
    return DefaultTabController(
      length: _competitionDetails.is_semifinal
          ? (_competitionDetails.is_result_in_final_exists ? 3 : 2)
          : (_competitionDetails.is_result_in_final_exists ? 2 : 1), // Количество вкладок зависит от флага
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text('Результаты', style: GoogleFonts.unbounded(fontWeight: FontWeight.w500, fontSize: 18)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: TabBar(
                  indicatorColor: Colors.transparent,
                  overlayColor:
                      MaterialStateProperty.all(Colors.transparent),
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: AppColors.mutedGold.withOpacity(0.25),
                  ),
                  labelStyle: GoogleFonts.unbounded(fontSize: 13, fontWeight: FontWeight.w500),
                  unselectedLabelStyle: GoogleFonts.unbounded(fontSize: 13, fontWeight: FontWeight.w400),
                  labelPadding:
                      const EdgeInsets.symmetric(horizontal: 8.0),
                  tabs: [
                    const Tab(text: 'Квалификация'),
                    if (_competitionDetails.is_semifinal)
                      const Tab(text: 'Полуфинал'),
                    if (_competitionDetails.is_result_in_final_exists)
                      const Tab(text: 'Финал'),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            if( _competitionDetails.is_france_system_qualification == 0)
              _buildQualificationTab(context),
            if( _competitionDetails.is_france_system_qualification == 1)
              _buildFranceQualificationTab(context),
            if ( _competitionDetails.is_semifinal) _buildSemifinalTab(context), // Показываем только при флаге
            if ( _competitionDetails.is_result_in_final_exists) _buildFinalTab(context),
          ],
        ),
      ),
    );
  }

  // Вкладка для квалификации
  Widget _buildQualificationTab(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
      ),
      body: _buildResultsSection(context, 'qualification'),
    );
  }
  Widget _buildFranceQualificationTab(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
      ),
      body: _buildFranceResultsSection(context, 'qualification'),
    );
  }
  // Вкладка для полуфинала
  Widget _buildSemifinalTab(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
      ),
      body: _buildFranceResultsSection(context, 'semifinal'),
    );
  }

  // Вкладка для финала
  Widget _buildFinalTab(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
      ),
      body: _buildFranceResultsSection(context, 'final'),
    );
  }

  Widget _buildResultsSection(BuildContext context, String stage) {
    List<Category> categoryList = _competitionDetails.categories
        .map((json) => Category.fromJson(json))
        .toList();
    if (categoryList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events_outlined, size: 64, color: AppColors.mutedGold.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text(
                'Нет категорий с результатами',
                style: AppTypography.secondary(),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: categoryList
            .map(
              (category) => _buildResultCard(
                title: category.category.split(' ').first,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ResultScreen(
                        eventId: _competitionDetails.id,
                        categoryId: category.id,
                        category: category,
                        uniqidCategoryId: category.uniqidCategoryId,
                      ),
                    ),
                  );
                },
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildFranceResultsSection(BuildContext context, String stage) {
    var amount_routes = 0;
    if (stage == 'qualification') {
      amount_routes = _competitionDetails.amount_routes_in_qualification;
    }
    if (stage == 'semifinal') {
      amount_routes = _competitionDetails.amount_routes_in_semifinal;
    }
    if (stage == 'final') {
      amount_routes = _competitionDetails.amount_routes_in_final;
    }

    List<Category> categoryList = _competitionDetails.categories
        .map((json) => Category.fromJson(json))
        .toList();
    if (categoryList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events_outlined, size: 64, color: AppColors.mutedGold.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text(
                'Нет категорий с результатами',
                style: AppTypography.secondary(),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: categoryList
            .map((category) => _buildResultCard(
          title: category.category,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FranceResultsPage(
                  eventId: _competitionDetails.id,
                  amount_routes: amount_routes,
                  category: category,
                  stage: stage,
                ),
              ),
            );
          },
        ))
            .toList(),
      ),
    );
  }

  Widget _buildResultCard({required String title, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTypography.athleteName().copyWith(fontSize: 15),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.mutedGold.withOpacity(0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsSection() {
    if (_statsLoading && _competitionStats == null) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_statsError != null && _competitionStats == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart, size: 64, color: Colors.grey[600]),
              const SizedBox(height: 16),
              Text(
                _statsError!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      );
    }
    final stats = _competitionStats;
    if (stats == null) {
      return const SizedBox.shrink();
    }
    final participantsTotal = (stats['participants_total'] ?? 0) as num;
    final participantsMale = (stats['participants_male'] ?? 0) as num;
    final participantsFemale = (stats['participants_female'] ?? 0) as num;
    final routesTotal = (stats['routes_total'] ?? 0) as num;
    final flashesTotal = (stats['flashes_total'] ?? 0) as num;
    final redpointsTotal = (stats['redpoints_total'] ?? 0) as num;
    final zonesTotal = (stats['zones_total'] ?? 0) as num;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatCard(title: 'Участники', value: participantsTotal.toInt().toString(), icon: Icons.people),
          const SizedBox(height: 12),
          _buildStatCard(title: 'Трассы', value: routesTotal.toInt().toString(), icon: Icons.route),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(title: 'Флеши', value: flashesTotal.toInt().toString(), icon: Icons.flash_on, color: Colors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(title: 'Редпоинты', value: redpointsTotal.toInt().toString(), icon: Icons.star, color: Colors.amber),
              ),
            ],
          ),
          if (zonesTotal.toInt() > 0) ...[
            const SizedBox(height: 12),
            _buildStatCard(title: 'Зоны', value: zonesTotal.toInt().toString(), icon: Icons.flag, color: Colors.orange),
          ],
          if (participantsTotal.toInt() > 0 && (participantsMale.toInt() > 0 || participantsFemale.toInt() > 0)) ...[
            const SizedBox(height: 24),
            const Text('Участники по полу', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: _buildGenderPieChart(participantsMale.toInt(), participantsFemale.toInt()),
            ),
          ],
          if (flashesTotal.toInt() > 0 || redpointsTotal.toInt() > 0 || zonesTotal.toInt() > 0) ...[
            const SizedBox(height: 32),
            const Text('Результаты по типам', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SizedBox(
                height: 200,
                child: _buildResultsBarChart(flashesTotal.toInt(), redpointsTotal.toInt(), zonesTotal.toInt()),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard({required String title, required String value, required IconData icon, Color? color}) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: c.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: c, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderPieChart(int male, int female) {
    final total = male + female;
    if (total == 0) return const SizedBox.shrink();
    final sections = <PieChartSectionData>[];
    if (male > 0) {
      sections.add(PieChartSectionData(
        value: male.toDouble(),
        title: 'М\n$male',
        color: Colors.blue,
        radius: 60,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }
    if (female > 0) {
      sections.add(PieChartSectionData(
        value: female.toDouble(),
        title: 'Ж\n$female',
        color: Colors.pink,
        radius: 60,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }
    return PieChart(
      PieChartData(
        sections: sections,
        sectionsSpace: 2,
        centerSpaceRadius: 30,
      ),
    );
  }

  Widget _buildResultsBarChart(int flashes, int redpoints, int zones) {
    final spots = <BarChartGroupData>[];
    final maxVal = [flashes, redpoints, zones].reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) return const SizedBox.shrink();
    spots.add(BarChartGroupData(
      x: 0,
      barRods: [BarChartRodData(toY: flashes.toDouble(), color: Colors.green, width: 24, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))],
      showingTooltipIndicators: [0],
    ));
    spots.add(BarChartGroupData(
      x: 1,
      barRods: [BarChartRodData(toY: redpoints.toDouble(), color: Colors.amber, width: 24, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))],
      showingTooltipIndicators: [0],
    ));
    spots.add(BarChartGroupData(
      x: 2,
      barRods: [BarChartRodData(toY: zones.toDouble(), color: Colors.orange, width: 24, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))],
      showingTooltipIndicators: [0],
    ));
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (maxVal * 1.2).clamp(1.0, double.infinity),
        barGroups: spots,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              rod.toY.toInt().toString(),
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, meta) {
                switch (v.toInt()) {
                  case 0: return const Padding(padding: EdgeInsets.only(top: 8), child: Text('Флеш', style: TextStyle(fontSize: 11)));
                  case 1: return const Padding(padding: EdgeInsets.only(top: 8), child: Text('Редпоинт', style: TextStyle(fontSize: 11)));
                  case 2: return const Padding(padding: EdgeInsets.only(top: 8), child: Text('Зона', style: TextStyle(fontSize: 11)));
                  default: return const Text('');
                }
              },
              reservedSize: 32,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: true),
      ),
    );
  }

  Future<void> _onRefreshPressed() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await fetchCompetition();
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  // Метод для инициализации состояния
  Future<void> _fetchInitialParticipationStatus() async {
    await fetchCompetition();
    // После того как данные загружены, перерисовываем UI
    if (mounted) {
      setState(() {});
    }
  }
  // Колбек для обновления состояния
  Future<void> _refreshParticipationStatus() async {
    await _fetchInitialParticipationStatus();
  }

  /// Загружает данные checkout и обновляет таймер; при истечении — отменяет регистрацию
  Future<void> _loadCheckoutDataIfNeeded(Competition c) async {
    if (!c.is_participant || !c.is_need_pay_for_reg || c.is_participant_paid) {
      if (mounted) setState(() {
        _checkoutRemainingSeconds = 0;
        _checkoutData = null;
        _paymentTimer?.cancel();
        _checkout404Received = false;
      });
      return;
    }
    if (_checkout404Received) return; // уже получили 404 — не повторяем запрос (защита от цикла)
    try {
      final token = await getToken();
      if (token == null) return;
      final r = await http.get(
        Uri.parse('$DOMAIN/api/event/${c.id}/checkout'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (!mounted) return;
      if (r.statusCode == 404 || r.statusCode != 200) {
        // Регистрации нет (404) — сбрасываем состояние, НЕ вызываем fetchCompetition (избегаем цикла)
        setState(() {
          _checkoutData = null;
          _checkoutRemainingSeconds = 0;
          _paymentTimer?.cancel();
          _checkout404Received = true;
        });
        return;
      }
      final raw = json.decode(r.body);
      final data = raw is Map ? Map<String, dynamic>.from(raw) : null;
      if (data == null) return;
      final hasBill = data['has_bill'] == true;
      int remaining = (data['remaining_seconds'] is num) ? (data['remaining_seconds'] as num).toInt() : 0;
      if (data['pay_time_expired'] == 1) remaining = 0;
      if (mounted) {
        setState(() {
          _receiptPending = hasBill;
          _checkoutData = data;
          _checkoutRemainingSeconds = remaining;
          _checkout404Received = false;
        });
        _paymentTimer?.cancel();
        if (hasBill) return;
        if (remaining <= 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _cancelTakePartFromEvent();
          });
        } else {
          _startPaymentTimer();
        }
      }
    } catch (_) {}
  }

  void _startPaymentTimer() {
    _paymentTimer?.cancel();
    if (_checkoutRemainingSeconds <= 0) return;
    _paymentTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      bool shouldCancel = false;
      setState(() {
        _checkoutRemainingSeconds--;
        if (_checkoutRemainingSeconds <= 0) {
          _paymentTimer?.cancel();
          shouldCancel = true;
        }
      });
      if (shouldCancel && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _cancelTakePartFromEvent();
        });
      }
    });
  }

  Future<void> _cancelTakePartFromEvent() async {
    if (!mounted) return;
    setState(() {
      _checkoutRemainingSeconds = 0;
      _checkoutData = null;
    });
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Время оплаты истекло'),
        content: const Text(
          'Оплата не была произведена. Регистрация отменена. Зарегистрируйтесь заново.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ок'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        final token = await getToken();
        await http.post(
          Uri.parse('$DOMAIN/api/event/${_competitionDetails.id}/cancel-take-part'),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        );
      } catch (_) {}
      if (mounted) fetchCompetition();
    }
  }

  @override
  void initState() {
    super.initState();
    _competitionDetails = widget.competition;
    fetchCompetition(); // _fetchInitialParticipationStatus = fetchCompetition, один вызов
  }

// Обновить детали соревнования
  Future<void> fetchCompetition() async {
    if (mounted) setState(() => _checkout404Received = false);
    final eventId = _competitionDetails.id;
    final cacheKey = CacheService.keyEventDetails(eventId);
    final cached = await CacheService.getStale(cacheKey);
    if (cached != null && cached.isNotEmpty && mounted) {
      try {
        final raw = json.decode(cached);
        final data = raw is List && raw.isNotEmpty ? raw.first : raw;
        if (data is Map) {
          final comp = Competition.fromJson(Map<String, dynamic>.from(data));
          setState(() => _competitionDetails = comp);
          _loadCheckoutDataIfNeeded(comp);
          final ac = comp.auto_categories;
          if (ac == AUTO_CATEGORIES_YEAR || ac == AUTO_CATEGORIES_AGE) {
            _loadUserBirthday();
          }
        }
      } catch (_) {}
    }

    final String? token = await getToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    try {
      final response = await http.get(
        Uri.parse(DOMAIN + '/api/competitions?event_id=$eventId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final raw = json.decode(response.body);
        final data = raw is List && raw.isNotEmpty ? raw.first : raw;
        if (data is! Map) return;
        await CacheService.set(
          cacheKey,
          response.body,
          ttl: CacheService.ttlEventDetails,
        );
        final Competition updatedCompetition = Competition.fromJson(Map<String, dynamic>.from(data));
        if (mounted) {
          setState(() {
            _competitionDetails = updatedCompetition;
          });
          if (!widget.isGuest) {
            _loadCheckoutDataIfNeeded(updatedCompetition);
            final ac = updatedCompetition.auto_categories;
            if (ac == AUTO_CATEGORIES_YEAR || ac == AUTO_CATEGORIES_AGE) {
              _loadUserBirthday();
            }
          }
        }
      } else if ((response.statusCode == 401 || response.statusCode == 419) && !widget.isGuest) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LoginScreen(),
            ),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Ошибка сессии', style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (_) {
      // Офлайн или ошибка сети — оставляем данные из кэша, ничего не перезаписываем
    }
  }

  Future<void> _loadUserBirthday() async {
    try {
      final profile = await ProfileService(baseUrl: DOMAIN).getProfile(context);
      if (mounted && profile != null) {
        setState(() {
          _userBirthday = profile.birthday.trim().isNotEmpty ? profile.birthday : null;
        });
      }
    } catch (_) {}
  }

  bool get _hasBirthdayFilled {
    if (_userBirthday != null && _userBirthday!.trim().isNotEmpty) return true;
    if (_selectedDate != null) return true;
    return false;
  }

  bool get _needsBirthdayButNotFilled {
    final ac = _competitionDetails.auto_categories;
    return (ac == AUTO_CATEGORIES_YEAR || ac == AUTO_CATEGORIES_AGE) && !_hasBirthdayFilled;
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

  /// Год рождения пользователя (для фильтрации сетов по возрасту)
  int? get _userBirthYear {
    final b = _birthdayForTakePart;
    return b != null ? b.year : null;
  }

  /// Диапазон годов категории из your_group (allow_year_from, allow_year_to)
  (int?, int?) _getCategoryYearRange() {
    final yg = _competitionDetails.your_group;
    if (yg == null || yg.isEmpty) return (null, null);
    for (final c in _competitionDetails.categories) {
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

  /// Выбранный сет, если он всё ещё доступен по возрасту
  NumberSets? get _effectiveSelectedNumberSet {
    final s = selectedNumberSet;
    if (s == null) return null;
    return _setsFilteredByAge.any((x) => x.id == s.id) ? s : null;
  }

  /// Сеты, отфильтрованные по возрасту пользователя (allow_years_from, allow_years_to)
  List<NumberSets> get _setsFilteredByAge {
    final all = _competitionDetails.number_sets
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

  Future<void> _fetchCompetitionStatistics() async {
    if (_statsLoading) return;
    final eventId = _competitionDetails.id;
    final cacheKey = CacheService.keyEventStatistics(eventId);
    final cached = await CacheService.getStale(cacheKey);
    if (cached != null && cached.isNotEmpty && mounted) {
      try {
        final data = json.decode(cached);
        setState(() {
          _competitionStats = data is Map ? Map<String, dynamic>.from(data) : null;
          _statsLoading = false;
          _statsError = null;
        });
      } catch (_) {}
    }
    if (!mounted) return;
    if (_competitionStats == null) {
      setState(() {
        _statsLoading = true;
        _statsError = null;
      });
    }
    try {
      final token = await getToken();
      final r = await http.get(
        Uri.parse('$DOMAIN/api/event/$eventId/statistics'),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (!mounted) return;
      if (r.statusCode == 200) {
        final data = json.decode(r.body);
        await CacheService.set(
          cacheKey,
          r.body,
          ttl: CacheService.ttlEventStatistics,
        );
        setState(() {
          _competitionStats = data is Map ? Map<String, dynamic>.from(data) : null;
          _statsLoading = false;
          _statsError = null;
        });
      } else {
        setState(() {
          _statsLoading = false;
          if (_competitionStats == null) _statsError = 'Не удалось загрузить данные';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statsLoading = false;
        if (_competitionStats == null) {
          _statsError = networkErrorMessage(e, 'Не удалось загрузить данные');
        }
      });
    }
  }

  Future<void> _cancelRegistration() async {

    final String? token = await getToken();

    final response = await http.post(
      Uri.parse('${DOMAIN}/api/event/cancel/take/part'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'event_id': '${_competitionDetails.id}',
      }),
    );

    if (response.statusCode == 200) {
      fetchCompetition();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
        content: const Text('Регистрация отменена успешно', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
      ),
      );
    } else if (response.statusCode == 401 || response.statusCode == 419) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LoginScreen(),
        ),
      );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Ошибка сессии', style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.red,
            ),
          );
    } else {
      // Ошибка при отмене регистрации
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
        content: const Text('Ошибка при отмене регистрации', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
      ),
      );
    }
  }
  void _onItemTapped(int index) {
    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });
      if (index == 2) _fetchCompetitionStatistics();
    }
  }

}

class CompetitionInfoCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;

  const CompetitionInfoCard({
    required this.label,
    required this.value,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.cardTheme.color ?? theme.colorScheme.surface;
    final blockBg = cardColor.computeLuminance() > 0.2
        ? Colors.white.withOpacity(0.08)
        : Colors.white.withOpacity(0.06);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: blockBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.unbounded(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: GoogleFonts.unbounded(
                      fontSize: 15,
                      color: Colors.white,
                      height: 1.35,
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
}
