import 'package:flutter/material.dart';

class FranceResultsPage extends StatelessWidget {
  final List<Map<String, dynamic>> femaleResults = [
    {
      'place': 1,
      'middlename': 'Иванова Анна',
      'city': 'Москва',
      'amount_final_results': '5T5z 88',
      'routes': [
        {'try_top': 1, 'try_zone': 1},
        {'try_top': 1, 'try_zone': 1},
      ],
    },
    {
      'place': 2,
      'middlename': 'Иванова22 Анна22',
      'city': 'Москва',
      'amount_final_results': '5T5z 88',
      'routes': [
        {'try_top': 1, 'try_zone': 1},
        {'try_top': 1, 'try_zone': 1},
        {'try_top': 1, 'try_zone': 1},
        {'try_top': 1, 'try_zone': 1},
      ],
    },
    // Добавьте больше результатов здесь
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: femaleResults.isNotEmpty
          ? Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: femaleResults.length,
          itemBuilder: (context, index) {
            var result = femaleResults[index];
            var routes = result['routes']; // Список маршрутов и их результатов

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
                    // Строка с местом, фамилией и городом
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

                    // Отображение маршрутов и финального результата
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Маршруты (в одну строку)
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
                                SizedBox(width: 10), // Отступ между маршрутами
                              ],
                            );
                          }).toList(),
                        ),

                        // Финальный результат
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




  // Виджет для верхней части бейджа
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

  // Виджет для нижней части бейджа
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

  // Виджет для разделяющей линии между бейджами
  Widget _buildDivider() {
    return Container(
      width: 30,
      height: 2,  // высота линии между бейджами
      color: Colors.black,
    );
  }
}
