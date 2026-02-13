import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/models/StrengthAchievement.dart';
import 'package:login_app/models/TrainingPlan.dart';
import 'package:login_app/services/TrainingPlanGenerator.dart';
import 'package:login_app/services/StrengthDashboardService.dart';
import 'package:login_app/services/StrengthTestApiService.dart';

/// Экран «Выполнить упражнения» — упражнения из плана + ОФП по уровню с чекбоксами.
/// Сохранение через API с fallback на локальное хранилище.
class ExerciseCompletionScreen extends StatefulWidget {
  final StrengthMetrics? metrics;

  const ExerciseCompletionScreen({super.key, this.metrics});

  @override
  State<ExerciseCompletionScreen> createState() => _ExerciseCompletionScreenState();
}

class _ExerciseCompletionScreenState extends State<ExerciseCompletionScreen> {
  static const String _keyCompleted = 'exercise_completions';
  TrainingPlan? _plan;
  List<CatalogExercise> _ofpExercises = [];
  Map<String, bool> _completed = {};
  Map<String, int> _completionIds = {};
  String _dateKey = '';
  String _userLevel = 'intermediate';

  @override
  void initState() {
    super.initState();
    _dateKey = _todayKey();
    _load();
  }

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  /// Fallback level для ОФП, если бэкенд не вернул упражнения по уровню.
  String? _fallbackLevelForOfp(String level) {
    if (level == 'intermediate') return null;
    return 'intermediate';
  }

