import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/models/StrengthMeasurementSession.dart';
import 'package:login_app/services/StrengthTestApiService.dart';
import 'package:login_app/services/StrengthHistoryService.dart';

/// Страница «Наши замеры» — список замеров + график прогресса.
class StrengthMeasurementsScreen extends StatefulWidget {
  const StrengthMeasurementsScreen({super.key});

  @override
  State<StrengthMeasurementsScreen> createState() =>
      _StrengthMeasurementsScreenState();
}

class _StrengthMeasurementsScreenState extends State<StrengthMeasurementsScreen> {
  List<StrengthMeasurementSession> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    var list = await StrengthTestApiService().getStrengthTestsHistory(periodDays: 365);
    if (list.isEmpty) {
      list = await StrengthHistoryService().getHistory();
    }
    list = List.from(list)..sort((a, b) => b.date.compareTo(a.date));
    if (list.length > 30) {
      list = list.sublist(0, 30);
    }
    if (mounted) {
      setState(() {
        _sessions = list;
        _loading = false;
      });
    }
  }

  bool _metricHasEnoughPoints(
    List<StrengthMeasurementSession> s,
    double? Function(StrengthMeasurementSession) get, {
    bool allowZero = false,
  }) {
    if (allowZero) {
      return s.map((x) => get(x)).where((v) => v != null).length >= 2;
    }
    return s.map((x) => get(x)).where((v) => v != null && v > 0).length >= 2;
  }

  bool _hasFingerData(List<StrengthMeasurementSession> s) =>
      s.any((x) => x.metrics.fingerBestPct != null && x.metrics.fingerBestPct! > 0);
  bool _hasPinchData(List<StrengthMeasurementSession> s) =>
      s.any((x) => x.metrics.pinchPct != null && x.metrics.pinchPct! > 0);
  bool _hasPullData(List<StrengthMeasurementSession> s) =>
      s.any((x) => x.metrics.pull1RmPct != null && x.metrics.pull1RmPct! > 0);
  bool _hasLockOffData(List<StrengthMeasurementSession> s) =>
      s.any((x) => x.metrics.lockOffSec != null && x.metrics.lockOffSec! > 0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.anthracite,
      appBar: AppBar(
        backgroundColor: AppColors.anthracite,
        title: Text(
          'Наши замеры',
          style: unbounded(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.mutedGold,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.mutedGold),
              )
            : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // График прогресса
                  ..._buildProgressCharts(),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // Список замеров
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'История',
                        style: unbounded(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  if (_sessions.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.fitness_center_outlined,
                                size: 64,
                                color: Colors.white24,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Пока пусто',
                                style: unbounded(
                                  fontSize: 16,
                                  color: Colors.white54,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Добавь первый замер в разделе «Замеры»',
                                style: unbounded(
                                  fontSize: 13,
                                  color: Colors.white38,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final s = _sessions[index];
                            return _buildSessionCard(s);
                          },
                          childCount: _sessions.length,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  List<Widget> _buildProgressCharts() {
    final sessions = _sessions;
    final hasCharts = sessions.isNotEmpty &&
        (_metricHasEnoughPoints(sessions, (x) => x.metrics.fingerBestPct) ||
            _metricHasEnoughPoints(sessions, (x) => x.metrics.pinchPct) ||
            _metricHasEnoughPoints(sessions, (x) => x.metrics.pull1RmPct) ||
            _metricHasEnoughPoints(sessions, (x) => x.metrics.lockOffSec?.toDouble(), allowZero: true));

    final labels = sessions.map((s) {
      if (s.date.length >= 10) {
        return '${s.date.substring(8, 10)}.${s.date.substring(5, 7)}';
      }
      return s.date;
    }).toList();

    if (!hasCharts) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.graphite),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fitness_center, size: 48, color: AppColors.mutedGold.withOpacity(0.5)),
                  const SizedBox(height: 12),
                  Text(
                    'Пройди тест силы хотя бы дважды,\nчтобы увидеть прогресс',
                    textAlign: TextAlign.center,
                    style: unbounded(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Text(
            'Прогресс по замерам',
            style: unbounded(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_hasFingerData(sessions))
                _buildStrengthChart(
                  'Пальцы (% от веса)',
                  sessions.map((s) => s.metrics.fingerBestPct?.toDouble()).toList(),
                  labels,
                  AppColors.mutedGold,
                ),
              if (_hasPinchData(sessions))
                _buildStrengthChart(
                  'Щипок (% от веса)',
                  sessions.map((s) => s.metrics.pinchPct?.toDouble()).toList(),
                  labels,
                  AppColors.successMuted,
                ),
              if (_hasPullData(sessions))
                _buildStrengthChart(
                  'Тяга (1RM % от веса)',
                  sessions.map((s) => s.metrics.pull1RmPct?.toDouble()).toList(),
                  labels,
                  const Color(0xFF8B5CF6),
                ),
              if (_hasLockOffData(sessions))
                _buildStrengthChart(
                  'Lock-off (сек)',
                  sessions.map((s) => (s.metrics.lockOffSec ?? 0).toDouble()).toList(),
                  labels,
                  const Color(0xFF3B82F6),
                ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildStrengthChart(
    String title,
    List<double?> values,
    List<String> labels,
    Color color,
  ) {
    final spots = <FlSpot>[];
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v != null && v > 0) {
        spots.add(FlSpot(i.toDouble(), v));
      }
    }
    if (spots.length < 2) return const SizedBox.shrink();

    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.15;
    final minY = (spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) * 0.85).clamp(0.0, double.infinity);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.graphite),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: unbounded(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (labels.length - 1).toDouble(),
                  minY: minY,
                  maxY: maxY,
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => AppColors.cardDark,
                      tooltipRoundedRadius: 8,
                      getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
                        final i = s.x.toInt();
                        final label = i >= 0 && i < labels.length ? labels[i] : '';
                        return LineTooltipItem(
                          '${s.y.toStringAsFixed(1)}\n$label',
                          unbounded(fontSize: 12, color: Colors.white),
                        );
                      }).toList(),
                    ),
                    handleBuiltInTouches: true,
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (v, meta) {
                          final i = v.toInt();
                          if (i >= 0 && i < labels.length) {
                            final step = labels.length > 10 ? 2 : 1;
                            if (i % step != 0) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                labels[i],
                                style: unbounded(fontSize: 9, color: Colors.white54),
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
                        reservedSize: 28,
                        getTitlesWidget: (v, meta) => Text(
                          v.toInt().toString(),
                          style: unbounded(fontSize: 10, color: Colors.white54),
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(color: Colors.white.withOpacity(0.08), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: color,
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: spots.length <= 12,
                        getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                          radius: 3,
                          color: color,
                          strokeWidth: 0,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withOpacity(0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSession(StrengthMeasurementSession s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Удалить замер?',
          style: unbounded(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Замер от ${s.dateFormatted} будет удалён. Это действие нельзя отменить.',
          style: unbounded(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Отмена', style: unbounded(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Удалить', style: unbounded(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    if (s.id != null) {
      await StrengthTestApiService().deleteStrengthTest(id: s.id);
    } else {
      await StrengthTestApiService().deleteStrengthTest(date: s.date);
    }
    await StrengthHistoryService().deleteSessionByDate(s.date);
    if (mounted) {
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Замер удалён'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.successMuted,
        ),
      );
    }
  }

  Widget _buildSessionCard(StrengthMeasurementSession s) {
    final m = s.metrics;
    final parts = <String>[];
    if (m.bodyWeightKg != null && m.bodyWeightKg! > 0) {
      parts.add('Вес: ${m.bodyWeightKg!.toStringAsFixed(1)} кг');
    }
    if (m.fingerLeftKg != null || m.fingerRightKg != null) {
      parts.add('Пальцы: Л ${m.fingerLeftKg?.toStringAsFixed(1) ?? '—'} / П ${m.fingerRightKg?.toStringAsFixed(1) ?? '—'} кг');
    }
    if (m.pinch40Kg != null || m.pinch60Kg != null || m.pinch80Kg != null) {
      final p = <String>[];
      if (m.pinch40Kg != null) p.add('40: ${m.pinch40Kg!.toStringAsFixed(1)}');
      if (m.pinch60Kg != null) p.add('60: ${m.pinch60Kg!.toStringAsFixed(1)}');
      if (m.pinch80Kg != null) p.add('80: ${m.pinch80Kg!.toStringAsFixed(1)}');
      parts.add('Щипок: ${p.join(' / ')} кг');
    }
    if (m.pullAddedKg != null) parts.add('Тяга: +${m.pullAddedKg!.toStringAsFixed(1)} кг');
    if (m.lockOffSec != null && m.lockOffSec! > 0) parts.add('Lock-off: ${m.lockOffSec} сек');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.graphite),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, color: AppColors.linkMuted, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.dateFormatted,
                  style: unbounded(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, size: 20, color: Colors.white38),
                onPressed: () => _deleteSession(s),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
          if (parts.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: parts
                  .map((p) => Text(
                        p,
                        style: unbounded(fontSize: 13, color: Colors.white70),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
