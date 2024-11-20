import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:login_app/main.dart';


class FranceResultsPage extends StatefulWidget {
  final int eventId; // Переданный eventId

  FranceResultsPage({required this.eventId});

  @override
  _FranceResultsPageState createState() => _FranceResultsPageState();
}

class _FranceResultsPageState extends State<FranceResultsPage> {
  List<Map<String, dynamic>> femaleResults = []; // Данные из API
  bool isLoading = true; // Флаг загрузки
  bool hasError = false; // Флаг ошибки

  @override
  void initState() {
    super.initState();
    fetchResults(); // Выполняем запрос при загрузке экрана
  }

  Future<void> fetchResults() async {
    final url = Uri.parse('$DOMAIN/api/france/results?eventId=${widget.eventId}');
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        // Успешный ответ
        final data = json.decode(response.body);
        setState(() {
          femaleResults = List<Map<String, dynamic>>.from(data['results']);
          isLoading = false;
        });
      } else {
        // Ошибка сервера
        setState(() {
          hasError = true;
          isLoading = false;
        });
      }
    } catch (e) {
      // Обработка ошибок
      setState(() {
        hasError = true;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('France Results'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator()) // Индикатор загрузки
          : hasError
          ? Center(child: Text('Ошибка загрузки данных')) // Сообщение об ошибке
          : femaleResults.isNotEmpty
          ? Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: femaleResults.length,
          itemBuilder: (context, index) {
            var result = femaleResults[index];
            var routes = result['routes'];

            return Card(
              margin: EdgeInsets.symmetric(vertical: 8.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4.0,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${result['place']} место',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          result['middlename'],
                          style: TextStyle(fontSize: 15),
                        ),
                        Text(
                          result['city'],
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: routes.map<Widget>((route) {
                            return Row(
                              children: [
                                Column(
                                  children: [
                                    _buildBadgeTop(route['try_top'].toString()),
                                    _buildDivider(),
                                    _buildBadgeBottom(route['try_zone'].toString()),
                                  ],
                                ),
                                SizedBox(width: 10),
                              ],
                            );
                          }).toList(),
                        ),
                        Text(
                          result['amount_final_results'],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      )
          : Center(child: Text('Результаты пока не добавлены')),
    );
  }

  Widget _buildBadgeTop(String value) {
    return Container(
      width: 30,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(5),
          topRight: Radius.circular(5),
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

  Widget _buildBadgeBottom(String value) {
    return Container(
      width: 30,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(5),
          bottomRight: Radius.circular(5),
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

