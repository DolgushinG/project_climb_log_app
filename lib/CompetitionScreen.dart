import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'button/button.dart';
import 'main.dart';

class Competition {
  final int id;
  final String title;
  final String description;
  final String city;
  final String contact;
  final String poster;
  final String payment_info;
  final String address;
  final DateTime start_date;
  final bool isCompleted;

  Competition({
    required this.id,
    required this.title,
    required this.city,
    required this.contact,
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
      city: json['city'],
      contact: json['contact'],
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
      Uri.parse(DOMAIN + 'api/competitions'),
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
  final Competition competition;

  CompetitionDetailScreen(this.competition);

  @override
  _CompetitionDetailScreenState createState() =>
      _CompetitionDetailScreenState();
}

class _CompetitionDetailScreenState extends State<CompetitionDetailScreen> {
  int _selectedIndex = 0;

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
        return _buildResultsSection();
      case 2:
        return _buildStatisticsSection();
      default:
        return _buildInformationSection();
    }
  }

  Widget _buildInformationSection() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.competition.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 300,
              decoration: const BoxDecoration(
                color: Colors.blueAccent,
                image: DecorationImage(
                  image: NetworkImage(
                      DOMAIN + 'storage/images/IMG_0707.jpeg'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 16),
            CompetitionInfoCard(
              label: 'Адрес',
              value: widget.competition.address,
            ),
            // Используем SizedBox с шириной double.infinity вместо Expanded
            Row(
              children: [
                Expanded(child:
                CompetitionInfoCard(
                  label: 'Город',
                  value: widget.competition.city,
                )),
                SizedBox(width: 8),
                Expanded(child:
                CompetitionInfoCard(
                  label: 'Контакты',
                  value: widget.competition.contact,
                ))
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: MyButtonScreen(),
                ),
                SizedBox(width: 8), // Небольшой отступ между кнопками
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
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
            )
          ],
        ),
      ),
    );
  }


  Widget _buildResultsSection() {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          bottom: const TabBar(
            labelColor: Colors.blueAccent,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'Квалификация'),
              Tab(text: 'Полуфинал'),
              Tab(text: 'Финал'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            Center(child: Text('Qualification Results')),
            Center(child: Text('Semifinal Results')),
            Center(child: Text('Final Results')),
          ],
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
