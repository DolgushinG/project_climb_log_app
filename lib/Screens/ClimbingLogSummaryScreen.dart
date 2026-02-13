import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:login_app/models/ClimbingLog.dart';
import 'package:login_app/models/StrengthAchievement.dart';
import 'package:login_app/models/StrengthTier.dart';
import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/services/ClimbingLogService.dart';
import 'package:login_app/services/StrengthDashboardService.dart';
import 'package:login_app/services/TrainingPlanGenerator.dart';
import 'package:login_app/services/TrainingGamificationService.dart';
import 'package:login_app/services/StrengthTestApiService.dart';
import 'package:login_app/services/PremiumSubscriptionService.dart';
import 'package:login_app/Screens/ClimbingLogAddScreen.dart';
import 'package:login_app/models/Workout.dart';
import 'package:login_app/Screens/ExerciseCompletionScreen.dart';
import 'package:login_app/Screens/WorkoutGenerateScreen.dart';

/// Стартовый экран «Обзор» — summary, графики, рекомендации, strength dashboard.
class ClimbingLogSummaryScreen extends StatefulWidget {
  final PremiumStatus? premiumStatus;
  final VoidCallback? onPremiumTap;

  const ClimbingLogSummaryScreen({
    super.key,
    this.premiumStatus,
    this.onPremiumTap,
  });

  @override
  State<ClimbingLogSummaryScreen> createState() =>
      _ClimbingLogSummaryScreenState();
}

class _ClimbingLogSummaryScreenState extends State<ClimbingLogSummaryScreen> {
  static const String _keyExercisesDone = 'exercises_all_done_';
  static const String _keyGeneratedWorkout = 'generated_workout_';
  final ClimbingLogService _service = ClimbingLogService();
  final StrengthDashboardService _strengthSvc = StrengthDashboardService();
  final TrainingGamificationService _gamification = TrainingGamificationService();

  ClimbingLogSummary? _summary;
  bool _exercisesAllDoneToday = false;
  bool _hasGeneratedWorkoutToday = false;
  List<ClimbingLogRecommendation> _recommendations = [];
  bool _loading = true;
  String? _error;

  StrengthMetrics? _strengthMetrics;
  double? _strengthChangePct;
  int _xp = 0;
  int _streak = 0;
  String _recoveryStatus = 'ready';

  String get _todayKey {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _load();
    _loadStrengthDashboard();
    _loadExercisesDoneState();
    _loadGeneratedWorkoutState();
  }

  Future<void> _loadGeneratedWorkoutState() async {
    final w = await _loadGeneratedWorkout();
    if (mounted) setState(() => _hasGeneratedWorkoutToday = w != null && w.entries.isNotEmpty);
  }

