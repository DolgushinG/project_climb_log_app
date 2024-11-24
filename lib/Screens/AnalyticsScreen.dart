import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyticsScreen extends StatelessWidget {
  final Map<String, dynamic> analytics;
  final Map<String, dynamic> analyticsProgress;

  const AnalyticsScreen({
    Key? key,
    required this.analytics,
    required this.analyticsProgress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: const Text('Аналитика и Статистика'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Overall Analytics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildLineChart(analytics, 'Overall Analytics'),
            const SizedBox(height: 30),
            const Text(
              'Progress Analytics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildLineChart(analyticsProgress, 'Progress Analytics'),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart(Map<String, dynamic> data, String title) {
    final labels = List<String>.from(data['labels']);
    final flashes = List<int>.from(data['flashes']);
    final redpoints = List<int>.from(data['redpoints']);

    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < labels.length) {
                    return Text(
                      labels[index],
                      style: const TextStyle(fontSize: 10),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          lineBarsData: [
            // Flashes line
            LineChartBarData(
              spots: List.generate(flashes.length, (index) {
                return FlSpot(index.toDouble(), flashes[index].toDouble());
              }),
              isCurved: true,
              color: Colors.blue,
              barWidth: 4,
              belowBarData: BarAreaData(show: false),
            ),
            // Redpoints line
            LineChartBarData(
              spots: List.generate(redpoints.length, (index) {
                return FlSpot(index.toDouble(), redpoints[index].toDouble());
              }),
              isCurved: true,
              color: Colors.red,
              barWidth: 4,
              belowBarData: BarAreaData(show: false),
            ),
          ],
          borderData: FlBorderData(show: true),
          gridData: FlGridData(show: true),
        ),
      ),
    );
  }

}
