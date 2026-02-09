import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:login_app/main.dart';
import 'package:login_app/services/ProfileService.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ProfileService(baseUrl: DOMAIN).getProfileAnalytics(context);
      if (mounted) {
        setState(() {
          _data = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: const Text('Аналитика и Статистика'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                'Не удалось загрузить данные',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    if (_data == null) {
      return const Center(child: Text('Нет данных'));
    }

    final analytics = _data!['analytics'] as Map<String, dynamic>? ?? {};
    final progress = _data!['analytics_progress'] as Map<String, dynamic>? ?? {};

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAnalyticsCards(analytics),
            const SizedBox(height: 24),
            _buildProgressSection(progress),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsCards(Map<String, dynamic> analytics) {
    final semifinalRate = (analytics['semifinal_rate'] as num?)?.toInt() ?? 0;
    final finalRate = (analytics['final_rate'] as num?)?.toInt() ?? 0;
    final averageStability = (analytics['averageStability'] as num?)?.toDouble() ?? 0.0;
    final totalPrizePlaces = (analytics['totalPrizePlaces'] as num?)?.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Сводка',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Полуфиналы',
                '$semifinalRate',
                Icons.emoji_events,
                Colors.amber.withOpacity(0.2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Финалы',
                '$finalRate',
                Icons.star,
                Colors.orange.withOpacity(0.2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Стабильность',
                averageStability.toStringAsFixed(2),
                Icons.trending_up,
                Colors.green.withOpacity(0.2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Призовые места',
                '$totalPrizePlaces',
                Icons.military_tech,
                Colors.blue.withOpacity(0.2),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color bgColor) {
    return Card(
      color: bgColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, color: Colors.white70, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.85),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection(Map<String, dynamic> progress) {
    final labels = List<String>.from(progress['labels'] ?? []);
    final flashes = List<int>.from(
      (progress['flashes'] ?? []).map((e) => (e as num).toInt()),
    );
    final redpoints = List<int>.from(
      (progress['redpoints'] ?? []).map((e) => (e as num).toInt()),
    );

    if (labels.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Прогресс по соревнованиям',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  'Пока нет данных о соревнованиях',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Прогресс по соревнованиям',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Флеши и редпоинты по последним 30 соревнованиям',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildLegendItem('Флеши', Colors.green),
            const SizedBox(width: 20),
            _buildLegendItem('Редпоинты', Colors.orange),
          ],
        ),
        const SizedBox(height: 8),
        _buildProgressChart(labels, flashes, redpoints),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    );
  }

  Widget _buildProgressChart(List<String> labels, List<int> flashes, List<int> redpoints) {
    final maxLen = [labels.length, flashes.length, redpoints.length].reduce((a, b) => a > b ? a : b);
    if (maxLen == 0) return const SizedBox.shrink();

    final all = [...flashes.take(maxLen), ...redpoints.take(maxLen)];
    final maxY = all.isEmpty ? 5.0 : (all.reduce((a, b) => a > b ? a : b).toDouble() * 1.2).clamp(5.0, double.infinity);

    return SizedBox(
      height: 280,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (maxLen - 1).toDouble(),
          minY: 0,
          maxY: maxY,
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ),
            ),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(maxLen, (i) => FlSpot(i.toDouble(), (i < flashes.length ? flashes[i] : 0).toDouble())),
              isCurved: true,
              color: Colors.green,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: Colors.green.withOpacity(0.15)),
            ),
            LineChartBarData(
              spots: List.generate(maxLen, (i) => FlSpot(i.toDouble(), (i < redpoints.length ? redpoints[i] : 0).toDouble())),
              isCurved: true,
              color: Colors.orange,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: Colors.orange.withOpacity(0.15)),
            ),
          ],
          borderData: FlBorderData(show: true, border: Border.all(color: Colors.white24)),
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY / 5),
        ),
      ),
    );
  }
}
