import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:login_app/main.dart';
import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/models/Workout.dart';
import 'package:login_app/services/TrainerService.dart';
import 'package:login_app/services/StrengthTestApiService.dart';
import 'package:login_app/Screens/ExerciseCompletionScreen.dart';

/// Экран «Мои задания от тренера» — список назначений для ученика.
class TrainerMyAssignmentsScreen extends StatefulWidget {
  const TrainerMyAssignmentsScreen({super.key});

  @override
  State<TrainerMyAssignmentsScreen> createState() => _TrainerMyAssignmentsScreenState();
}

class _TrainerMyAssignmentsScreenState extends State<TrainerMyAssignmentsScreen> {
  final TrainerService _trainerService = TrainerService(baseUrl: DOMAIN);
  final StrengthTestApiService _strengthApi = StrengthTestApiService();

  List<Map<String, dynamic>> _assignments = [];
  /// Ключ "exerciseId|date" для выполненных (совпадение по дате обязательно).
  Set<String> _completedKeys = {};
  /// Ключ "exerciseId|date" для пропущенных.
  Set<String> _skippedKeys = {};
  bool _loading = true;
  static const int _periodDays = 14;

  @override
  void initState() {
    super.initState();
    _load();
  }

  static String _normDate(String? s) {
    if (s == null || s.isEmpty) return '';
    return s.length >= 10 ? s.substring(0, 10) : s;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final assignments = await _trainerService.getMyAssignments(
      context,
      periodDays: _periodDays,
    );
    if (!mounted) return;
    final completions = await _strengthApi.getExerciseCompletions(periodDays: _periodDays);
    final skips = await _strengthApi.getExerciseSkips(periodDays: _periodDays);
    final completedKeys = completions
        .map((c) => '${c.exerciseId}|${_normDate(c.date)}')
        .toSet();
    final skippedKeys = skips
        .map((s) => '${s.exerciseId}|${_normDate(s.date)}')
        .toSet();
    setState(() {
      _assignments = assignments;
      _completedKeys = completedKeys;
      _skippedKeys = skippedKeys;
      _loading = false;
    });
  }

