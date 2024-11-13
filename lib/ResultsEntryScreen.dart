import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'CompetitionScreen.dart';
import 'main.dart';


Future<List<Routes>> getRoutesData({
  required final int eventId
}) async {
  final Uri url = Uri.parse('$DOMAIN/api/routes?event_id=$eventId');

  final response = await http.get(url);

  if (response.statusCode == 200) {
    List jsonResponse = json.decode(response.body);
    print(jsonResponse);
    return jsonResponse.map((data) => Routes.fromJson(data)).toList();
  } else {
    throw Exception('Failed to load participants');
  }
}


class ResultEntryPage extends StatefulWidget {
  final int eventId;

  ResultEntryPage({required this.eventId});

  @override
  _ResultEntryPageState createState() => _ResultEntryPageState();
}

class _ResultEntryPageState extends State<ResultEntryPage> {
  List<Routes> routes = [];
  List<Map<String, dynamic>> selectedAttempts = [];

  @override
  void initState() {
    super.initState();
    _getRoutesData();
  }
  void _showNotification(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: 2),
      ),
    );
  }
  void _submitResults() async {
    final data = {
      'results': selectedAttempts, // Отправка выбранных попыток
    };
    final String? token = await getToken();
    try {
      final response = await http.post(
        Uri.parse('$DOMAIN/api/event/send/results'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        _showNotification('Успешное внесение результатов', Colors.green);
        // Navigator.push(
        //   context,
        //   MaterialPageRoute(builder: (context) => CompetitionsScreen()),
        // );
      } else {
        print('Failed to submit results: ${response.body}');
      }
    } catch (e) {
      print("Error occurred while submitting results: $e");
    }
  }

  void _getRoutesData() async {
    final int eventId = widget.eventId;
    try {
      final data = await getRoutesData(eventId: eventId);
      setState(() {
        routes = data;
      });
    } catch (e) {
      print("Failed to load participants: $e");
    }
  }

  // Функция для обновления выбранной попытки
  void _updateSelectedAttempts(int routeId, int attempt) {
    setState(() {
      final index = selectedAttempts.indexWhere((a) => a['route_id'] == routeId);
      if (index != -1) {
        // Обновляем попытку, если она уже существует
        selectedAttempts[index]['attempt'] = attempt;
      } else {
        // Добавляем новую запись, если попытка для routeId не существует
        selectedAttempts.add({'route_id': routeId, 'attempt': attempt});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Внесение результата'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: routes.map((route) => RouteCard(
          route: route,
          selectedAttempts: selectedAttempts,
          onAttemptSelected: _updateSelectedAttempts,
        )).toList(),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[600],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: _submitResults,
          child: const Text('Отправить результат',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.0,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class RouteCard extends StatefulWidget {
  final Routes route;
  final List<Map<String, dynamic>> selectedAttempts;
  final Function(int routeId, int attempt) onAttemptSelected;

  const RouteCard({
    Key? key,
    required this.route,
    required this.selectedAttempts,
    required this.onAttemptSelected,
  }) : super(key: key);

  @override
  _RouteCardState createState() => _RouteCardState();
}

class _RouteCardState extends State<RouteCard> {
  int selectedAttempt = 0;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Трасса ${widget.route.routeId}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('Цвет: ', style: TextStyle(fontSize: 16)),
                Container(
                  width: 20,
                  height: 20,
                  color: widget.route.color,
                ),
                const SizedBox(width: 16),
                Text('Категория: ${widget.route.grade}', style: TextStyle(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Попытка:', style: TextStyle(fontSize: 16)),
                Row(
                  children: [
                    _buildAttemptIcon(0, 'X', Colors.red, widget.route.routeId),
                    const SizedBox(width: 8),
                    _buildAttemptIcon(1, 'Flash', Colors.green, widget.route.routeId),
                    const SizedBox(width: 8),
                    _buildAttemptIcon(2, 'Redpoint', Colors.yellow, widget.route.routeId),
                    const SizedBox(width: 8),
                    _buildAttemptIcon(3, 'Zone', Colors.orange, widget.route.routeId),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttemptIcon(int index, String label, Color color, int routeId) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedAttempt = index;
          widget.onAttemptSelected(routeId, selectedAttempt);
        });
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selectedAttempt == index ? color.withOpacity(1) : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class Routes {
  final int routeId;
  final String? routeName;
  final Color? color;
  final String grade;
  int attempt = 0;

  Routes({
    required this.routeId,
    required this.routeName,
    required this.color,
    required this.grade,
  });

  factory Routes.fromJson(Map<String, dynamic> json) {
    return Routes(
      routeId: json['route_id'] ?? 0,
      routeName: json['routeName'] ?? '',
      color: json['color'] != null ? _colorFromHex(json['color']) : Colors.transparent,
      grade: json['grade'] ?? '',
    );
  }

  // Helper function to convert a hex color string to Color
  static Color _colorFromHex(String hexColor) {
    hexColor = hexColor.replaceFirst('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor'; // Add opacity if not provided
    }
    return Color(int.parse(hexColor, radix: 16));
  }
}
