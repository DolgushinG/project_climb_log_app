import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/models/PlanModels.dart';
import 'package:login_app/models/ClimbingLog.dart';
import 'package:login_app/models/Workout.dart';
import 'package:login_app/services/TrainingPlanApiService.dart';
import 'package:login_app/services/ClimbingLogService.dart';
import 'package:login_app/services/StrengthTestApiService.dart';
import 'package:login_app/Screens/ExerciseCompletionScreen.dart';
import 'package:login_app/Screens/ClimbingLogAddScreen.dart';

/// Экран плана на день: упражнения, растяжка, кнопка «Выполнено».
class PlanDayScreen extends StatefulWidget {
  final ActivePlan plan;
  final DateTime date;
  final VoidCallback? onCompletedChanged;
  /// Тип сессии из календаря (ofp/sfp), если известен — для понятного сообщения при ошибке.
  final String? expectedSessionType;
  /// Уже загруженные данные дня (от PlanOverviewScreen) — пропускаем getPlanDay.
  final PlanDayResponse? initialDay;

  const PlanDayScreen({
    super.key,
    required this.plan,
    required this.date,
    this.onCompletedChanged,
    this.expectedSessionType,
    this.initialDay,
  });

  @override
  State<PlanDayScreen> createState() => _PlanDayScreenState();
}

class _PlanDayScreenState extends State<PlanDayScreen> {
  final TrainingPlanApiService _api = TrainingPlanApiService();
  final ClimbingLogService _climbingService = ClimbingLogService();
  final StrengthTestApiService _strengthApi = StrengthTestApiService();

