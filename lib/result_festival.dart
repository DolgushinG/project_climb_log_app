import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'main.dart';

// Структура данных для результатов участников
class ParticipantResult {
  final int user_place;
  final String middlename;
  final String category;
  final num points;
  final String gender;

  ParticipantResult({
    required this.user_place,
    required this.middlename,
    required this.category,
    required this.points,
    required this.gender,
  });

  // Фабричный метод для создания экземпляра из JSON
  factory ParticipantResult.fromJson(Map<String, dynamic> json) {
    return ParticipantResult(
      user_place: json['user_place'],
      middlename: json['middlename'],
      category: json['category'],
      points: json['points'],
      gender: json['gender'],
    );
  }
}

// Функция для получения данных участников
Future<List<ParticipantResult>> fetchParticipants({required final int eventId}) async {
  final Uri url = Uri.parse('$DOMAIN/api/results/festival/?event_id=$eventId');

  final response = await http.get(url);

  if (response.statusCode == 200) {
    List jsonResponse = json.decode(response.body);
    return jsonResponse.map((data) => ParticipantResult.fromJson(data)).toList();
  } else {
    throw Exception('Failed to load participants');
  }
}

class ResultScreen extends StatefulWidget {
  final int eventId;
  final List<Map<String, dynamic>> categories;

  ResultScreen({required this.eventId, required this.categories});

  @override
  _ResultScreenState createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ParticipantResult> results = [];
  List<ParticipantResult> filteredResults = [];
  String? searchQuery;
  String? selectedCategory;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchResults();
  }

  void _fetchResults() async {
    try {
      final data = await fetchParticipants(eventId: widget.eventId);

      setState(() {
        results = data;
        filteredResults = results;
      });
    } catch (e) {
      print("Failed to load participants: $e");
    }
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.3,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text('Фильтры', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(labelText: 'Поиск по имени'),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                  },
                ),
                DropdownButton<String>(
                  value: selectedCategory,
                  hint: Text('Выберите категорию'),
                  onChanged: (newValue) {
                    setState(() {
                      selectedCategory = newValue;
                    });
                  },
                  items: widget.categories.map((category) {
                    return DropdownMenuItem<String>(
                      value: category['category'],
                      child: Text(category['category']),
                    );
                  }).toList(),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _applyFilters();
                  },
                  child: Text('Применить фильтры'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _applyFilters() {
    setState(() {
      filteredResults = results.where((result) {
        final matchesSearchQuery = searchQuery == null || result.middlename.contains(searchQuery!);
        final matchesCategory = selectedCategory == null || result.category == selectedCategory;
        return matchesSearchQuery && matchesCategory;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Результаты'),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Мужчины'),
            Tab(text: 'Женщины'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: () => _showFilterSheet(context),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildResultList('male'),
          _buildResultList('female'),
        ],
      ),
    );
  }

  Widget _buildResultList(String gender) {
    final genderResults = filteredResults.where((result) => result.gender == gender).toList();

    return ListView.builder(
      itemCount: genderResults.length,
      itemBuilder: (context, index) {
        final result = genderResults[index];
        return Card(
          elevation: 2,
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(child: Text('${result.user_place}', style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(width: 10),
                Expanded(flex: 2, child: Text(result.middlename)),
                SizedBox(width: 10),
                Expanded(child: Text(result.category)),
                SizedBox(width: 10),
                Expanded(child: Text('${result.points}')),
              ],
            ),
          ),
        );
      },
    );
  }
}
