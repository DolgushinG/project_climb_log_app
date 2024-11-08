import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_html/flutter_html.dart';

class Competition {
  final int id;
  final String title;
  final String description;
  final String poster;
  final String payment_info;
  final String address;
  final DateTime start_date;
  final bool isCompleted;

  Competition({
    required this.id,
    required this.title,
    required this.address,
    required this.poster,
    required this.description,
    required this.payment_info,
    required this.start_date,
    required this.isCompleted,
  });

  factory Competition.fromJson(Map<String, dynamic> json) {
    return Competition(
      id: json['id'],
      title: json['title'],
      poster: json['poster'],
      description: json['description'],
      payment_info: json['payment_info'],
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
    final String token = '123'; // Ваш токен авторизации
    final response = await http.get(
      Uri.parse('http://127.0.0.1:8000/api/competitions'),
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
        title: Text('Competitions'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Current'),
            Tab(text: 'Completed'),
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
                  trailing: Text('${competition.start_date.toLocal().toString().split(' ')[0]}'),
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

class CompetitionDetailScreen extends StatelessWidget {
  final Competition competition;

  CompetitionDetailScreen(this.competition);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Competition Details'),
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок соревнования
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  competition.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Постер на весь экран
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  image: DecorationImage(
                    image: NetworkImage('http://127.0.0.1:8000/storage/images/IMG_0707.jpeg'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              // Информация: адрес, город, контакты
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Address: ${competition.address}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'City: Москва', // Пример добавления города
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Contact: +799999999', // Пример добавления контактов
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // Табуляция
              const TabBar(
                labelColor: Colors.blueAccent,
                unselectedLabelColor: Colors.grey,
                tabs: [
                  Tab(text: 'Описание'),
                  Tab(text: 'Оплата'),
                ],
              ),

              // Вкладки: описание и оплата
              const SizedBox(height: 8),
              Container(
                height: 300, // Добавим ограничение по высоте для TabBarView
                child: TabBarView(
                  children: [
                    // Описание
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            // Кнопки
                            ElevatedButton(
                              onPressed: () {},
                              child: Text('Участвовать'),
                            ),
                            ElevatedButton(
                              onPressed: () {},
                              child: Text('Список участников'),
                            ),
                            ElevatedButton(
                              onPressed: () {},
                              child: Text('Предварительные результаты'),
                            ),
                            ElevatedButton(
                              onPressed: () {},
                              child: Text('Результаты полуфинала'),
                            ),
                            ElevatedButton(
                              onPressed: () {},
                              child: Text('Результаты финала'),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Оплата
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        competition.payment_info,
                        style: const TextStyle(fontSize: 16),
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
}