  PlanDayResponse? _day;
  HistorySession? _climbingSessionForDate;
  bool _loading = true;
  String? _error;
  /// AI-комментарий из day-coach-comment (подгружается в фоне при light-режиме).
  String? _coachCommentFromAi;
  String? _whyThisSessionFromAi;
  bool _aiCoachAvailableFromAi = false;
  /// Ждём ответ AI — показываем «Анализирую план» вместо rule-based.
  bool _coachCommentLoading = false;
  /// exerciseId → completed для растяжки на эту дату
  Set<String> _stretchingCompletedIds = {};
  /// exerciseId для ОФП/СФП: выполнено / пропущено (для отображения на карточках)
  Set<String> _exerciseCompletedIds = {};
  Set<String> _exerciseSkippedIds = {};

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
      _coachCommentFromAi = null;
      _whyThisSessionFromAi = null;
      _aiCoachAvailableFromAi = false;
      _coachCommentLoading = false;
    });
    PlanDayResponse? day;
    final canUseInitial = widget.initialDay != null &&
        _feeling == null &&
        _focus == null &&
        _availableMinutes == null;
    if (canUseInitial) {
      day = widget.initialDay;
    } else {
      day = await _api.getPlanDay(
        widget.plan.id,
        _dateStr,
        feeling: _feeling,
        focus: _focus,
        availableMinutes: _availableMinutes,
        light: true,
      );
    }
    HistorySession? climbing = null;
    if (day != null && !day.isRest && (day.isClimbing || day.expectsClimbing || widget.plan.includeClimbingInDays)) {
      climbing = await _climbingService.getSessionForDate(_dateStr);
    }
    // Один запрос exercise-completions вместо двух (растяжка + ОФП/СФП)
    final needsCompletions = day != null &&
        (day!.stretching.isNotEmpty || day!.exercises.isNotEmpty);
    final completions = needsCompletions
        ? await _strengthApi.getExerciseCompletions(date: _dateStr)
        : <ExerciseCompletion>[];
    final completionIds = completions.map((c) => c.exerciseId).toSet();
    Set<String> stretchingCompleted = {};
    if (day != null && day!.stretching.isNotEmpty) {
      final ids = day!.stretching.expand((z) => z.exercises.where((e) => e.exerciseId != null).map((e) => e.exerciseId!));
      stretchingCompleted = completionIds.where((id) => ids.contains(id)).toSet();
    }
    Set<String> exerciseCompleted = {};
    Set<String> exerciseSkipped = {};
    if (day != null && day!.exercises.isNotEmpty) {
      final planIds = day!.exercises.asMap().entries.map((e) {
        final ex = e.value;
        return ex.exerciseId ?? 'plan_${e.key}_${ex.name.hashCode.abs()}';
      }).toSet();
      final skips = await _strengthApi.getExerciseSkips(date: _dateStr);
      exerciseCompleted = completionIds.where((id) => planIds.contains(id)).toSet();
      exerciseSkipped = skips.map((s) => s.exerciseId).where((id) => planIds.contains(id)).toSet();
    }
    if (mounted) {
      setState(() {
        _day = day;
        _climbingSessionForDate = climbing;
        _stretchingCompletedIds = stretchingCompleted;
        _exerciseCompletedIds = exerciseCompleted;
        _exerciseSkippedIds = exerciseSkipped;
        _loading = false;
      });
      if (day != null && !day.isRest && !canUseInitial) {
        _loadCoachCommentInBackground();
      }
    }
  }

  void _loadCoachCommentInBackground() {
    setState(() => _coachCommentLoading = true);
    _api.getPlanDayCoachComment(
      widget.plan.id,
      _dateStr,
      feeling: _feeling,
      focus: _focus,
      availableMinutes: _availableMinutes,
    ).then((res) {
      if (!mounted) return;
      setState(() {
        _coachCommentLoading = false;
        if (res != null) {
          _coachCommentFromAi = res.coachComment;
          _whyThisSessionFromAi = res.whyThisSession;
          _aiCoachAvailableFromAi = res.aiCoachAvailable;
        }
      });
    }).catchError((_) {
      if (mounted) setState(() => _coachCommentLoading = false);
    });
  }

  bool get _expectsClimbing =>
      _day != null &&
      !_day!.isRest &&
      (_day!.isClimbing || _day!.expectsClimbing || widget.plan.includeClimbingInDays);

  String? get _effectiveCoachRecommendation =>
      _coachCommentFromAi ?? _day?.coachRecommendation;
  String? get _effectiveWhyThisSession =>
      _whyThisSessionFromAi ?? _day?.whyThisSession;
  bool get _effectiveAiCoachAvailable =>
      (_coachCommentFromAi != null || _whyThisSessionFromAi != null)
          ? _aiCoachAvailableFromAi
          : (_day?.aiCoachAvailable ?? false);

  bool get _hasCoachContent {
    if (_day == null || _day!.isRest) return false;
    if (_coachCommentLoading) return true;
    return (_effectiveCoachRecommendation != null && _effectiveCoachRecommendation!.isNotEmpty) ||
        (_effectiveWhyThisSession != null && _effectiveWhyThisSession!.isNotEmpty);
  }

  Future<void> _toggleComplete() async {
    if (_day == null) return;
    final sessionType = _day!.sessionType;
    if (sessionType == 'rest') return; // ofp, sfp, climbing — можно отмечать

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
                    if (_day!.sessionIntensityModifier != null && _day!.sessionIntensityModifier! < 1.0) ...[
                      const SizedBox(height: 12),
                      _buildIntensityModifierHint(),
                    ],
                    if (_day!.weeklyFatigueWarning != null && _day!.weeklyFatigueWarning!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildWeeklyFatigueWarning(),
                    ],
                    const SizedBox(height: 20),
                    if (_hasCoachContent) ...[
                      _buildAnimatedCoachSection(),
                      const SizedBox(height: 20),
                    ],
                    if (_day!.isRest) ...[
                      _buildRestDay(),
                      if ((_day!.weakLinks ?? []).isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildWeakLinksPreview(),
                      ],
                    ]
                    else if (_day!.isClimbing) ...[
                      _buildClimbingBlock(isClimbingOnly: true),
                      if ((_day!.weakLinks ?? []).isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildWeakLinksPreview(),
                      ],
                      const SizedBox(height: 20),
                      _buildStretching(),
                    ]
                    else ...[
                      if (_expectsClimbing) ...[
                        _buildClimbingBlock(),
                        const SizedBox(height: 20),
                      ],
                      if (_isToday) _buildClarifyButton(),
                      if (_isToday) const SizedBox(height: 16),
                      if ((_day!.weakLinks ?? []).isNotEmpty) ...[
                        _day!.exercises.isEmpty
                            ? _buildWeakLinksPreview()
                            : _buildWeakLinksBlock(),
                        const SizedBox(height: 16),
                      ],
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

  Widget _buildWeeklyFatigueWarning() {
    final text = _day!.weeklyFatigueWarning!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.amber.shade300, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white70, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntensityModifierHint() {
    final mod = _day!.sessionIntensityModifier!;
    final pct = (mod * 100).round();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.mutedGold.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.mutedGold.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.tune, color: AppColors.mutedGold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Компактный вариант (~$pct%): план подстроен под ваши настройки на сегодня (время, самочувствие)',
              style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white70, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  static const _athleteNames = ['Ondra', 'Honnold', 'Garnbret', 'Sharma', 'Mawem', 'Nonaka', 'Narasaki'];

  Widget _buildAnimatedCoachSection() {
    return TweenAnimationBuilder<double>(
      key: ValueKey('coach_$_dateStr'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, value, _) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - value)),
          child: _buildCoachContentSection(),
        ),
      ),
    );
  }

  Widget _buildCoachContentSection() {
    if (_coachCommentLoading) {
      return _buildCoachCommentLoadingCard();
    }
    final coach = _effectiveCoachRecommendation;
    final why = _effectiveWhyThisSession;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (coach != null && coach.isNotEmpty)
          _buildCoachCommentCard(coach, aiCoachAvailable: _effectiveAiCoachAvailable),
        if (why != null && why.isNotEmpty) ...[
          if (coach != null && coach.isNotEmpty) const SizedBox(height: 10),
          _buildWhyThisSessionTap(why),
        ],
      ],
    );
  }

  Widget _buildCoachCommentLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.mutedGold.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.mutedGold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.sports_martial_arts, color: AppColors.mutedGold, size: 20),
              const SizedBox(width: 8),
              Text(
                'От тренера',
                style: GoogleFonts.unbounded(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedGold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.mutedGold,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Анализирую план и подбираю рекомендации…',
                  style: GoogleFonts.unbounded(fontSize: 13, color: Colors.white70, height: 1.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoachCommentCard(String text, {bool aiCoachAvailable = false}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.mutedGold.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.mutedGold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sports_martial_arts, color: AppColors.mutedGold, size: 20),
              const SizedBox(width: 8),
              Text(
                'От тренера',
                style: GoogleFonts.unbounded(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedGold,
                ),
              ),
              if (aiCoachAvailable) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.mutedGold.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.mutedGold.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, color: AppColors.mutedGold, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'AI',
                        style: GoogleFonts.unbounded(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.mutedGold),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          _buildCoachCommentText(text),
        ],
      ),
    );
  }

  /// Текст с подсветкой имён топ-атлетов (Ondra, Honnold, Garnbret и др.)
  Widget _buildCoachCommentText(String text) {
    final baseStyle = GoogleFonts.unbounded(fontSize: 13, color: Colors.white70, height: 1.5);
    final highlightStyle = GoogleFonts.unbounded(fontSize: 13, color: AppColors.mutedGold, height: 1.5, fontWeight: FontWeight.w600);
    final spans = <TextSpan>[];
    int lastEnd = 0;
    final pattern = RegExp(_athleteNames.join(r'|'), caseSensitive: false);
    for (final match in pattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start), style: baseStyle));
      }
      spans.add(TextSpan(text: match.group(0), style: highlightStyle));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: baseStyle));
    }
    if (spans.isEmpty) {
      return Text(text, style: baseStyle);
    }
    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildWhyThisSessionTap(String text) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showWhyThisSessionModal(text),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.linkMuted.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.linkMuted.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline, color: AppColors.linkMuted, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Почему так?',
                  style: GoogleFonts.unbounded(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.linkMuted),
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.linkMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showWhyThisSessionModal(String text) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.5),
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
                Icon(Icons.lightbulb_outline, color: AppColors.linkMuted, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Почему эта тренировка',
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
                  text,
                  style: GoogleFonts.unbounded(fontSize: 14, color: Colors.white70, height: 1.6),
                ),
              ),
            ),
          ],
        ),
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
      case 'climbing':
        label = 'Лазание';
        icon = Icons.route;
        color = AppColors.mutedGold;
        break;
      default:
        label = 'Отдых';
        icon = Icons.spa;
        color = AppColors.successMuted;
    }
    if (_day!.weekNumber != null) label += ' • Неделя ${_day!.weekNumber}';
    if (_day!.estimatedMinutes != null && _day!.estimatedMinutes! > 0) label += ' • ~${_day!.estimatedMinutes} мин';

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

  Widget _buildClimbingBlock({bool isClimbingOnly = false}) {
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
                      isClimbingOnly ? 'Лазание' : '1. Лазание',
                      style: GoogleFonts.unbounded(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    Text(
                      hasSession
                          ? '${session!.gymName} • $routesCount трасс'
                          : isClimbingOnly
                              ? 'Только лазание (без ОФП/СФП)'
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

  /// Блок «Твои слабые места» — кнопка, открывает bottom sheet со списком.
  Widget _buildWeakLinksBlock() {
    if ((_day!.weakLinks ?? []).isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showWeakLinksBottomSheet(),
        icon: Icon(Icons.track_changes, size: 20, color: AppColors.mutedGold),
        label: Text(
          'Твои слабые места',
          style: GoogleFonts.unbounded(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.mutedGold),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.mutedGold.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
        ),
      ),
    );
  }

  void _showWeakLinksBottomSheet() {
    final links = (_day!.weakLinks ?? []);
    if (links.isEmpty) return;
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
                Icon(Icons.track_changes, color: AppColors.mutedGold, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Твои слабые места',
                    style: GoogleFonts.unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Почему они слабые и что делать',
              style: GoogleFonts.unbounded(fontSize: 13, color: Colors.white54),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: links.map((wl) => _buildWeakLinkSheetItem(ctx, wl)).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeakLinkSheetItem(BuildContext ctx, WeakLink wl) {
    final whyText = (wl.reason != null && wl.reason!.isNotEmpty) ? wl.reason! : wl.hint;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.mutedGold.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.mutedGold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.mutedGold, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  wl.labelRu,
                  style: GoogleFonts.unbounded(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.mutedGold),
                ),
              ),
            ],
          ),
          if (whyText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              whyText,
              style: GoogleFonts.unbounded(fontSize: 14, color: Colors.white70, height: 1.5),
            ),
          ],
          if (wl.reason != null && wl.reason!.isNotEmpty && wl.hint.isNotEmpty && wl.hint != wl.reason) ...[
            const SizedBox(height: 8),
            Text(
              'Что делать: ${wl.hint}',
              style: GoogleFonts.unbounded(fontSize: 13, color: AppColors.mutedGold.withOpacity(0.9), height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  /// Для дней rest/climbing без упражнений: кнопка открывает bottom sheet.
  Widget _buildWeakLinksPreview() {
    if ((_day!.weakLinks ?? []).isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showWeakLinksBottomSheet(),
        icon: Icon(Icons.lightbulb_outline, size: 20, color: AppColors.mutedGold),
        label: Text(
          'На что обратить внимание в следующих тренировках',
          style: GoogleFonts.unbounded(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.mutedGold),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.mutedGold.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
        ),
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
          final id = ex.exerciseId ?? 'plan_${e.key}_${ex.name.hashCode.abs()}';
          final completed = _exerciseCompletedIds.contains(id);
          final skipped = _exerciseSkippedIds.contains(id);
          final weakLink = ex.targetsWeakLink != null
              ? (_day!.weakLinks ?? []).where((w) => w.key == ex.targetsWeakLink).firstOrNull
              : null;
          final weakLinkLabel = weakLink?.labelRu;
          return _buildExerciseCard(
            ex,
            e.key + 1,
            completed: completed,
            skipped: skipped,
            weakLinkLabel: weakLinkLabel,
          );
        }),
      ],
    );
  }

  Widget _buildExerciseCard(
    PlanDayExercise ex,
    int index, {
    bool completed = false,
    bool skipped = false,
    String? weakLinkLabel,
  }) {
    final hasWeakLink = weakLinkLabel != null && weakLinkLabel.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: completed || skipped ? AppColors.cardDark.withOpacity(0.8) : AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: completed
              ? AppColors.successMuted.withOpacity(0.4)
              : (skipped ? Colors.white24 : (hasWeakLink ? AppColors.mutedGold.withOpacity(0.4) : AppColors.graphite)),
        ),
        boxShadow: hasWeakLink && !completed && !skipped
            ? [BoxShadow(color: AppColors.mutedGold.withOpacity(0.08), blurRadius: 8, spreadRadius: 0)]
            : null,
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
                  color: completed
                      ? AppColors.successMuted.withOpacity(0.3)
                      : (skipped ? Colors.white12 : AppColors.mutedGold.withOpacity(0.2)),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: completed
                    ? Icon(Icons.check, size: 16, color: AppColors.successMuted)
                    : (skipped
                        ? Icon(Icons.remove_circle_outline, size: 16, color: Colors.white54)
                        : Text(
                            '$index',
                            style: GoogleFonts.unbounded(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.mutedGold),
                          )),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ex.name,
                            style: GoogleFonts.unbounded(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: completed ? Colors.white54 : (skipped ? Colors.white60 : Colors.white),
                              decoration: completed ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        if (weakLinkLabel != null && weakLinkLabel.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.mutedGold.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.mutedGold.withOpacity(0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.track_changes, color: AppColors.mutedGold, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    weakLinkLabel,
                                    style: GoogleFonts.unbounded(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.mutedGold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (skipped)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Пропущено',
                              style: GoogleFonts.unbounded(fontSize: 11, color: Colors.white54),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ex.dosageDisplay,
                      style: GoogleFonts.unbounded(
                        fontSize: 13,
                        color: completed || skipped ? Colors.white38 : AppColors.mutedGold,
                        decoration: completed ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (ex.estimatedMinutes != null && ex.estimatedMinutes! > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.graphite.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule, size: 14, color: Colors.white54),
                            const SizedBox(width: 6),
                            Text(
                              '~${ex.estimatedMinutes} мин',
                              style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                      const SizedBox(height: 6),
                      _buildHintBlock(ex.name, ex.hint!, isCompact: false),
                    ],
                    if (ex.climbingBenefit != null && ex.climbingBenefit!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _ClimbingBenefitRow(text: ex.climbingBenefit!, isCompact: false),
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

  /// Кнопка «Как выполнять» — по нажатию показывается hint в модалке.
  Widget _buildHintBlock(String exerciseName, String hint, {bool isCompact = false}) {
    final iconSize = isCompact ? 12.0 : 14.0;
    final fontSize = isCompact ? 11.0 : 12.0;
    return InkWell(
      onTap: () => _showHintModal(exerciseName, hint),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.help_outline, size: iconSize, color: AppColors.linkMuted),
            const SizedBox(width: 6),
            Text(
              'Как выполнять',
              style: GoogleFonts.unbounded(fontSize: fontSize, color: AppColors.linkMuted, fontWeight: FontWeight.w500),
            ),
          ],
        ),
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
    final totalMins = _day!.stretchingEstimatedMinutes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Растяжка',
              style: GoogleFonts.unbounded(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white54),
            ),
            if (totalMins != null && totalMins > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.graphite.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule, size: 12, color: Colors.white54),
                    const SizedBox(width: 4),
                    Text(
                      '~$totalMins мин',
                      style: GoogleFonts.unbounded(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ],
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
                  const SizedBox(height: 8),
                  ...z.exercises.map((ex) => _buildStretchingExerciseTile(ex)),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildStretchingExerciseTile(PlanStretchingExercise ex) {
    final completed = ex.exerciseId != null && _stretchingCompletedIds.contains(ex.exerciseId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (ex.exerciseId != null)
                Padding(
                  padding: const EdgeInsets.only(right: 10, top: 2),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: completed,
                      onChanged: (v) => _toggleStretchingCompletion(ex.exerciseId!, v ?? false),
                      activeColor: AppColors.mutedGold,
                      fillColor: WidgetStateProperty.resolveWith((_) =>
                          completed ? AppColors.mutedGold : AppColors.graphite),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text('•', style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white54)),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ex.name,
                      style: GoogleFonts.unbounded(
                        fontSize: 13,
                        color: completed ? Colors.white54 : Colors.white70,
                        decoration: completed ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (ex.estimatedMinutes != null && ex.estimatedMinutes! > 0) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.graphite.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule, size: 12, color: Colors.white54),
                            const SizedBox(width: 4),
                            Text(
                              '~${ex.estimatedMinutes} мин',
                              style: GoogleFonts.unbounded(fontSize: 11, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (ex.hint != null && ex.hint!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _buildHintBlock(ex.name, ex.hint!, isCompact: true),
                    ],
                    if (ex.climbingBenefit != null && ex.climbingBenefit!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _ClimbingBenefitRow(text: ex.climbingBenefit!, isCompact: true),
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

  Future<void> _toggleStretchingCompletion(String exerciseId, bool completed) async {
    if (completed) {
      final id = await _strengthApi.saveExerciseCompletion(
        date: _dateStr,
        exerciseId: exerciseId,
        setsDone: 1,
      );
      if (mounted && id != null) {
        setState(() => _stretchingCompletedIds = {..._stretchingCompletedIds, exerciseId});
      }
    } else {
      final completions = await _strengthApi.getExerciseCompletions(date: _dateStr);
      final list = completions.where((x) => x.exerciseId == exerciseId).toList();
      if (list.isNotEmpty) {
        await _strengthApi.deleteExerciseCompletion(list.first.id);
        if (mounted) {
          setState(() => _stretchingCompletedIds = {..._stretchingCompletedIds}..remove(exerciseId));
        }
      }
    }
  }

  List<MapEntry<String, WorkoutBlockExercise>> _planDayToWorkoutEntries() {
    if (_day == null || _day!.exercises.isEmpty) return [];
    final sessionType = _day!.sessionType;
    final category = sessionType == 'sfp' ? 'sfp' : 'ofp';
    final blockKey = sessionType == 'sfp' ? 'sfp' : (sessionType == 'ofp' ? 'ofp' : 'plan');
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
    final stretching = _day!.stretching.expand((z) => z.exercises).toList();
    final completed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseCompletionScreen(
          workoutExerciseEntries: entries,
          stretchingFromPlan: stretching,
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
  static const _timeOptions = [15, 30, 45, 60, 90];

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

/// Сворачиваемый блок «Польза для скалолазания» на карточке упражнения.
class _ClimbingBenefitRow extends StatefulWidget {
  final String text;
  final bool isCompact;

  const _ClimbingBenefitRow({required this.text, this.isCompact = false});

  @override
  State<_ClimbingBenefitRow> createState() => _ClimbingBenefitRowState();
}

class _ClimbingBenefitRowState extends State<_ClimbingBenefitRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final iconSize = widget.isCompact ? 12.0 : 14.0;
    final fontSize = widget.isCompact ? 11.0 : 12.0;
    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.route, size: iconSize, color: AppColors.mutedGold.withOpacity(0.8)),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Польза для скалолазания',
                        style: GoogleFonts.unbounded(
                          fontSize: fontSize,
                          color: AppColors.linkMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: iconSize + 2,
                        color: AppColors.linkMuted,
                      ),
                    ],
                  ),
                  if (_expanded) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.text,
                      style: GoogleFonts.unbounded(
                        fontSize: fontSize,
                        color: AppColors.mutedGold.withOpacity(0.9),
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
