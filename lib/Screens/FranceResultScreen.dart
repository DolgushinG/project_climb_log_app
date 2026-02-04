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
      if (data != null && data.statusCode == 200) {
        // Декодируем JSON-ответ
        final dynamic decoded = json.decode(data.body);

        // Нормализация результата к списку map'ов
        List normalizedResults = [];

        if (decoded is List) {
          if (decoded.isNotEmpty && decoded.first is List) {
            // Если это вложенный массив [[...]], объединяем в один список
            for (var sublist in decoded) {
              if (sublist is List) {
                normalizedResults.addAll(sublist);
              }
            }
          } else if (decoded.isNotEmpty && decoded.first is Map) {
            // Список map'ов. Возможны два варианта:
            // 1) [{...}, {...}] — уже то, что нужно
            // 2) [{1: {...}, 10: {...}}] — нужно взять values
            final first = decoded.first as Map;
            final bool isNumericKeyed =
                first.keys.isNotEmpty && first.keys.first is! String;

            if (isNumericKeyed) {
              for (final entry in decoded) {
                if (entry is Map) {
                  normalizedResults.addAll(entry.values);
                }
              }
            } else {
              normalizedResults = List.from(decoded);
            }
          }
        } else if (decoded is Map) {
          // Например, { "data": [ ... ] }
          final dataField = decoded['data'];
          if (dataField is List) {
            normalizedResults = List.from(dataField);
          }
        }

        if (mounted) {
          setState(() {
            results = normalizedResults;
            filteredResults = results;
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Что то пошло не так ' + (data?.statusCode.toString() ?? '')),
            backgroundColor: Colors.red,
          ),
        );

      }
    } catch (e) {
      throw Exception('Failed to load results ' + e.toString());

    }
  }

  Widget buildFinalResults(String gender) {
    final genderResults = filteredResults.where((result) {
      if (result is! Map) return false;
      final g = result['gender'];
      // Если бэк не прислал gender — показываем результат в обеих вкладках
      if (g == null || g.toString().isEmpty) return true;
      return g == gender;
    }).toList();
    final String gender_route;
    if(gender == 'female'){
      gender_route = 'Ж';
    } else {
       gender_route = 'М';
    }

    return ListView.builder(
      itemCount: genderResults.length,
      itemBuilder: (context, index) {
        final raw = genderResults[index];

        // Бэкенд возвращает объект вида:
        // {
        //   "\u0000*\u0000items": { ... поля участника ... },
        //   "\u0000*\u0000escapeWhenCastingToString": false,
        //   "gender": "female"
        // }
        //
        // Нам нужны только поля из "items" +, при желании, "gender".
        final Map<String, dynamic> data = <String, dynamic>{};
        if (raw is Map) {
          // Ищем ключ, в имени которого есть "items"
          String? itemsKey;
          for (final key in raw.keys) {
            final keyStr = key.toString();
            if (keyStr.contains('items')) {
              itemsKey = keyStr;
              break;
            }
          }

          if (itemsKey != null && raw[itemsKey] is Map) {
            data.addAll(Map<String, dynamic>.from(raw[itemsKey] as Map));
          }

          // Заодно сохраняем gender, если он нужен
          if (raw['gender'] != null) {
            data['gender'] = raw['gender'];
          }
        }

        // Формируем динамические данные для маршрутов
        final routes = List.generate(widget.amount_routes, (i) {
          final routeIndex = i + 1;
          return {
            'amount_try_top': data['amount_try_top_$routeIndex'] ?? 0,
            'route_id': gender_route+routeIndex.toString(),
            'amount_try_zone': data['amount_try_zone_$routeIndex'] ?? 0,
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
                            '${data['place'] ?? data['user_place'] ?? ''}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
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
                            (data['middlename'] ?? data['name'] ?? '')
                                .toString(),
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
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  children: [
                                    _buildBadgeTopNumberRoute('T', 5, 5),
                                    _buildBadgeBottom(
                                        (data['amount_top'] ?? 0).toString(),
                                        5,
                                        5),
                                  ],
                                ),
                                SizedBox(width: 9.0),
                                Column(
                                  children: [
                                    _buildBadgeTopNumberRoute('Z', 5, 5),
                                    _buildBadgeBottom(
                                        (data['amount_zone'] ?? 0).toString(),
                                        5,
                                        5),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 2.0),
                    // Колонка "Попытки"
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          _buildBadgeTopTitle('Попытки'),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  children: [
                                    _buildBadgeTopNumberRoute('T', 5, 5),
                                    _buildBadgeBottom(
                                        (data['amount_try_top'] ?? 0)
                                            .toString(),
                                        5,
                                        5),
                                  ],
                                ),
                                SizedBox(width: 9.0),
                                Column(
                                  children: [
                                    _buildBadgeTopNumberRoute('Z', 5, 5),
                                    _buildBadgeBottom(
                                        (data['amount_try_zone'] ?? 0)
                                            .toString(),
                                        5,
                                        5),
                                  ],
                                ),
                              ],
                            ),
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
      width: 72,
      height: 20,
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
        color: const Color(0xFF020617),
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
      color: Colors.white24,
    );
  }
}

