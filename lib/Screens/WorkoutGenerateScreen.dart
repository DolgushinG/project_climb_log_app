import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:login_app/main.dart';
import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/models/ClimbingLog.dart';
import 'package:login_app/models/StrengthAchievement.dart';
import 'package:login_app/models/Workout.dart';
import 'package:login_app/services/StrengthTestApiService.dart';
import 'package:login_app/services/StrengthDashboardService.dart';
import 'package:login_app/services/ClimbingLogService.dart';
import 'package:login_app/services/TrainingDisclaimerService.dart';
import 'package:login_app/Screens/WorkoutResultScreen.dart';

/// Экран генерации тренировки через API workout/generate.
class WorkoutGenerateScreen extends StatefulWidget {
  const WorkoutGenerateScreen({super.key});

  @override
  State<WorkoutGenerateScreen> createState() => _WorkoutGenerateScreenState();
}

class _WorkoutGenerateScreenState extends State<WorkoutGenerateScreen>
    with SingleTickerProviderStateMixin {
  int _userLevel = 2;
  String _goal = 'max_strength';
  int _availableTime = 75;
  int _experienceMonths = 12;
  final List<String> _injuries = [];
  int? _minPullups;

  bool _loading = false;
  WeeklyFatigueResponse? _weeklyFatigue;
  String? _error;
  final TrainingDisclaimerService _disclaimerService = TrainingDisclaimerService();
  bool _disclaimerAcknowledged = false;
  bool _disclaimerChecked = false;
  final ScrollController _scrollController = ScrollController();
  AnimationController? _loaderController;

  static const _goals = [
    ('max_strength', 'Макс. сила'),
    ('hypertrophy', 'Гипертрофия'),
    ('endurance', 'Выносливость'),
  ];

  bool get _hasLevelExperienceMismatch =>
      _userLevel >= 4 && _experienceMonths < 6;

  static const _levelLabels = {
    1: 'новичок',
    2: 'начальный',
    3: 'средний',
    4: 'продвинутый',
    5: 'опытный',
  };

  @override
  void initState() {
    super.initState();
    _loadWeeklyFatigue();
    _loadDisclaimerStatus();
  }

  Future<void> _loadDisclaimerStatus() async {
    final ack = await _disclaimerService.isAcknowledged();
    if (mounted) setState(() => _disclaimerAcknowledged = ack);
  }

  bool get _canGenerate => _disclaimerAcknowledged || _disclaimerChecked;

  @override
  void dispose() {
    _loaderController?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadWeeklyFatigue() async {
    final f = await StrengthTestApiService().getWeeklyFatigue();
    if (mounted) setState(() => _weeklyFatigue = f);
  }

  Future<void> _generate() async {
    if (!_disclaimerAcknowledged) {
      await _disclaimerService.acknowledge();
      if (mounted) setState(() => _disclaimerAcknowledged = true);
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final dayOffset = DateTime.now().weekday % 7;
    FatigueData? fatigueData;
    UserProfile? userProfile;
    PerformanceMetrics? perfMetrics;
    RecentClimbingData? climbingData;
    String? currentPhase;

    if (_weeklyFatigue != null) {
      fatigueData = FatigueData(
        weeklyFatigueSum: _weeklyFatigue!.weeklyFatigueSum,
        fatigueTrend: 'stable',
      );
    }
    final metricsSummary = await Future.wait([
      StrengthDashboardService().getLastMetrics(),
      ClimbingLogService().getSummary(period: 'all'),
    ]);
    final metrics = metricsSummary[0] as StrengthMetrics?;
    final summary = metricsSummary[1] as ClimbingLogSummary?;
    if (metrics != null && metrics.bodyWeightKg != null && metrics.bodyWeightKg! > 0) {
      userProfile = UserProfile(bodyweight: metrics.bodyWeightKg!);
      perfMetrics = PerformanceMetrics(
        deadHangSeconds: metrics.lockOffSec,
        maxPullups: _minPullups,
      );
    }
    if (summary != null) {
      climbingData = RecentClimbingData(
        sessionsLast7Days: summary.sessionsThisWeek,
        averageGrade: summary.maxGrade,
      );
    }

    final req = GenerateWorkoutRequest(
      userLevel: _userLevel,
      goal: _goal,
      injuries: List.from(_injuries),
      availableTimeMinutes: _availableTime,
      experienceMonths: _experienceMonths,
      minPullups: _minPullups,
      dayOffset: dayOffset,
      userProfile: userProfile,
      performanceMetrics: perfMetrics,
      recentClimbingData: climbingData,
      fatigueData: fatigueData,
      currentPhase: currentPhase,
    );
    final api = StrengthTestApiService();
    final minDelay = Future.delayed(const Duration(milliseconds: 2500));
    final apiCall = api.generateWorkout(req);
    final res = await Future.wait([apiCall, minDelay]).then((r) => r[0] as WorkoutGenerateResponse?);
    if (mounted) {
      _loaderController?.stop(canceled: false);
      setState(() {
        _loading = false;
        _error = res == null ? 'Не удалось сгенерировать тренировку' : null;
      });
      if (res != null) {
        _loadWeeklyFatigue();
        final result = await Navigator.push<GeneratedWorkoutResult>(
          context,
          MaterialPageRoute(builder: (_) => WorkoutResultScreen(workout: res)),
        );
        if (!mounted) return;
        if (result != null && result.entries.isNotEmpty) {
          Navigator.pop(context, result);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.anthracite,
      appBar: AppBar(
        backgroundColor: AppColors.anthracite,
        title: Text(
          'Сгенерировать тренировку',
          style: GoogleFonts.unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildIntroHint(),
            if (_weeklyFatigue != null) ...[
              const SizedBox(height: 16),
              _buildWeeklyFatigueCard(),
            ],
            const SizedBox(height: 20),
            if (_loading) _buildThematicLoader() else _buildForm(),
            if (!_loading) const SizedBox(height: 24),
            if (_error != null) ...[
              Text(_error!, style: GoogleFonts.unbounded(color: Colors.orange)),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildThematicLoader() {
    _loaderController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _loaderController!,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  Transform.rotate(
                    angle: _loaderController!.value * 2 * 3.14159,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.mutedGold.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: CustomPaint(
                        painter: _ArcLoaderPainter(
                          progress: _loaderController!.value,
                          color: AppColors.mutedGold,
                        ),
                      ),
                    ),
                  ),
                  Icon(Icons.fitness_center, color: AppColors.mutedGold, size: 36),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Генерируем план...',
            style: GoogleFonts.unbounded(
              fontSize: 14,
              color: Colors.white54,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Подбираем упражнения под ваш уровень',
            style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroHint() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.graphite),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: AppColors.mutedGold, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Персональный план',
                  style: GoogleFonts.unbounded(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Укажите уровень, цель и доступное время — алгоритм соберёт тренировку из разминки, основного блока, антагонистов, кора и заминки.',
                  style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white54, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyFatigueCard() {
    final f = _weeklyFatigue!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.graphite),
      ),
      child: Row(
        children: [
          Icon(Icons.insights, color: AppColors.linkMuted, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Недельная нагрузка: ${f.weeklyFatigueSum}${f.maxRecommended != null ? ' / ${f.maxRecommended}' : ''}',
                        style: GoogleFonts.unbounded(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.help_outline, color: AppColors.linkMuted, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () => _showHint(
                        context,
                        'Недельная нагрузка',
                        'Суммарная усталость от тренировок за текущую неделю. '
                        'Если значение близко к лимиту — снизьте интенсивность или добавьте день отдыха. '
                        'Это помогает избежать перетренированности.',
                      ),
                    ),
                  ],
                ),
                if (f.warning != null)
                  Text(
                    f.warning!,
                    style: GoogleFonts.unbounded(fontSize: 12, color: Colors.orange),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningCard(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.unbounded(fontSize: 13, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  void _showHint(BuildContext context, String title, String text) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: GoogleFonts.unbounded(color: Colors.white, fontSize: 16)),
        content: Text(
          text,
          style: GoogleFonts.unbounded(fontSize: 14, color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Понятно', style: GoogleFonts.unbounded(color: AppColors.mutedGold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimerBlock() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.graphite),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange.shade300, size: 20),
              const SizedBox(width: 8),
              Text(
                'Важная информация',
                style: GoogleFonts.unbounded(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Рекомендации и тренировки носят исключительно информационный характер и не являются медицинской или профессиональной консультацией. '
            'При травмах, болях или сомнениях проконсультируйтесь с врачом или тренером. '
            'Вы самостоятельно несёте ответственность за нагрузку и технику выполнения. Силовые тренировки несут риск травм.',
            style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white70, height: 1.5),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _disclaimerChecked,
            onChanged: (v) => setState(() => _disclaimerChecked = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.mutedGold,
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              'Ознакомлен(а), принимаю',
              style: GoogleFonts.unbounded(fontSize: 13, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMismatchWarning() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.amber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Уровень и опыт не совпадают',
                  style: GoogleFonts.unbounded(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Выбран высокий уровень (${_levelLabels[_userLevel]}) при стаже $_experienceMonths мес. '
                  'Алгоритм учтёт оба параметра и подберёт компромисс — возможно, менее интенсивную версию для вашего стажа.',
                  style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _formLabel(String label, String hint, String longHint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white54)),
                Text(
                  hint,
                  style: GoogleFonts.unbounded(fontSize: 11, color: Colors.white38),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.help_outline, color: AppColors.linkMuted, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => _showHint(context, label, longHint),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.graphite),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _formLabel(
            'Уровень (1–5)',
            'Сложность и объём упражнений',
            '1 — новичок, 2 — начальный, 3 — средний, 4 — продвинутый, 5 — опытный. '
            'Влияет на подбор упражнений и рекомендуемое количество подходов.',
          ),
          Slider(
            value: _userLevel.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            activeColor: AppColors.mutedGold,
            onChanged: (v) => setState(() => _userLevel = v.round()),
          ),
          Text(
            '$_userLevel — ${_levelLabels[_userLevel] ?? ''}',
            style: GoogleFonts.unbounded(fontSize: 16, color: Colors.white),
          ),
          const SizedBox(height: 16),
          _formLabel(
            'Цель',
            'Фокус тренировки',
            'Макс. сила — работа на пределе, мало повторов (3–6), длинный отдых (2–3 мин). '
            'Гипертрофия — рост мышц, средние повторы (8–12), отдых 60–90 сек. '
            'Выносливость — много повторов (15+), короткий отдых.',
          ),
          Wrap(
            spacing: 8,
            children: _goals.map((e) {
              final selected = _goal == e.$1;
              return ChoiceChip(
                label: Text(e.$2, style: GoogleFonts.unbounded(fontSize: 12)),
                selected: selected,
                onSelected: (_) => setState(() => _goal = e.$1),
                selectedColor: AppColors.mutedGold.withOpacity(0.4),
                backgroundColor: AppColors.rowAlt,
                labelStyle: TextStyle(color: selected ? AppColors.mutedGold : Colors.white70),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _formLabel(
            'Время (мин)',
            'Планируемая длительность',
            'Алгоритм подберёт количество и сложность упражнений под заданное время. '
            '30–45 мин — короткая, 60–75 — стандартная, 90+ — расширенная тренировка.',
          ),
          Slider(
            value: _availableTime.toDouble(),
            min: 30,
            max: 120,
            divisions: 9,
            activeColor: AppColors.mutedGold,
            onChanged: (v) => setState(() => _availableTime = v.round()),
          ),
          Text('$_availableTime мин', style: GoogleFonts.unbounded(fontSize: 16, color: Colors.white)),
          const SizedBox(height: 16),
          _formLabel(
            'Опыт (мес)',
            'Стаж систематических тренировок',
            'Сколько месяцев вы регулярно тренируетесь. Помогает подобрать прогрессию и нагрузку: '
            'новички получают более щадящие схемы, опытные — более интенсивные.',
          ),
          Slider(
            value: _experienceMonths.toDouble(),
            min: 1,
            max: 60,
            divisions: 59,
            activeColor: AppColors.mutedGold,
            onChanged: (v) => setState(() => _experienceMonths = v.round()),
          ),
          Text('$_experienceMonths мес', style: GoogleFonts.unbounded(fontSize: 16, color: Colors.white)),
          if (_hasLevelExperienceMismatch) ...[
            const SizedBox(height: 12),
            _buildMismatchWarning(),
          ],
          if (!_disclaimerAcknowledged) ...[
            const SizedBox(height: 24),
            _buildDisclaimerBlock(),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_loading || !_canGenerate) ? null : _generate,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.mutedGold,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      'Сгенерировать',
                      style: GoogleFonts.unbounded(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

}

class _ArcLoaderPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ArcLoaderPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 3.0;
    final rect = Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2,
        size.width - strokeWidth, size.height - strokeWidth);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final sweepAngle = 2.5 * 3.14159;
    final startAngle = -3.14159 / 2 + progress * 2 * 3.14159;
    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(covariant _ArcLoaderPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
