import 'package:flutter/material.dart';

import 'package:login_app/models/ClimbingLog.dart';
import 'package:login_app/models/StrengthAchievement.dart';
import 'package:login_app/models/StrengthMeasurementSession.dart';
import 'package:login_app/models/StrengthTier.dart';
import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/services/ClimbingLogService.dart';
import 'package:login_app/services/StrengthDashboardService.dart';
import 'package:login_app/services/TrainingPlanGenerator.dart';
import 'package:login_app/services/TrainingGamificationService.dart';
import 'package:login_app/services/StrengthTestApiService.dart';
import 'package:login_app/services/PremiumSubscriptionService.dart';
import 'package:login_app/services/TrainingPlanApiService.dart';
import 'package:login_app/models/PlanModels.dart';
import 'package:login_app/Screens/PlanCalendarScreen.dart';

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

class _ClimbingLogSummaryScreenState extends State<ClimbingLogSummaryScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final ClimbingLogService _service = ClimbingLogService();
  final StrengthDashboardService _strengthSvc = StrengthDashboardService();
  final TrainingGamificationService _gamification = TrainingGamificationService();
  final TrainingPlanApiService _planApi = TrainingPlanApiService();

  ClimbingLogSummary? _summary;
  ActivePlan? _plan;
  int? _planCompletedCount;
  int? _planTotalCount;
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
    _loadAll();
  }

  Future<(StrengthMetrics?, double?, int, int, String)> _loadStrengthDashboard() async {
    try {
      final api = StrengthTestApiService();
      final results = await Future.wait([
        _strengthSvc.getLastMetrics(),
        api.getGamification(),
        api.getStrengthTestsHistory(periodDays: 365),
      ]);
      final m = results[0] as StrengthMetrics?;
      final gamification = results[1] as GamificationData?;
      final history = results[2] as List<StrengthMeasurementSession>;
      double? changePct;
      if (history.length >= 2) {
        final sorted = List<StrengthMeasurementSession>.from(history)..sort((a, b) => b.date.compareTo(a.date));
        final prevAvg = _getAvgFromMetrics(sorted[1].metrics);
        final currAvg = _getAvgFromMetrics(sorted[0].metrics);
        if (prevAvg != null && prevAvg > 0 && currAvg != null) {
          changePct = currAvg - prevAvg;
        }
      }
      if (gamification != null) {
        return (m, changePct, gamification.totalXp, gamification.streakDays, gamification.recoveryStatus);
      }
      final xpResults = await Future.wait([
        _gamification.getTotalXp(),
        _gamification.getStreakDays(),
        _gamification.getRecoveryStatus(),
      ]);
      return (m, changePct, xpResults[0] as int, xpResults[1] as int, xpResults[2] as String);
    } catch (_) {
      return (null, null, 0, 0, 'ready');
    }
  }

  Future<void> _loadAll() async {
    final hadData = _summary != null;
    if (!hadData) setState(() { _loading = true; _error = null; });
    try {
      final summaryFuture = Future.wait([
        _service.getSummary(),
        _service.getRecommendations(),
      ]);
      final dashboardFuture = _loadStrengthDashboard();
      final planFuture = _loadPlanForToday();
      final results = await Future.wait([summaryFuture, dashboardFuture, planFuture]);
      final summaryResults = results[0] as List;
      final dash = results[1] as (StrengthMetrics?, double?, int, int, String);
      final planData = results[2] as (ActivePlan?, int?, int?);
      if (!mounted) return;
      setState(() {
        _summary = summaryResults[0] as ClimbingLogSummary?;
        _recommendations = summaryResults[1] as List<ClimbingLogRecommendation>;
        _strengthMetrics = dash.$1;
        _strengthChangePct = dash.$2;
        _xp = dash.$3;
        _streak = dash.$4;
        _recoveryStatus = dash.$5;
        _plan = planData.$1;
        _planCompletedCount = planData.$2;
        _planTotalCount = planData.$3;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _summary == null ? 'Не удалось загрузить данные' : null;
        });
      }
    }
  }

  Future<(ActivePlan?, int?, int?)> _loadPlanForToday() async {
    try {
      final result = await _planApi.getActivePlan();
      final plan = result.plan;
      if (plan == null) return (null, null, null);
      final progress = await _planApi.getPlanProgress(plan.id);
      return (plan, progress?.completed, progress?.total);
    } catch (_) {
      return (null, null, null);
    }
  }

  Future<void> _onRefresh() async {
    await _loadAll();
  }

  Widget _buildPlanProgressChart(BuildContext context) {
    final plan = _plan;
    final total = _planTotalCount;
    if (plan == null || total == null || total == 0) return const SizedBox.shrink();
    final completed = (_planCompletedCount ?? 0).clamp(0, total);
    final segmentCount = total.clamp(1, 60);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlanCalendarScreen(plan: plan, onRefresh: _loadAll),
            ),
          ).then((_) => _loadAll());
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
                    style: unbounded(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mutedGold,
                    ),
                  ),
                  Text(
                    '$completed из $total • ${total > 0 ? ((completed / total) * 100).round() : 0}%',
                    style: unbounded(
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
                  final spacing = 2.0;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: 4,
                    children: List.generate(segmentCount, (i) {
                      final isDone = i < completed;
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
                style: unbounded(fontSize: 11, color: Colors.white38),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _dayWord(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'день';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) return 'дня';
    return 'дней';
  }

  Widget _buildPremiumSection(BuildContext context) {
    final status = widget.premiumStatus;
    final onTap = widget.onPremiumTap!;
    if (status?.hasActiveSubscription == true) {
      final days = status!.subscriptionDaysLeft ?? 0;
      final cancelled = status.subscriptionCancelled;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cancelled
              ? AppColors.graphite.withOpacity(0.5)
              : AppColors.successMuted.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cancelled ? AppColors.graphite : AppColors.successMuted.withOpacity(0.4),
          ),
        ),
        child: Row(
          children: [
            Icon(
              cancelled ? Icons.cancel_outlined : Icons.check_circle_rounded,
              color: cancelled ? Colors.white54 : AppColors.successMuted,
              size: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cancelled ? 'Подписка отменена' : 'Подписка активна',
                    style: unbounded(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    cancelled
                        ? 'Действует до конца периода ($days ${_dayWord(days)})'
                        : 'Осталось $days ${_dayWord(days)}. Спасибо за поддержку!',
                    style: unbounded(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
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
                    style: unbounded(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    status?.isInTrial == true
                        ? 'Пробный период: ${status!.trialDaysLeft} ${_dayWord(status.trialDaysLeft)}'
                        : 'Подписка — доступ ко всем функциям',
                    style: unbounded(
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
    super.build(context);
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
                        style: unbounded(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      if (!_loading && _summary != null && (_summary!.totalSessions) > 0) ...[
                        const SizedBox(height: 16),
                        _buildSummaryCards(context, _summary!),
                        const SizedBox(height: 16),
                      ],
                      if (_plan != null) ...[
                        const SizedBox(height: 12),
                        _buildPlanProgressChart(context),
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
                            style: unbounded(color: Colors.white70),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadAll,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.mutedGold,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Повторить', style: unbounded(fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else ...[
                ..._buildContent(context),
                if (widget.onPremiumTap != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      child: _buildPremiumSection(context),
                    ),
                  ),
              ],
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
                      style: unbounded(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
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
              style: unbounded(
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
            style: unbounded(
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
                  style: unbounded(
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
                  style: unbounded(fontSize: 12, color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Опыт: $_xp',
                style: unbounded(fontSize: 12, color: Colors.white54),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Серия: $_streak ${_dayWord(_streak)}',
                  style: unbounded(fontSize: 12, color: Colors.white54),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
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
            style: unbounded(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Выполните план на сегодня или добавьте тренировку во вкладке «История» — здесь появится сводка и рекомендации.',
            style: unbounded(color: Colors.white70, fontSize: 14),
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
            style: unbounded(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: unbounded(color: Colors.white70, fontSize: 12),
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
                style: unbounded(color: Colors.white70, fontSize: 14),
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
                  style: unbounded(color: Colors.white70, fontSize: 14),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
