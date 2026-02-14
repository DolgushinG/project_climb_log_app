import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/models/PlanModels.dart';
import 'package:login_app/services/TrainingPlanApiService.dart';
import 'package:login_app/Screens/PlanDayScreen.dart';

/// Календарь плана: дни с типом сессии и отметками выполнения.
class PlanCalendarScreen extends StatefulWidget {
  final ActivePlan plan;
  final VoidCallback? onRefresh;

  const PlanCalendarScreen({super.key, required this.plan, this.onRefresh});

  @override
  State<PlanCalendarScreen> createState() => _PlanCalendarScreenState();
}

class _PlanCalendarScreenState extends State<PlanCalendarScreen> {
  final TrainingPlanApiService _api = TrainingPlanApiService();

  late DateTime _currentMonth;
  PlanCalendarResponse? _calendar;
  bool _loading = true;

  static const _weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    _load();
  }

  String get _monthParam =>
      '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() => _loading = true);
    final cal = await _api.getPlanCalendar(widget.plan.id, _monthParam);
    if (mounted) {
      setState(() {
        _calendar = cal;
        _loading = false;
      });
    }
  }

  CalendarDay? _dayFor(String date) {
    if (_calendar == null) return null;
    try {
      return _calendar!.days.firstWhere((d) => d.date == date);
    } catch (_) {
      return null;
    }
  }

  /// Определяем session_type: из API или вычисляем rest/ofp/sfp по scheduled_weekdays.
  /// Иконки (ОФП/СФП/отдых) показываем только для дат ВНУТРИ плана (start_date .. end_date).
  String? _sessionTypeFor(DateTime dt, CalendarDay? dayData) {
    if (!_isInPlanRange(dt)) return null;
    if (dayData?.sessionType != null) return dayData!.sessionType;
    final weekdays = widget.plan.scheduledWeekdays;
    if (weekdays == null || weekdays.isEmpty) return null;
    if (!weekdays.contains(dt.weekday)) return 'rest';
    return _inferTrainingSessionType(dt);
  }

  /// Fallback: когда API не вернул session_type для дня тренировки,
  /// считаем OFP/СФП по порядку дней (типично 2 ОФП, 1 СФП в неделю).
  String _inferTrainingSessionType(DateTime dt) {
    final start = _parseDate(widget.plan.startDate);
    final end = _parseDate(widget.plan.endDate);
    final weekdays = widget.plan.scheduledWeekdays!;
    int idx = 0;
    for (var d = DateTime(start.year, start.month, start.day);
        !d.isAfter(DateTime(end.year, end.month, end.day));
        d = d.add(const Duration(days: 1))) {
      if (weekdays.contains(d.weekday)) {
        if (d.year == dt.year && d.month == dt.month && d.day == dt.day) {
          break;
        }
        idx++;
      }
    }
    return (idx % 3 == 2) ? 'sfp' : 'ofp';
  }

  bool _isInPlanRange(DateTime dt) {
    final start = _parseDate(widget.plan.startDate);
    final end = _parseDate(widget.plan.endDate);
    final d = DateTime(dt.year, dt.month, dt.day);
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    return !d.isBefore(s) && !d.isAfter(e);
  }

  DateTime _parseDate(String s) {
    final p = s.split('-');
    if (p.length >= 3) {
      return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    }
    return DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.anthracite,
      appBar: AppBar(
        backgroundColor: AppColors.anthracite,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Календарь',
          style: GoogleFonts.unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                      });
                      _load();
                    },
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        _monthTitle(),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
                      });
                      _load();
                    },
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.mutedGold),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildWeekdayHeaders(),
                  const SizedBox(height: 8),
                  _buildCalendarGrid(),
                  const SizedBox(height: 16),
                  _buildLegend(),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  String _monthTitle() {
    const months = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
    ];
    return '${months[_currentMonth.month - 1]} ${_currentMonth.year}';
  }

  Widget _buildWeekdayHeaders() {
    return Row(
      children: _weekdays.map((w) => Expanded(
            child: Center(
              child: Text(
                w,
                style: GoogleFonts.unbounded(fontSize: 11, color: Colors.white38),
              ),
            ),
          )).toList(),
    );
  }

  Widget _buildCalendarGrid() {
    final first = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final last = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    // Пн=0, Вт=1, ..., Вс=6; Dart weekday: 1=Пн, 7=Вс
    final startOffset = first.weekday - 1;
    final daysInMonth = last.day;
    final totalCells = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: List.generate(rows, (row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: List.generate(7, (col) {
              final idx = row * 7 + col;
              if (idx < startOffset || idx >= startOffset + daysInMonth) {
                return const Expanded(child: SizedBox());
              }
              final day = idx - startOffset + 1;
              final dateStr =
                  '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
              final dayData = _dayFor(dateStr);
              final dt = DateTime(_currentMonth.year, _currentMonth.month, day);
              final isToday = _isToday(dt);
              final inRange = _isInPlanRange(dt);
              // completed только для дат не в будущем — бэкенд не должен помечать будущие как выполненные
              final completed = (dayData?.completed ?? false) && !_isFutureDate(dt);
              final sessionType = _sessionTypeFor(dt, dayData);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: inRange
                          ? () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PlanDayScreen(
                                    plan: widget.plan,
                                    date: dt,
                                    expectedSessionType: sessionType,
                                    onCompletedChanged: () {
                                      _load();
                                      widget.onRefresh?.call();
                                    },
                                  ),
                                ),
                              );
                              if (mounted) {
                                _load();
                                widget.onRefresh?.call();
                              }
                            }
                          : null,
                      borderRadius: BorderRadius.circular(10),
                        child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: _cellColor(inRange, completed, isToday, sessionType),
                          borderRadius: BorderRadius.circular(10),
                          border: isToday
                              ? Border.all(color: AppColors.mutedGold, width: 2)
                              : sessionType == 'rest'
                                  ? Border.all(color: AppColors.successMuted.withOpacity(0.6), width: 1)
                                  : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$day',
                              style: GoogleFonts.unbounded(
                                fontSize: 14,
                                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                                color: _textColor(inRange, isToday, sessionType),
                              ),
                            ),
                            if (sessionType != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    sessionType == 'ofp'
                                        ? Icons.fitness_center
                                        : sessionType == 'sfp'
                                            ? Icons.back_hand
                                            : Icons.spa,
                                    size: 12,
                                    color: sessionType == 'rest'
                                        ? AppColors.successMuted.withOpacity(0.8)
                                        : (completed ? AppColors.successMuted : AppColors.mutedGold.withOpacity(0.7)),
                                  ),
                                  if (sessionType != 'rest' && widget.plan.includeClimbingInDays) ...[
                                    const SizedBox(width: 2),
                                    Icon(
                                      Icons.route,
                                      size: 10,
                                      color: completed
                                          ? AppColors.successMuted.withOpacity(0.8)
                                          : AppColors.mutedGold.withOpacity(0.5),
                                    ),
                                  ],
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  bool _isFutureDate(DateTime d) {
    final n = DateTime.now();
    return d.year > n.year ||
        (d.year == n.year && d.month > n.month) ||
        (d.year == n.year && d.month == n.month && d.day > n.day);
  }

  Color _cellColor(bool inRange, bool completed, bool isToday, String? sessionType) {
    if (!inRange) return AppColors.rowAlt.withOpacity(0.3);
    if (sessionType == 'rest') return AppColors.successMuted.withOpacity(0.35);
    if (completed) return AppColors.successMuted.withOpacity(0.25);
    if (isToday) return AppColors.mutedGold.withOpacity(0.15);
    return AppColors.cardDark;
  }

  Color _textColor(bool inRange, bool isToday, String? sessionType) {
    if (!inRange) return Colors.white38;
    if (sessionType == 'rest') return AppColors.successMuted.withOpacity(0.9);
    if (isToday) return AppColors.mutedGold;
    return Colors.white70;
  }

  Widget _buildLegend() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: [
        _legendItem(Icons.fitness_center, 'ОФП'),
        _legendItem(Icons.back_hand, 'СФП'),
        _legendItem(Icons.spa, 'Отдых', color: AppColors.successMuted),
        if (widget.plan.includeClimbingInDays)
          _legendItem(Icons.route, 'Лазание', color: AppColors.mutedGold.withOpacity(0.6)),
      ],
    );
  }

  Widget _legendItem(IconData icon, String label, {Color? color}) {
    final c = color ?? AppColors.mutedGold.withOpacity(0.7);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.unbounded(fontSize: 11, color: Colors.white54),
        ),
      ],
    );
  }
}
