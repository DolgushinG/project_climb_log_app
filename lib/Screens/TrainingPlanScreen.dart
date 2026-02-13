import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/models/StrengthAchievement.dart';
import 'package:login_app/models/TrainingPlan.dart';
import 'package:login_app/services/TrainingPlanGenerator.dart';
import 'package:login_app/services/StrengthTestApiService.dart';

/// Экран «Генератор плана» — персонализированная программа на основе замеров.
class TrainingPlanScreen extends StatefulWidget {
  final StrengthMetrics metrics;

  const TrainingPlanScreen({super.key, required this.metrics});

  @override
  State<TrainingPlanScreen> createState() => _TrainingPlanScreenState();
}

class _TrainingPlanScreenState extends State<TrainingPlanScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _savePlanToApi());
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
          style: GoogleFonts.unbounded(
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
              _buildCoachTipCard(plan.coachTip),
              const SizedBox(height: 20),
              _buildRadarChart(radarData),
              const SizedBox(height: 20),
              _buildDrillsCard(plan),
              const SizedBox(height: 20),
              _buildProtocolSummary(analysis),
            ],
          ),
        ),
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
              Icon(Icons.lightbulb, color: AppColors.mutedGold, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Совет',
                  style: GoogleFonts.unbounded(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedGold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            tip,
            style: GoogleFonts.unbounded(
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
            style: GoogleFonts.unbounded(
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
                titleTextStyle: GoogleFonts.unbounded(
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
          style: GoogleFonts.unbounded(
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
              Icon(Icons.fitness_center, color: AppColors.mutedGold, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Висы и тяги (${plan.weeksPlan} нед., ${plan.sessionsPerWeek}×/нед)',
                  style: GoogleFonts.unbounded(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...plan.drills.map((d) => _buildDrillTile(d)),
        ],
      ),
    );
  }

  Widget _buildDrillTile(TrainingDrill d) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.rowAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              d.name,
              style: GoogleFonts.unbounded(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (d.targetWeightKg != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.monitor_weight_outlined, size: 14, color: Colors.white54),
                          const SizedBox(width: 4),
                          Text(
                            '${d.targetWeightKg!.toStringAsFixed(1)} кг',
                            style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white70),
                          ),
                        ],
                      ),
                    Text(
                      'отдых ${d.rest}',
                      style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white54),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${d.sets} × ${d.reps}',
                  style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white70),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
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
          Text(
            'Протоколы под тебя',
            style: GoogleFonts.unbounded(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: a.protocols.map((p) {
              final label = _protocolLabel(p);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.successMuted.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white70),
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
        return 'Power Pulls (взрывные подтяги)';
      case 'pinch_lifting':
        return 'Щипковый блок';
      case 'unilateral':
        return 'Однорукие / Offset';
      default:
        return id;
    }
  }
}
