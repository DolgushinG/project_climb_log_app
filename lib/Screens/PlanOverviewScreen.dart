import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/models/PlanModels.dart';
import 'package:login_app/models/Workout.dart';
import 'package:login_app/services/TrainingPlanApiService.dart';
import 'package:login_app/services/StrengthTestApiService.dart';
import 'package:login_app/services/ClimbingLogService.dart';
import 'package:login_app/services/PremiumSubscriptionService.dart';
import 'package:login_app/Screens/PlanSelectionScreen.dart';
import 'package:login_app/Screens/ExerciseCompletionScreen.dart';
import 'package:login_app/Screens/PlanCalendarScreen.dart';
import 'package:login_app/Screens/PlanDayScreen.dart';
import 'package:login_app/Screens/ClimbingLogAddScreen.dart';
import 'package:login_app/services/PlanCompletionClearService.dart';

/// Обзор плана: при отсутствии — кнопка создания; при наличии — календарь и «Сегодня».
class PlanOverviewScreen extends StatefulWidget {
  final bool isTabVisible;
  final PremiumStatus? premiumStatus;
  final VoidCallback? onPremiumTap;

  const PlanOverviewScreen({
    super.key,
    this.isTabVisible = true,
    this.premiumStatus,
    this.onPremiumTap,
  });

  @override
  State<PlanOverviewScreen> createState() => _PlanOverviewScreenState();
}

