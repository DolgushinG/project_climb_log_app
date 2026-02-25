import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/models/Workout.dart';
import 'package:login_app/services/StrengthTestApiService.dart';
import 'package:login_app/Screens/ExerciseCompletionScreen.dart';

/// Экран результата генерации — комментарии тренера закреплены сверху, блоки скроллятся внизу.
class WorkoutResultScreen extends StatelessWidget {
  final WorkoutGenerateResponse workout;

  const WorkoutResultScreen({super.key, required this.workout});

  static const _sectionBlocks = {
    'Разминка': ['warmup'],
    'СФП (план)': ['main', 'secondary'],
    'ОФП': ['antagonist', 'core'],
    'Растяжка': ['cooldown'],
  };

  static const _blockHints = {
    'warmup': 'Разминка — подготовка мышц и суставов к работе, разогрев.',
    'main': 'Основной блок — ключевые упражнения под вашу цель (сила/гипертрофия/выносливость).',
    'secondary': 'Дополнительно — вспомогательные движения для баланса нагрузки.',
    'antagonist': 'Антагонисты — мышцы-антагонисты тянущих (например, отжимания при фокусе на спину).',
    'core': 'Кор — укрепление корпуса, стабилизация.',
    'cooldown': 'Заминка — расслабление, восстановление пульса и дыхания.',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.anthracite,
      appBar: AppBar(
        backgroundColor: AppColors.anthracite,
        title: Text(
          'Тренировка готова',
          style: unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 90),
              children: [
                if (_hasCoachContent) ...[
                  _buildAnimatedCoachSection(context),
                  const SizedBox(height: 20),
                ],
                if (workout.weeklyFatigueWarning != null) ...[
                  _buildWarningCard(workout.weeklyFatigueWarning!),
                  const SizedBox(height: 12),
                ],
                ...workout.warnings.map((w) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildWarningCard(w),
                )),
                if (workout.warnings.isNotEmpty) const SizedBox(height: 12),
                _buildWorkoutBlocks(context),
              ],
            ),
          ),
          _buildBottomButton(context),
        ],
      ),
    );
  }

  bool get _hasCoachContent =>
      workout.coachComment != null ||
      workout.whyThisSession != null ||
      workout.intensityExplanation != null ||
      (workout.loadDistribution != null && workout.loadDistribution!.isNotEmpty) ||
      (workout.weeklyLoadDistribution != null && workout.weeklyLoadDistribution!.hasAny) ||
      workout.progressionHint != null ||
      workout.sessionStimulus != null ||
      workout.athleteState != null;

  static const _athleteNames = ['Ondra', 'Honnold', 'Garnbret', 'Sharma', 'Mawem', 'Nonaka', 'Narasaki'];

  Widget _buildAnimatedCoachSection(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, value, _) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - value)),
          child: _buildCoachSection(context),
        ),
      ),
    );
  }

  Widget _buildCoachSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (workout.coachComment != null) ...[
          _buildCoachCommentCard(),
          const SizedBox(height: 12),
        ],
        if (workout.intensityExplanation != null) ...[
          _buildIntensityExplanationCard(),
          const SizedBox(height: 12),
        ],
        if (workout.whyThisSession != null) ...[
          _buildWhyThisSessionTap(context),
          const SizedBox(height: 12),
        ],
        if (workout.loadDistribution != null && workout.loadDistribution!.isNotEmpty) ...[
          _buildLoadDistributionCard(),
          const SizedBox(height: 12),
        ],
        if (workout.weeklyLoadDistribution != null && workout.weeklyLoadDistribution!.hasAny) ...[
          _buildWeeklyLoadDistributionCard(),
          const SizedBox(height: 12),
        ],
        if (workout.sessionStimulus != null) ...[
          _buildSessionStimulusCard(),
          const SizedBox(height: 12),
        ],
        if (workout.athleteState != null) ...[
          _buildAthleteStateCard(),
          const SizedBox(height: 12),
        ],
        if (workout.progressionHint != null) _buildProgressionHintCard(),
      ],
    );
  }

  Widget _buildIntensityExplanationCard() {
    final text = workout.intensityExplanation!;
    return Container(
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
            children: [
              Icon(Icons.speed, color: AppColors.mutedGold, size: 18),
              const SizedBox(width: 8),
              Text(
                'Почему такая интенсивность',
                style: unbounded(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedGold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: unbounded(fontSize: 13, color: Colors.white70, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachCommentCard() {
    final text = workout.coachComment!;
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
                style: unbounded(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedGold,
                ),
              ),
              if (workout.aiCoachAvailable) ...[
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
                        style: unbounded(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.mutedGold),
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

  Widget _buildCoachCommentText(String text) {
    final baseStyle = unbounded(fontSize: 13, color: Colors.white70, height: 1.5);
    final highlightStyle = unbounded(fontSize: 13, color: AppColors.mutedGold, height: 1.5, fontWeight: FontWeight.w600);
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

  Widget _buildWhyThisSessionTap(BuildContext context) {
    final text = workout.whyThisSession!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showWhyThisSessionModal(context, text),
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
                  style: unbounded(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.linkMuted),
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.linkMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showWhyThisSessionModal(BuildContext context, String text) {
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
                    style: unbounded(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
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
                  style: unbounded(fontSize: 14, color: Colors.white70, height: 1.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadDistributionCard() {
    final ld = workout.loadDistribution!;
    final labels = {'finger': 'Пальцы', 'endurance': 'Выносливость', 'strength': 'Сила', 'mobility': 'Мобильность'};
    final entries = ld.entries.where((e) => e.value > 0).toList();
    if (entries.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.graphite),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Распределение нагрузки',
            style: unbounded(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 10),
          ...entries.map((e) {
            final label = labels[e.key] ?? e.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: unbounded(fontSize: 11, color: Colors.white70),
                    softWrap: true,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: (e.value / 100).clamp(0.0, 1.0),
                          backgroundColor: AppColors.graphite,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.mutedGold),
                          minHeight: 5,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${e.value}%',
                        style: unbounded(fontSize: 11, color: Colors.white54),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProgressionHintCard() {
    final text = workout.progressionHint!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.linkMuted.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.linkMuted.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: AppColors.linkMuted, size: 18),
              const SizedBox(width: 8),
              Text(
                'Прогрессия',
                style: unbounded(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.linkMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: unbounded(fontSize: 13, color: Colors.white70, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyLoadDistributionCard() {
    final wld = workout.weeklyLoadDistribution!;
    final labels = {'finger': 'Пальцы', 'endurance': 'Выносливость', 'strength': 'Сила', 'mobility': 'Мобильность'};
    final entries = <MapEntry<String, int>>[];
    if ((wld.finger ?? 0) > 0) entries.add(MapEntry('finger', wld.finger!));
    if ((wld.endurance ?? 0) > 0) entries.add(MapEntry('endurance', wld.endurance!));
    if ((wld.strength ?? 0) > 0) entries.add(MapEntry('strength', wld.strength!));
    if ((wld.mobility ?? 0) > 0) entries.add(MapEntry('mobility', wld.mobility!));
    if (entries.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.graphite),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Распределение нагрузки за неделю',
            style: unbounded(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 10),
          ...entries.map((e) {
            final label = labels[e.key] ?? e.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: unbounded(fontSize: 11, color: Colors.white70),
                    softWrap: true,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: (e.value / 100).clamp(0.0, 1.0),
                          backgroundColor: AppColors.graphite,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.mutedGold),
                          minHeight: 5,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${e.value}%',
                        style: unbounded(fontSize: 11, color: Colors.white54),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSessionStimulusCard() {
    final ss = workout.sessionStimulus!;
    final rows = <Widget>[];
    final items = [
      ('finger_load', ss.fingerLoad, 'Пальцы'),
      ('pull_strength_load', ss.pullStrengthLoad, 'Тяга'),
      ('power_load', ss.powerLoad, 'Мощность'),
      ('endurance_load', ss.enduranceLoad, 'Выносливость'),
      ('core_load', ss.coreLoad, 'Кор'),
      ('cns_stress', ss.cnsStress, 'ЦНС'),
    ];
    for (final t in items) {
      if (t.$2 != null && t.$2! > 0) {
        final v = t.$2!;
        final display = v <= 1 ? '${(v * 100).round()}%' : v.toStringAsFixed(1);
        rows.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t.$3, style: unbounded(fontSize: 11, color: Colors.white70)),
              Text(
                display,
                style: unbounded(fontSize: 11, color: AppColors.mutedGold),
              ),
            ],
          ),
        ));
      }
    }
    if (ss.sessionLoadScore != null) {
      rows.add(Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Интенсивность', style: unbounded(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
            Text(
              '${ss.sessionLoadScore!.toStringAsFixed(1)}/5',
              style: unbounded(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.mutedGold),
            ),
          ],
        ),
      ));
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.graphite),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Профиль сессии',
            style: unbounded(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }

  Widget _buildAthleteStateCard() {
    final ast = workout.athleteState!;
    final rows = <Widget>[];
    if (ast.formScore != null) {
      rows.add(_athleteStateRow('Форма', '${(ast.formScore! * 100).round()}%'));
    }
    if (ast.fatigueScore != null) {
      rows.add(_athleteStateRow('Усталость', '${(ast.fatigueScore! * 100).round()}%'));
    }
    if (ast.injuryRisk != null && ast.injuryRisk! > 0) {
      rows.add(_athleteStateRow('Риск травм', '${(ast.injuryRisk! * 100).round()}%'));
    }
    if (ast.progressTrend != null && ast.progressTrend!.isNotEmpty) {
      rows.add(_athleteStateRow('Прогресс', ast.progressTrend!));
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardDark.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.graphite),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person, color: AppColors.mutedGold, size: 18),
              const SizedBox(width: 8),
              Text(
                'Состояние атлета',
                style: unbounded(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }

  Widget _athleteStateRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: unbounded(fontSize: 11, color: Colors.white70)),
          Text(value, style: unbounded(fontSize: 11, color: AppColors.mutedGold)),
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
        border: Border.all(color: Colors.orange.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber, color: Colors.orange, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: unbounded(fontSize: 13, color: Colors.white70, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutBlocks(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Тренировка',
              style: unbounded(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ..._sectionBlocks.entries.map((section) {
          final blockKeys = section.value;
          final items = <Widget>[];
          for (final key in blockKeys) {
            final ex = workout.blocks[key];
            if (ex != null) {
              items.add(Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildBlockCard(context, ex, key),
              ));
            }
          }
          if (items.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(section.key, items.length),
                const SizedBox(height: 10),
                ...items,
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.mutedGold.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.mutedGold.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            title == 'Разминка' ? Icons.whatshot :
            title.startsWith('СФП') ? Icons.rocket_launch :
            title == 'ОФП' ? Icons.fitness_center :
            Icons.self_improvement,
            color: AppColors.mutedGold,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: unbounded(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.mutedGold),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.graphite,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$count',
              style: unbounded(fontSize: 12, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockCard(BuildContext context, WorkoutBlockExercise ex, String blockKey) {
    final title = workout.blockTitleRu(blockKey);
    final hint = _blockHints[blockKey];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.mutedGold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fitness_center, color: AppColors.mutedGold, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: unbounded(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedGold,
                  ),
                ),
              ),
              if (hint != null)
                IconButton(
                  icon: Icon(Icons.info_outline, color: AppColors.linkMuted, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => _showHint(context, title, hint),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            ex.displayName,
            style: unbounded(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            '${ex.defaultSets} × ${ex.repsDisplay} • отдых ${ex.restDisplay}',
            style: unbounded(fontSize: 13, color: Colors.white54),
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
        title: Text(title, style: unbounded(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        content: Text(text, style: unbounded(fontSize: 14, color: Colors.white70, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Понятно', style: unbounded(color: AppColors.mutedGold)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.anthracite,
        border: Border(top: BorderSide(color: AppColors.graphite)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => _onStartWorkoutPressed(context),
          icon: const Icon(Icons.play_arrow, size: 20),
          label: Text(
            'Выполнить упражнения',
            style: unbounded(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.successMuted,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Future<void> _onStartWorkoutPressed(BuildContext context) async {
    final entries = workout.orderedBlocks
        .where((e) => e.value != null)
        .map((e) => MapEntry(e.key, e.value!))
        .toList();
    final today = DateTime.now();
    final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final completions = await StrengthTestApiService().getExerciseCompletions(date: dateKey);
    final hasCompletions = completions.isNotEmpty;

    if (hasCompletions && context.mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Новый план',
            style: unbounded(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          content: Text(
            'У вас отмечено ${completions.length} ${_exerciseWord(completions.length)} за сегодня. '
            'Сгенерированная тренировка — это другой набор. Отметки будут сброшены, начнёте с чистого листа. Продолжить?',
            style: unbounded(fontSize: 14, color: Colors.white70, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Отмена', style: unbounded(color: Colors.white54)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.mutedGold),
              child: Text('Продолжить', style: unbounded(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;

      final api = StrengthTestApiService();
      for (final c in completions) {
        await api.deleteExerciseCompletion(c.id);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('exercises_all_done_$dateKey');
      await ExerciseCompletionScreen.clearCacheForToday();
    }

    if (!context.mounted) return;
    Navigator.pop(context, GeneratedWorkoutResult(
      entries: entries,
      coachComment: workout.coachComment,
      loadDistribution: workout.loadDistribution,
      progressionHint: workout.progressionHint,
    ));
  }

  String _exerciseWord(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'упражнение';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) return 'упражнения';
    return 'упражнений';
  }
}
