import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:login_app/main.dart';

import '../models/Category.dart';


Future<http.Response?> fetchResults({required final int eventId,required final int categoryId,required final String stage}) async {
  final url = Uri.parse('$DOMAIN/api/results/france?event_id=$eventId&stage=$stage&category_id=$categoryId');
  try {
    final response = await http.get(url);
    return response;
  } catch (e) {
    print("Failed to load participants: $e");
  }
  return null;
}

class FranceResultsPage extends StatefulWidget {
  final int eventId;
  final int amount_routes;
  final int categoryId;
  final Category category; // Переданный eventId
  final String stage; // Переданный eventId

  FranceResultsPage({required this.eventId,required this.amount_routes,  required this.categoryId, required this.category, required this.stage});

  @override
  _FranceResultsPageState createState() => _FranceResultsPageState();
}

class _FranceResultsPageState extends State<FranceResultsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isLoading = true; // Флаг загрузки
  bool hasError = false; // Флаг ошибки
  List results = [];
  List filteredResults = [];
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
        title: Text(widget.category.category),
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
          buildFinalResults('male'),
          buildFinalResults('female'),
        ],
      ),
    );
  }
  void _fetchResults() async {
    final int eventId = widget.eventId;
    final String stage = widget.stage;
    final int categoryId = widget.categoryId;
    try {
      final data = await fetchResults(eventId: eventId, categoryId: categoryId, stage: stage);
      if (data!.statusCode == 200) {
        // Декодируем JSON-ответ
        List<dynamic> jsonResponse = json.decode(data.body);

        // Нормализация результата
        List normalizedResults = [];

        if (jsonResponse.isNotEmpty) {
          if (jsonResponse.first is List) {

            // Если это вложенный массив [[...]], объединяем в один список
            for (var sublist in jsonResponse) {
              if (sublist is List) {
                normalizedResults.addAll(sublist);
              }
            }
          } else {
            jsonResponse.forEach((entry) {
              entry.forEach((key, value) {
                normalizedResults.add(value);
              });
            });
          }
        }
        print(normalizedResults);
        if (mounted) {
          setState(() {
            results = normalizedResults;
            filteredResults = results;
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Что то пошло не так ' + data!.statusCode.toString()),
            backgroundColor: Colors.red,
          ),
        );

      }
    } catch (e) {
      throw Exception('Failed to load results ' + e.toString());

    }
  }

  Widget buildFinalResults(String gender) {
    final genderResults = filteredResults.where((result) => result['gender'] == gender).toList();
    final String gender_route;
    if(gender == 'female'){
      gender_route = 'Ж';
    } else {
       gender_route = 'М';
    }

    return ListView.builder(
      itemCount: genderResults.length,
      itemBuilder: (context, index) {
        final result = genderResults[index];

        // Формируем динамические данные для маршрутов
        final routes = List.generate(widget.amount_routes, (i) {
          final routeIndex = i + 1;
          return {
            'amount_try_top': result['amount_try_top_$routeIndex'] ?? 0,
            'route_id': gender_route+routeIndex.toString(),
            'amount_try_zone': result['amount_try_zone_$routeIndex'] ?? 0,
          };
        });

        return Card(
          elevation: 2,
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Блок с основной информацией
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
                            '${result['place']}',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result['middlename'],
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.0),

                // Блок с бейджами
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Блок с бейджами, где бейджи автоматически переносятся
                    Expanded(
                      flex: 3,
                      child: Wrap(
                        spacing: 8.0, // Отступы между бейджами по горизонтали
                        runSpacing: 8.0, // Отступы между строками
                        children: routes.map<Widget>((route) {
                          return Column(
                            children: [
                              _buildBadgeTopNumberRoute(route['route_id'], 5, 5),
                              _buildBadgeTop(route['amount_try_top'].toString()),
                              _buildDivider(),
                              _buildBadgeBottom(route['amount_try_zone'].toString(), 5, 5),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                    SizedBox(width: 6.0),
                    // Колонка "Кол-во"
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          _buildBadgeTopTitle('Кол-во'),
                          Row(
                            children: [
                              Column(
                                children: [
                                  _buildBadgeTopNumberRoute('T', 0, 0),
                                  _buildBadgeBottom(result['amount_top'].toString(), 5, 5),
                                ],
                              ),
                              SizedBox(width: 9.0),
                              Column(
                                children: [
                                  _buildBadgeTopNumberRoute('Z', 0, 0),
                                  _buildBadgeBottom(result['amount_zone'].toString(), 5, 5),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 6.0),
                    // Колонка "Попытки"
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          _buildBadgeTopTitle('Попытки'),
                          Row(
                            children: [
                              Column(
                                children: [
                                  _buildBadgeTopNumberRoute('T', 0, 0),
                                  _buildBadgeBottom(result['amount_try_top'].toString(), 5, 5),
                                ],
                              ),
                              SizedBox(width: 9.0),
                              Column(
                                children: [
                                  _buildBadgeTopNumberRoute('Z', 0, 0),
                                  _buildBadgeBottom(result['amount_try_zone'].toString(), 5, 5),
                                ],
                              ),
                            ],
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
  Widget _buildBadgeTopTitle(String text) {
    return Container(
      width: 69,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(5),
          topRight: Radius.circular(5),
        ),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
  Widget _buildBadgeTopNumberRoute(String value, double radius_left, double radius_right) {
    return Container(
      width: 30,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(radius_left),
          topRight: Radius.circular(radius_right),
        ),
      ),
      child: Center(
        child: Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
  Widget _buildBadgeTop(String value) {
    return Container(
      width: 30,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.green,
      ),
      child: Center(
        child: Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildBadgeBottom(String value, double radius_left, double radius_right) {
    return Container(
      width: 30,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(radius_left),
          bottomRight: Radius.circular(radius_right),
        ),
      ),
      child: Center(
        child: Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 30,
      height: 2,
      color: Colors.black,
    );
  }
}

