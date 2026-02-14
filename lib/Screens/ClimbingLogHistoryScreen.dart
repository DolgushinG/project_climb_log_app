import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/models/ClimbingLog.dart';
import 'package:login_app/models/StrengthMeasurementSession.dart';
import 'package:login_app/utils/climbing_log_colors.dart';
import 'package:login_app/Screens/ClimbingLogAddScreen.dart';
import 'package:login_app/Screens/StrengthHistoryScreen.dart';
import 'package:login_app/services/ClimbingLogService.dart';
import 'package:login_app/services/StrengthTestApiService.dart';
import 'package:login_app/services/StrengthHistoryService.dart';

/// Объединённая история: тренировки (лазание), замеры, выполнение упражнений.
class ClimbingLogHistoryScreen extends StatefulWidget {
  const ClimbingLogHistoryScreen({super.key});

  @override
  State<ClimbingLogHistoryScreen> createState() =>
      _ClimbingLogHistoryScreenState();
}

enum _HistoryFilter { all, climbing, measurements, exercises }

class _HistoryDay {
  final String date;
  HistorySession? climbing;
  StrengthMeasurementSession? measurement;
  final List<ExerciseCompletion> completions = [];

  _HistoryDay({required this.date, this.climbing, this.measurement});
}

class _ClimbingLogHistoryScreenState extends State<ClimbingLogHistoryScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final ClimbingLogService _climbingService = ClimbingLogService();
  final StrengthTestApiService _strengthApi = StrengthTestApiService();

  List<_HistoryDay> _days = [];
  bool _loading = true;
  String? _error;
  _HistoryFilter _filter = _HistoryFilter.all;

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
        _climbingService.getHistory(),
        _strengthApi.getStrengthTestsHistory(periodDays: 365),
        _strengthApi.getExerciseCompletions(periodDays: 365),
      ]);
      final climbing = results[0] as List<HistorySession>;
      var measurements = results[1] as List<StrengthMeasurementSession>;
      final completions = results[2] as List<ExerciseCompletion>;

      if (measurements.isEmpty) {
        final local = await StrengthHistoryService().getHistory();
        measurements = local;
      }
      measurements = List.from(measurements)..sort((a, b) => b.date.compareTo(a.date));

      final Map<String, _HistoryDay> byDate = {};
      for (final s in climbing) {
        byDate.putIfAbsent(s.date, () => _HistoryDay(date: s.date)).climbing = s;
      }
      for (final m in measurements) {
        byDate.putIfAbsent(m.date, () => _HistoryDay(date: m.date)).measurement = m;
      }
      for (final c in completions) {
        final d = byDate.putIfAbsent(c.date, () => _HistoryDay(date: c.date));
        d.completions.add(c);
      }

      final days = byDate.values.toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      if (mounted) {
        setState(() {
          _days = days;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Ошибка загрузки';
        });
      }
    }
  }

  List<_HistoryDay> get _filteredDays {
    if (_filter == _HistoryFilter.all) return _days;
    return _days.where((d) {
      switch (_filter) {
        case _HistoryFilter.climbing:
          return d.climbing != null;
        case _HistoryFilter.measurements:
          return d.measurement != null;
        case _HistoryFilter.exercises:
          return d.completions.isNotEmpty;
        default:
          return true;
      }
    }).toList();
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.tryParse(dateStr);
      if (dt != null) return DateFormat('dd.MM.yyyy').format(dt);
    } catch (_) {}
    return dateStr;
  }

  void _openEditClimbing(HistorySession session) {
    if (session.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Редактирование пока недоступно. Обновите приложение после обновления бэкенда.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClimbingLogAddScreen(
          session: session,
          onSaved: _load,
        ),
      ),
    );
  }

  Future<void> _deleteClimbing(HistorySession session) async {
    if (session.id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: Text('Удалить тренировку?', style: GoogleFonts.unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
        content: Text(
          'Тренировка ${_formatDate(session.date)}${session.gymName != 'Не указан' ? ' (${session.gymName})' : ''} будет удалена.',
          style: GoogleFonts.unbounded(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Отмена', style: GoogleFonts.unbounded(color: AppColors.mutedGold))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Удалить', style: GoogleFonts.unbounded(color: Colors.redAccent, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final ok = await _climbingService.deleteSession(session.id!);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Тренировка удалена'), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.mutedGold));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final filtered = _filteredDays;

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
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Text(
                    'История',
                    style: GoogleFonts.unbounded(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _filterChip('Всё', _filter == _HistoryFilter.all, () => setState(() => _filter = _HistoryFilter.all)),
                      _filterChip('Лазание', _filter == _HistoryFilter.climbing, () => setState(() => _filter = _HistoryFilter.climbing)),
                      _filterChip('Замеры', _filter == _HistoryFilter.measurements, () => setState(() => _filter = _HistoryFilter.measurements)),
                      _filterChip('ОФП/СФП', _filter == _HistoryFilter.exercises, () => setState(() => _filter = _HistoryFilter.exercises)),
                    ],
                  ),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.mutedGold)))
              else if (_error != null)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center, style: GoogleFonts.unbounded(color: Colors.white70)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _load,
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.mutedGold, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            child: Text('Повторить', style: GoogleFonts.unbounded(fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (filtered.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.white24),
                        const SizedBox(height: 16),
                        Text(
                          _filter == _HistoryFilter.all ? 'Пока нет записей' : 'Нет записей по выбранному фильтру',
                          style: GoogleFonts.unbounded(color: Colors.white70, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Добавляйте тренировки, делайте замеры, выполняйте ОФП/СФП',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.unbounded(color: Colors.white54, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _DayCard(
                        day: filtered[index],
                        formatDate: _formatDate,
                        onEditClimbing: _openEditClimbing,
                        onDeleteClimbing: _deleteClimbing,
                        onOpenMeasurements: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StrengthHistoryScreen())).then((_) => _load()),
                      ),
                      childCount: filtered.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label, style: GoogleFonts.unbounded(fontSize: 13)),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.mutedGold.withOpacity(0.4),
      backgroundColor: AppColors.rowAlt,
      checkmarkColor: AppColors.mutedGold,
      labelStyle: TextStyle(color: selected ? AppColors.mutedGold : Colors.white70),
    );
  }
}

