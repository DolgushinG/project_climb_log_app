import 'package:flutter/material.dart';

class ResultEntryPage extends StatefulWidget {

  final int eventId;

  ResultEntryPage({required this.eventId});
  @override
  _ResultEntryPageState createState() => _ResultEntryPageState();
}

class _ResultEntryPageState extends State<ResultEntryPage> {
  List<RouteResult> routes = [
    RouteResult(routeId: 1, color: Colors.red, grade: '6a'),
    RouteResult(routeId: 2, color: Colors.blue, grade: '6b'),
    RouteResult(routeId: 3, color: Colors.green, grade: '6c'),
  ];

  void _submitResults() async {
    // Логика для отправки данных
    Navigator.pushNamed(context, '/competitionDetails');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Внесение результата'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: routes.map((route) => RouteCard(route: route)).toList(),
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
  final RouteResult route;

  const RouteCard({Key? key, required this.route}) : super(key: key);

  @override
  _RouteCardState createState() => _RouteCardState();
}

class _RouteCardState extends State<RouteCard> {
  int selectedAttempt = 0;

  void _selectAttempt(int attempt) {
    setState(() {
      selectedAttempt = attempt;
      widget.route.attempt = selectedAttempt;
    });
  }

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
            // Text(
            //   'ID: ${widget.route.routeId}',
            //   style: const TextStyle(fontSize: 12, color: Colors.grey),
            // ),
            const SizedBox(height: 8),
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
                    _buildAttemptIcon(0, 'X', Colors.red),
                    const SizedBox(width: 8),
                    _buildAttemptIcon(1, 'Flash', Colors.green),
                    const SizedBox(width: 8),
                    _buildAttemptIcon(2, 'Redpoint', Colors.yellow),
                    const SizedBox(width: 8),
                    _buildAttemptIcon(3, 'Zone', Colors.orange),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttemptIcon(int value, String label, Color color) {
    return GestureDetector(
      onTap: () => _selectAttempt(value),
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: selectedAttempt == value ? color.withOpacity(1) : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

class RouteResult {
  final int routeId;
  final Color color;
  final String grade;
  int attempt = 0;

  RouteResult({
    required this.routeId,
    required this.color,
    required this.grade,
  });
}
