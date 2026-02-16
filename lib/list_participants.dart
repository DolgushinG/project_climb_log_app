import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:login_app/main.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models/Category.dart';
import 'models/NumberSets.dart';
import 'Screens/PublicProfileScreen.dart';
import 'theme/app_theme.dart';
import 'utils/display_helper.dart';

/// Нормализует значение number_set из API (может быть int, String или List<int>)
List<int> _parseNumberSets(dynamic value) {
  if (value == null) return [];
  if (value is int && value > 0) return [value];
  if (value is num && value.toInt() > 0) return [value.toInt()];
  if (value is String) {
    final p = int.tryParse(value.trim());
    if (p != null && p > 0) return [p];
  }
  if (value is List) {
    final result = <int>[];
    for (final e in value) {
      int? v;
      if (e is int) v = e;
      else if (e is num) v = e.toInt();
      else v = int.tryParse(e?.toString() ?? '');
      if (v != null && v > 0) result.add(v);
    }
    return result;
  }
  return [];
}

class Participant {

  final String middlename;
  final String city;
  final String category;
  final String gender;
  final String birthday;
  final int? userId;
  /// Номера сетов участника (из API: set, number_set, number_sets)
  final List<int> numberSets;

  Participant({
    required this.middlename,
    required this.city,
    required this.category,
    required this.gender,
    required this.birthday,
    this.userId,
    this.numberSets = const [],
  });

  // Метод для создания объекта из JSON (для получения данных из API)
  factory Participant.fromJson(Map<String, dynamic> json) {
    int? parsedUserId;
    final uid = json['user_id'] ?? json['id'];
    if (uid is int && uid > 0) parsedUserId = uid;
    if (uid is num && uid.toInt() > 0) parsedUserId = uid.toInt();
    if (uid is String) {
      final p = int.tryParse(uid);
      if (p != null && p > 0) parsedUserId = p;
    }
    // category: верхний уровень или participant_category.category
    String categoryStr = (json['category'] ?? '').toString().trim();
    if (categoryStr.isEmpty) {
      final pc = json['participant_category'];
      if (pc is Map) {
        categoryStr = (pc['category'] ?? '').toString().trim();
      }
    }
    // number_set: верхний уровень или set.number_set, или set как int
    dynamic numberSetsRaw = json['number_sets'] ?? json['number_set'] ?? json['set'] ?? json['sets'];
    if (numberSetsRaw == null) {
      final setObj = json['set'];
      if (setObj is Map) {
        numberSetsRaw = setObj['number_set'] ?? setObj['number_sets'];
      }
    }
    return Participant(
      middlename: (json['middlename'] ?? '').toString(),
      gender: (json['gender'] ?? '').toString(),
      category: categoryStr,
      city: (json['city'] ?? '').toString(),
      birthday: (json['birthday'] ?? '').toString(),
      userId: parsedUserId,
      numberSets: _parseNumberSets(numberSetsRaw),
    );
  }
}


