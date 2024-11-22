import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:login_app/main.dart';

import '../models/Category.dart';


Future<http.Response?> fetchResults({required final int eventId,required final int categoryId,required final String stage}) async {
  final url = Uri.parse('$DOMAIN/api/results/france?event_id=$eventId&stage=$stage&category_id=$categoryId');
  try {
    final response = await http.get(url);
    print(response.body);
    return response;
  } catch (e) {
    print("Failed to load participants: $e");
  }
  return null;
}

class FranceResultsPage extends StatefulWidget {
  final int eventId;
  final int categoryId;
  final Category category; // Переданный eventId
  final String stage; // Переданный eventId

  FranceResultsPage({required this.eventId, required this.categoryId, required this.category, required this.stage});

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
        List jsonResponse = json.decode(data.body);
        List normalizedResults = [];
        jsonResponse.forEach((entry) {
          entry.forEach((key, value) {
            normalizedResults.add(value);
          });
        });
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
                            '${result['place']}',
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
                            result['middlename'],
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
    // return Scaffold(
    //   appBar: AppBar(
    //     title: Text('France Results'),
    //   ),
    //   body: isLoading
    //       ? Center(child: CircularProgressIndicator()) // Индикатор загрузки
    //       : hasError
    //       ? Center(child: Text('Ошибка загрузки данных')) // Сообщение об ошибке
    //       : genderResults.isNotEmpty
    //       ? Padding(
    //     padding: const EdgeInsets.all(16.0),
    //     child: ListView.builder(
    //       itemCount: genderResults.length,
    //       itemBuilder: (context, index) {
    //         var result = genderResults[index];
    //
    //         return Card(
    //           margin: EdgeInsets.symmetric(vertical: 8.0),
    //           shape: RoundedRectangleBorder(
    //             borderRadius: BorderRadius.circular(12),
    //           ),
    //           elevation: 4.0,
    //           child: Padding(
    //             padding: const EdgeInsets.all(16.0),
    //             child: Column(
    //               crossAxisAlignment: CrossAxisAlignment.start,
    //               children: [
    //                 Row(
    //                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
    //                   children: [
    //                     Text(
    //                       '${result['middlename']} место',
    //                       style: TextStyle(
    //                         fontSize: 18,
    //                         fontWeight: FontWeight.bold,
    //                       ),
    //                     ),
    //                     Text(
    //                       result['middlename'],
    //                       style: TextStyle(fontSize: 15),
    //                     ),
    //                   ],
    //                 ),
    //                 SizedBox(height: 12.0),
    //                 Row(
    //                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
    //                   children: [
    //                     Row(
    //                       children: routes.map<Widget>((route) {
    //                         return Row(
    //                           children: [
    //                             Column(
    //                               children: [
    //                                 _buildBadgeTop(route['amount_try_top'].toString()),
    //                                 _buildDivider(),
    //                                 _buildBadgeBottom(route['amount_try_zone'].toString()),
    //                               ],
    //                             ),
    //                             SizedBox(width: 10),
    //                           ],
    //                         );
    //                       }).toList(),
    //                     ),
    //                     Text(
    //                       result['amount_final_results'],
    //                       style: TextStyle(
    //                         fontSize: 16,
    //                         fontWeight: FontWeight.bold,
    //                         color: Colors.black,
    //                       ),
    //                     ),
    //                   ],
    //                 ),
    //               ],
    //             ),
    //           ),
    //         );
    //       },
    //     ),
    //   )
    //       : Center(child: Text('Результаты пока не добавлены')),
    // );
  }
  //
  // Widget _buildBadgeTop(String value) {
  //   return Container(
  //     width: 30,
  //     height: 20,
  //     decoration: BoxDecoration(
  //       color: Colors.green,
  //       borderRadius: BorderRadius.only(
  //         topLeft: Radius.circular(5),
  //         topRight: Radius.circular(5),
  //       ),
  //     ),
  //     child: Center(
  //       child: Text(
  //         value,
  //         style: TextStyle(
  //           color: Colors.white,
  //           fontSize: 12,
  //           fontWeight: FontWeight.bold,
  //         ),
  //       ),
  //     ),
  //   );
  // }
  //
  // Widget _buildBadgeBottom(String value) {
  //   return Container(
  //     width: 30,
  //     height: 20,
  //     decoration: BoxDecoration(
  //       color: Colors.green,
  //       borderRadius: BorderRadius.only(
  //         bottomLeft: Radius.circular(5),
  //         bottomRight: Radius.circular(5),
  //       ),
  //     ),
  //     child: Center(
  //       child: Text(
  //         value,
  //         style: TextStyle(
  //           color: Colors.white,
  //           fontSize: 12,
  //           fontWeight: FontWeight.bold,
  //         ),
  //       ),
  //     ),
  //   );
  // }
  //
  // Widget _buildDivider() {
  //   return Container(
  //     width: 30,
  //     height: 2,
  //     color: Colors.black,
  //   );
  // }
}

