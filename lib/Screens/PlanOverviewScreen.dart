import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/models/ClimbingLog.dart';
import 'package:login_app/models/PlanModels.dart';
import 'package:login_app/models/Workout.dart';
import 'package:login_app/services/TrainingPlanApiService.dart' show TrainingPlanApiService, PlanApiException;
import 'package:login_app/services/StrengthTestApiService.dart';
import 'package:login_app/services/ClimbingLogService.dart';
import 'package:login_app/services/PremiumSubscriptionService.dart';
import 'package:login_app/Screens/PlanSelectionScreen.dart';
import 'package:login_app/Screens/ExerciseCompletionScreen.dart';
import 'package:login_app/Screens/PlanCalendarScreen.dart';
import 'package:login_app/Screens/PlanDayScreen.dart';
import 'package:login_app/Screens/ClimbingLogAddScreen.dart';

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
  PlanGuide? _planGuide;
  PlanDayResponse? _todayPlanDay;
  int? _remainingExercises;
  int? _todayCompletedCount;
  int? _todaySkippedCount;
  bool? _hasClimbingForToday;
  int? _planCompletedCount;
  int? _planTotalCount;
  bool _loading = true;
  bool _loadError = false;
  String? _loadErrorMessage;
  bool _loadingTodayPlanDay = false;
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
      final result = await _api.getActivePlan();
      if (mounted) {
        final plan = result.plan;
        final planChanged = _plan?.id != plan?.id;
        setState(() {
          _plan = plan;
          _planGuide = result.planGuide;
          _loading = false;
          _loadError = false;
          _loadErrorMessage = null;
          if (plan == null || planChanged) {
            _todayPlanDay = null;
            _remainingExercises = null;
            _hasClimbingForToday = null;
            _planCompletedCount = null;
            _planTotalCount = null;
            _loadingTodayPlanDay = false;
          }
        });
        if (plan != null) {
          await Future.wait([_loadPlanDayProgress(), _loadPlanProgress()]);
        }
      }
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _loadError = _plan == null;
        _loadErrorMessage = e is PlanApiException ? e.message : null;
      });
    }
  }

  Future<void> _loadPlanDayProgress() async {
    final plan = _plan;
    if (plan == null) return;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final startDate = _parseDate(plan.startDate);
    if (todayDate.isBefore(startDate)) {
      if (mounted && _plan?.id == plan.id) {
        setState(() {
          _todayPlanDay = null;
          _loadingTodayPlanDay = false;
        });
      }
      return;
    }
    if (mounted && _plan?.id == plan.id) setState(() => _loadingTodayPlanDay = true);
    final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final day = await _api.getPlanDay(plan.id, dateStr, light: true);
    if (day == null || !mounted || _plan?.id != plan.id) {
      if (mounted && _plan?.id == plan.id) setState(() => _loadingTodayPlanDay = false);
      return;
    }
    final needClimbing = day.isClimbing || (plan.includeClimbingInDays && !day.isRest);
    final needCompletionsSkips = !day.isRest && day.exercises.isNotEmpty;
    // Параллельная загрузка history + completions + skips вместо последовательных вызовов
    List<HistorySession>? history;
    List<ExerciseCompletion>? completions;
    List<ExerciseSkip>? skips;
    if (needClimbing || needCompletionsSkips) {
      final api = StrengthTestApiService();
      final futures = <Future>[];
      if (needClimbing) futures.add(_climbingService.getHistory());
      if (needCompletionsSkips) {
        futures.add(api.getExerciseCompletions(date: dateStr));
        futures.add(api.getExerciseSkips(date: dateStr));
      }
      final results = await Future.wait(futures);
      int i = 0;
      if (needClimbing) history = results[i++] as List<HistorySession>;
      if (needCompletionsSkips) {
        completions = results[i++] as List<ExerciseCompletion>;
        skips = results[i++] as List<ExerciseSkip>;
      }
    }
    HistorySession? sess;
    if (history != null) {
      try {
        sess = history.firstWhere((s) => s.date == dateStr);
      } catch (_) {}
    }
    if (day.isRest || day.exercises.isEmpty) {
      if (mounted && _plan?.id == plan.id) setState(() {
        _todayPlanDay = day;
        _remainingExercises = 0;
        _todayCompletedCount = null;
        _todaySkippedCount = null;
        _hasClimbingForToday = needClimbing ? sess != null : null;
        _loadingTodayPlanDay = false;
      });
      return;
    }
    final entries = _planDayToWorkoutEntries(day);
    final ids = entries.map((e) => e.value.exerciseId).toSet();
    final completedIds = completions?.map((c) => c.exerciseId).toSet() ?? <String>{};
    final skippedIds = skips?.map((s) => s.exerciseId).toSet() ?? <String>{};
    final completedCount = ids.where((id) => completedIds.contains(id)).length;
    final skippedCount = ids.where((id) => skippedIds.contains(id)).length;
    if (day.completed) {
      if (mounted && _plan?.id == plan.id) setState(() {
        _todayPlanDay = day;
        _remainingExercises = 0;
        _todayCompletedCount = completedCount;
        _todaySkippedCount = skippedCount;
        _hasClimbingForToday = plan.includeClimbingInDays ? sess != null : null;
        _loadingTodayPlanDay = false;
      });
      return;
    }
    if (mounted && _plan?.id == plan.id) {
      setState(() {
        _todayPlanDay = day;
        _remainingExercises = (ids.length - completedCount - skippedCount).clamp(0, ids.length);
        _todayCompletedCount = null;
        _todaySkippedCount = null;
        _hasClimbingForToday = needClimbing ? sess != null : null;
        _loadingTodayPlanDay = false;
      });
    }
  }

  Future<void> _loadPlanProgress() async {
    final plan = _plan;
    if (plan == null) return;
    try {
      final start = _parseDate(plan.startDate);
      final end = _parseDate(plan.endDate);
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      if (end.isBefore(start)) {
        if (mounted && _plan?.id == plan.id) {
          setState(() {
            _planCompletedCount = 0;
            _planTotalCount = 0;
          });
        }
        return;
      }
      // Сначала GET /plans/{id}/progress — один запрос вместо N по месяцам
      final progress = await _api.getPlanProgress(plan.id);
      if (progress != null && mounted && _plan?.id == plan.id) {
        setState(() {
          _planCompletedCount = progress.completed;
          _planTotalCount = progress.total;
        });
        return;
      }
      // Fallback: бэкенд ещё не реализовал progress — календарь по месяцам
      int completed = 0;
      int total = 0;
      var current = DateTime(start.year, start.month, 1);
      final lastMonth = DateTime(end.year, end.month, 1);
      while (!current.isAfter(lastMonth)) {
        final monthStr = '${current.year}-${current.month.toString().padLeft(2, '0')}';
        final cal = await _api.getPlanCalendar(plan.id, monthStr);
        if (cal != null && mounted && _plan?.id == plan.id) {
          for (final d in cal.days) {
            if (!d.inPlanRange || d.sessionType == null) continue;
            final isTraining = d.sessionType == 'ofp' || d.sessionType == 'sfp' || d.sessionType == 'climbing';
            if (!isTraining) continue;
            final dateParts = d.date.split('-');
            if (dateParts.length >= 3) {
              final dt = DateTime(int.parse(dateParts[0]), int.parse(dateParts[1]), int.parse(dateParts[2]));
              if (!dt.isBefore(start) && !dt.isAfter(end)) {
                total++;
                if (!dt.isAfter(todayDate) && d.completed) completed++;
              }
            }
          }
        }
        current = DateTime(current.year, current.month + 1, 1);
      }
      if (mounted && _plan?.id == plan.id) {
        setState(() {
          _planCompletedCount = completed;
          _planTotalCount = total;
        });
      }
    } catch (_) {
      if (mounted && _plan?.id == plan.id) {
        setState(() {
          _planCompletedCount = null;
          _planTotalCount = null;
        });
      }
    }
  }

  List<MapEntry<String, WorkoutBlockExercise>> _planDayToWorkoutEntries(PlanDayResponse day) {
    if (day.exercises.isEmpty) return [];
    final sessionType = day.sessionType;
    final category = sessionType == 'sfp' ? 'sfp' : 'ofp';
    final blockKey = sessionType == 'sfp' ? 'sfp' : (sessionType == 'ofp' ? 'ofp' : 'plan');
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

  DateTime _parseDate(String s) {
    final p = s.split('-');
    if (p.length >= 3) return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    return DateTime.now();
  }

  String _planDurationWeeks(ActivePlan plan) {
    try {
      final start = _parseDate(plan.startDate);
      final end = _parseDate(plan.endDate);
      final days = end.difference(start).inDays;
      if (days <= 0) return '1 неделя';
      final weeks = (days / 7).ceil();
      if (weeks == 1) return '1 неделя';
      if (weeks >= 2 && weeks <= 4) return '$weeks недели';
      return '$weeks недель';
    } catch (_) {
      return '—';
    }
  }

  Future<void> _openPlanSelection({required bool planExists}) async {
    if (planExists) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Обновить план',
            style: GoogleFonts.unbounded(color: Colors.white, fontSize: 18),
          ),
          content: Text(
            'Можно изменить длительность, дни недели и другие настройки. Продолжить?',
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
        builder: (_) => PlanSelectionScreen(
          onPlanCreated: _onPlanCreated,
          existingPlan: planExists ? _plan : null,
        ),
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
        actions: const [],
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
    final subtitle = _loadErrorMessage ??
        'Проверьте подключение к интернету и нажмите «Повторить»';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _loadErrorMessage != null ? Icons.hourglass_empty_rounded : Icons.wifi_off_rounded,
              size: 64,
              color: Colors.white38,
            ),
            const SizedBox(height: 20),
            Text(
              'Не удалось загрузить план',
              style: GoogleFonts.unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.unbounded(fontSize: 14, color: Colors.white54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _loadErrorMessage = null;
                });
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
    final guide = _planGuide;
    final shortDesc = guide?.shortDescription;
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
            shortDesc ?? 'Персональное расписание ОФП и СФП под ваши цели',
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
          if (guide != null) ...[
            if (guide.howItWorks != null && ((guide.howItWorks!.sections ?? []).isNotEmpty || (guide.howItWorks!.items ?? []).isNotEmpty)) ...[
              _buildGuideSection(guide.howItWorks!),
              const SizedBox(height: 12),
            ],
            if (guide.whatWeConsider != null && ((guide.whatWeConsider!.sections ?? []).isNotEmpty || (guide.whatWeConsider!.items ?? []).isNotEmpty)) ...[
              _buildGuideSection(guide.whatWeConsider!),
              const SizedBox(height: 12),
            ],
            if (guide.whatYouGet != null && ((guide.whatYouGet!.sections ?? []).isNotEmpty || (guide.whatYouGet!.items ?? []).isNotEmpty)) ...[
              _buildGuideSection(guide.whatYouGet!),
              const SizedBox(height: 12),
            ],
          ] else ...[
            _buildInfoCard(
              'Расписание на недели',
              'Вы получаете готовое расписание ОФП и СФП: в какие дни тренироваться, какие упражнения делать, сколько подходов и повторений.',
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              'Как это работает',
              'Выберите аудиторию (новичок/продолжающий) и шаблон. План создаётся под вас. Карточка «Сегодня» покажет: отдых или тренировку (ОФП/СФП) — нажмите «Приступить».',
            ),
            const SizedBox(height: 12),
          ],
          _buildInfoCard(
            'Продолжить тренировку',
            'Если вы начали, но не закончили — карточка «Сегодня» превратится в «Продолжить тренировку». Отмечаете подходы, возвращаетесь. Прогресс сохраняется.',
          ),
        ],
      ),
    );
  }

  Widget _buildGuideSection(PlanGuideSection section) {
    final title = section.title ?? 'Как это работает';
    final sectionsList = section.sections;
    final itemsList = section.items;
    final hasContent = (sectionsList != null && sectionsList.isNotEmpty) || (itemsList != null && itemsList.isNotEmpty);
    if (!hasContent) return const SizedBox.shrink();
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
          const SizedBox(height: 12),
          if (sectionsList != null)
            ...sectionsList.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (e.title != null && e.title!.isNotEmpty)
                        Text(
                          e.title!,
                          style: GoogleFonts.unbounded(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      if (e.text != null && e.text!.isNotEmpty)
                        Text(
                          e.text!,
                          style: GoogleFonts.unbounded(fontSize: 13, color: Colors.white70, height: 1.5),
                        ),
                    ],
                  ),
                )),
          if (itemsList != null)
            ...itemsList.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '• ${(e.label != null && e.label!.isNotEmpty) ? '${e.label}: ' : ''}${e.text ?? ''}',
                    style: GoogleFonts.unbounded(fontSize: 13, color: Colors.white70, height: 1.5),
                  ),
                )),
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

  Widget _buildPlanProgressBar() {
    final plan = _plan;
    final completed = _planCompletedCount;
    final total = _planTotalCount;
    if (plan == null || total == null || total == 0) return const SizedBox.shrink();
    final done = (completed ?? 0).clamp(0, total);
    final pct = total > 0 ? (done / total).clamp(0.0, 1.0) : 0.0;
    final segmentCount = total.clamp(1, 60);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlanCalendarScreen(plan: plan, onRefresh: _load),
            ),
          );
          _load();
        },
        borderRadius: BorderRadius.circular(12),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Прогресс плана',
                    style: GoogleFonts.unbounded(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mutedGold,
                    ),
                  ),
                  Text(
                    '$done из $total • ${(pct * 100).round()}%',
                    style: GoogleFonts.unbounded(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final segW = (w / segmentCount).clamp(2.0, 24.0);
                  const spacing = 2.0;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: 4,
                    children: List.generate(segmentCount, (i) {
                      final isDone = i < done;
                      return Container(
                        width: segW - spacing,
                        height: 20,
                        decoration: BoxDecoration(
                          color: isDone
                              ? AppColors.successMuted.withOpacity(0.8)
                              : AppColors.graphite,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  );
                },
              ),
              const SizedBox(height: 6),
              Text(
                'Нажмите для календаря',
                style: GoogleFonts.unbounded(fontSize: 11, color: Colors.white38),
              ),
            ],
          ),
        ),
      ),
    );
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
          _buildWelcomeTip(Icons.today, 'Сегодня', '«Сегодня мы отдыхаем» — день восстановления. «Сегодня ОФП/СФП» — нажмите «Приступить», чтобы начать тренировку.'),
          const SizedBox(height: 8),
          _buildWelcomeTip(Icons.tune, 'Изменение тренировки', 'При открытии дня можно менять план под себя: самочувствие, фокус, доступное время — через кнопку «Уточнить на сегодня» или иконку настроек в шапке экрана.'),
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
    final status = widget.premiumStatus;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPlanProgressBar(),
          const SizedBox(height: 20),
          if (_showPlanCreatedWelcome) _buildPlanCreatedWelcomeCard(plan),
          if (status?.trialEndsIn3OrLess == true &&
              status?.hasActiveSubscription != true &&
              widget.onPremiumTap != null) ...[
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
          _buildTodayCard(today, plan),
          if (!_isBeforePlanStart(today, plan) &&
              _todayPlanDay != null &&
              !_todayPlanDay!.isRest &&
              _hasClimbingForToday != true) ...[
            const SizedBox(height: 12),
            _buildAddClimbingRow(),
          ],
          const SizedBox(height: 20),
          _buildPlanSettingsCard(plan),
          const SizedBox(height: 28),
          _buildDeletePlanButton(),
        ],
      ),
    );
  }

  Widget _buildDeletePlanButton() {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _confirmDeletePlan,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete_outline, size: 18, color: Colors.white38),
                const SizedBox(width: 8),
                Text(
                  'Удалить план',
                  style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white38),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeletePlan() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Удалить план?',
          style: GoogleFonts.unbounded(color: Colors.white, fontSize: 18),
        ),
        content: Text(
          'План и расписание будут удалены. Вы сможете создать новый план.',
          style: GoogleFonts.unbounded(fontSize: 14, color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Отмена', style: GoogleFonts.unbounded(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: Text('Удалить', style: GoogleFonts.unbounded(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final deleted = await _api.deleteActivePlan();
    if (mounted) {
      if (deleted) {
        _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось удалить план'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPlanSettingsCard(ActivePlan plan) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.graphite),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Настройки плана',
                  style: GoogleFonts.unbounded(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.mutedGold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _openPlanSelection(planExists: true),
                icon: Icon(Icons.edit_outlined, size: 22, color: AppColors.mutedGold),
                tooltip: 'Редактировать план',
                style: IconButton.styleFrom(padding: const EdgeInsets.all(6)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPlanSettingRow(Icons.date_range, 'Период', '${plan.startDate} — ${plan.endDate}'),
          _buildPlanSettingRow(Icons.schedule, 'Длительность', _planDurationWeeks(plan)),
          if (plan.scheduledWeekdaysDisplay.isNotEmpty) ...[
            _buildPlanSettingRow(Icons.today, 'Дни', plan.scheduledWeekdaysDisplay),
            _buildPlanSettingRow(Icons.fitness_center, 'Тренировок в неделю', '${plan.scheduledWeekdays!.length}'),
          ],
          _buildPlanSettingRow(
            Icons.route,
            'Лазание в днях',
            plan.includeClimbingInDays ? 'Да (лазание + ОФП/СФП)' : 'Нет (только ОФП/СФП)',
          ),
          _buildPlanSettingRow(Icons.grid_view, 'Шаблон', plan.templateKey),
        ],
      ),
    );
  }

  Widget _buildPlanSettingRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.white38),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white54),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
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

  String _todayDoneSummary(int total) {
    final done = _todayCompletedCount ?? 0;
    final skipped = _todaySkippedCount ?? 0;
    if (done > 0 && skipped > 0) {
      return '$done ${_exLabel(done)} выполнено, $skipped пропущено. Нажмите, чтобы посмотреть детали.';
    }
    if (skipped > 0) {
      return '$skipped ${_exLabel(skipped)} пропущено. Нажмите, чтобы посмотреть детали.';
    }
    if (done > 0) {
      return '$done ${_exLabel(done)} выполнено. Нажмите, чтобы посмотреть детали.';
    }
    return '$total ${_exLabel(total)} в плане. Нажмите, чтобы посмотреть детали.';
  }

  /// Сообщение в стиле тренера для карточки «Сегодня».
  String _todayCoachMessage(PlanDayResponse? day, ActivePlan plan, int remaining, int total, bool canContinue, DateTime today) {
    if (_isBeforePlanStart(today, plan)) return 'Первый день — ${plan.startDate}. Ждём старта!';
    if (day == null) return 'Загрузка...';
    if (canContinue && remaining > 0) return 'Осталось $remaining ${_exLabel(remaining)}. Продолжаем!';
    if (canContinue && remaining == 0) {
      return 'Всё отмечено. Нажмите «Завершить» — день будет засчитан, здесь появится итог и возможность добавить лазание.';
    }
    if (day.isRest) {
      final rec = day.coachRecommendation;
      return rec != null && rec.isNotEmpty
          ? rec
          : 'Восстановление и лёгкая активность. Не перегружайте организм.';
    }
    if (day.isClimbing) {
      final mins = day.estimatedMinutes ?? 90;
      return '1–2 часа на стене. Только лазание. ~$mins мин.';
    }
    final mins = day.estimatedMinutes ?? 45;
    final stretchMins = day.stretchingEstimatedMinutes ?? 10;
    final totalMins = mins + stretchMins;
    final hasClimbing = plan.includeClimbingInDays;
    String workoutDesc = day.isOfp ? 'сила, выносливость, стабилизация' : 'лазание и пальцы';
    final weekInfo = day.weekNumber != null ? ' Неделя ${day.weekNumber}.' : '';
    final dayInfo = (day.isOfp && day.ofpDayIndex != null)
        ? ' ОФП день ${day.ofpDayIndex! + 1}.'
        : (day.isSfp && day.sfpDayIndex != null)
            ? ' СФП день ${day.sfpDayIndex! + 1}.'
            : '';
    if (day.coachRecommendation != null && day.coachRecommendation!.isNotEmpty) {
      return day.coachRecommendation!;
    }
    if (hasClimbing) {
      return 'Лазаем 1–2 ч, потом $workoutDesc — всего ~$totalMins мин.$dayInfo$weekInfo Поехали!';
    }
    return '$workoutDesc — ~$totalMins мин.$dayInfo$weekInfo Поехали!';
  }

  bool _isBeforePlanStart(DateTime today, ActivePlan plan) {
    final todayDate = DateTime(today.year, today.month, today.day);
    final start = _parseDate(plan.startDate);
    return todayDate.isBefore(start);
  }

  String _todaySessionTitle(PlanDayResponse? day, ActivePlan? plan, DateTime today) {
    if (plan != null && _isBeforePlanStart(today, plan)) return 'План начинается';
    if (day == null) return 'Сегодня';
    if (day.isRest) return 'Сегодня день отдыха';
    if (day.isClimbing) return 'Сегодня только лазание';
    if (day.isOfp) return 'Сегодня ОФП';
    if (day.isSfp) return 'Сегодня СФП';
    return 'Сегодня тренировка';
  }

  Widget _buildTodayCard(DateTime today, ActivePlan plan) {
    final remaining = _remainingExercises ?? 0;
    final day = _todayPlanDay;
    final total = day?.exercises.length ?? 0;
    final isDone = day?.completed ?? false;
    final hasStarted = day != null && total > 0 && remaining < total && !isDone;
    final entries = hasStarted ? _planDayToWorkoutEntries(day!) : <MapEntry<String, WorkoutBlockExercise>>[];
    final canContinue = hasStarted && entries.isNotEmpty;
    final isRest = day?.isRest ?? false;
    final beforeStart = _isBeforePlanStart(today, plan);
    final showAddClimbing = isDone &&
        day != null &&
        !day.isRest &&
        _hasClimbingForToday == false &&
        (plan.includeClimbingInDays || day.isClimbing);

    final isLoading = _loadingTodayPlanDay;

    Future<void> onTap() async {
      if (beforeStart || isLoading) return;
      if (isDone) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlanDayScreen(
              plan: plan,
              date: today,
              expectedSessionType: day?.sessionType,
              onCompletedChanged: _load,
              initialDay: day,
            ),
          ),
        );
        if (mounted) _load();
        return;
      }
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
            if (mounted) {
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
        }
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlanDayScreen(
              plan: plan,
              date: today,
              expectedSessionType: day?.sessionType,
              onCompletedChanged: _load,
              initialDay: day,
            ),
          ),
        );
        if (mounted) _load();
      }
    }

    final cardActive = !beforeStart && !isRest && !isLoading;
    final isCompletedState = isDone && day != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isLoading
                ? AppColors.mutedGold.withOpacity(0.08)
                : (beforeStart || isRest
                    ? AppColors.cardDark
                    : (canContinue
                        ? AppColors.mutedGold.withOpacity(0.15)
                        : (isCompletedState ? AppColors.successMuted.withOpacity(0.12) : AppColors.cardDark))),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isLoading
                  ? AppColors.mutedGold.withOpacity(0.6)
                  : (beforeStart || isRest
                      ? AppColors.graphite
                      : (canContinue
                          ? AppColors.mutedGold.withOpacity(0.5)
                          : (isCompletedState ? AppColors.successMuted.withOpacity(0.5) : AppColors.mutedGold.withOpacity(0.4)))),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 320;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isRest
                              ? Colors.white12
                              : (isCompletedState
                                  ? AppColors.successMuted.withOpacity(0.3)
                                  : AppColors.mutedGold.withOpacity(canContinue ? 0.3 : 0.2)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          beforeStart
                              ? Icons.schedule
                              : (isRest
                                  ? Icons.bedtime
                                  : (isCompletedState
                                      ? Icons.check_circle
                                      : (canContinue ? Icons.play_arrow : Icons.fitness_center))),
                          color: beforeStart || isRest
                              ? Colors.white38
                              : (isCompletedState ? AppColors.successMuted : AppColors.mutedGold),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isCompletedState
                                  ? 'Сегодня сделано'
                                  : (canContinue
                                      ? (remaining == 0 ? 'Завершить тренировку' : 'Продолжить тренировку')
                                      : _todaySessionTitle(day, plan, today)),
                              style: GoogleFonts.unbounded(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                isCompletedState
                                    ? (total > 0
                                        ? _todayDoneSummary(total)
                                        : 'Тренировка завершена. Нажмите, чтобы посмотреть детали.')
                                    : _todayCoachMessage(day, plan, remaining, total, canContinue, today),
                                style: GoogleFonts.unbounded(fontSize: 13, color: Colors.white70, height: 1.4),
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (showAddClimbing)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ClimbingLogAddScreen(initialDate: today),
                                      ),
                                    ).then((_) => _load());
                                  },
                                  icon: const Icon(Icons.route, size: 18),
                                  label: Text(
                                    'Добавить лазание',
                                    style: GoogleFonts.unbounded(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.mutedGold,
                                    side: BorderSide(color: AppColors.mutedGold.withOpacity(0.7)),
                                  ),
                                ),
                              )
                            else if (day != null &&
                                !day.isRest &&
                                _hasClimbingForToday != null &&
                                (plan.includeClimbingInDays || day.isClimbing) &&
                                !isCompletedState)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Row(
                                  children: [
                                    Icon(
                                      _hasClimbingForToday! ? Icons.check_circle : Icons.route,
                                      size: 14,
                                      color:
                                          _hasClimbingForToday! ? AppColors.successMuted : AppColors.mutedGold.withOpacity(0.8),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _hasClimbingForToday! ? 'Лазание ✓' : 'Лазание +',
                                      style: GoogleFonts.unbounded(
                                          fontSize: 11, color: _hasClimbingForToday! ? AppColors.successMuted : Colors.white54),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (cardActive && !narrow && !showAddClimbing)
                        FilledButton(
                          onPressed: isLoading ? null : () => onTap(),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.mutedGold,
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            minimumSize: Size.zero,
                          ),
                          child: isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54),
                                )
                              : Text(
                                  isCompletedState
                                      ? 'Подробнее'
                                      : (canContinue ? (remaining == 0 ? 'Завершить' : 'Продолжить') : 'Приступить'),
                                  style: GoogleFonts.unbounded(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                        )
                      else if (cardActive && !narrow && showAddClimbing)
                        Icon(Icons.chevron_right, color: Colors.white54),
                    ],
                  ),
                  if (narrow && cardActive)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: isLoading ? null : () => onTap(),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.mutedGold,
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: isLoading
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54),
                                )
                              : Text(
                                  isCompletedState
                                      ? 'Подробнее'
                                      : (canContinue ? (remaining == 0 ? 'Завершить' : 'Продолжить') : 'Приступить'),
                                  style: GoogleFonts.unbounded(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
