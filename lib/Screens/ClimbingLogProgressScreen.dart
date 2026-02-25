import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:login_app/models/ClimbingLog.dart';
import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/services/ClimbingLogService.dart';
import 'package:login_app/utils/climbing_log_colors.dart';

/// Экран прогресса (статистика трасс).
class ClimbingLogProgressScreen extends StatefulWidget {
  const ClimbingLogProgressScreen({super.key});

  @override
  State<ClimbingLogProgressScreen> createState() =>
      _ClimbingLogProgressScreenState();
}

class _ClimbingLogProgressScreenState extends State<ClimbingLogProgressScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final ClimbingLogService _service = ClimbingLogService();
  ClimbingProgress? _progress;
  ClimbingLogStatistics? _statisticsDaily;
  ClimbingLogStatistics? _statisticsWeekly;
  bool _loading = true;
  String? _error;
  List<String> _orderedGrades = orderedGrades;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final results = await Future.wait([
      _service.getProgress(),
      _service.getStatistics(groupBy: 'day', periodDays: 14),
      _service.getStatistics(groupBy: 'week', periodDays: 56),
    ]);
    var progress = results[0] as ClimbingProgress?;
    var statsDaily = results[1] as ClimbingLogStatistics?;
    var statsWeekly = results[2] as ClimbingLogStatistics?;
    if (!mounted) return;
    setState(() {
      _progress = progress;
      _statisticsDaily = statsDaily;
      _statisticsWeekly = statsWeekly;
      _loading = false;
      if (progress == null && _progress == null) {
        _error = 'Нет данных. Добавьте первую тренировку.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.anthracite,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Text(
                    'Прогресс',
                    style: unbounded(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                if (_error != null && (_progress == null || _progress!.grades.isEmpty))
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.graphite),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.trending_up, size: 40, color: Colors.white24),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ..._buildContent(context),
                ..._buildRouteCharts(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildContent(BuildContext context) {
    final p = _progress;
    if (p == null) return [];

    final totalRoutes = p.grades.values.fold(0, (a, b) => a + b);

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (p.maxGrade != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.mutedGold.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Максимальный грейд',
                        style: unbounded(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.maxGrade!,
                        style: unbounded(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      _GradientProgressBar(
                        value: p.progressPercentage / 100,
                        height: 8,
                        borderRadius: 8,
                        colors: const [
                          Color(0xFF3B82F6),
                          Color(0xFF8B5CF6),
                          Color(0xFFD946EF),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${p.progressPercentage}% по шкале',
                        style: unbounded(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Text(
                'Всего трасс: $totalRoutes',
                style: unbounded(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final grade = _orderedGrades[index];
              final count = p.grades[grade] ?? 0;
              if (count == 0) return const SizedBox.shrink();
              final maxCount = p.grades.values.isEmpty
                  ? 1
                  : p.grades.values.reduce((a, b) => a > b ? a : b);
              final barWidth = maxCount > 0 ? count / maxCount : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      child: Text(
                        grade,
                        style: unbounded(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                    Expanded(
                      child: _GradientProgressBar(
                        value: barWidth,
                        height: 24,
                        borderRadius: 6,
                        colors: gradientForGrade(grade),
                      ),
                    ),
                    if (count > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.arrow_upward,
                          size: 18,
                          color: gradientForGrade(grade).first,
                        ),
                      ),
                    Text(
                      '$count',
                      style: unbounded(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ],
                ),
              );
            },
            childCount: _orderedGrades.length,
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 32)),
    ];
  }

  List<Widget> _buildRouteCharts(BuildContext context) {
    final dailyStats = _statisticsDaily;
    final weeklyStats = _statisticsWeekly;
    final hasDailyData = dailyStats != null && dailyStats.routes.any((r) => r > 0);
    final hasWeeklyData = weeklyStats != null && weeklyStats.routes.any((r) => r > 0);
    final hasGradesData = weeklyStats != null &&
        weeklyStats.gradesBreakdown.isNotEmpty &&
        weeklyStats.gradesBreakdown.any((e) => e.value > 0);

    if (!hasDailyData && !hasWeeklyData && !hasGradesData) return [];

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text(
            'Графики тренировок',
            style: unbounded(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
      if (hasDailyData)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Трассы по дням (14 дней)',
                  style: unbounded(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white70),
                ),
                const SizedBox(height: 12),
                _buildBarChart(dailyStats!),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      if (hasWeeklyData)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Трассы по неделям',
                  style: unbounded(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white70),
                ),
                const SizedBox(height: 12),
                _buildBarChart(weeklyStats!),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      if (hasGradesData)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Распределение по грейдам',
                  style: unbounded(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white70),
                ),
                const SizedBox(height: 12),
                _buildGradesPieChart(weeklyStats!),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
    ];
  }

  static Color _barColor(int index) {
    final colors = [
      const Color(0xFF3B82F6),
      const Color(0xFF8B5CF6),
      const Color(0xFFD946EF),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFF06B6D4),
      const Color(0xFF6366F1),
      const Color(0xFF14B8A6),
    ];
    return colors[index % colors.length];
  }

  Widget _buildBarChart(ClimbingLogStatistics stats) {
    final routes = stats.routes;
    final labels = stats.labels;
    final maxY = routes.isEmpty
        ? 5.0
        : (routes.reduce((a, b) => a > b ? a : b).toDouble() * 1.2).clamp(5.0, double.infinity);

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i >= 0 && i < labels.length) {
                    final showEvery = labels.length > 12 ? 2 : 1;
                    if (i % showEvery != 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        labels[i],
                        style: const TextStyle(fontSize: 10, color: Colors.white54),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10, color: Colors.white54),
                ),
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 5,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.white.withOpacity(0.08),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: routes.asMap().entries.map((e) {
            final val = e.value.toDouble();
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: val,
                  color: _barColor(e.key),
                  width: 16,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxY,
                    color: Colors.white.withOpacity(0.04),
                  ),
                ),
              ],
              showingTooltipIndicators: [],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildGradesPieChart(ClimbingLogStatistics stats) {
    final breakdown = stats.gradesBreakdown.where((e) => e.value > 0).toList();
    if (breakdown.isEmpty) return const SizedBox.shrink();
    final total = breakdown.fold(0, (a, e) => a + e.value);
    if (total == 0) return const SizedBox.shrink();

    final sections = breakdown.map((e) {
      final count = e.value;
      return PieChartSectionData(
        value: count.toDouble(),
        title: '',
        color: gradientForGrade(e.key).first,
        radius: 52,
      );
    }).toList();

    return SizedBox(
      height: 220,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 160,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 2,
                  centerSpaceRadius: 32,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: breakdown.map((e) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: gradientForGrade(e.key).first,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${e.key}: ${e.value}',
                      style: unbounded(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Прогресс-бар с градиентной заливкой.
class _GradientProgressBar extends StatelessWidget {
  final double value;
  final double height;
  final double borderRadius;
  final List<Color> colors;

  const _GradientProgressBar({
    required this.value,
    required this.height,
    required this.borderRadius,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Container(
                width: constraints.maxWidth,
                height: height,
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
              ),
              FractionallySizedBox(
                widthFactor: value.clamp(0.0, 1.0),
                child: Container(
                  height: height,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: colors,
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class FractionallySizedBox extends StatelessWidget {
  final double widthFactor;
  final Widget child;

  const FractionallySizedBox({
    super.key,
    required this.widthFactor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth * widthFactor;
        return SizedBox(
          width: width,
          child: child,
        );
      },
    );
  }
}
