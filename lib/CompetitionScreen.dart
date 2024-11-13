import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:login_app/login.dart';
import 'package:login_app/result_festival.dart';
import 'dart:convert';
import 'ResultsEntryScreen.dart';
import 'button/take_part.dart';
import 'list_participants.dart';
import 'list_participants.dart';
import 'main.dart';
import 'models/Category.dart';

class Competition {
  final int id;
  final String title;
  final String description;
  final String city;
  final String contact;
  final bool is_participant;
  final String poster;
  final String info_payment;
  final List<Map<String, dynamic>> categories;
  final String address;
  final DateTime start_date;
  final bool isCompleted;
  final int is_access_user_cancel_take_part;

  Competition({
    required this.id,
    required this.title,
    required this.city,
    required this.contact,
    required this.is_participant,
    required this.address,
    required this.poster,
    required this.description,
    required this.is_access_user_cancel_take_part,
    required this.info_payment,
    required this.categories,
    required this.start_date,
    required this.isCompleted,
  });

  factory Competition.fromJson(Map<String, dynamic> json) {
    return Competition(
      id: json['id'],
      title: json['title'],
      city: json['city'],
      is_participant: json['is_participant'],
      contact: json['contact'],
      poster: json['poster'],
      is_access_user_cancel_take_part: json['is_access_user_cancel_take_part'],
      description: json['description'],
      categories: (json['categories'] as List).map((item) => Map<String, dynamic>.from(item)).toList(),
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

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);

      List<Competition> competitions =
          data.map((json) => Competition.fromJson(json)).toList();

      setState(() {
        _currentCompetitions =
            competitions.where((c) => !c.isCompleted).toList();
        _completedCompetitions =
            competitions.where((c) => c.isCompleted).toList();
        _isLoading = false;
      });
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
      setState(() {
        _isLoading = false;
      });
    }
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
        title: Text('Соревнвоания'),
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
                buildCompetitionList(_currentCompetitions),
                buildCompetitionList(_completedCompetitions),
              ],
            ),
    );
  }

  Widget buildCompetitionList(List<dynamic> competitions) {
    return competitions.isEmpty
        ? const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('No competitions found.'),
          )
        : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
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
                          builder: (context) =>
                              CompetitionDetailScreen(competition)),
                    );
                  },
                ),
              );
            },
          );
  }
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

  late Competition _competitionDetails; // Хранит обновленные данные соревнования



  // Метод для инициализации состояния
  Future<void> _fetchInitialParticipationStatus() async {
    await fetchCompetition();
    // После того как данные загружены, перерисовываем UI
    setState(() {});
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

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // Преобразуем JSON в объект `Competition`
      final Competition updatedCompetition = Competition.fromJson(data);
      setState(() {
        _competitionDetails = updatedCompetition; // Обновляем детали соревнования
      });
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
    setState(() {
      _selectedIndex = index;
    });
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
        return _buildResultsSection(context);
      case 2:
        return _buildStatisticsSection();
      default:
        return _buildInformationSection();
    }
  }

  Widget _buildInformationSection() {
    Category? selectedCategory;
    List<Category> categoryList = _competitionDetails.categories.map((json) => Category.fromJson(json)).toList();
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
            const SizedBox(height: 16),
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.blueAccent,
                image: DecorationImage(
                  image: NetworkImage(
                      '$DOMAIN${_competitionDetails.poster}'),
                  fit: BoxFit.cover,
                ),
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
                Expanded(child:
                CompetitionInfoCard(
                  label: 'Город',
                  value: _competitionDetails.city,
                )),
                SizedBox(width: 8),
                Expanded(child:
                CompetitionInfoCard(
                  label: 'Контакты',
                  value: _competitionDetails.contact,
                ))
              ],
            ),
            SizedBox(height: 20),
            Row(
              children: [
                SizedBox(height: 8),
                if (!_competitionDetails.isCompleted && !_competitionDetails.is_participant)
                  Expanded(
                  child:
                  DropdownButton<Category>(
                    value: selectedCategory,
                    onChanged: (Category? newValue) {
                      setState(() {
                        selectedCategory = newValue;
                      });
                    },
                    items: categoryList.map<DropdownMenuItem<Category>>((Category category) {
                      return DropdownMenuItem<Category>(
                        value: category,
                        child: Text(category.category),
                      );
                    }).toList(),
                    hint: Text('Выберите категорию'),
                  )
                ),
                SizedBox(height: 8),
              ],
            ),
            SizedBox(height: 20),
            Row(
              children: [
                if (!_competitionDetails.isCompleted)
                  Expanded(
                    child: TakePartButtonScreen(
                      _competitionDetails.id,
                      _competitionDetails.is_participant,
                      _refreshParticipationStatus
                    ),
                  ),
                SizedBox(width: 10), // Небольшой отступ между кнопками
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ParticipantListScreen(_competitionDetails.id, _competitionDetails.categories),
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
                  Expanded(
                    child:  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ResultEntryPage(eventId: _competitionDetails.id),
                          ),
                        );
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
                  SizedBox(height: 8, width: _competitionDetails.is_access_user_cancel_take_part == 1 ? 10: 0),
                  if(_competitionDetails.is_access_user_cancel_take_part == 1)
                    Expanded(
                      child:  ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          // Показать диалог с подтверждением
                          bool? confirm = await showDialog<bool>(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text('Подтверждение отмены регистрации'),
                                content: Text('Вы уверены, что хотите отменить регистрацию?'),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop(false); // Отклонить
                                    },
                                    child: Text('Отмена'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop(true); // Подтвердить
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
              )
          ],
        ),
      ),
    );
  }


  @override
  Widget _buildResultsSection(BuildContext context) {
    List<Category> categoryList = _competitionDetails.categories.map((json) => Category.fromJson(json)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Категории'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: categoryList
              .map((category) => _buildResultCard(
            title: category.category.split(' ').first,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ResultScreen(
                    eventId: _competitionDetails.id,
                    categoryId: category.id,
                    category: category,
                  ),
                ),
              );
            },
          ),
          )
              .toList(),
        ),
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
              Icon(
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
