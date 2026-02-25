import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/models/StrengthAchievement.dart';
import 'package:login_app/models/TrainingPlan.dart';
import 'package:login_app/services/TrainingPlanGenerator.dart';
import 'package:login_app/services/StrengthTestApiService.dart';
import 'package:login_app/Screens/ExerciseCompletionScreen.dart';

/// Экран «Генератор плана» — персонализированная программа на основе замеров.
class TrainingPlanScreen extends StatefulWidget {
  final StrengthMetrics metrics;

  const TrainingPlanScreen({super.key, required this.metrics});

  @override
  State<TrainingPlanScreen> createState() => _TrainingPlanScreenState();
}

class _TrainingPlanScreenState extends State<TrainingPlanScreen> {
  List<CatalogExercise> _ofpExercises = [];
  String _userLevel = 'intermediate';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _savePlanToApi());
    _loadOfp();
  }

  String _computeLevel(StrengthMetrics m) {
    final bw = m.bodyWeightKg;
    if (bw == null || bw <= 0) return 'intermediate';
    final list = <double>[];
    if (m.fingerBestPct != null) list.add(m.fingerBestPct!);
    if (m.pinchPct != null) list.add(m.pinchPct!);
    if (m.pull1RmPct != null) list.add(m.pull1RmPct!);
    if (m.lockOffSec != null && m.lockOffSec! > 0) {
      list.add((m.lockOffSec! / 30.0) * 100);
    }
    if (list.isEmpty) return 'intermediate';
    final avg = list.reduce((a, b) => a + b) / list.length;
    if (avg < 40) return 'novice';
    if (avg >= 65) return 'pro';
    return 'intermediate';
  }

  Future<void> _loadOfp() async {
    final api = StrengthTestApiService();
    final strengthLevel = await api.getStrengthLevel();
    final level = strengthLevel?.level ?? _computeLevel(widget.metrics);
    var list = await api.getExercises(level: level, category: 'ofp');
    if (list.isEmpty && level != 'intermediate') {
      list = await api.getExercises(level: 'intermediate', category: 'ofp');
    }
    if (mounted) {
      setState(() {
        _ofpExercises = list;
        _userLevel = level;
      });
    }
  }

  Future<void> _savePlanToApi() async {
    final generator = TrainingPlanGenerator();
    final analysis = generator.analyzeWeakLink(widget.metrics);
    final plan = generator.generatePlan(widget.metrics, analysis);
    await StrengthTestApiService().saveTrainingPlan(plan);
  }

  @override
  Widget build(BuildContext context) {
    final generator = TrainingPlanGenerator();
    final analysis = generator.analyzeWeakLink(widget.metrics);
    final plan = generator.generatePlan(widget.metrics, analysis);
    final radarData = generator.prepareRadarData(widget.metrics);

    return Scaffold(
      backgroundColor: AppColors.anthracite,
      appBar: AppBar(
        backgroundColor: AppColors.anthracite,
        title: Text(
          'План под твои замеры',
          style: unbounded(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionHeader('Что делать на тренировке'),
              const SizedBox(height: 12),
              _buildCoachTipCard(plan.coachTip),
              const SizedBox(height: 20),
              _buildDrillsCard(plan),
              const SizedBox(height: 20),
              if (analysis.protocols.isNotEmpty) ...[
                _buildProtocolSummary(analysis),
                const SizedBox(height: 20),
              ],
              if (_ofpExercises.isNotEmpty) ...[
                _buildOfpCard(),
                const SizedBox(height: 20),
              ],
              _buildRadarChart(radarData),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: unbounded(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    );
  }

  Widget _buildCoachTipCard(String? tip) {
    if (tip == null || tip.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.mutedGold.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: AppColors.mutedGold, size: 20),
              const SizedBox(width: 8),
              Text(
                'Зачем это',
                style: unbounded(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedGold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            tip,
            style: unbounded(
              fontSize: 14,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarChart(StrengthRadarData radarData) {
    final userEntries = radarData.userValues.map((v) => RadarEntry(value: v)).toList();
    final targetEntries = radarData.targetValues.map((v) => RadarEntry(value: v)).toList();

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
          Text(
            'Ты vs эталон 7b',
            style: unbounded(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 260,
            child: RadarChart(
              RadarChartData(
                dataSets: [
                  RadarDataSet(
                    fillColor: AppColors.mutedGold.withOpacity(0.15),
                    borderColor: AppColors.mutedGold,
                    borderWidth: 2,
                    dataEntries: userEntries,
                    entryRadius: 4,
                  ),
                  RadarDataSet(
                    fillColor: Colors.white.withOpacity(0.05),
                    borderColor: Colors.white54,
                    borderWidth: 1.5,
                    dataEntries: targetEntries,
                    entryRadius: 2,
                  ),
                ],
                radarBackgroundColor: Colors.transparent,
                borderData: FlBorderData(show: false),
                radarBorderData: const BorderSide(color: Colors.transparent),
                titlePositionPercentageOffset: 0.18,
                titleTextStyle: unbounded(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                getTitle: (index, angle) {
                  if (index >= 0 && index < radarData.labels.length) {
                    return RadarChartTitle(
                      text: radarData.labels[index],
                      angle: angle,
                    );
                  }
                  return RadarChartTitle(text: '', angle: 0);
                },
                tickCount: 3,
                ticksTextStyle: const TextStyle(color: Colors.transparent),
                tickBorderData: const BorderSide(color: Colors.transparent),
                gridBorderData: BorderSide(
                  color: Colors.white.withOpacity(0.12),
                  width: 1,
                ),
              ),
              duration: const Duration(milliseconds: 400),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendDot(AppColors.mutedGold, 'Ты'),
              const SizedBox(width: 20),
              _buildLegendDot(Colors.white54, 'Цель 7b'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: unbounded(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildDrillsCard(TrainingPlan plan) {
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
          Row(
            children: [
              Icon(Icons.list_alt, color: AppColors.mutedGold, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Делай по порядку (${plan.weeksPlan} нед., ${plan.sessionsPerWeek}×/нед)',
                  style: unbounded(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Выполни упражнения сверху вниз — каждое по подходам.',
            style: unbounded(fontSize: 12, color: Colors.white54),
          ),
          const SizedBox(height: 16),
          ...plan.drills.asMap().entries.map((e) => _buildDrillTile(e.key + 1, e.value)),
        ],
      ),
    );
  }

  Widget _buildDrillTile(int index, TrainingDrill d) {
    return _DrillTileWithHint(
      index: index,
      drill: d,
    );
  }

  Widget _buildProtocolSummary(WeakLinkAnalysis a) {
    if (a.protocols.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.successMuted.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Типы протоколов',
                style: unbounded(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: 'Это названия методик в упражнениях выше',
                child: Icon(Icons.info_outline, size: 16, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: a.protocols.map((p) {
              final label = _protocolLabel(p);
              final hint = _protocolHint(p);
              return Tooltip(
                message: hint,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.successMuted.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    label,
                    style: unbounded(fontSize: 12, color: Colors.white70),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _protocolLabel(String id) {
    switch (id) {
      case 'max_hangs':
        return 'Max Hangs 3-5-7';
      case 'power_pulls':
        return 'Power Pulls';
      case 'pinch_lifting':
        return 'Щипковый блок';
      case 'unilateral':
        return 'Однорукие / Offset';
      default:
        return id;
    }
  }

  Widget _buildOfpCard() {
    String levelLabel;
    switch (_userLevel) {
      case 'novice':
        levelLabel = 'новичок';
        break;
      case 'novice_plus':
        levelLabel = 'новичок+';
        break;
      case 'intermediate':
        levelLabel = 'продвинутый';
        break;
      case 'intermediate_plus':
        levelLabel = 'продвинутый+';
        break;
      case 'pro':
        levelLabel = 'профи';
        break;
      default:
        levelLabel = 'продвинутый';
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.linkMuted.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sports_gymnastics, color: AppColors.linkMuted, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'ОФП по твоему уровню ($levelLabel)',
                  style: unbounded(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._ofpExercises.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.circle, size: 6, color: AppColors.linkMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.displayName,
                        style: unbounded(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${e.defaultSets} × ${e.defaultReps}',
                        style: unbounded(fontSize: 12, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExerciseCompletionScreen(metrics: widget.metrics),
                  ),
                );
              },
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: Text(
                'Отметить в «Выполнить упражнения»',
                style: unbounded(fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.linkMuted,
                side: BorderSide(color: AppColors.linkMuted.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _protocolHint(String id) {
    switch (id) {
      case 'max_hangs':
        return 'Макс. висы на финге — пиковая сила пальцев';
      case 'power_pulls':
        return 'Взрывные подтяги — тяговая сила';
      case 'pinch_lifting':
        return 'Щипок — колониты и слабы';
      case 'unilateral':
        return 'Однорукие и offset — убираем асимметрию';
      default:
        return '';
    }
  }
}

/// Карточка упражнения с раскрывающейся подсказкой.
class _DrillTileWithHint extends StatefulWidget {
  final int index;
  final TrainingDrill drill;

  const _DrillTileWithHint({required this.index, required this.drill});

  @override
  State<_DrillTileWithHint> createState() => _DrillTileWithHintState();
}

class _DrillTileWithHintState extends State<_DrillTileWithHint> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.drill;
    final hasHint = (d.hint ?? '').isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.rowAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
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
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.mutedGold.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${widget.index}',
                    style: unbounded(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mutedGold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.name,
                        style: unbounded(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (d.targetWeightKg != null) ...[
                            Icon(Icons.monitor_weight_outlined, size: 14, color: Colors.white54),
                            const SizedBox(width: 4),
                            Text(
                              '${d.targetWeightKg!.toStringAsFixed(1)} кг',
                              style: unbounded(fontSize: 13, color: Colors.white70),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Text(
                            '${d.sets} × ${d.reps}',
                            style: unbounded(fontSize: 13, color: Colors.white70),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'отдых ${d.rest}',
                            style: unbounded(fontSize: 12, color: Colors.white54),
                          ),
                        ],
                      ),
                      if (hasHint) ...[
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () => setState(() => _expanded = !_expanded),
                          child: Row(
                            children: [
                              Icon(
                                _expanded ? Icons.expand_less : Icons.help_outline,
                                size: 18,
                                color: AppColors.mutedGold,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _expanded ? 'Свернуть' : 'Что это?',
                                style: unbounded(
                                  fontSize: 12,
                                  color: AppColors.mutedGold,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_expanded) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.mutedGold.withOpacity(0.2)),
                            ),
                            child: Text(
                              d.hint!,
                              style: unbounded(
                                fontSize: 12,
                                color: Colors.white70,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
