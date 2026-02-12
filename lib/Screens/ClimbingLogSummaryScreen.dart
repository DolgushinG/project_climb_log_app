import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:login_app/models/ClimbingLog.dart';
import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/services/ClimbingLogService.dart';
import 'package:login_app/utils/climbing_log_colors.dart';

/// Стартовый экран «Обзор» — summary, графики, рекомендации.
/// Использует API: summary, statistics, recommendations.
class ClimbingLogSummaryScreen extends StatefulWidget {
  const ClimbingLogSummaryScreen({super.key});

  @override
  State<ClimbingLogSummaryScreen> createState() =>
      _ClimbingLogSummaryScreenState();
}

class _ClimbingLogSummaryScreenState extends State<ClimbingLogSummaryScreen> {
  final ClimbingLogService _service = ClimbingLogService();
  ClimbingLogSummary? _summary;
  ClimbingLogStatistics? _statisticsDaily;
  ClimbingLogStatistics? _statisticsWeekly;
  List<ClimbingLogRecommendation> _recommendations = [];
  bool _loading = true;
  String? _error;

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
    try {
      final results = await Future.wait([
        _service.getSummary(),
        _service.getStatistics(groupBy: 'day', periodDays: 14),
        _service.getStatistics(groupBy: 'week', periodDays: 56),
        _service.getRecommendations(),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as ClimbingLogSummary?;
        _statisticsDaily = results[1] as ClimbingLogStatistics?;
        _statisticsWeekly = results[2] as ClimbingLogStatistics?;
        _recommendations = results[3] as List<ClimbingLogRecommendation>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Не удалось загрузить данные';
        });
      }
    }
  }

  String _dayWord(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'день';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) return 'дня';
    return 'дней';
  }

  @override
  Widget build(BuildContext context) {
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
                    'Обзор',
                    style: GoogleFonts.unbounded(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null || _summary == null)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.white24,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _error ?? 'Не удалось загрузить данные',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.unbounded(color: Colors.white70),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _load,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.mutedGold,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Повторить', style: GoogleFonts.unbounded(fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ..._buildContent(context),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildContent(BuildContext context) {
    final s = _summary;
    final dailyStats = _statisticsDaily;
    final weeklyStats = _statisticsWeekly;
    final sessionsCount = s?.totalSessions ?? 0;
    final hasDailyData = dailyStats != null && dailyStats.routes.any((r) => r > 0);
    final hasWeeklyData = weeklyStats != null && weeklyStats.routes.any((r) => r > 0);
    final hasGradesData = weeklyStats != null &&
        weeklyStats.gradesBreakdown.isNotEmpty &&
        weeklyStats.gradesBreakdown.any((e) => e.value > 0);

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sessionsCount == 0) ...[
                _buildEmptyState(context),
              ] else ...[
                _buildSummaryCards(context, s!),
                const SizedBox(height: 24),
                if (hasDailyData) ...[
                  _buildSectionTitle(context, 'Трассы по дням (14 дней)'),
                  const SizedBox(height: 12),
                  _buildBarChart(dailyStats),
                  const SizedBox(height: 24),
                ],
                if (hasWeeklyData) ...[
                  _buildSectionTitle(context, 'Трассы по неделям'),
                  const SizedBox(height: 12),
                  _buildBarChart(weeklyStats),
                  const SizedBox(height: 24),
                ],
                if (hasGradesData) ...[
                  _buildSectionTitle(context, 'Распределение по грейдам'),
                  const SizedBox(height: 12),
                  _buildGradesPieChart(weeklyStats!),
                  const SizedBox(height: 24),
                ],
                _buildSectionTitle(context, 'Рекомендации'),
                const SizedBox(height: 12),
                _buildRecommendations(_recommendations),
              ],
            ],
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 32)),
    ];
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.graphite,
            AppColors.anthracite,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.mutedGold.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.rocket_launch, size: 48, color: Colors.white70),
          const SizedBox(height: 16),
          Text(
            'Добро пожаловать в трекер тренировок',
            style: GoogleFonts.unbounded(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Добавьте первую тренировку во вкладке «Тренировка» — здесь появится сводка, графики и рекомендации.',
            style: GoogleFonts.unbounded(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, ClimbingLogSummary s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Тренировок',
                '${s.totalSessions}',
                Icons.fitness_center,
                const Color(0xFF3B82F6).withOpacity(0.2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Трасс всего',
                '${s.totalRoutes}',
                Icons.route,
                const Color(0xFF8B5CF6).withOpacity(0.2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Макс. грейд',
                s.maxGrade ?? '—',
                Icons.trending_up,
                const Color(0xFF10B981).withOpacity(0.2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Серия',
                s.currentStreak > 0
                    ? '${s.currentStreak} ${_dayWord(s.currentStreak)}'
                    : '—',
                Icons.local_fire_department,
                const Color(0xFFF59E0B).withOpacity(0.2),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.mutedGold, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.unbounded(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.unbounded(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: GoogleFonts.unbounded(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildBarChart(ClimbingLogStatistics stats) {
    final routes = stats.routes;
    final labels = stats.labels;
    final maxY = routes.isEmpty
        ? 5.0
        : (routes.reduce((a, b) => a > b ? a : b).toDouble() * 1.2)
            .clamp(5.0, double.infinity);

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
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white54,
                        ),
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
    final breakdown = stats.gradesBreakdown
        .where((e) => e.value > 0)
        .toList();
    if (breakdown.isEmpty) return const SizedBox.shrink();
    final total = breakdown.fold(0, (a, e) => a + e.value);
    if (total == 0) return const SizedBox.shrink();

    final sections = breakdown.map((e) {
      final grade = e.key;
      final count = e.value;
      final color = gradientForGrade(grade).first;
      return PieChartSectionData(
        value: count.toDouble(),
        title: '',
        color: color,
        radius: 52,
      );
    }).toList();

    return SizedBox(
      height: 220,
      child: Column(
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
                    style: GoogleFonts.unbounded(color: Colors.white70, fontSize: 12),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Color _barColor(int index) {
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

  Widget _buildRecommendations(List<ClimbingLogRecommendation> recs) {
    if (recs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.lightbulb_outline,
              size: 18,
              color: AppColors.mutedGold,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Добавьте первую тренировку в следующей вкладке',
                style: GoogleFonts.unbounded(color: Colors.white70, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: recs.map((r) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 18,
                color: AppColors.mutedGold,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  r.text,
                  style: GoogleFonts.unbounded(color: Colors.white70, fontSize: 14),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
