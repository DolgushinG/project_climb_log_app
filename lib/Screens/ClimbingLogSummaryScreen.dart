import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:login_app/models/ClimbingLog.dart';
import 'package:login_app/models/StrengthAchievement.dart';
import 'package:login_app/models/StrengthTier.dart';
import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/services/ClimbingLogService.dart';
import 'package:login_app/services/StrengthDashboardService.dart';
import 'package:login_app/services/TrainingPlanGenerator.dart';
import 'package:login_app/services/TrainingGamificationService.dart';
import 'package:login_app/services/StrengthTestApiService.dart';
import 'package:login_app/utils/climbing_log_colors.dart';
import 'package:login_app/Screens/ClimbingLogAddScreen.dart';
import 'package:login_app/Screens/ExerciseCompletionScreen.dart';

/// Стартовый экран «Обзор» — summary, графики, рекомендации, strength dashboard.
class ClimbingLogSummaryScreen extends StatefulWidget {
  const ClimbingLogSummaryScreen({super.key});

  @override
  State<ClimbingLogSummaryScreen> createState() =>
      _ClimbingLogSummaryScreenState();
}

class _ClimbingLogSummaryScreenState extends State<ClimbingLogSummaryScreen> {
  final ClimbingLogService _service = ClimbingLogService();
  final StrengthDashboardService _strengthSvc = StrengthDashboardService();
  final TrainingGamificationService _gamification = TrainingGamificationService();

  ClimbingLogSummary? _summary;
  ClimbingLogStatistics? _statisticsDaily;
  ClimbingLogStatistics? _statisticsWeekly;
  List<ClimbingLogRecommendation> _recommendations = [];
  bool _loading = true;
  String? _error;

  StrengthMetrics? _strengthMetrics;
  int _xp = 0;
  int _streak = 0;
  String _recoveryStatus = 'ready';

  @override
  void initState() {
    super.initState();
    _load();
    _loadStrengthDashboard();
  }

  Future<void> _loadStrengthDashboard() async {
    final m = await _strengthSvc.getLastMetrics();
    final api = StrengthTestApiService();
    final gamification = await api.getGamification();
    if (gamification != null && mounted) {
      setState(() {
        _strengthMetrics = m;
        _xp = gamification.totalXp;
        _streak = gamification.streakDays;
        _recoveryStatus = gamification.recoveryStatus;
      });
    } else {
      final xp = await _gamification.getTotalXp();
      final streak = await _gamification.getStreakDays();
      final recovery = await _gamification.getRecoveryStatus();
      if (mounted) {
        setState(() {
          _strengthMetrics = m;
          _xp = xp;
          _streak = streak;
          _recoveryStatus = recovery;
        });
      }
    }
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

  Future<void> _onRefresh() async {
    await _load();
    await _loadStrengthDashboard();
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
          onRefresh: _onRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Обзор',
                        style: GoogleFonts.unbounded(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (ctx) => const ClimbingLogAddScreen(),
                              ),
                            );
                            if (mounted) {
                              _load();
                              _loadStrengthDashboard();
                            }
                          },
                          icon: const Icon(Icons.add, size: 20),
                          label: Text(
                            'Добавить тренировку',
                            style: GoogleFonts.unbounded(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.mutedGold,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
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
      if (_strengthMetrics != null) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: _buildStrengthDashboard(context),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: _buildExerciseCompletionCard(context),
          ),
        ),
      ],
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

  Widget _buildStrengthDashboard(BuildContext context) {
    final m = _strengthMetrics!;
    final gen = TrainingPlanGenerator();
    final analysis = gen.analyzeWeakLink(m);
    final rank = _getRankFromMetrics(m);
    final avg = _getAvgFromMetrics(m);
    final next = rank?.nextTier;
    final gap = rank != null && avg != null && next != null
        ? (StrengthTierExt.minPctForTier(next) - avg)
        : null;
    final progressToNext = gap != null && gap > 0 && next != null && avg != null && rank != null
        ? ((avg! - StrengthTierExt.minPctForTier(rank)) /
                (StrengthTierExt.minPctForTier(next) - StrengthTierExt.minPctForTier(rank)))
            .clamp(0.0, 1.0)
        : null;

    String focusHint = 'Упор на щипок';
    if (analysis.pinchWeak && m.pinchKg != null && m.bodyWeightKg != null) {
      final target = m.bodyWeightKg! * 0.4;
      final needed = (target - m.pinchKg!).clamp(0.0, double.infinity);
      focusHint = 'Упор на щипок (+${needed.toStringAsFixed(1)} кг)';
    } else if (analysis.fingersWeak) {
      focusHint = 'Упор на висы (Max Hangs)';
    } else if (analysis.pullWeak) {
      focusHint = 'Упор на взрывные подтяги';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.mutedGold.withOpacity(0.15),
            AppColors.cardDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.mutedGold.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rank != null) ...[
            Text(
              'Цель: ${next != null ? "достичь ${next.titleRu}" : rank.titleRu}'
              '${progressToNext != null && next != null ? " — ${(progressToNext * 100).toStringAsFixed(0)}% готово" : ""}',
              style: GoogleFonts.unbounded(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
            const SizedBox(height: 8),
          ],
          Text(
            'Рекомендация: $focusHint',
            style: GoogleFonts.unbounded(
              fontSize: 13,
              color: AppColors.mutedGold,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                DefaultTabController.of(context).animateTo(3);
              },
              icon: const Icon(Icons.fitness_center, size: 18),
              label: Text(
                'Тренировка пальцев сегодня',
                style: GoogleFonts.unbounded(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.mutedGold,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                _recoveryStatus == 'optimal' ? Icons.check_circle : Icons.schedule,
                size: 18,
                color: _recoveryStatus == 'optimal'
                    ? AppColors.successMuted
                    : Colors.white54,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Восстановление: ${_gamification.recoveryStatusTextRu(_recoveryStatus)}',
                  style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Опыт: $_xp',
                style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white54),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Серия: $_streak ${_dayWord(_streak)}',
                  style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white54),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseCompletionCard(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExerciseCompletionScreen(metrics: _strengthMetrics),
            ),
          );
          _loadStrengthDashboard();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.graphite),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, color: AppColors.successMuted, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Выполнить упражнения',
                      style: GoogleFonts.unbounded(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Отмечай сделанное из плана',
                      style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }

  StrengthTier? _getRankFromMetrics(StrengthMetrics m) {
    final avg = _getAvgFromMetrics(m);
    if (avg == null) return null;
    return StrengthTierExt.fromAveragePct(avg);
  }

  double? _getAvgFromMetrics(StrengthMetrics m) {
    final bw = m.bodyWeightKg;
    if (bw == null || bw <= 0) return null;
    final list = <double>[];
    if (m.fingerBestPct != null) list.add(m.fingerBestPct!);
    if (m.pinchPct != null) list.add(m.pinchPct!);
    if (m.pull1RmPct != null) list.add(m.pull1RmPct!);
    if (m.lockOffSec != null && m.lockOffSec! > 0) {
      list.add((m.lockOffSec! / 30.0) * 100);
    }
    if (list.isEmpty) return null;
    return list.reduce((a, b) => a + b) / list.length;
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
