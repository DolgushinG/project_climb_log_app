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
    // Бэкенд теперь отдаёт поле place (ранее было user_place) —
    // поддерживаем оба варианта для совместимости.
    final dynamic rawPlace = json['place'] ?? json['user_place'];
    int parsedPlace;
    if (rawPlace is int) {
      parsedPlace = rawPlace;
    } else if (rawPlace is String) {
      parsedPlace = int.tryParse(rawPlace) ?? 0;
    } else {
      parsedPlace = 0;
    }

    final dynamic rawPoints = json['points'];
    num parsedPoints;
    if (rawPoints is num) {
      parsedPoints = rawPoints;
    } else if (rawPoints is String) {
      parsedPoints = num.tryParse(rawPoints) ?? 0;
    } else {
      parsedPoints = 0;
    }

    return ParticipantResult(
      user_place: parsedPlace,
      middlename: json['middlename'] ?? '',
      category: json['category'] ?? '',
      points: parsedPoints,
      gender: json['gender'] ?? '',
    );
  }
}



// Функция для получения данных участников фестиваля
Future<List<ParticipantResult>> fetchParticipants({
  required final int eventId,
  required final String uniqidCategoryId,
}) async {
  final Uri url = Uri.parse(
    '$DOMAIN/api/results/festival/?event_id=$eventId&uniqid_category_id=$uniqidCategoryId',
  );

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
  // Уникальный идентификатор категории, ожидаемый бэкендом для festival-результатов
  final String uniqidCategoryId;
  final Category category;
  ResultScreen({
    required this.eventId,
    required this.categoryId,
    required this.category,
    required this.uniqidCategoryId,
  });

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



  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.category.split(' ').first),
        automaticallyImplyLeading: true,
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
                  Tab(text: 'Мужчины'),
                  Tab(text: 'Женщины'),
                ],
              ),
            ),
          ),
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
  void _fetchResults() async {
    final int eventId = widget.eventId;
    final String uniqidCategoryId = widget.uniqidCategoryId;
    try {
      final data = await fetchParticipants(
        eventId: eventId,
        uniqidCategoryId: uniqidCategoryId,
      );
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