class _DayCard extends StatelessWidget {
  final _HistoryDay day;
  final String Function(String) formatDate;
  final void Function(HistorySession) onEditClimbing;
  final void Function(HistorySession) onDeleteClimbing;
  final VoidCallback onOpenMeasurements;

  const _DayCard({
    required this.day,
    required this.formatDate,
    required this.onEditClimbing,
    required this.onDeleteClimbing,
    required this.onOpenMeasurements,
  });

  @override
  Widget build(BuildContext context) {
    final hasClimbing = day.climbing != null;
    final hasMeasurement = day.measurement != null;
    final hasCompletions = day.completions.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.graphite),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 18, color: AppColors.mutedGold),
                const SizedBox(width: 8),
                Text(
                  formatDate(day.date),
                  style: GoogleFonts.unbounded(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ],
            ),
          ),
          if (hasClimbing) _buildClimbingSection(context),
          if (hasClimbing && (hasMeasurement || hasCompletions))
            Divider(height: 1, color: AppColors.graphite, indent: 14, endIndent: 14),
          if (hasMeasurement) _buildMeasurementSection(context),
          if (hasMeasurement && hasCompletions)
            Divider(height: 1, color: AppColors.graphite, indent: 14, endIndent: 14),
          if (hasCompletions) _buildCompletionsSection(context),
        ],
      ),
    );
  }

  Widget _buildClimbingSection(BuildContext context) {
    final s = day.climbing!;
    final totalCount = s.routes.fold(0, (a, r) => a + r.count);
    final canEditDelete = s.id != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.route, size: 18, color: AppColors.mutedGold),
              const SizedBox(width: 8),
              Text('Лазание', style: GoogleFonts.unbounded(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.mutedGold)),
              const Spacer(),
              if (canEditDelete)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => onEditClimbing(s), style: IconButton.styleFrom(foregroundColor: AppColors.mutedGold, padding: const EdgeInsets.all(4), minimumSize: const Size(32, 32))),
                    IconButton(icon: const Icon(Icons.delete_outline, size: 18), onPressed: () => onDeleteClimbing(s), style: IconButton.styleFrom(foregroundColor: Colors.red.withOpacity(0.8), padding: const EdgeInsets.all(4), minimumSize: const Size(32, 32))),
                  ],
                ),
            ],
          ),
          if (s.gymName.isNotEmpty && s.gymName != 'Не указан')
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                Icon(Icons.place, size: 14, color: Colors.white54),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(s.gymName, style: GoogleFonts.unbounded(fontSize: 13, color: Colors.white70), overflow: TextOverflow.ellipsis, maxLines: 1),
                ),
              ]),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: s.routes.map((r) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradientForGrade(r.grade).map((c) => c.withOpacity(0.4)).toList(), begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: gradientForGrade(r.grade).first.withOpacity(0.5)),
              ),
              child: Text('${r.grade} × ${r.count}', style: GoogleFonts.unbounded(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
            )).toList(),
          ),
          Text('Всего: $totalCount трасс', style: GoogleFonts.unbounded(fontSize: 11, color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _buildMeasurementSection(BuildContext context) {
    final m = day.measurement!.metrics;
    final parts = <String>[];
    if (m.bodyWeightKg != null && m.bodyWeightKg! > 0) parts.add('Вес: ${m.bodyWeightKg!.toStringAsFixed(1)} кг');
    if (m.fingerLeftKg != null || m.fingerRightKg != null) parts.add('Пальцы: Л ${m.fingerLeftKg?.toStringAsFixed(1) ?? '—'} / П ${m.fingerRightKg?.toStringAsFixed(1) ?? '—'} кг');
    if (m.pinchKg != null) parts.add('Щипок: ${m.pinchKg!.toStringAsFixed(1)} кг');
    if (m.pullAddedKg != null) parts.add('Тяга: +${m.pullAddedKg!.toStringAsFixed(1)} кг');
    if (m.lockOffSec != null && m.lockOffSec! > 0) parts.add('Lock-off: ${m.lockOffSec} сек');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onOpenMeasurements,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Icon(Icons.fitness_center, size: 18, color: AppColors.linkMuted),
                const SizedBox(width: 8),
                Text('Замер', style: GoogleFonts.unbounded(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.linkMuted)),
                const Spacer(),
                Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.linkMuted),
              ],
            ),
          ),
          if (parts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                children: parts.map((p) => Text(p, style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white70))).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompletionsSection(BuildContext context) {
    final names = day.completions.map((c) => c.exerciseName ?? c.exerciseId).whereType<String>().toSet().take(3).toList();
    final count = day.completions.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline, size: 18, color: AppColors.successMuted),
              const SizedBox(width: 8),
              Text('ОФП/СФП', style: GoogleFonts.unbounded(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.successMuted)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$count ${count == 1 ? 'упражнение' : count >= 2 && count <= 4 ? 'упражнения' : 'упражнений'} выполнено',
            style: GoogleFonts.unbounded(fontSize: 13, color: Colors.white70),
          ),
          if (names.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(names.join(', '), style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white54), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
    );
  }
}