  /// Группировка по дате (дата -> список заданий).
  Map<String, List<Map<String, dynamic>>> get _byDate {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final a in _assignments) {
      final d = a['date']?.toString() ?? '';
      if (d.isEmpty) continue;
      map.putIfAbsent(d, () => []).add(a);
    }
    final keys = map.keys.toList()..sort();
    return Map.fromEntries(keys.map((k) => MapEntry(k, map[k]!)));
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.tryParse(dateStr);
      if (dt != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final d = DateTime(dt.year, dt.month, dt.day);
        if (d == today) return 'Сегодня';
        if (d == today.subtract(const Duration(days: 1))) return 'Вчера';
        return DateFormat('d MMM, EEE', 'ru').format(dt);
      }
    } catch (_) {}
    return dateStr;
  }

  Future<void> _openCompletion(String dateStr, List<Map<String, dynamic>> list) async {
    if (list.isEmpty) return;
    final entries = list.asMap().entries.map((e) {
      final a = e.value;
      final exerciseId = a['exercise_id']?.toString() ?? 'trainer_${e.key}';
      final name = a['exercise_name']?.toString() ?? 'Упражнение';
      final nameRu = a['exercise_name_ru'] ?? a['exercise_name'] ?? name;
      final sets = a['sets'] as int? ?? 3;
      final reps = a['reps'] ?? '6';
      final hold = a['hold_seconds'] as int?;
      final rest = a['rest_seconds'] as int? ?? 90;
      final hint = a['how_to_perform']?.toString();
      final comment = a['climbing_benefits']?.toString();
      final category = (a['category'] ?? 'ofp').toString();
      final dosage = hold != null ? '$sets × ${hold}с' : '$sets × $reps';
      final w = WorkoutBlockExercise(
        exerciseId: exerciseId,
        name: name,
        nameRu: nameRu,
        category: category,
        comment: comment,
        hint: hint,
        dosage: dosage,
        defaultSets: sets,
        defaultReps: reps is int ? reps : (int.tryParse(reps.toString()) ?? 6),
        holdSeconds: hold,
        defaultRestSeconds: rest,
      );
      return MapEntry('trainer', w);
    }).toList();
    DateTime? date;
    try {
      date = DateTime.tryParse(dateStr);
    } catch (_) {}
    final completed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseCompletionScreen(
          workoutExerciseEntries: entries,
          date: date,
        ),
      ),
    );
    if (mounted && completed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.anthracite,
      appBar: AppBar(
        title: Text(
          'Задания от тренера',
          style: unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: AppColors.cardDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
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
                  Text('Загрузка...', style: unbounded(fontSize: 14, color: Colors.white54)),
                ],
              ),
            )
          : _assignments.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.assignment_outlined, size: 64, color: Colors.white38),
                        const SizedBox(height: 16),
                        Text(
                          'Нет заданий от тренера',
                          style: unbounded(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Когда тренер назначит упражнения, они появятся здесь',
                          style: unbounded(fontSize: 14, color: Colors.white54),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.mutedGold,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: _byDate.entries.map((e) {
                      final dateStr = e.key;
                      final list = e.value;
                      final pendingCount = list.where((a) {
                        final id = a['exercise_id']?.toString();
                        final d = _normDate(a['date']?.toString());
                        if (id == null || id.isEmpty) return false;
                        return !_completedKeys.contains('$id|$d') && !_skippedKeys.contains('$id|$d');
                      }).length;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.graphite),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 18, color: AppColors.mutedGold),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatDate(dateStr),
                                    style: unbounded(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                                  ),
                                  const Spacer(),
                                  if (pendingCount > 0)
                                    Text(
                                      '$pendingCount из ${list.length}',
                                      style: unbounded(fontSize: 12, color: Colors.white54),
                                    ),
                                ],
                              ),
                            ),
                            ...list.map((a) {
                              final name = a['exercise_name_ru'] ?? a['exercise_name'] ?? a['exercise_id'] ?? '—';
                              final sets = a['sets'] as int? ?? 3;
                              final reps = (a['reps'] ?? '?').toString();
                              final hold = a['hold_seconds'] as int?;
                              final dosage = hold != null ? '$sets × ${hold}с' : '$sets × $reps';
                              final exerciseId = a['exercise_id']?.toString() ?? '';
                              final assignmentDate = _normDate(a['date']?.toString());
                              final key = '$exerciseId|$assignmentDate';
                              final completed = _completedKeys.contains(key) ||
                                  (a['status']?.toString() == 'completed');
                              final skipped = _skippedKeys.contains(key) ||
                                  (a['status']?.toString() == 'skipped');
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                child: Row(
                                  children: [
                                    Icon(
                                      completed
                                          ? Icons.check_circle
                                          : skipped
                                              ? Icons.remove_circle_outline
                                              : Icons.assignment_outlined,
                                      size: 20,
                                      color: completed
                                          ? AppColors.successMuted
                                          : skipped
                                              ? Colors.white54
                                              : AppColors.mutedGold,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: unbounded(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: completed || skipped ? Colors.white54 : Colors.white,
                                              decoration: completed || skipped ? TextDecoration.lineThrough : null,
                                            ),
                                          ),
                                          Text(
                                            dosage,
                                            style: unbounded(fontSize: 12, color: AppColors.mutedGold),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (completed)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.successMuted.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Выполнено',
                                          style: unbounded(fontSize: 11, color: AppColors.successMuted, fontWeight: FontWeight.w500),
                                        ),
                                      )
                                    else if (skipped)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white12,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Пропущено',
                                          style: unbounded(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }),
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: pendingCount > 0
                                  ? FilledButton.icon(
                                      onPressed: () => _openCompletion(dateStr, list),
                                      icon: const Icon(Icons.play_arrow, size: 20),
                                      label: Text(
                                        'Выполнить',
                                        style: unbounded(fontSize: 14, fontWeight: FontWeight.w600),
                                      ),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.mutedGold,
                                        foregroundColor: Colors.white,
                                      ),
                                    )
                                  : Row(
                                      children: [
                                        Icon(Icons.check_circle, size: 18, color: AppColors.successMuted),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Все выполнено',
                                          style: unbounded(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.successMuted),
                                        ),
                                        const Spacer(),
                                        TextButton(
                                          onPressed: () => _openCompletion(dateStr, list),
                                          child: Text(
                                            'Повторить',
                                            style: unbounded(fontSize: 13, color: Colors.white54),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
    );
  }
}
