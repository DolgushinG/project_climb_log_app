import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/models/CustomSetExercise.dart';
import 'package:login_app/models/SavedCustomSet.dart';
import 'package:login_app/models/Workout.dart';
import 'package:login_app/services/CustomExerciseSetService.dart';
import 'package:login_app/Screens/ExerciseCompletionScreen.dart';

/// Экран настройки выбранных упражнений: количество, повторения, отдых.
/// После настройки — кнопка «Начать выполнение».
class CustomSetCustomizationScreen extends StatefulWidget {
  final List<CustomSetExercise> exercises;
  final DateTime? date;
  final bool popOnReturn;

  const CustomSetCustomizationScreen({
    super.key,
    required this.exercises,
    this.date,
    this.popOnReturn = false,
  });

  @override
  State<CustomSetCustomizationScreen> createState() =>
      _CustomSetCustomizationScreenState();
}

class _CustomSetCustomizationScreenState
    extends State<CustomSetCustomizationScreen> {
  final CustomExerciseSetService _customSetService = CustomExerciseSetService();
  late List<CustomSetExercise> _exercises;

  @override
  void initState() {
    super.initState();
    _exercises = List.from(widget.exercises);
  }

  List<MapEntry<String, WorkoutBlockExercise>> _toWorkoutEntries() {
    final byCategory = <String, List<CustomSetExercise>>{};
    for (final ex in _exercises) {
      byCategory.putIfAbsent(ex.catalog.category, () => []).add(ex);
    }
    final entries = <MapEntry<String, WorkoutBlockExercise>>[];
    const orderedCats = ['ofp', 'sfp', 'stretching', 'other'];
    final extraCats =
        byCategory.keys.where((c) => !orderedCats.contains(c)).toList();
    for (final cat in [...orderedCats, ...extraCats]) {
      final list = byCategory[cat] ?? [];
      for (var i = 0; i < list.length; i++) {
        entries.add(
            MapEntry(cat, list[i].toWorkoutBlockExercise(blockKey: cat)));
      }
    }
    return entries;
  }

  Future<void> _startExecution() async {
    final entries = _toWorkoutEntries();
    if (entries.isEmpty) return;

    final setName =
        'Сет ${DateTime.now().day.toString().padLeft(2, '0')}.${DateTime.now().month.toString().padLeft(2, '0')}.${DateTime.now().year}';
    final set = SavedCustomSet(
      id: 0,
      name: setName,
      exercises: _exercises.asMap().entries.map((e) => SavedCustomSetExercise(
            exerciseId: e.value.catalog.id,
            order: e.key,
            sets: e.value.sets,
            reps: e.value.reps,
            holdSeconds: e.value.holdSeconds,
            restSeconds: e.value.restSeconds,
          )).toList(),
    );
    await _customSetService.createSet(set);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseCompletionScreen(
          workoutExerciseEntries: entries,
          date: widget.date ?? DateTime.now(),
          isCustomSet: true,
        ),
      ),
    );
    if (mounted && widget.popOnReturn) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final nav = Navigator.maybeOf(context);
        if (nav != null && nav.canPop()) {
          nav.pop(true);
        }
      });
    }
  }

  void _removeExercise(int index) {
    setState(() => _exercises.removeAt(index));
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
          'Настройка сета',
          style: unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      body: _exercises.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fitness_center, size: 64, color: Colors.white38),
                  const SizedBox(height: 16),
                  Text(
                    'Добавьте упражнения в экране выбора',
                    style: unbounded(fontSize: 16, color: Colors.white54),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Настройте количество, повторения и отдых для каждого упражнения',
                          style: unbounded(fontSize: 14, color: Colors.white54),
                        ),
                        const SizedBox(height: 20),
                        ...List.generate(
                          _exercises.length,
                          (i) => _buildExerciseCard(_exercises[i], i),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildBottomBar(),
              ],
            ),
    );
  }

  Widget _buildExerciseCard(CustomSetExercise ex, int index) {
    final catLabels = {
      'ofp': 'ОФП',
      'sfp': 'СФП',
      'stretching': 'Растяжка',
      'other': 'Прочее'
    };
    final catLabel = catLabels[ex.catalog.category] ?? ex.catalog.category;
    final isStretching = ex.catalog.category == 'stretching';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppColors.cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ex.catalog.displayName,
                    style: unbounded(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                Chip(
                  label: Text(catLabel,
                      style: unbounded(fontSize: 10, color: Colors.white70)),
                  backgroundColor: AppColors.graphite,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 22),
                  onPressed: () => _removeExercise(index),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    key: ValueKey('sets_${ex.catalog.id}_$index'),
                    initialValue: ex.sets.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Сеты',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    style: unbounded(fontSize: 16, color: Colors.white),
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null && n >= 1 && n <= 20) {
                        ex.sets = n;
                        setState(() {});
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    key: ValueKey('reps_${ex.catalog.id}_$index'),
                    initialValue: isStretching
                        ? (ex.holdSeconds != null ? '${ex.holdSeconds} с' : ex.reps)
                        : ex.reps,
                    decoration: InputDecoration(
                      labelText: isStretching ? 'Секунды' : 'Повторения',
                      hintText: isStretching ? '30' : '10, max',
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    style: unbounded(fontSize: 16, color: Colors.white),
                    onChanged: (v) {
                      final secMatch = RegExp(r'(\d+)').firstMatch(v);
                      if (v.contains('с') ||
                          v.contains('s') ||
                          v.contains('сек') ||
                          (isStretching && secMatch != null)) {
                        ex.holdSeconds =
                            secMatch != null ? int.tryParse(secMatch.group(1) ?? '') : null;
                        ex.reps = ex.holdSeconds?.toString() ?? '1';
                      } else {
                        ex.holdSeconds = null;
                        ex.reps = v.trim().isEmpty ? '10' : v;
                      }
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey('rest_${ex.catalog.id}_$index'),
                    initialValue: '${ex.restSeconds}',
                    decoration: const InputDecoration(
                      labelText: 'Отдых (сек)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    style: unbounded(fontSize: 16, color: Colors.white),
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null && n >= 0 && n <= 300) {
                        ex.restSeconds = n;
                        setState(() {});
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                TextButton.icon(
                  onPressed: () {
                    ex.resetToDefaults();
                    setState(() {});
                  },
                  icon: const Icon(Icons.refresh, size: 18, color: AppColors.mutedGold),
                  label: Text(
                    'Сброс',
                    style: unbounded(fontSize: 14, color: AppColors.mutedGold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      color: AppColors.surfaceDark,
      child: SafeArea(
        child: FilledButton.icon(
          onPressed: _exercises.isEmpty ? null : _startExecution,
          icon: const Icon(Icons.play_arrow, size: 24),
          label: Text(
            'Начать выполнение (${_exercises.length})',
            style: unbounded(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.mutedGold,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            minimumSize: const Size(double.infinity, 0),
          ),
        ),
      ),
    );
  }
}
