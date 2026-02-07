
import 'package:flutter/material.dart';
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
import 'models/Category.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';

String _normalizePosterPath(String path) {
  if (path.isEmpty) return path;
  if (path.startsWith('http')) return path;
  return path.startsWith('/') ? path : '/$path';
}

bool _jsonToBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final v = value.toLowerCase();
    return v == 'true' || v == '1';
  }
  return false;
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
  final DateTime start_date;
  final bool isCompleted;
  final int is_auto_categories;
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
    required this.poster,
    required this.description,
    required this.is_participant_paid,
    required this.is_access_user_cancel_take_part,
    required this.is_auto_categories,
    required this.is_input_set,
    required this.is_semifinal,
    required this.is_france_system_qualification,
    this.is_access_user_edit_result,
    this.is_send_result_state,
    this.is_open_send_result_state,
    this.is_need_pay_for_reg = false,
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
      is_input_set: json['is_input_set'] ?? 0,
      is_france_system_qualification: json['is_france_system_qualification'] ?? 0,
      is_access_user_edit_result: _jsonToBool(json['is_access_user_edit_result']),
      is_send_result_state: _jsonToBool(json['is_send_result_state']),
      is_open_send_result_state: _jsonToBool(json['is_open_send_result_state']),
      is_need_pay_for_reg: _jsonToBool(json['is_need_pay_for_reg']),
      description: json['description'] ?? '',
      categories: (categoriesRaw is List)
          ? categoriesRaw.map((item) => Map<String, dynamic>.from(item as Map)).toList()
          : [],
      sport_categories: (sportCategoriesRaw is List)
          ? sportCategoriesRaw.map((item) => Map<String, dynamic>.from(item as Map)).toList()
          : [],
      number_sets: (setsRaw is List)
          ? setsRaw.map((item) => Map<String, dynamic>.from(item as Map)).toList()
          : [],
      info_payment: json['info_payment'] ?? '',
      address: json['address'] ?? '',
      climbing_gym_name: (json['climbing_gym_name'] ?? json['climbing_gym'] ?? '').toString(),
      start_date: startDate,
      isCompleted: isCompleted,
    );
  }
}

class CompetitionsScreen extends StatefulWidget {
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

  static const MethodChannel _tracerChannel =
      MethodChannel('tracer_test_channel');