  /// Уровень по средней силе: novice (< 40%), intermediate (40–65%), pro (65%+).
  String _computeLevel(StrengthMetrics? m) {
    if (m == null) return 'intermediate';
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

  Future<void> _load() async {
    var m = widget.metrics;
    if (m == null) {
      m = await StrengthDashboardService().getLastMetrics();
    }
    final api = StrengthTestApiService();
    final strengthLevel = await api.getStrengthLevel();
    final level = strengthLevel?.level ?? _computeLevel(m);
    TrainingPlan? plan;
    if (m != null && (m.bodyWeightKg != null || m.fingerBestPct != null || m.pinchKg != null)) {
      final gen = TrainingPlanGenerator();
      final analysis = gen.analyzeWeakLink(m);
      plan = gen.generatePlan(m, analysis);
    }

    final completions = await api.getExerciseCompletions(date: _dateKey);
    Map<String, bool> completed = {};
    Map<String, int> completionIds = {};
    for (final c in completions) {
      completed[c.exerciseId] = true;
      completionIds[c.exerciseId] = c.id;
    }

    var ofpList = await api.getExercises(level: level, category: 'ofp');
    if (ofpList.isEmpty) {
      final fallbackLevel = _fallbackLevelForOfp(level);
      if (fallbackLevel != null) {
        ofpList = await api.getExercises(level: fallbackLevel, category: 'ofp');
      }
    }

    if (completed.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('${_keyCompleted}_$_dateKey');
      if (json != null) {
        try {
          final decoded = jsonDecode(json) as Map<String, dynamic>?;
          if (decoded != null) {
            completed = decoded.map((k, v) => MapEntry(k, v == true));
          }
        } catch (_) {}
      }
    }

    if (mounted) {
      setState(() {
        _plan = plan;
        _ofpExercises = ofpList;
        _completed = completed;
        _completionIds = completionIds;
        _userLevel = level;
      });
    }
  }

  Future<void> _toggleCompleted(TrainingDrill d, bool value) async {
    final key = d.exerciseId ?? d.name;
    await _toggleExerciseCompleted(key, value, setsDone: d.sets, weightKg: d.targetWeightKg);
  }

  Future<void> _toggleOfpCompleted(CatalogExercise e, bool value) async {
    await _toggleExerciseCompleted(e.id, value, setsDone: e.defaultSets, weightKg: null);
  }

  Future<void> _toggleExerciseCompleted(
    String exerciseId,
    bool value, {
    int setsDone = 1,
    double? weightKg,
  }) async {
    setState(() => _completed[exerciseId] = value);

    final api = StrengthTestApiService();
    if (value) {
      final id = await api.saveExerciseCompletion(
        date: _dateKey,
        exerciseId: exerciseId,
        setsDone: setsDone,
        weightKg: weightKg,
      );
      if (id != null && mounted) {
        setState(() => _completionIds[exerciseId] = id);
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('${_keyCompleted}_$_dateKey', jsonEncode(_completed));
      }
    } else {
      final cid = _completionIds[exerciseId];
      if (cid != null) {
        final ok = await api.deleteExerciseCompletion(cid);
        if (ok && mounted) {
          setState(() => _completionIds.remove(exerciseId));
        } else {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('${_keyCompleted}_$_dateKey', jsonEncode(_completed));
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('${_keyCompleted}_$_dateKey', jsonEncode(_completed));
      }
    }
  }

  int get _doneCount => _completed.values.where((v) => v).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.anthracite,
      appBar: AppBar(
        backgroundColor: AppColors.anthracite,
        title: Text(
          'Выполнить упражнения',
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
      body: _plan == null && _ofpExercises.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.mutedGold,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    if (_plan != null) ...[
                      _buildTip(),
                      const SizedBox(height: 20),
                      _buildDrillsList(),
                      const SizedBox(height: 24),
                    ],
                    if (_ofpExercises.isNotEmpty) _buildOfpSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center_outlined, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              'Нет данных для плана',
              style: GoogleFonts.unbounded(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Сделай тест силы и сохрани замер — тогда появится персональный план',
              style: GoogleFonts.unbounded(
                fontSize: 13,
                color: Colors.white38,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final planCount = _plan?.drills.length ?? 0;
    final total = planCount + _ofpExercises.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.mutedGold.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.today, color: AppColors.mutedGold, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'План на сегодня',
                  style: GoogleFonts.unbounded(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '$_doneCount из $total выполнено',
                  style: GoogleFonts.unbounded(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          if (_doneCount == total && total > 0)
            Icon(Icons.check_circle, color: AppColors.successMuted, size: 28),
        ],
      ),
    );
  }

  Widget _buildTip() {
    final tip = _plan?.coachTip;
    if (tip == null || tip.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.linkMuted.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: AppColors.mutedGold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tip,
              style: GoogleFonts.unbounded(
                fontSize: 13,
                color: Colors.white70,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrillsList() {
    final drills = _plan?.drills ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'План (СФП)',
          style: GoogleFonts.unbounded(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 12),
        ...drills.asMap().entries.map((e) {
          final i = e.key + 1;
          final d = e.value;
          final key = d.exerciseId ?? d.name;
          final done = _completed[key] ?? false;
          return _buildDrillTile(i, d, done);
        }        ),
      ],
    );
  }

  Widget _buildOfpSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'ОФП по уровню',
              style: GoogleFonts.unbounded(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.linkMuted.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _levelLabel(_userLevel),
                style: GoogleFonts.unbounded(fontSize: 11, color: Colors.white70),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._ofpExercises.map((e) => _buildOfpTile(e)),
      ],
    );
  }

  String _levelLabel(String level) {
    switch (level) {
      case 'novice':
        return 'новичок';
      case 'novice_plus':
        return 'новичок+';
      case 'intermediate':
        return 'продвинутый';
      case 'intermediate_plus':
        return 'продвинутый+';
      case 'pro':
        return 'профи';
      default:
        return 'продвинутый';
    }
  }

  Widget _buildOfpTile(CatalogExercise e) {
    final done = _completed[e.id] ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleOfpCompleted(e, !done),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: done ? AppColors.successMuted.withOpacity(0.2) : AppColors.cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: done ? AppColors.successMuted : AppColors.graphite,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: Checkbox(
                    value: done,
                    onChanged: (v) => _toggleOfpCompleted(e, v ?? false),
                    activeColor: AppColors.successMuted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.displayName,
                        style: GoogleFonts.unbounded(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: done ? Colors.white70 : Colors.white,
                          decoration: done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${e.defaultSets} × ${e.defaultReps} • отдых ${e.defaultRest}',
                        style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white54),
                      ),
                      if (e.description != null && e.description!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          e.description!,
                          style: GoogleFonts.unbounded(
                            fontSize: 11,
                            color: Colors.white38,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrillTile(int index, TrainingDrill d, bool done) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleCompleted(d, !done),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: done ? AppColors.successMuted.withOpacity(0.2) : AppColors.cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: done ? AppColors.successMuted : AppColors.graphite,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: Checkbox(
                    value: done,
                    onChanged: (v) => _toggleCompleted(d, v ?? false),
                    activeColor: AppColors.successMuted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.name,
                        style: GoogleFonts.unbounded(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: done ? Colors.white70 : Colors.white,
                          decoration: done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 2,
                        children: [
                          if (d.targetWeightKg != null)
                            Text(
                              '${d.targetWeightKg!.toStringAsFixed(1)} кг',
                              style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white54),
                            ),
                          Text(
                            '${d.sets} × ${d.reps}',
                            style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white54),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '• отдых ${d.rest}',
                            style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white38),
                          ),
                        ],
                      ),
                      if (d.hint != null && d.hint!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          d.hint!,
                          style: GoogleFonts.unbounded(
                            fontSize: 11,
                            color: Colors.white38,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
