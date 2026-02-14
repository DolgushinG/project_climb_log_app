import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/models/PlanModels.dart';
import 'package:login_app/models/ClimbingLog.dart';
import 'package:login_app/models/Workout.dart';
import 'package:login_app/services/TrainingPlanApiService.dart';
import 'package:login_app/services/ClimbingLogService.dart';
import 'package:login_app/Screens/ExerciseCompletionScreen.dart';
import 'package:login_app/Screens/ClimbingLogAddScreen.dart';

/// Экран плана на день: упражнения, растяжка, кнопка «Выполнено».
class PlanDayScreen extends StatefulWidget {
  final ActivePlan plan;
  final DateTime date;
  final VoidCallback? onCompletedChanged;
  /// Тип сессии из календаря (ofp/sfp), если известен — для понятного сообщения при ошибке.
  final String? expectedSessionType;

  const PlanDayScreen({
    super.key,
    required this.plan,
    required this.date,
    this.onCompletedChanged,
    this.expectedSessionType,
  });

  @override
  State<PlanDayScreen> createState() => _PlanDayScreenState();
}

class _PlanDayScreenState extends State<PlanDayScreen> {
  final TrainingPlanApiService _api = TrainingPlanApiService();
  final ClimbingLogService _climbingService = ClimbingLogService();

  PlanDayResponse? _day;
  HistorySession? _climbingSessionForDate;
  bool _loading = true;
  String? _error;

  int? _feeling;
  String? _focus;
  int? _availableMinutes;