  Future<void> _sendNativeTestCrash() async {
    try {
      await _tracerChannel.invokeMethod('nativeTestCrash');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось отправить тестовый крэш: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchCompetitions();
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
    final String? token = await getToken(); // Ваш токен авторизации
    final response = await http.get(
      Uri.parse(DOMAIN + '/api/competitions'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);

      List<Competition> competitions =
      data.map((json) => Competition.fromJson(json)).toList();

      if (mounted) {
        setState(() {
          _allCurrent = competitions.where((c) => !c.isCompleted).toList();
          _allCompleted = competitions.where((c) => c.isCompleted).toList();
          _isLoading = false;
        });
      }
    } else if (response.statusCode == 401 || response.statusCode == 419) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LoginScreen(),
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сессии')),
      );
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
    final theme = Theme.of(context);
    final baseNavColor = const Color(0xFF020617).withOpacity(0.96);
    final accentNavColor = theme.colorScheme.primary.withOpacity(0.32);

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
        title: const Text('Соревнования'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Отправить тестовый крэш в Tracer',
            onPressed: _sendNativeTestCrash,
          ),
        ],
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
                  color: Colors.white.withOpacity(0.16),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
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
                                dropdownColor: const Color(0xFF1E293B),
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
        final String dateLabel =
            DateFormat('dd.MM.yyyy').format(competition.start_date);
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
                      CompetitionDetailScreen(competition),
                ),
              );
            },
            child: Card(
              color: const Color(0xFF0B1220),
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
                        alignment: Alignment.topCenter,
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
                                    style: const TextStyle(
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
                                    style: TextStyle(
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
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                Text(
                                  dateLabel,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
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

  CompetitionDetailScreen(this.competition);

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
  bool _isRefreshing = false;
  final TextEditingController _textEditingController = TextEditingController();
  final FocusNode _focusNode = AlwaysDisabledFocusNode();

  @override
  void dispose() {
    _textEditingController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _showSetSelectionDialog() {
    List<NumberSets> numberSetList = _competitionDetails.number_sets.map((json) => NumberSets.fromJson(json)).toList();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Локальная переменная для временного хранения выбора
        NumberSets? tempSelectedNumberSet = selectedNumberSet;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Выберите сет'),
              content: SingleChildScrollView(
                child: Column(
                  children: numberSetList.map((numberSet) {
                    return RadioListTile<NumberSets>(
                      title: Text(numberSet.time),
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
                  onPressed: () {
                    Navigator.pop(context); // Закрыть окно без сохранения
                  },
                  child: Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Обновляем состояние главного виджета
                    if (mounted) {
                      setState(() {
                        selectedNumberSet = tempSelectedNumberSet;
                      });
                    }
                    Navigator.pop(context); // Закрыть окно
                  },
                  child: Text('Сохранить'),
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
              title: Text('Выберите категорию'),
              content: SingleChildScrollView(
                child: Column(
                  children: categoryList.map((category) {
                    return RadioListTile<Category>(
                      title: Text(category.category),
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
                  onPressed: () {
                    Navigator.pop(context); // Закрыть окно без сохранения
                  },
                  child: Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Обновляем состояние главного виджета
                    if (mounted) {
                      setState(() {
                        selectedCategory = tempSelectedCategory;
                      });
                    }
                    Navigator.pop(context); // Закрыть окно
                  },
                  child: Text('Сохранить'),
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
              title: Text('Выберите разряд'),
              content: SingleChildScrollView(
                child: Column(
                  children: categoryList.map((sport_category) {
                    return RadioListTile<SportCategory>(
                      title: Text(sport_category.sport_category),
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
                  onPressed: () {
                    Navigator.pop(context); // Закрыть окно без сохранения
                  },
                  child: Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Обновляем состояние главного виджета
                    if (mounted) {
                      setState(() {
                        selectedSportCategory = tempSelectedSportCategory;
                      });
                    }
                    Navigator.pop(context); // Закрыть окно
                  },
                  child: Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
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
            Container(
              height: 300,
              width: MediaQuery.of(context).size.width, // Задаём ширину равную ширине экрана
              decoration: const BoxDecoration(
                color: Colors.blueAccent,
              ),
              child: CachedNetworkImage(
                imageUrl: '$DOMAIN${_competitionDetails.poster}',
                fit: BoxFit.cover,

                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(), // Виджет загрузки
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(
                    Icons.error, // Иконка ошибки
                    color: Colors.red,
                    size: 50,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: const [
                Icon(Icons.info_outline, size: 18, color: Colors.white70),
                SizedBox(width: 8),
                Text(
                  'О соревновании',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0B1220),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _competitionDetails.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_competitionDetails.climbing_gym_name.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: CompetitionInfoCard(
                        icon: Icons.sports_outlined,
                        label: 'Скалодром',
                        value: _competitionDetails.climbing_gym_name,
                      ),
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
            const SizedBox(height: 20),
            if(!_competitionDetails.isCompleted && !_competitionDetails.is_participant && _competitionDetails.is_need_send_birthday)
              Row(
                  children: [
                    Expanded( // Используем Flexible для более гибкого контроля
                      child: TextField(
                        focusNode: _focusNode,
                        controller: _textEditingController,
                        readOnly: true,
                        onTap: () => _selectDate(context),
                        decoration: InputDecoration(
                          labelText: 'Выберите дату',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ]),
            const SizedBox(height: 12),
            if (!_competitionDetails.isCompleted && !_competitionDetails.is_participant)
              if(_competitionDetails.is_need_sport_category == 1)
                Row(
                    children: [
                      Expanded( // Используем Flexible для более гибкого контроля
                        child:  ElevatedButton(
                          onPressed: _showSportCategorySelectionDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1D4ED8),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            selectedSportCategory == null
                                ? 'Выберите разряд'
                                : 'Разряд: ${selectedSportCategory!.sport_category}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ]),
            if (!_competitionDetails.isCompleted && !_competitionDetails.is_participant)
              if(_competitionDetails.is_auto_categories == 0)
                Row(
                children: [
                  Expanded( // Используем Flexible для более гибкого контроля
                      child:  ElevatedButton(
                        onPressed: _showCategorySelectionDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D4ED8),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          selectedCategory == null
                              ? 'Выберите категорию'
                              : 'Категория: ${selectedCategory!.category}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ),
                ]),
            const SizedBox(height: 8),
            if (!_competitionDetails.isCompleted && !_competitionDetails.is_participant)
              if(_competitionDetails.is_input_set == 0)
                Row(children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _showSetSelectionDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D4ED8),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      selectedNumberSet == null
                          ? 'Выберите сет'
                          : 'Сет: ${selectedNumberSet!.number_set}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ),
                )
              ]),
            const SizedBox(height: 24),
            Row(
              children: const [
                Icon(Icons.hiking_rounded, size: 18, color: Colors.white70),
                SizedBox(width: 8),
                Text(
                  'Ваше участие',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
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
                child: const Center(
                  child: Text(
                    'Соревнование завершено',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
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
                    backgroundColor: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Список участников',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: TakePartButtonScreen(
                      _competitionDetails.id,
                      _competitionDetails.is_participant,
                      _selectedDate,
                      selectedCategory,
                      selectedSportCategory,
                      selectedNumberSet,
                      _refreshParticipationStatus,
                      is_need_pay_for_reg: _competitionDetails.is_need_pay_for_reg,
                      onNeedCheckout: (eventId) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CheckoutScreen(eventId: eventId),
                          ),
                        ).then((_) => _refreshParticipationStatus());
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
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
                        backgroundColor: const Color(0xFF1E293B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Список участников',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
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

                    if (!canShowResultButton || !_competitionDetails.is_routes_exists) {
                      return const SizedBox.shrink();
                    }

                    return Column(
                      children: [
                        const SizedBox(height: 10),
                        Row(
                          children: [
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
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () async {
                                    bool? confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          title: const Text(
                                              'Подтверждение отмены регистрации'),
                                          content: const Text(
                                              'Вы уверены, что хотите отменить регистрацию?'),
                                          actions: <Widget>[
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(context).pop(false),
                                              child: const Text('Отмена'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(context).pop(true),
                                              child: const Text('Подтвердить'),
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
                                  child: const Text(
                                    'Отменить регистрацию',
                                    style: TextStyle(
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.w500,
                                    ),
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
    final theme = Theme.of(context);
    final baseNavColor = const Color(0xFF020617).withOpacity(0.96);
    final accentNavColor = theme.colorScheme.primary.withOpacity(0.32);

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
        title: const Text('Детали соревнования'),
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
              selectedItemColor: theme.colorScheme.primary,
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
          onRefresh: () async => fetchCompetition(),
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
          title: Text('Результаты'),
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
                    color: Colors.white.withOpacity(0.16),
                  ),
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
    return Card(
      color: const Color(0xFF0B1220),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      elevation: 0.0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14.0,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsSection() {
    return Center(
      child: Text(
        'Statistics coming soon...',
        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
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

  /// Если участник платного соревнования и не оплатил — проверяем таймер и редиректим на Checkout
  Future<void> _checkAndRedirectToCheckoutIfNeeded(Competition c) async {
    if (!c.is_participant || !c.is_need_pay_for_reg || c.is_participant_paid) return;
    try {
      final token = await getToken();
      if (token == null) return;
      final r = await http.get(
        Uri.parse('$DOMAIN/api/event/${c.id}/checkout'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (r.statusCode != 200 || !mounted) return;
      final raw = json.decode(r.body);
      final data = raw is Map ? Map<String, dynamic>.from(raw) : null;
      if (data == null) return;
      final hasBill = data['has_bill'] == true;
      final remaining = (data['remaining_seconds'] is num) ? (data['remaining_seconds'] as num).toInt() : 0;
      if (mounted) {
        setState(() => _receiptPending = hasBill);
        if (hasBill) return; // Чек загружен — остаёмся на странице соревнования
        if (remaining > 0) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CheckoutScreen(eventId: c.id, initialData: data),
            ),
          ).then((_) => fetchCompetition());
        }
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _competitionDetails = widget.competition;
    fetchCompetition(); // _fetchInitialParticipationStatus = fetchCompetition, один вызов
  }

// Обновить детали соревнования
  Future<void> fetchCompetition() async {
    final String? token = await getToken();
    final response = await http.get(
      Uri.parse(DOMAIN + '/api/competitions?event_id=${_competitionDetails.id}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );


    if (response.statusCode == 200) {
      final raw = json.decode(response.body);
      final data = raw is List && raw.isNotEmpty ? raw.first : raw;
      if (data is! Map) return;
      final Competition updatedCompetition = Competition.fromJson(Map<String, dynamic>.from(data));
      if (mounted) {
        setState(() {
          _competitionDetails = updatedCompetition;
        });
        _checkAndRedirectToCheckoutIfNeeded(updatedCompetition);
      }
    } else if (response.statusCode == 401 || response.statusCode == 419) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LoginScreen(),
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сессии')),
      );
    } else {
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
        SnackBar(content: Text('Регистрация отменена успешно')),
      );
    } else if (response.statusCode == 401 || response.statusCode == 419) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LoginScreen(),
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сессии')),
      );
    } else {
      // Ошибка при отмене регистрации
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при отмене регистрации')),
      );
    }
  }
  void _onItemTapped(int index) {
    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });
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
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.85),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
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
