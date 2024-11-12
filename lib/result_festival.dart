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

class Category {
  final String category;
  final String toGrade;
  final String fromGrade;

  Category({
    required this.category,
    required this.toGrade,
    required this.fromGrade,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      category: json['category'],
      toGrade: json['to_grade'],
      fromGrade: json['from_grade'],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Category && other.category == category;
  }

  @override
  int get hashCode => category.hashCode;
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
    try {
      final data = await fetchParticipants(eventId: eventId);

      setState(() {
        results = data;
        filteredResults = results;
      });
    } catch (e) {
      print("Failed to load participants: $e");
    }
  }

  void _showFilterSheet(BuildContext context, List<Category> categories) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.3,
          widthFactor: 1.0,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Фильтры',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                StatefulBuilder(
                  builder: (BuildContext context, StateSetter setState) {
                    return DropdownButton<Category>(
                      value: selectedCategory,
                      onChanged: (Category? newValue) {
                        setState(() {
                          selectedCategory = newValue;
                        });
                        _applyFilters(selectedCategory); // Применяем фильтр после выбора
                      },
                      items: categories.map<DropdownMenuItem<Category>>((Category category) {
                        return DropdownMenuItem<Category>(
                          value: category,
                          child: Text(category.category),
                        );
                      }).toList(),
                      hint: Text('Выберите категорию'),
                    );
                  },
                ),
                SizedBox(height: 16),
                // ElevatedButton(
                //   onPressed: () {
                //     Navigator.pop(context);
                //     _applyFilters(selectedCategory); // Применяем выбранную категорию
                //   },
                //   child: Text('Применить фильтр'),
                // ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _applyFilters(Category? selectedCategory) {
    setState(() {
      filteredResults = results.where((result) {
        if (selectedCategory != null) {
          return result.category == selectedCategory.category;
        }
        return true;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Category> categoryList = widget.categories.map((json) => Category.fromJson(json)).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text('Результаты'),
        automaticallyImplyLeading: true,
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
            onPressed: () => _showFilterSheet(context, categoryList),
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
                            result.category,
                            style: TextStyle(fontSize: 10),
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