Future<List<Participant>> fetchParticipants({
  required final int eventId,
  required final String? token,
}) async {
  final Uri url = Uri.parse('$DOMAIN/api/participants?event_id=$eventId');

  final response = await http.get(
    url,
    headers: {
      if (token != null) 'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    },
  );

  if (response.statusCode == 200) {
    final List<dynamic> jsonResponse = json.decode(response.body);
    return jsonResponse.map((data) => Participant.fromJson(data)).toList();
  } else {
    // Логируем, чтобы понимать, что именно не нравится бэку
    throw Exception('Failed to load participants');
  }
}

class ParticipantListScreen extends StatefulWidget {
  final int eventId;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> numberSets;

  ParticipantListScreen(this.eventId, this.categories, [this.numberSets = const []]);

  @override
  _ParticipantListScreenState createState() => _ParticipantListScreenState();
}

class _ParticipantListScreenState extends State<ParticipantListScreen> {
  List<Participant> participants = [];
  List<Participant> filteredParticipants = [];
  String searchQuery = '';
  Category? selectedCategory;
  int? selectedNumberSet; // Номер сета для фильтра (number_set)

  @override
  void initState() {
    super.initState();
    _fetchParticipants();
  }

  void _fetchParticipants() async {
    final int eventId = widget.eventId;
    try {
      final String? token = await getToken();
      final data = await fetchParticipants(eventId: eventId, token: token);
      if (mounted) {
        setState(() {
          participants = data;
          _applyFilters();
        });
      }
    } catch (e) {
    }
  }

  void _showFilterSheet(BuildContext context, List<Category> categories, List<NumberSets> setsList) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.45,
          widthFactor: 1.0,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Фильтры',
                  style: GoogleFonts.unbounded(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 16),
                if (categories.isNotEmpty) ...[
                  Text('Категория (группа)', style: GoogleFonts.unbounded(fontSize: 13, color: Colors.white70)),
                  SizedBox(height: 6),
                  StatefulBuilder(
                    builder: (BuildContext context, StateSetter setState) {
                      return DropdownButtonFormField<Category>(
                        value: selectedCategory,
                        onChanged: (Category? newValue) {
                          setState(() => selectedCategory = newValue);
                          _applyFilters();
                        },
                        items: [
                          DropdownMenuItem<Category>(value: null, child: Text('Все категории')),
                          ...categories.map<DropdownMenuItem<Category>>((Category category) {
                            return DropdownMenuItem<Category>(
                              value: category,
                              child: Text(category.category),
                            );
                          }),
                        ],
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.08),
                        ),
                        dropdownColor: AppColors.cardDark,
                      );
                    },
                  ),
                  SizedBox(height: 16),
                ],
                if (setsList.isNotEmpty) ...[
                  Text('Сет', style: GoogleFonts.unbounded(fontSize: 13, color: Colors.white70)),
                  SizedBox(height: 6),
                  StatefulBuilder(
                    builder: (BuildContext context, StateSetter setState) {
                      return DropdownButtonFormField<int>(
                        value: selectedNumberSet,
                        onChanged: (int? newValue) {
                          setState(() => selectedNumberSet = newValue);
                          _applyFilters();
                        },
                        items: [
                          DropdownMenuItem<int>(value: null, child: Text('Все сеты')),
                          ...setsList.map<DropdownMenuItem<int>>((NumberSets s) {
                            return DropdownMenuItem<int>(
                              value: s.number_set,
                              child: Text(formatSetCompact(s)),
                            );
                          }),
                        ],
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.08),
                        ),
                        dropdownColor: AppColors.cardDark,
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _applyFilters() {
    if (mounted) {
      setState(() {
        filteredParticipants = participants.where((participant) {
          if (selectedCategory != null) {
            final catA = (participant.category).trim();
            final catB = (selectedCategory!.category).trim();
            if (catA != catB) return false;
          }
          if (selectedNumberSet != null) {
            if (participant.numberSets.isEmpty) return false;
            if (!participant.numberSets.contains(selectedNumberSet)) return false;
          }
          if (searchQuery.trim().isNotEmpty) {
            if (!participant.middlename.toLowerCase().contains(searchQuery.trim().toLowerCase())) {
              return false;
            }
          }
          return true;
        }).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Category> categoryList = widget.categories.map((json) => Category.fromJson(json)).toList();
    List<NumberSets> setsList = widget.numberSets
        .map((j) => NumberSets.fromJson(Map<String, dynamic>.from(j)))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Участники',
          style: GoogleFonts.unbounded(fontWeight: FontWeight.w500, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () async {
              final query = await showSearch<String>(
                context: context,
                delegate: ParticipantSearchDelegate(
                  participants: participants,
                  onSelected: (q) {},
                ),
              );
              setState(() {
                searchQuery = query ?? '';
                _applyFilters();
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: () => _showFilterSheet(context, categoryList, setsList),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: filteredParticipants.length,
        itemBuilder: (context, index) {
          final participant = filteredParticipants[index];
          final hasAlternateBg = index.isEven;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: participant.userId != null
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PublicProfileScreen(
                              userId: participant.userId!),
                        ),
                      );
                    }
                  : null,
              child: Container(
                decoration: BoxDecoration(
                  color: hasAlternateBg ? AppColors.cardDark : AppColors.rowAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayValue(participant.middlename),
                            style: AppTypography.athleteName(),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              displayValue(participant.category),
                              displayValue(participant.city),
                              if (participant.numberSets.isNotEmpty)
                                'Сет ${participant.numberSets.join(', ')}',
                            ].where((s) => s != 'Нет данных' && s.isNotEmpty).join(' · '),
                            style: AppTypography.secondary(),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        displayValue(participant.birthday),
                        style: AppTypography.scoreBadge().copyWith(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}


class ParticipantSearchDelegate extends SearchDelegate<String> {
  final List<Participant> participants;
  final Function(String) onSelected;

  ParticipantSearchDelegate({required this.participants, required this.onSelected});

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final results = participants
        .where((p) => p.middlename.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final participant = results[index];
        return ListTile(
          title: Text(
            displayValue(participant.middlename),
            style: AppTypography.athleteName().copyWith(fontSize: 14),
          ),
          subtitle: Text(
            '${displayValue(participant.category)} · ${displayValue(participant.city)}',
            style: AppTypography.secondary(),
          ),
          onTap: () {
            onSelected(query);
            close(context, query);
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = participants
        .where((p) => p.middlename.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final participant = suggestions[index];
        return ListTile(
          title: Text(
            displayValue(participant.middlename),
            style: AppTypography.athleteName().copyWith(fontSize: 14),
          ),
          subtitle: Text(
            '${displayValue(participant.category)} · ${displayValue(participant.city)}',
            style: AppTypography.secondary(),
          ),
          onTap: () {
            onSelected(participant.middlename);
            close(context, participant.middlename);
          },
        );
      },
    );
  }
}
