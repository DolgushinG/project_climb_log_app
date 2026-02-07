import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:login_app/main.dart';
import 'package:login_app/Screens/PublicProfileScreen.dart';

import '../models/Category.dart';


Future<http.Response?> fetchResults({
  required final int eventId,
  required final String stage,
  required final String categoryIdentifier,
}) async {
  final url = Uri.parse('$DOMAIN/api/results/france').replace(
    queryParameters: {
      'event_id': eventId.toString(),
      'stage': stage,
      'uniqid_category_id': categoryIdentifier,
    },
  );
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
  final Category category;
  final String stage;

  FranceResultsPage({
    required this.eventId,
    required this.amount_routes,
    required this.category,
    required this.stage,
  });

  @override
  _FranceResultsPageState createState() => _FranceResultsPageState();
}

class _FranceResultsPageState extends State<FranceResultsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isLoading = true;
  List results = [];
  List filteredResults = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchResults();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List _getSearchFiltered() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return filteredResults;
    return filteredResults.where((r) {
      if (r is! Map) return false;
      final name = _extractName(r);
      return name.toLowerCase().contains(query);
    }).toList();
  }

  String? _extractGender(dynamic raw) {
    if (raw is! Map) return null;
    final g = raw['gender'];
    if (g != null && g.toString().isNotEmpty) return g.toString();
    for (final key in raw.keys) {
      if (key.toString().contains('items') && raw[key] is Map) {
        final m = raw[key] as Map;
        final ig = m['gender'];
        if (ig != null && ig.toString().isNotEmpty) return ig.toString();
      }
    }
    return null;
  }

  String _extractName(dynamic raw) {
    if (raw is! Map) return '';
    String? itemsKey;
    for (final key in raw.keys) {
      if (key.toString().contains('items')) {
        itemsKey = key.toString();
        break;
      }
    }
    if (itemsKey != null && raw[itemsKey] is Map) {
      final m = raw[itemsKey] as Map;
      return (m['middlename'] ?? m['name'] ?? '').toString();
    }
    return (raw['middlename'] ?? raw['name'] ?? '').toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.category),
        automaticallyImplyLeading: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Поиск по имени...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.transparent,
                    overlayColor: MaterialStateProperty.all(Colors.transparent),
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Colors.white.withOpacity(0.16),
                    ),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                    tabs: const [
                      Tab(text: 'Мужчины'),
                      Tab(text: 'Женщины'),
                    ],
                  ),
                ),
              ),
            ],
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
    final categoryId = widget.category.uniqidCategoryId.isNotEmpty
        ? widget.category.uniqidCategoryId
        : widget.category.id.toString();
    try {
      final data = await fetchResults(
        eventId: widget.eventId,
        stage: widget.stage,
        categoryIdentifier: categoryId,
      );
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
    final searchFiltered = _getSearchFiltered();
    final genderResults = searchFiltered.where((result) {
      if (result is! Map) return false;
      final g = _extractGender(result);
      if (g == null || g.isEmpty) return false;
      return g == gender;
    }).toList();
    final String gender_route = gender == 'female' ? 'Ж' : 'М';

    if (genderResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _searchController.text.trim().isEmpty
                ? 'Нет результатов'
                : 'Ничего не найдено',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
          ),
        ),
      );
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
          data['gender'] = _extractGender(raw);
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

        final userId = _extractUserId(data);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: userId != null
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PublicProfileScreen(userId: userId),
                      ),
                    );
                  }
                : null,
            child: Card(
              elevation: 2,
              margin: EdgeInsets.zero,
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
        ),
        ),
        );
      },
    );
  }

  int? _extractUserId(Map<String, dynamic> data) {
    final uid = data['user_id'] ?? data['id'];
    if (uid is int && uid > 0) return uid;
    if (uid is num && uid.toInt() > 0) return uid.toInt();
    if (uid is String) {
      final parsed = int.tryParse(uid);
      if (parsed != null && parsed > 0) return parsed;
    }
    return null;
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
    final isZero = value == '0';
    return Container(
      width: 30,
      height: 20,
      decoration: BoxDecoration(
        color: isZero ? Colors.red : Colors.green,
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