  String get _dateStr =>
      '${widget.date.year}-${widget.date.month.toString().padLeft(2, '0')}-${widget.date.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PlanDayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date || oldWidget.plan.id != widget.plan.id) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final day = await _api.getPlanDay(
      widget.plan.id,
      _dateStr,
      feeling: _feeling,
      focus: _focus,
      availableMinutes: _availableMinutes,
    );
    HistorySession? climbing = null;
    if (day != null && !day.isRest && (day.expectsClimbing || widget.plan.includeClimbingInDays)) {
      climbing = await _climbingService.getSessionForDate(_dateStr);
    }
    if (mounted) {
      setState(() {
        _day = day;
        _climbingSessionForDate = climbing;
        _loading = false;
      });
    }
  }

  bool get _expectsClimbing =>
      _day != null &&
      !_day!.isRest &&
      (_day!.expectsClimbing || widget.plan.includeClimbingInDays);

  Future<void> _toggleComplete() async {
    if (_day == null) return;
    final sessionType = _day!.sessionType;
    if (sessionType == 'rest') return;

    if (_day!.completed) {
      final ok = await _api.uncompleteSession(
        planId: widget.plan.id,
        date: _dateStr,
        sessionType: sessionType,
      );
      if (mounted && ok) {
        await _load();
        widget.onCompletedChanged?.call();
      }
    } else {
      final ok = await _api.completeSession(
        planId: widget.plan.id,
        date: _dateStr,
        sessionType: sessionType,
        ofpDayIndex: _day!.ofpDayIndex,
      );
      if (mounted && ok) {
        await _load();
        widget.onCompletedChanged?.call();
      }
    }
  }

  static const _weekdays = ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];

  bool get _isToday {
    final n = DateTime.now();
    return widget.date.year == n.year &&
        widget.date.month == n.month &&
        widget.date.day == n.day;
  }

  Future<void> _showSessionQuickQuestions() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SessionQuickQuestionsSheet(
        initialFeeling: _feeling,
        initialFocus: _focus,
        initialMinutes: _availableMinutes,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _feeling = result['feeling'] as int?;
        _focus = result['focus'] as String?;
        _availableMinutes = result['available_minutes'] as int?;
      });
      await _load();
    }
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
          '${widget.date.day}.${widget.date.month.toString().padLeft(2, '0')}.${widget.date.year} • ${_weekdays[widget.date.weekday % 7]}',
          style: GoogleFonts.unbounded(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.route, color: AppColors.mutedGold),
            tooltip: 'Добавить лазание',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClimbingLogAddScreen(initialDate: widget.date),
                ),
              );
              if (mounted) _load();
            },
          ),
          if (_day != null && !_day!.isRest)
            IconButton(
              icon: Icon(
                _feeling != null || _focus != null || _availableMinutes != null
                    ? Icons.tune
                    : Icons.tune_outlined,
                color: AppColors.mutedGold,
              ),
              onPressed: _showSessionQuickQuestions,
            ),
        ],
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.mutedGold),
                  const SizedBox(height: 16),
                  Text('Загрузка...', style: GoogleFonts.unbounded(fontSize: 14, color: Colors.white54)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_day == null)
                    _buildNoDataState()
                  else ...[
                    _buildSessionTypeHeader(),
                    const SizedBox(height: 20),
                    if (_day!.isRest)
                      _buildRestDay()
                    else ...[
                      if (_expectsClimbing) ...[
                        _buildClimbingBlock(),
                        const SizedBox(height: 20),
                      ],
                      if (_isToday) _buildClarifyButton(),
                      if (_isToday) const SizedBox(height: 16),
                      _buildExercises(),
                      const SizedBox(height: 24),
                      _buildStretching(),
                    ],
                    const SizedBox(height: 32),
                    if (!_day!.isRest) _buildCompleteButton(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildNoDataState() {
    final typeLabel = widget.expectedSessionType == 'sfp'
        ? 'СФП (пальцы, фингерборд)'
        : widget.expectedSessionType == 'ofp'
            ? 'ОФП'
            : 'этот день';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.cloud_off_outlined, size: 48, color: Colors.white38),
          const SizedBox(height: 16),
          Text(
            'Данные по $typeLabel не загружены',
            style: GoogleFonts.unbounded(fontSize: 16, color: Colors.white54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Проверьте интернет или попробуйте позже. Возможно, бэкенд пока не отдаёт план по этому дню.',
            style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white38),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _load(),
            icon: const Icon(Icons.refresh, size: 20),
            label: const Text('Повторить'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.mutedGold,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTypeHeader() {
    final type = _day!.sessionType;
    String label;
    IconData icon;
    Color color;
    switch (type) {
      case 'ofp':
        label = 'ОФП';
        icon = Icons.fitness_center;
        color = AppColors.mutedGold;
        break;
      case 'sfp':
        label = 'СФП';
        icon = Icons.back_hand;
        color = AppColors.linkMuted;
        break;
      default:
        label = 'Отдых';
        icon = Icons.spa;
        color = AppColors.successMuted;
    }
    if (_day!.weekNumber != null) label += ' • Неделя ${_day!.weekNumber}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.unbounded(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
          if (_day!.completed)
            Icon(Icons.check_circle, color: AppColors.successMuted, size: 24),
        ],
      ),
    );
  }

  Widget _buildClarifyButton() {
    final hasParams = _feeling != null || _focus != null || _availableMinutes != null;
    return OutlinedButton.icon(
      onPressed: _showSessionQuickQuestions,
      icon: Icon(
        hasParams ? Icons.tune : Icons.tune_outlined,
        size: 20,
        color: AppColors.mutedGold,
      ),
      label: Text(
        hasParams ? 'Изменить настройки на сегодня' : 'Уточнить на сегодня',
        style: GoogleFonts.unbounded(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.mutedGold),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: AppColors.mutedGold.withOpacity(0.6)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Widget _buildClimbingBlock() {
    final hasSession = _climbingSessionForDate != null;
    final session = _climbingSessionForDate;
    final routesCount = session?.routes.fold<int>(0, (s, r) => s + r.count) ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasSession ? AppColors.successMuted.withOpacity(0.5) : AppColors.mutedGold.withOpacity(0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.route,
                color: hasSession ? AppColors.successMuted : AppColors.mutedGold,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '1. Лазание',
                      style: GoogleFonts.unbounded(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    Text(
                      hasSession
                          ? '${session!.gymName} • $routesCount трасс'
                          : '1–2 часа, затем ОФП',
                      style: GoogleFonts.unbounded(fontSize: 13, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              if (hasSession)
                Icon(Icons.check_circle, color: AppColors.successMuted, size: 24)
              else
                FilledButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClimbingLogAddScreen(initialDate: widget.date),
                      ),
                    );
                    if (mounted) _load();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.mutedGold,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: Text('Добавить', style: GoogleFonts.unbounded(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRestDay() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.graphite),
      ),
      child: Column(
        children: [
          Icon(Icons.spa, color: AppColors.successMuted, size: 48),
          const SizedBox(height: 12),
          Text(
            'День отдыха',
            style: GoogleFonts.unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Сделайте лёгкую растяжку и восстановитесь.',
            textAlign: TextAlign.center,
            style: GoogleFonts.unbounded(fontSize: 14, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildExercises() {
    if (_day!.exercises.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _expectsClimbing ? '2. Упражнения' : 'Упражнения',
          style: GoogleFonts.unbounded(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white54),
        ),
        const SizedBox(height: 12),
        ..._day!.exercises.asMap().entries.map((e) {
          final ex = e.value;
          return _buildExerciseCard(ex, e.key + 1);
        }),
      ],
    );
  }

  Widget _buildExerciseCard(PlanDayExercise ex, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.graphite),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.mutedGold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$index',
                  style: GoogleFonts.unbounded(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.mutedGold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ex.name,
                      style: GoogleFonts.unbounded(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ex.dosageDisplay,
                      style: GoogleFonts.unbounded(fontSize: 13, color: AppColors.mutedGold),
                    ),
                    if (ex.comment != null && ex.comment!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb_outline, size: 14, color: AppColors.mutedGold.withOpacity(0.8)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              ex.comment!,
                              style: GoogleFonts.unbounded(fontSize: 12, color: AppColors.mutedGold.withOpacity(0.9), height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (ex.hint != null && ex.hint!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _showHintModal(ex.name, ex.hint!),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.help_outline, size: 16, color: AppColors.linkMuted),
                              const SizedBox(width: 6),
                              Text(
                                'Как выполнять',
                                style: GoogleFonts.unbounded(fontSize: 12, color: AppColors.linkMuted, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showHintModal(String title, String hint) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: AppColors.graphite),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.help_outline, color: AppColors.mutedGold, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Как выполнять: $title',
                    style: GoogleFonts.unbounded(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Text(
                  hint,
                  style: GoogleFonts.unbounded(fontSize: 14, color: Colors.white70, height: 1.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStretching() {
    if (_day!.stretching.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Растяжка',
          style: GoogleFonts.unbounded(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white54),
        ),
        const SizedBox(height: 12),
        ..._day!.stretching.map((z) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardDark.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.graphite),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    z.zone,
                    style: GoogleFonts.unbounded(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  ...z.exercises.map((ex) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text('• $ex', style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white54)),
                      )),
                ],
              ),
            )),
      ],
    );
  }

  List<MapEntry<String, WorkoutBlockExercise>> _planDayToWorkoutEntries() {
    if (_day == null || _day!.exercises.isEmpty) return [];
    final sessionType = _day!.sessionType;
    final category = sessionType == 'sfp' ? 'sfp' : 'ofp';
    final blockKey = 'plan';
    return _day!.exercises.asMap().entries.map((e) {
      final ex = e.value;
      int? holdSeconds;
      dynamic defaultReps = ex.reps;
      if (ex.reps.contains('s') || ex.reps.contains('с') || ex.reps.contains('держ')) {
        final match = RegExp(r'(\d+)').firstMatch(ex.reps);
        if (match != null) holdSeconds = int.tryParse(match.group(1) ?? '');
      }
      if (holdSeconds == null) {
        defaultReps = int.tryParse(ex.reps) ?? ex.reps;
      }
      final w = WorkoutBlockExercise(
        exerciseId: ex.exerciseId ?? 'plan_${e.key}_${ex.name.hashCode.abs()}',
        name: ex.name,
        nameRu: ex.name,
        category: category,
        comment: ex.comment,
        hint: ex.hint,
        dosage: ex.dosage,
        defaultSets: ex.sets,
        defaultReps: defaultReps,
        holdSeconds: holdSeconds,
        defaultRestSeconds: 90,
      );
      return MapEntry(blockKey, w);
    }).toList();
  }

  Future<void> _openExerciseCompletion() async {
    if (_day == null || _day!.exercises.isEmpty) return;
    final entries = _planDayToWorkoutEntries();
    if (entries.isEmpty) return;
    final completed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseCompletionScreen(
          workoutExerciseEntries: entries,
          date: widget.date,
        ),
      ),
    );
    if (mounted && completed == true) {
      final ok = await _api.completeSession(
        planId: widget.plan.id,
        date: _dateStr,
        sessionType: _day!.sessionType,
        ofpDayIndex: _day!.ofpDayIndex,
      );
      if (ok) {
        await _load();
        widget.onCompletedChanged?.call();
      }
    }
  }

  Widget _buildCompleteButton() {
    final completed = _day!.completed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!completed && _day!.exercises.isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _openExerciseCompletion,
              icon: const Icon(Icons.play_arrow, size: 22),
              label: Text(
                'Начать выполнение',
                style: GoogleFonts.unbounded(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.mutedGold,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        if (!completed && _day!.exercises.isNotEmpty) const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _toggleComplete,
            icon: Icon(completed ? Icons.remove_circle_outline : Icons.check_circle_outline, size: 22),
            label: Text(
              completed ? 'Убрать отметку' : 'Отметить выполненным',
              style: GoogleFonts.unbounded(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: completed ? AppColors.graphite : AppColors.rowAlt,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}

class _SessionQuickQuestionsSheet extends StatefulWidget {
  final int? initialFeeling;
  final String? initialFocus;
  final int? initialMinutes;

  const _SessionQuickQuestionsSheet({
    this.initialFeeling,
    this.initialFocus,
    this.initialMinutes,
  });

  @override
  State<_SessionQuickQuestionsSheet> createState() => _SessionQuickQuestionsSheetState();
}

class _SessionQuickQuestionsSheetState extends State<_SessionQuickQuestionsSheet> {
  int? _feeling;
  String? _focus;
  int? _minutes;

  @override
  void initState() {
    super.initState();
    _feeling = widget.initialFeeling;
    _focus = widget.initialFocus;
    _minutes = widget.initialMinutes;
  }

  static const _focusOptions = [
    ('climbing', 'Лазание'),
    ('strength', 'Сила'),
    ('recovery', 'Восстановление'),
  ];
  static const _timeOptions = [30, 45, 60, 90];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Уточнить на сегодня',
            style: GoogleFonts.unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'План дня подстроится под самочувствие, фокус и время — упражнений станет меньше или легче.',
            style: GoogleFonts.unbounded(fontSize: 13, color: Colors.white54, height: 1.4),
          ),
          const SizedBox(height: 20),
          Text('Самочувствие (1–5)', style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (i) {
              final v = i + 1;
              final sel = _feeling == v;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    onTap: () => setState(() => _feeling = v),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.mutedGold.withOpacity(0.3) : AppColors.rowAlt,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '$v',
                          style: GoogleFonts.unbounded(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: sel ? AppColors.mutedGold : Colors.white54,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Text('Фокус', style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _focusOptions.map((e) {
              final sel = _focus == e.$1;
              return ChoiceChip(
                label: Text(e.$2, style: GoogleFonts.unbounded(fontSize: 12)),
                selected: sel,
                onSelected: (v) => setState(() => _focus = v ? e.$1 : null),
                selectedColor: AppColors.mutedGold.withOpacity(0.4),
                backgroundColor: AppColors.rowAlt,
                labelStyle: TextStyle(color: sel ? AppColors.mutedGold : Colors.white70),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text('Время (мин)', style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _timeOptions.map((m) {
              final sel = _minutes == m;
              return ChoiceChip(
                label: Text('$m', style: GoogleFonts.unbounded(fontSize: 12)),
                selected: sel,
                onSelected: (v) => setState(() => _minutes = v ? m : null),
                selectedColor: AppColors.mutedGold.withOpacity(0.4),
                backgroundColor: AppColors.rowAlt,
                labelStyle: TextStyle(color: sel ? AppColors.mutedGold : Colors.white70),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context, {'feeling': null, 'focus': null, 'available_minutes': null}),
                child: Text('Сбросить', style: GoogleFonts.unbounded(color: Colors.white54)),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.pop(context, {
                  'feeling': _feeling,
                  'focus': _focus,
                  'available_minutes': _minutes,
                }),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.mutedGold,
                  foregroundColor: Colors.white,
                ),
                child: Text('Применить', style: GoogleFonts.unbounded(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
