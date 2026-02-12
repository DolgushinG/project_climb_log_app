import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../utils/display_helper.dart';
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
        title: Text(
          widget.category.category,
          style: GoogleFonts.unbounded(fontWeight: FontWeight.w500, fontSize: 18),
        ),
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
                      color: AppColors.mutedGold.withOpacity(0.25),
                    ),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                    labelStyle: GoogleFonts.unbounded(fontSize: 13, fontWeight: FontWeight.w500),
                    unselectedLabelStyle: GoogleFonts.unbounded(fontSize: 13, fontWeight: FontWeight.w400),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events_outlined, size: 64, color: AppColors.mutedGold.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text(
                _searchController.text.trim().isEmpty
                    ? 'Нет результатов'
                    : 'Ничего не найдено',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
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
          final top = _parseInt(data['amount_try_top_$routeIndex']);
          final zone = _parseInt(data['amount_try_zone_$routeIndex']);
          return {
            'amount_try_top': top,
            'route_id': '$gender_route$routeIndex',
            'amount_try_zone': zone,
          };
        });

        final userId = _extractUserId(data);
        final place = _parsePlace(data['place'] ?? data['user_place']);
        final isMedal = place >= 1 && place <= 3;
        final hasAlternateBg = index.isEven;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
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
            child: Container(
              decoration: BoxDecoration(
                color: hasAlternateBg ? AppColors.cardDark : AppColors.rowAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 16,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Text(
                        formatPlace(place),
                        style: AppTypography.rankNumber(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 36,
                          child: isMedal
                              ? Icon(
                                  Icons.emoji_events_outlined,
                                  size: 20,
                                  color: AppColors.mutedGold,
                                )
                              : Text(
                                  formatPlace(place),
                                  style: AppTypography.scoreBadge().copyWith(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.4),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            displayValue((data['middlename'] ?? data['name'])?.toString()),
                            style: AppTypography.athleteName(),
                          ),
                        ),
                        Flexible(
                          child: _buildBadgesSection(data, routes),
                        ),
                      ],
                    ),
                  ),
                ],
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

  int _parsePlace(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }

  int _parseInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }

  Widget _buildBadgesSection(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> routes,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.end,
          children: routes.map<Widget>((route) {
            final top = (route['amount_try_top'] ?? 0) as int;
            final zone = (route['amount_try_zone'] ?? 0) as int;
            return _buildPremiumBadge(
              route['route_id'].toString(),
              top.toString(),
              zone.toString(),
              isZero: top == 0 && zone == 0,
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          alignment: WrapAlignment.end,
          children: [
            _buildScoreBadge('ΣT', (data['amount_top'] ?? 0).toString()),
            _buildScoreBadge('ΣZ', (data['amount_zone'] ?? 0).toString()),
            _buildScoreBadge('ПT', (data['amount_try_top'] ?? 0).toString()),
            _buildScoreBadge('ПZ', (data['amount_try_zone'] ?? 0).toString()),
          ],
        ),
      ],
    );
  }

  Widget _buildPremiumBadge(String routeId, String top, String zone, {bool isZero = false}) {
    final fillColor = isZero
        ? Colors.white.withOpacity(0.06)
        : AppColors.mutedGold.withOpacity(0.15);
    return Container(
      width: 26,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              routeId,
              style: AppTypography.smallLabel(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
            child: Text(
              '$top/$zone',
              style: AppTypography.smallLabel().copyWith(
                fontSize: 9,
                color: Colors.white.withOpacity(0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppTypography.smallLabel()),
          const SizedBox(height: 1),
          Text(
            value,
            style: AppTypography.scoreBadge().copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }

}