class _PlanOverviewScreenState extends State<PlanOverviewScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final TrainingPlanApiService _api = TrainingPlanApiService();
  final ClimbingLogService _climbingService = ClimbingLogService();

  ActivePlan? _plan;
  PlanDayResponse? _todayPlanDay;
  int? _remainingExercises;
  bool? _hasClimbingForToday;
  bool _loading = true;
  bool _loadError = false;
  bool _wasVisible = false;
  /// Показать приветственную карточку после создания плана (детали и подсказки).
  bool _showPlanCreatedWelcome = false;

  @override
  void initState() {
    super.initState();
    _wasVisible = widget.isTabVisible;
    _load();
  }

  @override
  void didUpdateWidget(PlanOverviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTabVisible && !_wasVisible) {
      _wasVisible = true;
      _load();
    } else if (!widget.isTabVisible) {
      _wasVisible = false;
    }
  }

  Future<void> _load() async {
    final hadPlan = _plan != null;
    if (!hadPlan) setState(() => _loading = true);
    try {
      final plan = await _api.getActivePlan();
      if (mounted) {
        final planChanged = _plan?.id != plan?.id;
        setState(() {
          _plan = plan;
          _loading = false;
          _loadError = false;
          if (plan == null || planChanged) {
            _todayPlanDay = null;
            _remainingExercises = null;
            _hasClimbingForToday = null;
          }
        });
        if (plan != null) _loadPlanDayProgress();
      }
    } catch (_) {
      if (mounted) setState(() {
        _loading = false;
        _loadError = _plan == null;
      });
    }
  }

  bool _isTodayTrainingDay(ActivePlan plan) {
    final weekdays = plan.scheduledWeekdays;
    if (weekdays == null || weekdays.isEmpty) return true;
    final today = DateTime.now();
    return weekdays.contains(today.weekday);
  }

  Future<void> _loadPlanDayProgress() async {
    final plan = _plan;
    if (plan == null || !_isTodayTrainingDay(plan)) return;
    final today = DateTime.now();
    final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final day = await _api.getPlanDay(plan.id, dateStr);
    if (day == null || !mounted || _plan?.id != plan.id) return;
    if (day.isRest || day.exercises.isEmpty) {
      if (mounted) setState(() {
        _todayPlanDay = day;
        _remainingExercises = 0;
      });
      return;
    }
    if (day.completed) {
      bool? hasClimbing;
      if (plan.includeClimbingInDays) {
        final sess = await _climbingService.getSessionForDate(dateStr);
        hasClimbing = sess != null;
      }
      if (mounted && _plan?.id == plan.id) setState(() {
        _todayPlanDay = day;
        _remainingExercises = 0;
        _hasClimbingForToday = hasClimbing;
      });
      return;
    }
    final entries = _planDayToWorkoutEntries(day);
    final ids = entries.map((e) => e.value.exerciseId).toSet();
    final api = StrengthTestApiService();
    final completions = await api.getExerciseCompletions(date: dateStr);
    final completedIds = completions.map((c) => c.exerciseId).toSet();
    final completed = ids.where((id) => completedIds.contains(id)).length;
    bool? hasClimbing;
    if (plan.includeClimbingInDays && !day.isRest) {
      final sess = await _climbingService.getSessionForDate(dateStr);
      hasClimbing = sess != null;
    }
    if (mounted && _plan?.id == plan.id) {
      setState(() {
        _todayPlanDay = day;
        _remainingExercises = (ids.length - completed).clamp(0, ids.length);
        _hasClimbingForToday = hasClimbing;
      });
    }
  }

  List<MapEntry<String, WorkoutBlockExercise>> _planDayToWorkoutEntries(PlanDayResponse day) {
    if (day.exercises.isEmpty) return [];
    final sessionType = day.sessionType;
    final category = sessionType == 'sfp' ? 'sfp' : 'ofp';
    const blockKey = 'plan';
    return day.exercises.asMap().entries.map((e) {
      final ex = e.value;
      int? holdSeconds;
      dynamic defaultReps = ex.reps;
      if (ex.reps.contains('s') || ex.reps.contains('с') || ex.reps.contains('держ')) {
        final match = RegExp(r'(\d+)').firstMatch(ex.reps);
        if (match != null) holdSeconds = int.tryParse(match.group(1) ?? '');
      }
      if (holdSeconds == null) defaultReps = int.tryParse(ex.reps) ?? ex.reps;
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

  void _onPlanCreated(ActivePlan plan) {
    setState(() => _plan = plan);
  }

  Future<void> _clearAllData() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Очистить все данные',
          style: GoogleFonts.unbounded(color: Colors.white, fontSize: 18),
        ),
        content: Text(
          'Удалить план и все отметки на сервере, очистить локальный кэш. Как будто пришёл новый пользователь. Для тестирования.',
          style: GoogleFonts.unbounded(fontSize: 14, color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Отмена', style: GoogleFonts.unbounded(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.mutedGold),
            child: Text('Очистить', style: GoogleFonts.unbounded(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final result = await PlanCompletionClearService.clearAllAsNewUser();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Очищено: план=${result['planDeleted'] == 1 ? "да" : "нет"}, ${result['apiCompletions']} отметок, ${result['localKeys']} локальных ключей',
            style: GoogleFonts.unbounded(),
          ),
          backgroundColor: AppColors.mutedGold,
        ),
      );
      _load();
    }
  }

  DateTime? _findNextUpcomingSession(ActivePlan plan, DateTime today) {
    final end = _parseDate(plan.endDate);
    final weekdays = plan.scheduledWeekdays;
    for (var i = 1; i <= 14; i++) {
      final d = today.add(Duration(days: i));
      if (d.isAfter(end)) return null;
      if (weekdays == null || weekdays.isEmpty || weekdays.contains(d.weekday)) return d;
    }
    return null;
  }

  DateTime _parseDate(String s) {
    final p = s.split('-');
    if (p.length >= 3) return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    return DateTime.now();
  }

  Widget _buildUpcomingCard(DateTime date, ActivePlan plan) {
    final weekday = ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'][date.weekday % 7];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlanDayScreen(plan: plan, date: date, onCompletedChanged: _load),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.graphite),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.linkMuted.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.event_available, color: AppColors.linkMuted, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Следующая тренировка',
                      style: GoogleFonts.unbounded(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    Text(
                      '$weekday, ${date.day}.${date.month.toString().padLeft(2, '0')}.${date.year}',
                      style: GoogleFonts.unbounded(fontSize: 13, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPlanSelection({required bool planExists}) async {
    if (planExists) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Изменить план',
            style: GoogleFonts.unbounded(color: Colors.white, fontSize: 18),
          ),
          content: Text(
            'Текущий план будет заменён новым. Продолжить?',
            style: GoogleFonts.unbounded(fontSize: 14, color: Colors.white70, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Отмена', style: GoogleFonts.unbounded(color: Colors.white54)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.mutedGold),
              child: Text('Продолжить', style: GoogleFonts.unbounded(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    final result = await Navigator.push<ActivePlan>(
      context,
      MaterialPageRoute(
        builder: (_) => PlanSelectionScreen(onPlanCreated: _onPlanCreated),
      ),
    );
    if (result != null && mounted) {
      _onPlanCreated(result);
      setState(() => _showPlanCreatedWelcome = true);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.anthracite,
      appBar: AppBar(
        backgroundColor: AppColors.anthracite,
        automaticallyImplyLeading: false,
        title: Text(
          'План тренировок',
          style: GoogleFonts.unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        actions: [
          IconButton(
            onPressed: _clearAllData,
            icon: Icon(Icons.delete_sweep, size: 22, color: Colors.white54),
            tooltip: 'Очистить данные (тест)',
          ),
          if (_plan != null)
            TextButton.icon(
              onPressed: () => _openPlanSelection(planExists: true),
              icon: Icon(Icons.edit_outlined, size: 20, color: AppColors.mutedGold),
              label: Text(
                'Изменить',
                style: GoogleFonts.unbounded(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.mutedGold),
              ),
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
          : _loadError && _plan == null
              ? _buildLoadErrorState()
              : _plan == null
                  ? _buildNoPlanState()
                  : _buildPlanState(),
    );
  }

  Widget _buildLoadErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 64, color: Colors.white38),
            const SizedBox(height: 20),
            Text(
              'Не удалось загрузить план',
              style: GoogleFonts.unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Проверьте подключение к интернету и нажмите «Повторить»',
              style: GoogleFonts.unbounded(fontSize: 14, color: Colors.white54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                setState(() => _loading = true);
                _load();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.mutedGold,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoPlanState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.mutedGold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.mutedGold.withOpacity(0.4), width: 2),
              ),
              child: Icon(Icons.calendar_month_rounded, size: 48, color: AppColors.mutedGold),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Что такое план тренировок?',
            style: GoogleFonts.unbounded(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Персональное расписание ОФП и СФП под ваши цели',
            style: GoogleFonts.unbounded(fontSize: 14, color: Colors.white54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () => _openPlanSelection(planExists: false),
            icon: const Icon(Icons.add_rounded, size: 22),
            label: Text(
              'Создать план',
              style: GoogleFonts.unbounded(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.mutedGold,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
              shadowColor: AppColors.mutedGold.withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 32),
          _buildInfoCard(
            'Расписание на недели',
            'Вы получаете готовое расписание ОФП и СФП: в какие дни тренироваться, какие упражнения делать, сколько подходов и повторений.',
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            'Как это работает',
            'Выберите аудиторию (новичок/продолжающий) и шаблон. План создаётся под вас. «Сегодня» — начать или продолжить тренировку. «Следующая» — просмотр грядущей сессии.',
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            'Продолжить тренировку',
            'Если вы начали, но не закончили — карточка «Сегодня» превратится в «Продолжить тренировку». Отмечаете подходы, возвращаетесь. Прогресс сохраняется.',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String text) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.graphite),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.unbounded(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.mutedGold),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: GoogleFonts.unbounded(fontSize: 13, color: Colors.white70, height: 1.5),
          ),
        ],
      ),
    );
  }

  String _dayWord(int n) {
    if (n == 1) return 'день';
    if (n >= 2 && n <= 4) return 'дня';
    return 'дней';
  }

  Widget _buildPlanCreatedWelcomeCard(ActivePlan plan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.mutedGold.withOpacity(0.2),
            AppColors.mutedGold.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.mutedGold.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: AppColors.mutedGold.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.mutedGold.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.check_circle, color: AppColors.mutedGold, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'План успешно создан!',
                      style: GoogleFonts.unbounded(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${plan.startDate} — ${plan.endDate} • ${plan.scheduledWeekdaysDisplay.isNotEmpty ? plan.scheduledWeekdaysDisplay : "Любые дни"}',
                      style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white70),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _showPlanCreatedWelcome = false),
                icon: Icon(Icons.close, color: Colors.white54, size: 22),
                tooltip: 'Закрыть',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Что делать дальше:',
            style: GoogleFonts.unbounded(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedGold,
            ),
          ),
          const SizedBox(height: 12),
          _buildWelcomeTip(Icons.today, 'Сегодня', 'Нажмите, чтобы начать первую тренировку или посмотреть упражнения дня.'),
          const SizedBox(height: 8),
          _buildWelcomeTip(Icons.tune, 'Изменение тренировки', 'При открытии дня можно менять план под себя: самочувствие, фокус, доступное время — через кнопку «Уточнить на сегодня» или иконку настроек в шапке экрана.'),
          const SizedBox(height: 8),
          _buildWelcomeTip(Icons.event_available, 'Следующая тренировка', 'Смотрите расписание грядущих сессий и переходите к нужной дате.'),
          const SizedBox(height: 8),
          _buildWelcomeTip(Icons.calendar_month, 'Календарь', 'Обзор всего плана по неделям: ОФП, СФП, дни отдыха.'),
          const SizedBox(height: 8),
          _buildWelcomeTip(Icons.route, 'Добавить лазание', 'Фиксируйте сессии на стене — они учитываются в плане.'),
        ],
      ),
    );
  }

  Widget _buildWelcomeTip(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.mutedGold.withOpacity(0.9)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.unbounded(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              Text(
                description,
                style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white60, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlanState() {
    final plan = _plan!;
    final today = DateTime.now();
    final upcoming = _findNextUpcomingSession(plan, today);
    final status = widget.premiumStatus;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_showPlanCreatedWelcome) _buildPlanCreatedWelcomeCard(plan),
          if (status?.trialEndsIn3OrLess == true && widget.onPremiumTap != null) ...[
            GestureDetector(
              onTap: widget.onPremiumTap,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.mutedGold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.mutedGold.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule, color: AppColors.mutedGold, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Пробный период заканчивается через ${status!.trialDaysLeft} ${_dayWord(status.trialDaysLeft)}. Оформить подписку →',
                        style: GoogleFonts.unbounded(fontSize: 13, color: Colors.white, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_todayPlanDay != null) ...[
            _buildCoachCard(_todayPlanDay!),
            const SizedBox(height: 20),
          ],
          _buildTodayCard(today, plan),
          const SizedBox(height: 12),
          _buildAddClimbingRow(),
          if (upcoming != null) ...[
            const SizedBox(height: 20),
            _buildUpcomingCard(upcoming, plan),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.graphite),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${plan.startDate} — ${plan.endDate}',
                        style: GoogleFonts.unbounded(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Шаблон: ${plan.templateKey}',
                        style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white54),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (plan.scheduledWeekdaysDisplay.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Дни: ${plan.scheduledWeekdaysDisplay}',
                            style: GoogleFonts.unbounded(fontSize: 11, color: AppColors.linkMuted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlanCalendarScreen(plan: plan, onRefresh: _load),
                      ),
                    );
                  },
                  icon: const Icon(Icons.calendar_month, size: 20),
                  label: const Text('Календарь'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.mutedGold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachCard(PlanDayResponse day) {
    final recommendation = day.coachRecommendation ??
        (day.isRest
            ? 'День отдыха. Восстановление и легкая активность.'
            : day.isOfp
                ? 'Сегодня ОФП: силу, выносливость и стабилизацию.'
                : 'Сегодня СФП: лазание и пальцы.');
    final minutes = day.estimatedMinutes ??
        (day.exercises.length * 5 + day.stretching.fold<int>(0, (s, z) => s + z.exercises.length * 2) + 5);
    final load = day.loadLevel ??
        (day.isRest ? 'Отдых' : day.isOfp ? 'Средняя' : 'СФП');
    final focus = day.sessionFocus ??
        (day.weekNumber != null ? 'Неделя ${day.weekNumber}' : null);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.mutedGold.withOpacity(0.12),
            AppColors.mutedGold.withOpacity(0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.mutedGold.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sports_martial_arts, color: AppColors.mutedGold, size: 24),
              const SizedBox(width: 10),
              Text(
                'От тренера',
                style: GoogleFonts.unbounded(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedGold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            recommendation,
            style: GoogleFonts.unbounded(fontSize: 14, color: Colors.white, height: 1.5),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildCoachChip(Icons.schedule, '~$minutes мин'),
              _buildCoachChip(Icons.fitness_center, load),
              if (focus != null) _buildCoachChip(Icons.calendar_today, focus),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoachChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.graphite),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.mutedGold.withOpacity(0.9)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  String _exLabel(int n) {
    if (n == 1) return 'упражнение';
    if (n >= 2 && n <= 4) return 'упражнения';
    return 'упражнений';
  }

  Widget _buildAddClimbingRow() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClimbingLogAddScreen(initialDate: DateTime.now()),
            ),
          ).then((_) => _load());
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.cardDark.withOpacity(0.6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.graphite),
          ),
          child: Row(
            children: [
              Icon(Icons.route, size: 22, color: AppColors.mutedGold.withOpacity(0.9)),
              const SizedBox(width: 12),
              Text(
                'Добавить лазание',
                style: GoogleFonts.unbounded(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
              ),
              const Spacer(),
              Icon(Icons.add_circle_outline, size: 20, color: AppColors.mutedGold),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayCard(DateTime today, ActivePlan plan) {
    final remaining = _remainingExercises ?? 0;
    final day = _todayPlanDay;
    final total = day?.exercises.length ?? 0;
    final hasStarted = day != null && total > 0 && remaining < total;
    final entries = hasStarted ? _planDayToWorkoutEntries(day) : <MapEntry<String, WorkoutBlockExercise>>[];
    final canContinue = hasStarted && entries.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          if (canContinue) {
            final completed = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => ExerciseCompletionScreen(
                  workoutExerciseEntries: entries,
                  date: today,
                ),
              ),
            );
            if (mounted) {
              _load();
              if (completed == true && _todayPlanDay != null) {
                await _api.completeSession(
                  planId: plan.id,
                  date: '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
                  sessionType: _todayPlanDay!.sessionType,
                  ofpDayIndex: _todayPlanDay!.ofpDayIndex,
                );
                _load();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('План выполнен! Добавить лазание?', style: GoogleFonts.unbounded()),
                    behavior: SnackBarBehavior.floating,
                    action: SnackBarAction(
                      label: 'Добавить',
                      textColor: AppColors.mutedGold,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ClimbingLogAddScreen(initialDate: today),
                          ),
                        );
                      },
                    ),
                  ),
                );
              }
            }
          } else {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlanDayScreen(
                  plan: plan,
                  date: today,
                  onCompletedChanged: _load,
                ),
              ),
            );
            if (mounted) _load();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: canContinue ? AppColors.mutedGold.withOpacity(0.15) : AppColors.cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: canContinue ? AppColors.mutedGold.withOpacity(0.5) : AppColors.mutedGold.withOpacity(0.4),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.mutedGold.withOpacity(canContinue ? 0.3 : 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  canContinue ? Icons.play_arrow : Icons.today,
                  color: AppColors.mutedGold,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      canContinue ? 'Продолжить тренировку' : 'Сегодня',
                      style: GoogleFonts.unbounded(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    Text(
                      canContinue
                          ? 'Осталось $remaining ${_exLabel(remaining)}'
                          : '${today.day}.${today.month.toString().padLeft(2, '0')}.${today.year}',
                      style: GoogleFonts.unbounded(fontSize: 13, color: Colors.white54),
                    ),
                    if (plan.includeClimbingInDays && _todayPlanDay != null && !_todayPlanDay!.isRest && _hasClimbingForToday != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(
                              _hasClimbingForToday! ? Icons.check_circle : Icons.route,
                              size: 14,
                              color: _hasClimbingForToday! ? AppColors.successMuted : AppColors.mutedGold.withOpacity(0.8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _hasClimbingForToday! ? 'Лазание ✓' : 'Лазание +',
                              style: GoogleFonts.unbounded(fontSize: 11, color: _hasClimbingForToday! ? AppColors.successMuted : Colors.white54),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}
