import 'dart:convert';
import 'dart:ffi';
import 'package:http/http.dart' as http;
import 'package:login_app/main.dart';
import 'package:flutter/material.dart';

import 'models/Category.dart';

class Participant {

  final String middlename;
  final String city;
  final String category;
  final String gender;
  final String birthday;
  // final String set;

  Participant({
    required this.middlename,
    required this.city,
    required this.category,
    required this.gender,
    required this.birthday,
    // required this.set,
  });

  // Метод для создания объекта из JSON (для получения данных из API)
  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      middlename: json['middlename'],
      gender: json['gender'] ?? '',
      category: json['category'] ?? '',
      city: json['city'] ?? '',
      birthday: json['birthday'] ?? '',
      // set: json['set'],
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
    print('Failed to load participants, status: ${response.statusCode}');
    print('Failed to load participants body: ${response.body}');
    throw Exception('Failed to load participants');
  }
}

class ParticipantListScreen extends StatefulWidget {
  final int eventId;
  final List<Map<String, dynamic>> categories;

  ParticipantListScreen(this.eventId, this.categories);

  @override
  _ParticipantListScreenState createState() => _ParticipantListScreenState();
}

class _ParticipantListScreenState extends State<ParticipantListScreen> {
  List<Participant> participants = [];
  List<Participant> filteredParticipants = [];
  String searchQuery = '';
  Category? selectedCategory;

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
          filteredParticipants = participants;
        });
      }
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
    if (mounted) {
      setState(() {
        filteredParticipants = participants.where((participant) {
          if (selectedCategory != null) {
            return participant.category == selectedCategory.category;
          }
          return true;
        }).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Преобразуем JSON в объекты Category перед вызовом _showFilterSheet
    List<Category> categoryList = widget.categories.map((json) => Category.fromJson(json)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Участники'),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              setState(() {
                searchQuery = '';
              });
              showSearch(
                context: context,
                delegate: ParticipantSearchDelegate(
                  participants: participants,
                  onSelected: (query) {
                    setState(() {
                      searchQuery = query;
                      _applyFilters(selectedCategory); // Используем выбранный фильтр, если есть
                    });
                  },
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: () => _showFilterSheet(context, categoryList), // Передаем список категорий
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: filteredParticipants.length,
        itemBuilder: (context, index) {
          final participant = filteredParticipants[index];
          return Card(
            elevation: 3,
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: ListTile(
              title: Text('${participant.middlename}'),
              subtitle: Text('${participant.category} - ${participant.city}'),
              trailing: Text('${participant.birthday}'),
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
          title: Text('${participant.middlename}'),
          subtitle: Text('${participant.category} - ${participant.city}'),
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
          title: Text('${participant.middlename}'),
          subtitle: Text('${participant.category} - ${participant.city}'),
          onTap: () {
            onSelected(participant.middlename);
            close(context, participant.middlename);
          },
        );
      },
    );
  }
}
