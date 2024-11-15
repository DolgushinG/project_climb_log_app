import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'main.dart';
import 'models/Category.dart';


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
Future<List<ParticipantResult>> fetchParticipants({required final int eventId,required final int categoryId}) async {
  final Uri url = Uri.parse('$DOMAIN/api/results/festival/?event_id=$eventId&category_id=$categoryId');

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
  final int categoryId;
  final Category category;
  ResultScreen({required this.eventId, required this.categoryId, required this.category});

  @override
  _ResultScreenState createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ParticipantResult> results = [];
  List<ParticipantResult> filteredResults = [];
  String? searchQuery = '';
  Category? selectedCategory;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchResults();
  }

  void _fetchResults() async {
    final int eventId = widget.eventId;
    final int categoryId = widget.categoryId;
    try {
      final data = await fetchParticipants(eventId: eventId, categoryId: categoryId);
      if (mounted) {
        setState(() {
          results = data;
          filteredResults = results;
        });
      }
    } catch (e) {
      print("Failed to load participants: $e");
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.category.split(' ').first),
        automaticallyImplyLeading: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Мужчины'),
            Tab(text: 'Женщины'),
          ],
        ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Место',
                            style: TextStyle(fontSize: 8, color: Colors.grey),
                          ),
                          Text(
                            '${result.user_place}',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result.middlename,
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Баллы',
                            style: TextStyle(fontSize: 8, color: Colors.grey),
                          ),
                          Text(
                            '${result.points}',
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