  Future<void> _loadExercisesDoneState() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getBool('$_keyExercisesDone$_todayKey');
    if (mounted) setState(() => _exercisesAllDoneToday = val == true);
  }

  Future<void> _saveExercisesDoneState(bool done) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_keyExercisesDone$_todayKey', done);
  }

  static const String _keyGeneratedWorkoutCoach = 'generated_workout_coach_';

  Future<void> _saveGeneratedWorkout(GeneratedWorkoutResult result) async {
    final prefs = await SharedPreferences.getInstance();
    final list = result.entries.map((e) => {'block_key': e.key, ...e.value.toJson()}).toList();
    await prefs.setString('$_keyGeneratedWorkout$_todayKey', jsonEncode(list));
    final coach = <String, dynamic>{
      if (result.coachComment != null) 'coach_comment': result.coachComment,
      if (result.loadDistribution != null && result.loadDistribution!.isNotEmpty)
        'load_distribution': result.loadDistribution,
      if (result.progressionHint != null) 'progression_hint': result.progressionHint,
    };
    if (coach.isNotEmpty) {
      await prefs.setString('$_keyGeneratedWorkoutCoach$_todayKey', jsonEncode(coach));
    } else {
      await prefs.remove('$_keyGeneratedWorkoutCoach$_todayKey');
    }
  }

  Future<GeneratedWorkoutResult?> _loadGeneratedWorkout() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('$_keyGeneratedWorkout$_todayKey');
    if (json == null) return null;
    try {
      final list = jsonDecode(json) as List<dynamic>?;
      if (list == null || list.isEmpty) return null;
      final entries = list.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        final key = m.remove('block_key') as String? ?? 'main';
        return MapEntry(key, WorkoutBlockExercise.fromJson(m));
      }).toList();
      String? coachComment;
      Map<String, int>? loadDistribution;
      String? progressionHint;
      final coachJson = prefs.getString('$_keyGeneratedWorkoutCoach$_todayKey');
      if (coachJson != null) {
        try {
          final coach = jsonDecode(coachJson) as Map<String, dynamic>?;
          if (coach != null) {
            coachComment = coach['coach_comment'] as String?;
            progressionHint = coach['progression_hint'] as String?;
            final ld = coach['load_distribution'] as Map<String, dynamic>?;
            if (ld != null) {
              loadDistribution = ld.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0));
            }
          }
        } catch (_) {}
      }
      return GeneratedWorkoutResult(
        entries: entries,
        coachComment: coachComment,
        loadDistribution: loadDistribution,
        progressionHint: progressionHint,
      );
    } catch (_) {}
    return null;
  }

  Future<void> _loadStrengthDashboard() async {
    final m = await _strengthSvc.getLastMetrics();
    final api = StrengthTestApiService();
    final gamification = await api.getGamification();
    double? changePct;
    final history = await api.getStrengthTestsHistory(periodDays: 365);
    if (history.length >= 2) {
      final sorted = List.of(history)..sort((a, b) => b.date.compareTo(a.date));
      final prevAvg = _getAvgFromMetrics(sorted[1].metrics);
      final currAvg = _getAvgFromMetrics(sorted[0].metrics);
      if (prevAvg != null && prevAvg > 0 && currAvg != null) {
        changePct = currAvg - prevAvg;
      }
    }
    if (gamification != null && mounted) {
      setState(() {
        _strengthMetrics = m;
        _strengthChangePct = changePct;
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
          _strengthChangePct = changePct;
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
        _service.getRecommendations(),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as ClimbingLogSummary?;
        _recommendations = results[1] as List<ClimbingLogRecommendation>;
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
    await _loadExercisesDoneState();
  }

  String _dayWord(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'день';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) return 'дня';
    return 'дней';
  }

  Widget _buildPremiumSection(BuildContext context) {
    final status = widget.premiumStatus;
    final onTap = widget.onPremiumTap!;
    if (status?.hasActiveSubscription == true) return const SizedBox.shrink();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.mutedGold.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.star_outline, color: AppColors.mutedGold, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Premium',
                    style: GoogleFonts.unbounded(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    status?.isInTrial == true
                        ? 'Пробный период: ${status!.trialDaysLeft} ${_dayWord(status.trialDaysLeft)}'
                        : 'Подписка — доступ ко всем функциям',
                    style: GoogleFonts.unbounded(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: AppColors.mutedGold, size: 16),
          ],
        ),
      ),
    );
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
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Обзор',
                        style: GoogleFonts.unbounded(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      if (!_loading && _summary != null && (_summary!.totalSessions) > 0) ...[
                        const SizedBox(height: 16),
                        _buildSummaryCards(context, _summary!),
                        const SizedBox(height: 16),
                      ],
                      const SizedBox(height: 12),
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
                      if (widget.onPremiumTap != null) ...[
                        const SizedBox(height: 12),
                        _buildPremiumSection(context),
                      ],
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
    final sessionsCount = s?.totalSessions ?? 0;

    return [
      if (_strengthMetrics != null)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStrengthDashboard(context),
                const SizedBox(height: 12),
                _buildExerciseCompletionCard(context, compact: false),
                const SizedBox(height: 12),
                _buildWorkoutGenerateCard(context, compact: false),
              ],
            ),
          ),
        ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: sessionsCount == 0
              ? _buildEmptyState(context)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Рекомендации',
                      style: GoogleFonts.unbounded(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    _buildRecommendations(_recommendations),
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
          if (_strengthChangePct != null && (_strengthChangePct!.abs() >= 0.5)) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  _strengthChangePct! >= 0 ? Icons.trending_up : Icons.trending_down,
                  size: 18,
                  color: _strengthChangePct! >= 0 ? AppColors.successMuted : Colors.orange,
                ),
                const SizedBox(width: 6),
                Text(
                  _strengthChangePct! >= 0
                      ? 'Прирост +${_strengthChangePct!.toStringAsFixed(1)}%'
                      : 'Регресс ${_strengthChangePct!.toStringAsFixed(1)}%',
                  style: GoogleFonts.unbounded(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _strengthChangePct! >= 0 ? AppColors.successMuted : Colors.orange,
                  ),
                ),
              ],
            ),
          ],
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

  Widget _buildExerciseCompletionCard(BuildContext context, {bool compact = false}) {
    final done = _exercisesAllDoneToday;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final workout = await _loadGeneratedWorkout();
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => workout != null && workout.entries.isNotEmpty
                  ? ExerciseCompletionScreen(
                      workoutExerciseEntries: workout.entries,
                      coachComment: workout.coachComment,
                      loadDistribution: workout.loadDistribution,
                      progressionHint: workout.progressionHint,
                    )
                  : ExerciseCompletionScreen(metrics: _strengthMetrics),
            ),
          );
          if (mounted) {
            _loadStrengthDashboard();
            if (result != null) {
              setState(() => _exercisesAllDoneToday = result);
              _saveExercisesDoneState(result);
            }
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(compact ? 12 : 16),
          decoration: BoxDecoration(
            color: done ? AppColors.successMuted.withOpacity(0.15) : AppColors.cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: done ? AppColors.successMuted.withOpacity(0.5) : AppColors.graphite,
            ),
          ),
          child: Row(
            children: [
              Icon(
                done ? Icons.check_circle : Icons.check_circle_outline,
                color: AppColors.successMuted,
                size: compact ? 22 : 28,
              ),
              SizedBox(width: compact ? 10 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      done ? 'Готово!' : 'Выполнить упражнения',
                      style: GoogleFonts.unbounded(
                        fontSize: compact ? 13 : 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!compact)
                      Text(
                        done
                            ? 'Можно зайти и обновить данные'
                            : _hasGeneratedWorkoutToday
                                ? 'Из сгенерированной тренировки'
                                : 'Из плана по замерам',
                        style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white54),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: compact ? 12 : 14, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkoutGenerateCard(BuildContext context, {bool compact = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push<GeneratedWorkoutResult>(
            context,
            MaterialPageRoute(builder: (_) => const WorkoutGenerateScreen()),
          );
          if (!mounted) return;
          if (result != null && result.entries.isNotEmpty) {
            await _saveGeneratedWorkout(result);
            if (!mounted) return;
            final done = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => ExerciseCompletionScreen(
                  workoutExerciseEntries: result.entries,
                  coachComment: result.coachComment,
                  loadDistribution: result.loadDistribution,
                  progressionHint: result.progressionHint,
                ),
              ),
            );
            if (mounted && done != null) {
              setState(() => _exercisesAllDoneToday = done);
              await _saveExercisesDoneState(done);
            }
          }
          if (mounted) {
            _loadExercisesDoneState();
            _loadStrengthDashboard();
            _loadGeneratedWorkoutState();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(compact ? 12 : 16),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.mutedGold.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.mutedGold, size: compact ? 22 : 28),
              SizedBox(width: compact ? 10 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Сгенерировать тренировку',
                      style: GoogleFonts.unbounded(
                        fontSize: compact ? 13 : 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!compact)
                      Text(
                        'План под ваш уровень и цель',
                        style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white54),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: compact ? 12 : 14, color: Colors.white38),
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
