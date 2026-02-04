
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:login_app/Screens/FranceResultScreen.dart';
import 'package:login_app/login.dart';
import 'package:login_app/models/NumberSets.dart';
import 'package:login_app/models/SportCategory.dart';
import 'package:login_app/result_festival.dart';
import 'dart:convert';
import 'ResultsEntryScreen.dart';
import 'button/take_part.dart';
import 'list_participants.dart';
import 'main.dart';
import 'models/Category.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
    required this.poster,
    required this.description,
    required this.is_participant_paid,
    required this.is_access_user_cancel_take_part,
    required this.is_auto_categories,
    required this.is_input_set,
    required this.is_semifinal,
    required this.is_france_system_qualification,
    this.is_access_user_edit_result,
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
    return Competition(
      id: json['id'],
      title: json['title'],
      city: json['city'],
      is_participant: _jsonToBool(json['is_participant']),
      is_participant_active: _jsonToBool(json['is_participant_active']),
      is_result_in_final_exists: _jsonToBool(json['is_result_in_final_exists']),
      amount_routes_in_qualification: json['amount_routes_in_qualification'],
      amount_routes_in_final: json['amount_routes_in_final'] ?? 0,
      amount_routes_in_semifinal: json['amount_routes_in_semifinal'] ?? 0,
      is_semifinal: _jsonToBool(json['is_semifinal']),
      is_need_send_birthday: _jsonToBool(json['is_need_send_birthday']),
      is_need_sport_category: json['is_need_sport_category'],
      is_routes_exists: _jsonToBool(json['is_routes_exists']),
      is_participant_paid: _jsonToBool(json['is_participant_paid']),
      contact: json['contact'] ?? '',
      poster: json['poster'],
      is_access_user_cancel_take_part: json['is_access_user_cancel_take_part'],
      is_auto_categories: json['is_auto_categories'],
      is_input_set: json['is_input_set'],
      is_france_system_qualification: json['is_france_system_qualification'],
      is_access_user_edit_result: _jsonToBool(json['is_access_user_edit_result']),
      description: json['description'] ?? '',
      categories: (json['categories'] as List).map((item) => Map<String, dynamic>.from(item)).toList(),
      sport_categories: (json['sport_categories'] as List).map((item) => Map<String, dynamic>.from(item)).toList(),
      number_sets: (json['sets'] as List).map((item) => Map<String, dynamic>.from(item)).toList(),
      info_payment: json['info_payment'] ?? '',
      address: json['address'],
      start_date: DateTime.parse(json['start_date']),
      isCompleted: json['isCompleted'],
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchCompetitions();
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

    print('fetchCompetitions status: ${response.statusCode}');
    print('fetchCompetitions body: ${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);

      List<Competition> competitions =
      data.map((json) => Competition.fromJson(json)).toList();

      if (mounted) {
        setState(() {
          _currentCompetitions =
              competitions.where((c) => !c.isCompleted).toList();
          _completedCompetitions =
              competitions.where((c) => c.isCompleted).toList();
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
      print('Failed to load competitions');
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
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Соревнования'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Текущие'),
            Tab(text: 'Завершенные'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  onRefresh: _refreshCompetitions,
                  child: buildCompetitionList(_currentCompetitions),
                ),
                RefreshIndicator(
                  onRefresh: _refreshCompetitions,
                  child: buildCompetitionList(_completedCompetitions),
                ),
              ],
            ),
    );
  }

  Widget buildCompetitionList(List<dynamic> competitions) {
    if (competitions.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(
              child: Text('No competitions found.'),
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
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            title: Text(competition.title),
            subtitle: Text(competition.address),
            trailing: Text(
                '${competition.start_date.toLocal().toString().split(' ')[0]}'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CompetitionDetailScreen(competition),
                ),
              );
            },
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
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
            const SizedBox(height: 8),
            Text(
              _competitionDetails.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            CompetitionInfoCard(
              label: 'Адрес',
              value: _competitionDetails.address,
            ),
            // Используем SizedBox с шириной double.infinity вместо Expanded
            Row(
              children: [
                Flexible( // Используем Flexible для более гибкого контроля
                  child: CompetitionInfoCard(
                    label: 'Город',
                    value: _competitionDetails.city,
                  ),
                ),
                SizedBox(width: 3),
                Flexible(
                  child: CompetitionInfoCard(
                    label: 'Контакты',
                    value: _competitionDetails.contact,
                  ),
                ),
              ],
            ),
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
            if (!_competitionDetails.isCompleted && !_competitionDetails.is_participant)
              if(_competitionDetails.is_need_sport_category == 1)
                Row(
                    children: [
                      Expanded( // Используем Flexible для более гибкого контроля
                        child:  ElevatedButton(
                          onPressed: _showSportCategorySelectionDialog,
                          child: Text(
                            selectedSportCategory == null
                                ? 'Выберите разряд'
                                : 'Разряд: ${selectedSportCategory!.sport_category}',
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
                        child: Text(
                          selectedCategory == null
                              ? 'Выберите категорию'
                              : 'Категория: ${selectedCategory!.category}',
                        ),
                      ),
                  ),
                ]),
            if (!_competitionDetails.isCompleted && !_competitionDetails.is_participant)
              if(_competitionDetails.is_input_set == 0)
                Row(children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _showSetSelectionDialog,
                    child: Text(
                      selectedNumberSet == null
                          ? 'Выберите сет'
                          : 'Сет: ${selectedNumberSet!.number_set}',
                    ),
                ),
                )
              ]),
            SizedBox(height: 10),
            Row(
              children: [
                if (!_competitionDetails.isCompleted)
                  Expanded(
                    child: TakePartButtonScreen(
                      _competitionDetails.id,
                      _competitionDetails.is_participant,
                      _selectedDate,
                      selectedCategory,
                      selectedSportCategory,
                      selectedNumberSet,
                      _refreshParticipationStatus,
                    ),
                  ),
                SizedBox(width: 10), // Небольшой отступ между кнопками
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
                      backgroundColor: Colors.blue[600],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('Список участников', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
            if (_competitionDetails.is_participant)
              Row(
                children: [
                  if (_competitionDetails.is_routes_exists &&
                      _competitionDetails.is_france_system_qualification == 0)
                    Expanded(
                      child: _jsonToBool(_competitionDetails.is_participant_active)
                          ? (_jsonToBool(_competitionDetails.is_access_user_edit_result)
                              ? ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  onPressed: () async {
                                    final bool? needRefresh =
                                        await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ResultEntryPage(
                                          eventId: _competitionDetails.id,
                                          isParticipantActive: _jsonToBool(
                                            _competitionDetails
                                                .is_participant_active,
                                          ),
                                        ),
                                      ),
                                    );

                                    // Если с экрана внесения результатов вернулись с флагом обновления — перезапрашиваем данные события
                                    if (needRefresh == true) {
                                      await _refreshParticipationStatus();
                                    }
                                  },
                                  child: const Text(
                                    'Редактировать результаты',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.0,
                                    ),
                                    textAlign: TextAlign.left,
                                  ),
                                )
                              : Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 8),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    'Результаты добавлены',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ))
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: () async {
                                final bool? needRefresh = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ResultEntryPage(
                                      eventId: _competitionDetails.id,
                                      isParticipantActive: _jsonToBool(
                                        _competitionDetails.is_participant_active,
                                      ),
                                    ),
                                  ),
                                );

                                // Если с экрана внесения результатов вернулись с флагом обновления — перезапрашиваем данные события
                                if (needRefresh == true) {
                                  await _refreshParticipationStatus();
                                }
                              },
                              child: const Text(
                                'Внести результаты',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.0,
                                ),
                                textAlign: TextAlign.left,
                              ),
                            ),
                    ),
                  SizedBox(height: 8, width: _competitionDetails.is_access_user_cancel_take_part == 1 && !_competitionDetails.is_participant_paid ? 10 : 0),
                  if (_competitionDetails.is_access_user_cancel_take_part == 1 && !_competitionDetails.is_participant_paid)
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          bool? confirm = await showDialog<bool>(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text('Подтверждение отмены регистрации'),
                                content: Text('Вы уверены, что хотите отменить регистрацию?'),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop(false);
                                    },
                                    child: Text('Отмена'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop(true);
                                    },
                                    child: Text('Подтвердить'),
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
                            color: Colors.white,
                            fontSize: 14.0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали соревнования'),
      ),
      body: _buildContent(),
      bottomNavigationBar: BottomNavigationBar(
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
        selectedItemColor: Colors.blueAccent,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildInformationSection();
      case 1:
        return buildResults(context);
      case 2:
        return _buildStatisticsSection();
      default:
        return _buildInformationSection();
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
          bottom: TabBar(
            tabs: [
              Tab(text: 'Квалификация'),
              if ( _competitionDetails.is_semifinal) Tab(text: 'Полуфинал'), // Показываем только при флаге
              if (_competitionDetails.is_result_in_final_exists) Tab(text: 'Финал'),
            ],
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
                  categoryId: category.id,
                  category: category,
                  stage: stage
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      elevation: 4.0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const Icon(
                Icons.arrow_forward,
                color: Colors.blueAccent,
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

  @override
  void initState() {
    super.initState();
    _fetchInitialParticipationStatus();
    _competitionDetails = widget.competition; // Инициализируем значением из конструктора
    fetchCompetition();
  }

// Обновить детали соревнования
  Future<void> fetchCompetition() async {
    final String? token = await getToken();
    print(DOMAIN + '/api/competitions?event_id=${_competitionDetails.id}'); // Ваш токен авторизации
    final response = await http.get(
      Uri.parse(DOMAIN + '/api/competitions?event_id=${_competitionDetails.id}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    print('fetchCompetition status: ${response.statusCode}');
    print('fetchCompetition body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // Преобразуем JSON в объект `Competition`
      final Competition updatedCompetition = Competition.fromJson(data);
      if (mounted) {
        setState(() {
          _competitionDetails =
              updatedCompetition; // Обновляем детали соревнования
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
      print('Failed to load competitions');
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

  const CompetitionInfoCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        subtitle: Text(
          value,
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
