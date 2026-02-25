import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:login_app/main.dart';
import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/models/PlanModels.dart';
import 'package:login_app/models/StrengthAchievement.dart';
import 'package:login_app/models/TrainingPlan.dart';
import 'package:login_app/models/Workout.dart';
import 'package:login_app/services/TrainingPlanGenerator.dart';
import 'package:login_app/services/StrengthDashboardService.dart';
import 'package:login_app/services/StrengthTestApiService.dart';

/// Экран «Выполнить упражнения» — упражнения из плана + ОФП по уровню с чекбоксами.
/// Сохранение через API с fallback на локальное хранилище.
/// При передаче [workoutExerciseEntries] показываются только эти упражнения, сгруппированные по секциям (режим сгенерированной тренировки).
/// При передаче [date] используется эта дата для сохранения (иначе — сегодня).
class ExerciseCompletionScreen extends StatefulWidget {
  final StrengthMetrics? metrics;
  /// Упражнения из сгенерированной тренировки (blockKey, exercise) — при наличии используются вместо плана и ОФП.
  final List<MapEntry<String, WorkoutBlockExercise>>? workoutExerciseEntries;
  /// Растяжка из плана дня (уже загружена) — без доп. запросов к API.
  final List<PlanStretchingExercise>? stretchingFromPlan;
  /// Комментарий тренера (при workoutExerciseEntries).
  final String? coachComment;
  /// Распределение нагрузки (при workoutExerciseEntries).
  final Map<String, int>? loadDistribution;
  /// Подсказка по прогрессии (при workoutExerciseEntries).
  final String? progressionHint;
  /// Дата сессии — для плана тренировок (иначе сегодня).
  final DateTime? date;

  const ExerciseCompletionScreen({
    super.key,
    this.metrics,
    this.workoutExerciseEntries,
    this.stretchingFromPlan,
    this.coachComment,
    this.loadDistribution,
    this.progressionHint,
    this.date,
  });

  /// Очищает кэш плана на сегодня (например, после нового замера).
  static Future<void> clearCacheForToday() async {
    final prefs = await SharedPreferences.getInstance();
    final n = DateTime.now();
    final key = 'exercise_completion_screen_cache_${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
    await prefs.remove(key);
  }

  @override
  State<ExerciseCompletionScreen> createState() => _ExerciseCompletionScreenState();
}

class _ExerciseCompletionScreenState extends State<ExerciseCompletionScreen>
    with SingleTickerProviderStateMixin {
  static const String _keyCompleted = 'exercise_completions';
  static const String _keyCache = 'exercise_completion_screen_cache';
  static const String _keySectionExpanded = 'exercise_completion_section_expanded';
  static const String _keySwipeHintShown = 'exercise_skip_swipe_hint_shown';
  TrainingPlan? _plan;
  List<CatalogExercise> _ofpExercises = [];
  List<CatalogExercise> _stretchingExercises = [];
  Map<String, bool> _completed = {};
  Map<String, int> _completionIds = {};
  Map<String, bool> _skipped = {};
  Map<String, int> _skipIds = {};
  Map<String, List<bool>> _approachDone = {};
  final Map<String, String> _workoutBlockKeys = {};
  final Map<String, bool> _workoutSectionExpanded = {};
  String _dateKey = '';
  String _userLevel = 'intermediate';

  bool _loading = true;
  bool _allDoneCelebrationShown = false;

  bool _planExpanded = false;
  bool _ofpExpanded = false;
  bool _stretchingExpanded = false;

  String? _restExerciseKey;
  int? _restSecondsRemaining;
  int _restTotal = 180;
  Timer? _restTimer;

  bool _showSwipeHint = false;
  AnimationController? _swipeHintController;

  /// На web: кнопка «Пропустить» появляется после удержания 1 сек на блоке.
  final Set<String> _skipButtonRevealedFor = {};
  Timer? _longPressTimer;
  String? _longPressExerciseId;
  double _longPressProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _dateKey = _dateKeyFrom(widget.date);
    _loadFromCache().then((_) => _load());
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _longPressTimer?.cancel();
    _swipeHintController?.dispose();
    super.dispose();
  }

  /// Парсит строку отдыха "180s", "90s", "2m" в секунды.
  int _parseRestSeconds(String rest) {
    final s = rest.trim().toLowerCase();
    final match = RegExp(r'^(\d+)\s*(s|сек|sec|m|мин|min)?$').firstMatch(s);
    if (match == null) return 180;
    final n = int.tryParse(match.group(1) ?? '') ?? 180;
    final unit = match.group(2) ?? 's';
    if (unit.startsWith('m') || unit == 'мин') return n * 60;
    return n;
  }

  bool _restTimerVisible = false;

  void _startRestTimer(String exerciseKey, int seconds) {
    _restTimer?.cancel();
    setState(() {
      _restExerciseKey = exerciseKey;
      _restTotal = seconds;
      _restSecondsRemaining = seconds;
      _restTimerVisible = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _restSecondsRemaining != null && _restSecondsRemaining! > 0) {
        setState(() => _restTimerVisible = true);
      }
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
        setState(() {
          _restSecondsRemaining = (_restSecondsRemaining ?? 0) - 1;
          if (_restSecondsRemaining! <= 0) {
            t.cancel();
            _restTimer = null;
            _restExerciseKey = null;
            _restSecondsRemaining = null;
            _restTimerVisible = false;
          }
        });
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    _restTimer = null;
    if (mounted) {
      setState(() {
        _restExerciseKey = null;
        _restSecondsRemaining = null;
        _restTimerVisible = false;
      });
    }
  }

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  String _dateKeyFrom(DateTime? d) {
    if (d == null) return _todayKey();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
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

  Future<void> _loadSectionExpandedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('${_keySectionExpanded}_$_dateKey');
      if (json == null) return;
      final data = jsonDecode(json) as Map<String, dynamic>?;
      if (data == null || !mounted) return;
      setState(() {
        _planExpanded = data['plan'] == true;
        _ofpExpanded = data['ofp'] == true;
        _stretchingExpanded = data['stretching'] == true;
        for (final e in data.entries) {
          if (e.key != 'plan' && e.key != 'ofp' && e.key != 'stretching' && e.value == true) {
            _workoutSectionExpanded[e.key] = true;
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _saveSectionExpandedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = <String, dynamic>{
        'plan': _planExpanded,
        'ofp': _ofpExpanded,
        'stretching': _stretchingExpanded,
        ..._workoutSectionExpanded.map((k, v) => MapEntry(k, v)),
      };
      await prefs.setString('${_keySectionExpanded}_$_dateKey', jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _loadFromCache() async {
    if (_isWorkoutMode) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('${_keyCache}_$_dateKey');
      if (json == null) return;
      final data = jsonDecode(json) as Map<String, dynamic>?;
      if (data == null) return;
      TrainingPlan? plan;
      if (data['plan'] != null) {
        plan = TrainingPlan.fromJson(Map<String, dynamic>.from(data['plan'] as Map));
      }
      List<CatalogExercise> ofp = [];
      final ofpRaw = data['ofp_exercises'] as List<dynamic>?;
      if (ofpRaw != null) {
        for (final e in ofpRaw) {
          ofp.add(CatalogExercise.fromJson(Map<String, dynamic>.from(e as Map)));
        }
      }
      List<CatalogExercise> stretching = [];
      final strRaw = data['stretching_exercises'] as List<dynamic>?;
      if (strRaw != null) {
        for (final e in strRaw) {
          stretching.add(CatalogExercise.fromJson(Map<String, dynamic>.from(e as Map)));
        }
      }
      Map<String, bool> completed = {};
      final completedRaw = data['completed'] as Map<String, dynamic>?;
      if (completedRaw != null) {
        completed = completedRaw.map((k, v) => MapEntry(k, v == true));
      }
      Map<String, int> completionIds = {};
      final idsRaw = data['completion_ids'] as Map<String, dynamic>?;
      if (idsRaw != null) {
        completionIds = idsRaw.map((k, v) => MapEntry(k, (v as num).toInt()));
      }
      Map<String, bool> skipped = {};
      final skippedRaw = data['skipped'] as Map<String, dynamic>?;
      if (skippedRaw != null) {
        skipped = skippedRaw.map((k, v) => MapEntry(k, v == true));
      }
      Map<String, int> skipIds = {};
      final skipIdsRaw = data['skip_ids'] as Map<String, dynamic>?;
      if (skipIdsRaw != null) {
        skipIds = skipIdsRaw.map((k, v) => MapEntry(k, (v as num).toInt()));
      }
      if (mounted && (plan != null || ofp.isNotEmpty || stretching.isNotEmpty)) {
        setState(() {
          _plan = plan;
          _ofpExercises = ofp;
          _stretchingExercises = stretching;
          _completed = completed;
          _completionIds = completionIds;
          _skipped = skipped;
          _skipIds = skipIds;
          _userLevel = data['user_level'] as String? ?? _userLevel;
          _loading = false;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveToCache(
    TrainingPlan? plan,
    List<CatalogExercise> ofp,
    List<CatalogExercise> stretching,
    Map<String, bool> completed,
    Map<String, int> completionIds,
    Map<String, bool> skipped,
    Map<String, int> skipIds,
    String userLevel,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = <String, dynamic>{
        'ofp_exercises': ofp.map((e) => e.toJson()).toList(),
        'stretching_exercises': stretching.map((e) => e.toJson()).toList(),
        'completed': completed.map((k, v) => MapEntry(k, v)),
        'completion_ids': completionIds.map((k, v) => MapEntry(k, v)),
        'skipped': skipped.map((k, v) => MapEntry(k, v)),
        'skip_ids': skipIds.map((k, v) => MapEntry(k, v)),
        'user_level': userLevel,
      };
      if (plan != null) data['plan'] = plan.toJson();
      await prefs.setString('${_keyCache}_$_dateKey', jsonEncode(data));
    } catch (_) {}
  }

  bool get _isWorkoutMode => widget.workoutExerciseEntries != null && widget.workoutExerciseEntries!.isNotEmpty;

  Future<void> _load() async {
    await _loadSectionExpandedState();
    if (_isWorkoutMode) {
      await _loadWorkoutMode();
      return;
    }
    await _loadStandardMode();
  }

  Future<void> _loadWorkoutMode() async {
    final api = StrengthTestApiService();
    final completions = await api.getExerciseCompletions(date: _dateKey);
    final skips = await api.getExerciseSkips(date: _dateKey);
    Map<String, bool> completed = {};
    Map<String, int> completionIds = {};
    Map<String, bool> skipped = {};
    Map<String, int> skipIds = {};
    for (final c in completions) {
      completed[c.exerciseId] = true;
      completionIds[c.exerciseId] = c.id;
    }
    for (final s in skips) {
      skipped[s.exerciseId] = true;
      skipIds[s.exerciseId] = s.id;
    }
    final entries = widget.workoutExerciseEntries!;
    final ofpList = entries.map((e) => CatalogExercise.fromWorkoutBlock(e.value)).toList();
    _workoutBlockKeys.clear();
    for (var i = 0; i < entries.length; i++) {
      _workoutBlockKeys[ofpList[i].id] = entries[i].key;
    }

    // Растяжка из плана дня (уже загружена) — без доп. запросов
    final stretchingList = (widget.stretchingFromPlan ?? [])
        .where((e) => e.exerciseId != null)
        .map((e) => CatalogExercise.fromPlanStretching(e))
        .toList();

    if (mounted) {
      setState(() {
        _plan = null;
        _ofpExercises = ofpList;
        _stretchingExercises = stretchingList;
        _completed = completed;
        _completionIds = completionIds;
        _skipped = skipped;
        _skipIds = skipIds;
        _userLevel = 'intermediate';
        _loading = false;
      });
      _maybeShowSwipeHint();
    }
  }

  Future<void> _loadStandardMode() async {
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
    final skips = await api.getExerciseSkips(date: _dateKey);
    Map<String, bool> completed = {};
    Map<String, int> completionIds = {};
    Map<String, bool> skipped = {};
    Map<String, int> skipIds = {};
    for (final c in completions) {
      completed[c.exerciseId] = true;
      completionIds[c.exerciseId] = c.id;
    }
    for (final s in skips) {
      skipped[s.exerciseId] = true;
      skipIds[s.exerciseId] = s.id;
    }

    final dayOffset = DateTime.now().weekday % 7;
    var ofpList = await api.getExercises(level: level, category: 'ofp', dayOffset: dayOffset);
    if (ofpList.isEmpty) {
      final fallbackLevel = _fallbackLevelForOfp(level);
      if (fallbackLevel != null) {
        ofpList = await api.getExercises(level: fallbackLevel, category: 'ofp', dayOffset: dayOffset);
      }
    }
    var stretchingList = await api.getExercises(level: level, category: 'stretching', dayOffset: dayOffset);
    if (stretchingList.isEmpty && level != 'intermediate') {
      stretchingList = await api.getExercises(level: 'intermediate', category: 'stretching');
    }
    if (ofpList.isNotEmpty && stretchingList.isNotEmpty) {
      final ofpMuscles = ofpList.expand((e) => e.muscleGroups).toSet();
      if (ofpMuscles.isNotEmpty) {
        stretchingList = stretchingList
            .where((s) => s.muscleGroups.isEmpty || s.muscleGroups.any((m) => ofpMuscles.contains(m)))
            .toList();
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
        _stretchingExercises = stretchingList;
        _completed = completed;
        _completionIds = completionIds;
        _skipped = skipped;
        _skipIds = skipIds;
        _userLevel = level;
        _loading = false;
      });
      _saveToCache(plan, ofpList, stretchingList, completed, completionIds, skipped, skipIds, level);
      _maybeShowSwipeHint();
    }
  }

  Future<void> _maybeShowSwipeHint() async {
    if (_totalCount == 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_keySwipeHintShown) == true) return;
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _swipeHintController?.dispose();
        if (_isSwipeSupported) {
          _swipeHintController = AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 1500),
          )..repeat(reverse: true);
        }
        setState(() => _showSwipeHint = true);
      });
    } catch (_) {}
  }

  Future<void> _dismissSwipeHint() async {
    if (!_showSwipeHint) return;
    _swipeHintController?.dispose();
    _swipeHintController = null;
    setState(() => _showSwipeHint = false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keySwipeHintShown, true);
    } catch (_) {}
  }

  /// На web и iOS PWA свайп не работает — показываем кнопку «Пропустить» на карточках.
  bool get _isSwipeSupported => !kIsWeb;

  Future<void> _skipExerciseWithConfirmation(String exerciseId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Пропустить упражнение?', style: unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
        content: Text(
          'Упражнение будет отмечено как пропущенное.',
          style: unbounded(fontSize: 14, color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Отмена', style: unbounded(color: Colors.white54))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.mutedGold),
            child: Text('Пропустить', style: unbounded(color: Colors.black87, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) _toggleExerciseSkipped(exerciseId, true, skipConfirmation: true);
  }

  void _cancelLongPressTimer() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _longPressExerciseId = null;
    if (_longPressProgress > 0) {
      _longPressProgress = 0;
      if (mounted) setState(() {});
    }
  }

  Widget _wrapWithLongPressReveal(String exerciseId, Widget child) {
    if (_isSwipeSupported) return child;
    final isHolding = _longPressExerciseId == exerciseId;
    return Listener(
      onPointerDown: (_) {
        _cancelLongPressTimer();
        _longPressExerciseId = exerciseId;
        _longPressProgress = 0.0;
        if (mounted) setState(() {});
        _longPressTimer = Timer.periodic(const Duration(milliseconds: 50), (t) {
          if (!mounted) {
            t.cancel();
            return;
          }
          setState(() {
            _longPressProgress += 0.05;
            if (_longPressProgress >= 1.0) {
              _skipButtonRevealedFor.add(exerciseId);
              t.cancel();
              _longPressTimer = null;
              _longPressExerciseId = null;
              _longPressProgress = 0.0;
              HapticFeedback.mediumImpact();
            }
          });
        });
      },
      onPointerUp: (_) => _cancelLongPressTimer(),
      onPointerCancel: (_) => _cancelLongPressTimer(),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          if (isHolding && _longPressProgress > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                child: LinearProgressIndicator(
                  value: _longPressProgress,
                  backgroundColor: AppColors.mutedGold.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.mutedGold),
                  minHeight: 4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _isSkipButtonVisible(String exerciseId, {required bool done, required bool skipped}) =>
      !done && !skipped && !_isSwipeSupported && _skipButtonRevealedFor.contains(exerciseId);

  Widget _buildSkipButton(String exerciseId) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _skipExerciseWithConfirmation(exerciseId),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.skip_next, color: AppColors.mutedGold, size: 20),
              const SizedBox(width: 6),
              Text('Пропустить', style: unbounded(fontSize: 12, color: AppColors.mutedGold, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
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
    final sid = _skipIds[exerciseId];
    setState(() {
      _completed[exerciseId] = value;
      if (value) {
        _skipped.remove(exerciseId);
        _skipIds.remove(exerciseId);
      }
    });

    final api = StrengthTestApiService();
    if (value) {
      if (sid != null) await api.deleteExerciseSkip(sid);
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
      if (mounted) _maybeShowAllDoneCelebration();
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

  Future<void> _toggleExerciseSkipped(String exerciseId, bool value, {bool skipConfirmation = false}) async {
    if (value && !skipConfirmation) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Пропустить упражнение?',
            style: unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          content: Text(
            'Упражнение будет отмечено как пропущенное.',
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
              child: Text('Пропустить', style: unbounded(color: Colors.black87, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    final cid = _completionIds[exerciseId];
    setState(() {
      _skipped[exerciseId] = value;
      if (value) {
        _completed.remove(exerciseId);
        _completionIds.remove(exerciseId);
      } else {
        _skipIds.remove(exerciseId);
      }
    });

    final api = StrengthTestApiService();
    if (value) {
      if (cid != null) await api.deleteExerciseCompletion(cid);
      final id = await api.saveExerciseSkip(
        date: _dateKey,
        exerciseId: exerciseId,
      );
      if (id != null && mounted) {
        setState(() => _skipIds[exerciseId] = id);
      }
      if (mounted) _maybeShowAllDoneCelebration();
    } else {
      final sid = _skipIds[exerciseId];
      if (sid != null) {
        final ok = await api.deleteExerciseSkip(sid);
        if (ok && mounted) {
          setState(() => _skipIds.remove(exerciseId));
        }
      }
    }
  }

  int get _doneCount => _completed.values.where((v) => v).length;
  int get _skippedCount => _skipped.values.where((v) => v).length;
  int get _resolvedCount => _doneCount + _skippedCount;
  int get _totalCount =>
      (_plan?.drills.length ?? 0) + _ofpExercises.length + _stretchingExercises.length;

  String _fullImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '$DOMAIN${path.startsWith('/') ? path : '/$path'}';
  }

  static const List<Map<String, String>> _allDoneMessages = [
    {'title': 'Так держать!', 'subtitle': 'Ты стал сильнее. Каждая тренировка — шаг к цели.'},
    {'title': 'План выполнен!', 'subtitle': 'Отличная работа. Отдыхай и восстанавливайся.'},
    {'title': 'Молодец!', 'subtitle': 'Сила растёт, когда ты не сдаёшься.'},
    {'title': 'Супер!', 'subtitle': 'Ещё один день — ещё одна победа над собой.'},
    {'title': 'Красавчик!', 'subtitle': 'Замеры не врут — ты реально прогрессируешь.'},
  ];

  void _maybeShowAllDoneCelebration() {
    if (_allDoneCelebrationShown || !mounted) return;
    if (_totalCount == 0 || _resolvedCount != _totalCount) return;
    _allDoneCelebrationShown = true;
    final msg = _allDoneMessages[(DateTime.now().millisecond % _allDoneMessages.length)];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events, color: AppColors.mutedGold, size: 56),
              const SizedBox(height: 16),
              Text(
                msg['title']!,
                style: unbounded(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                msg['subtitle']!,
                style: unbounded(
                  fontSize: 14,
                  color: Colors.white70,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Ок',
                style: unbounded(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedGold,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.anthracite,
      appBar: AppBar(
        backgroundColor: AppColors.anthracite,
        leadingWidth: 56,
        title: Text(
          'Выполнить упражнения',
          style: unbounded(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Назад',
          onPressed: () => Navigator.pop(context, _resolvedCount == _totalCount && _totalCount > 0),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _load(),
          ),
        ],
      ),
      body: _loading && _plan == null && _ofpExercises.isEmpty && _stretchingExercises.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.mutedGold),
            )
          : _plan == null && _ofpExercises.isEmpty && _stretchingExercises.isEmpty
              ? _buildEmptyState()
              : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.mutedGold,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.coachComment != null ||
                            (widget.loadDistribution != null && widget.loadDistribution!.isNotEmpty) ||
                            widget.progressionHint != null) ...[
                          _buildCoachSection(),
                          const SizedBox(height: 20),
                        ],
                        _buildHeader(),
                        if (_showSwipeHint) ...[
                          const SizedBox(height: 16),
                          _buildSwipeHintBanner(),
                          const SizedBox(height: 20),
                        ] else ...[
                          const SizedBox(height: 20),
                        ],
                          if (_plan != null) ...[
                            _buildTip(),
                            const SizedBox(height: 20),
                            _buildCollapsibleSection(
                              title: 'План (СФП)',
                              expanded: _planExpanded,
                              onToggle: () {
                                setState(() {
                                  _planExpanded = !_planExpanded;
                                  _saveSectionExpandedState();
                                });
                              },
                              count: _plan!.drills.length,
                              child: _buildDrillsListContent(),
                            ),
                            const SizedBox(height: 24),
                          ],
                          if (_ofpExercises.isNotEmpty)
                            _isWorkoutMode
                                ? _buildWorkoutGroupedSections()
                                : _buildCollapsibleSection(
                                    title: 'ОФП по уровню',
                                    expanded: _ofpExpanded,
                                    onToggle: () {
                                      setState(() {
                                        _ofpExpanded = !_ofpExpanded;
                                        _saveSectionExpandedState();
                                      });
                                    },
                                    count: _ofpExercises.length,
                                    badge: _levelLabel(_userLevel),
                                    child: _buildOfpSectionContent(),
                                  ),
                          if (_stretchingExercises.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            _buildCollapsibleSection(
                              title: 'Растяжка (после ОФП)',
                              expanded: _stretchingExpanded,
                              onToggle: () {
                                setState(() {
                                  _stretchingExpanded = !_stretchingExpanded;
                                  _saveSectionExpandedState();
                                });
                              },
                              count: _stretchingExercises.length,
                              icon: Icons.self_improvement,
                              child: _buildStretchingSectionContent(),
                            ),
                          ],
                          if (_resolvedCount == _totalCount && _totalCount > 0) ...[
                            const SizedBox(height: 24),
                            _buildFinishWorkoutButton(),
                          ],
                        ],
                      ),
                    ),
                  ),
                if (_restSecondsRemaining != null && _restSecondsRemaining! > 0)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: IgnorePointer(
                          ignoring: !_restTimerVisible,
                          child: AnimatedOpacity(
                            opacity: _restTimerVisible ? 1 : 0,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            child: Material(
                              elevation: 8,
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.transparent,
                              child: _buildRestTimer(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildFinishWorkoutButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => Navigator.pop(context, _resolvedCount == _totalCount && _totalCount > 0),
            icon: const Icon(Icons.check_circle, size: 22),
            label: Text(
              'Завершить тренировку',
              style: unbounded(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.successMuted,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: () => _load(),
            icon: const Icon(Icons.refresh, size: 18, color: Colors.white54),
            label: Text(
              'Обновить данные',
              style: unbounded(fontSize: 13, color: Colors.white54),
            ),
          ),
        ),
      ],
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
              style: unbounded(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Сделай тест силы и сохрани замер — тогда появится персональный план',
              style: unbounded(
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

  Widget _buildCoachSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.coachComment != null) ...[
          _buildCoachCommentCard(),
          const SizedBox(height: 12),
        ],
        if (widget.loadDistribution != null && widget.loadDistribution!.isNotEmpty) ...[
          _buildLoadDistributionCard(),
          const SizedBox(height: 12),
        ],
        if (widget.progressionHint != null) _buildProgressionHintCard(),
      ],
    );
  }

  Widget _buildCoachCommentCard() {
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
                style: unbounded(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.mutedGold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.coachComment!,
            style: unbounded(fontSize: 13, color: Colors.white70, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadDistributionCard() {
    final ld = widget.loadDistribution!;
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
                      Text('${e.value}%', style: unbounded(fontSize: 11, color: Colors.white54)),
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
            widget.progressionHint!,
            style: unbounded(fontSize: 13, color: Colors.white70, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final total = _totalCount;
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
                  style: unbounded(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _skippedCount > 0
                      ? '$_doneCount выполнено, $_skippedCount пропущено из $total'
                      : '$_doneCount из $total выполнено',
                  style: unbounded(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          if (_resolvedCount == total && total > 0)
            Icon(Icons.check_circle, color: AppColors.successMuted, size: 28),
        ],
      ),
    );
  }

  Widget _buildSwipeHintBanner() {
    final isWeb = !_isSwipeSupported;
    final hintText = isWeb
        ? 'Удерживайте блок упражнения 1 секунду, чтобы появилась кнопка пропуска'
        : 'Свайпните влево, чтобы пропустить упражнение';
    final hintIcon = isWeb ? Icons.touch_app : Icons.swipe_left;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: _dismissSwipeHint,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.mutedGold.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              if (!isWeb && _swipeHintController != null)
                AnimatedBuilder(
                  animation: _swipeHintController!,
                  builder: (context, _) {
                    final dx = -32.0 * _swipeHintController!.value;
                    return Transform.translate(
                      offset: Offset(dx, 0),
                      child: Icon(
                        hintIcon,
                        color: AppColors.mutedGold,
                        size: 32,
                      ),
                    );
                  },
                )
              else
                Icon(hintIcon, color: AppColors.mutedGold, size: 32),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  hintText,
                  style: unbounded(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              Icon(Icons.close, size: 18, color: Colors.white54),
            ],
          ),
        ),
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
              style: unbounded(
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

  Widget _buildRestTimer() {
    final remain = _restSecondsRemaining ?? 0;
    final progress = _restTotal > 0 ? 1 - (remain / _restTotal) : 1.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.successMuted.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer_outlined, color: AppColors.successMuted, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Отдых между подходами: ${remain ~/ 60}:${(remain % 60).toString().padLeft(2, '0')}',
                  style: unbounded(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              TextButton(
                onPressed: _skipRest,
                child: Text(
                  'Пропустить',
                  style: unbounded(
                    fontSize: 13,
                    color: AppColors.mutedGold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.rowAlt,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.successMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrillsListContent() {
    final drills = _plan?.drills ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: drills.asMap().entries.map((e) {
        final i = e.key + 1;
        final d = e.value;
        final key = d.exerciseId ?? d.name;
        final done = _completed[key] ?? false;
        return _buildDrillTile(i, d, done);
      }).toList(),
    );
  }

  static const _sectionBlocks = {
    'Разминка': ['warmup'],
    'СФП (план)': ['main', 'secondary', 'sfp'],
    'ОФП': ['antagonist', 'core', 'plan', 'ofp'],
    'Растяжка': ['cooldown'],
  };

  Widget _buildWorkoutGroupedSections() {
    final sectionsWithContent = _sectionBlocks.entries
        .map((e) => MapEntry(e.key, _ofpExercises.where((ex) => e.value.contains(_workoutBlockKeys[ex.id])).toList()))
        .where((e) => e.value.isNotEmpty)
        .toList();
    final onlyOneSection = sectionsWithContent.length == 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _sectionBlocks.entries.map((section) {
        final blockKeys = section.value.toSet();
        final exercises = _ofpExercises
            .where((e) => blockKeys.contains(_workoutBlockKeys[e.id]))
            .toList();
        if (exercises.isEmpty) return const SizedBox.shrink();
        final expKey = section.key;
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: _buildCollapsibleSection(
            title: section.key,
            expanded: _workoutSectionExpanded[expKey] ?? onlyOneSection,
            onToggle: () {
              setState(() {
                _workoutSectionExpanded[expKey] = !(_workoutSectionExpanded[expKey] ?? false);
                _saveSectionExpandedState();
              });
            },
            count: exercises.length,
            icon: section.key == 'Разминка' ? Icons.whatshot
                : section.key.startsWith('СФП') ? Icons.rocket_launch
                : section.key == 'ОФП' ? Icons.fitness_center
                : Icons.self_improvement,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: exercises.map((e) => _buildOfpTile(e)).toList(),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOfpSectionContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _ofpExercises.map((e) => _buildOfpTile(e)).toList(),
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

  Widget _buildStretchingSectionContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _stretchingExercises.map((e) => _buildStretchingTile(e)).toList(),
    );
  }

  Widget _buildCollapsibleSection({
    required String title,
    required bool expanded,
    required VoidCallback onToggle,
    required int count,
    required Widget child,
    String? badge,
    IconData? icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.graphite),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: AppColors.linkMuted, size: 20),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: unbounded(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.linkMuted.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badge,
                          style: unbounded(fontSize: 11, color: Colors.white70),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      '$count',
                      style: unbounded(
                        fontSize: 13,
                        color: Colors.white54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white54,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded) ...[
            Divider(height: 1, color: AppColors.graphite, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
              child: child,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStretchingTile(CatalogExercise e) {
    final done = _completed[e.id] ?? false;
    final skipped = _skipped[e.id] ?? false;
    final tile = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: skipped ? null : () => _toggleStretchingCompleted(e, !done),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: done
                  ? AppColors.successMuted.withOpacity(0.2)
                  : skipped
                      ? AppColors.graphite.withOpacity(0.2)
                      : AppColors.cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: done ? AppColors.successMuted : AppColors.graphite,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildExerciseThumbnail(e),
                const SizedBox(width: 12),
                if (skipped)
                  InkWell(
                    onTap: () => _toggleExerciseSkipped(e.id, false),
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: Icon(Icons.remove_circle_outline, color: Colors.white54, size: 28),
                    ),
                  )
                else
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: Checkbox(
                      value: done,
                      onChanged: (v) => _toggleStretchingCompleted(e, v ?? false),
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: unbounded(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: done || skipped ? Colors.white70 : Colors.white,
                          decoration: done || skipped ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${e.dosageDisplay} • отдых ${e.defaultRest}',
                        style: unbounded(fontSize: 12, color: Colors.white54),
                      ),
                      if (e.description != null && e.description!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _CollapsibleBenefitRow(
                          text: e.description!,
                          icon: Icons.fitness_center,
                          title: 'Как выполнять',
                        ),
                      ],
                    ],
                  ),
                ),
                if (_isSkipButtonVisible(e.id, done: done, skipped: skipped)) ...[
                  const SizedBox(width: 8),
                  _buildSkipButton(e.id),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    if (!done && !skipped && _isSwipeSupported) {
      return Dismissible(
        key: ValueKey('stretch_${e.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppColors.mutedGold.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Пропустить',
            style: unbounded(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ),
        confirmDismiss: (direction) async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.cardDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Пропустить упражнение?', style: unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
              content: Text(
                'Смайпните влево для пропуска. Нажмите на иконку, чтобы отменить.',
                style: unbounded(fontSize: 14, color: Colors.white70, height: 1.5),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Отмена', style: unbounded(color: Colors.white54))),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.mutedGold),
                  child: Text('Пропустить', style: unbounded(color: Colors.black87, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          );
          return ok == true;
        },
        onDismissed: (_) => _toggleExerciseSkipped(e.id, true, skipConfirmation: true),
        child: tile,
      );
    }
    if (!done && !skipped && !_isSwipeSupported) {
      return _wrapWithLongPressReveal(e.id, tile);
    }
    return tile;
  }

  Future<void> _toggleStretchingCompleted(CatalogExercise e, bool value) async {
    await _toggleExerciseCompleted(e.id, value, setsDone: e.defaultSets, weightKg: null);
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
                  hint,
                  style: unbounded(fontSize: 14, color: Colors.white70, height: 1.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBenefitModal(String title, String text) {
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
                Icon(Icons.route, color: AppColors.mutedGold, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Польза для скалолазания: $title',
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

  Widget _buildExerciseThumbnail(CatalogExercise e) {
    final url = _fullImageUrl(e.imageUrl);
    if (url.isEmpty) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.rowAlt,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.fitness_center, color: Colors.white38, size: 28),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CachedNetworkImage(
        imageUrl: url,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: 56,
          height: 56,
          color: AppColors.rowAlt,
          child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
        ),
        errorWidget: (_, __, ___) => Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: AppColors.rowAlt, borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.fitness_center, color: Colors.white38, size: 28),
        ),
      ),
    );
  }

  Widget _buildOfpTile(CatalogExercise e) {
    final done = _completed[e.id] ?? false;
    final skipped = _skipped[e.id] ?? false;
    final sets = e.defaultSets;
    final approaches = _approachDone[e.id] ?? List.filled(sets, false);
    final nextIndex = approaches.indexWhere((a) => !a);
    final canTapNext = nextIndex >= 0 && _restExerciseKey == null;
    final isRestingForThis = _restExerciseKey == e.id;

    final tile = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: done
              ? AppColors.successMuted.withOpacity(0.2)
              : skipped
                  ? AppColors.graphite.withOpacity(0.2)
                  : AppColors.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: done ? AppColors.successMuted : AppColors.graphite,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildExerciseThumbnail(e),
                const SizedBox(width: 12),
                if (skipped)
                  InkWell(
                    onTap: () => _toggleExerciseSkipped(e.id, false),
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: Icon(Icons.remove_circle_outline, color: Colors.white54, size: 28),
                    ),
                  )
                else if (sets <= 1)
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: Checkbox(
                      value: done,
                      onChanged: (v) => _toggleOfpCompleted(e, v ?? false),
                      activeColor: AppColors.successMuted,
                    ),
                  )
                else
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: done
                        ? Icon(Icons.check_circle, color: AppColors.successMuted, size: 28)
                        : const SizedBox.shrink(),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: unbounded(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: done || skipped ? Colors.white70 : Colors.white,
                          decoration: done || skipped ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${e.dosageDisplay} • отдых ${e.defaultRest}',
                        style: unbounded(fontSize: 12, color: Colors.white54),
                      ),
                      if (e.description != null && e.description!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => _showBenefitModal(e.displayName, e.description!),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.route, size: 14, color: AppColors.mutedGold),
                                const SizedBox(width: 6),
                                Text(
                                  'Польза для скалолазания',
                                  style: unbounded(fontSize: 12, color: AppColors.mutedGold, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (e.hint != null && e.hint!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => _showHintModal(e.displayName, e.hint!),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.help_outline, size: 14, color: AppColors.linkMuted),
                                const SizedBox(width: 6),
                                Text(
                                  'Как выполнять',
                                  style: unbounded(fontSize: 12, color: AppColors.linkMuted, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (sets > 1 && !done && !skipped) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(sets, (i) {
                            final isDone = approaches[i];
                            final isNext = i == nextIndex;
                            final enabled = isNext && canTapNext && !isRestingForThis;
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: enabled
                                    ? () => _onOfpApproachTap(e, i)
                                    : null,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDone
                                          ? AppColors.successMuted.withOpacity(0.3)
                                          : isNext
                                              ? AppColors.mutedGold.withOpacity(0.25)
                                              : AppColors.rowAlt,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isDone
                                            ? AppColors.successMuted
                                            : isNext
                                                ? AppColors.mutedGold
                                                : Colors.white24,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isDone)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 4),
                                            child: Icon(Icons.check, color: AppColors.successMuted, size: 16),
                                          ),
                                        Text(
                                          '${i + 1} подход',
                                          style: unbounded(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isDone ? Colors.white70 : (enabled ? Colors.white : Colors.white54),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_isSkipButtonVisible(e.id, done: done, skipped: skipped)) ...[
                  const SizedBox(width: 8),
                  _buildSkipButton(e.id),
                ],
              ],
            ),
          ],
        ),
      ),
    );
    if (!done && !skipped && _isSwipeSupported) {
      return Dismissible(
        key: ValueKey('ofp_${e.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppColors.mutedGold.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Пропустить',
            style: unbounded(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ),
        confirmDismiss: (direction) async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.cardDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Пропустить упражнение?', style: unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
              content: Text(
                'Смайпните влево для пропуска. Нажмите на иконку, чтобы отменить.',
                style: unbounded(fontSize: 14, color: Colors.white70, height: 1.5),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Отмена', style: unbounded(color: Colors.white54))),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.mutedGold),
                  child: Text('Пропустить', style: unbounded(color: Colors.black87, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          );
          return ok == true;
        },
        onDismissed: (_) => _toggleExerciseSkipped(e.id, true, skipConfirmation: true),
        child: tile,
      );
    }
    if (!done && !skipped && !_isSwipeSupported) {
      return _wrapWithLongPressReveal(e.id, tile);
    }
    return tile;
  }

  Widget _buildDrillTile(int index, TrainingDrill d, bool done) {
    final key = d.exerciseId ?? d.name;
    final skipped = _skipped[key] ?? false;
    final sets = d.sets;
    final restSec = _parseRestSeconds(d.rest);
    final approaches = _approachDone[key] ?? List.filled(sets, false);
    final nextIndex = approaches.indexWhere((a) => !a);
    final canTapNext = nextIndex >= 0 && _restExerciseKey == null;
    final isRestingForThis = _restExerciseKey == key;

    final tile = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: done
              ? AppColors.successMuted.withOpacity(0.2)
              : skipped
                  ? AppColors.graphite.withOpacity(0.2)
                  : AppColors.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: done
                ? AppColors.successMuted
                : skipped
                    ? AppColors.graphite
                    : AppColors.graphite,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (skipped)
                  InkWell(
                    onTap: () => _toggleExerciseSkipped(key, false),
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: Icon(Icons.remove_circle_outline, color: Colors.white54, size: 28),
                    ),
                  )
                else if (sets <= 1)
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: Checkbox(
                      value: done,
                      onChanged: (v) => _toggleCompleted(d, v ?? false),
                      activeColor: AppColors.successMuted,
                    ),
                  )
                else
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: done
                        ? Icon(Icons.check_circle, color: AppColors.successMuted, size: 28)
                        : const SizedBox.shrink(),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: unbounded(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: done || skipped ? Colors.white70 : Colors.white,
                          decoration: done || skipped ? TextDecoration.lineThrough : null,
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
                              style: unbounded(fontSize: 12, color: Colors.white54),
                            ),
                          Text(
                            '${d.sets} × ${d.reps} • отдых ${d.rest}',
                            style: unbounded(fontSize: 12, color: Colors.white54),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      if (d.hint != null && d.hint!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          d.hint!,
                          style: unbounded(
                            fontSize: 11,
                            color: Colors.white38,
                            height: 1.3,
                          ),
                        ),
                      ],
                      if (sets > 1 && !done && !skipped) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(sets, (i) {
                            final isDone = approaches[i];
                            final isNext = i == nextIndex;
                            final enabled = isNext && canTapNext && !isRestingForThis;
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: enabled
                                    ? () => _onDrillApproachTap(d, i, restSec)
                                    : null,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDone
                                          ? AppColors.successMuted.withOpacity(0.3)
                                          : isNext
                                              ? AppColors.mutedGold.withOpacity(0.25)
                                              : AppColors.rowAlt,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isDone
                                            ? AppColors.successMuted
                                            : isNext
                                                ? AppColors.mutedGold
                                                : Colors.white24,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isDone)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 4),
                                            child: Icon(Icons.check, color: AppColors.successMuted, size: 16),
                                          ),
                        Text(
                          '${i + 1} подход',
                          style: unbounded(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDone ? Colors.white70 : (enabled ? Colors.white : Colors.white54),
                          ),
                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            );
                          }),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_isSkipButtonVisible(key, done: done, skipped: skipped)) ...[
                  const SizedBox(width: 8),
                  _buildSkipButton(key),
                ],
              ],
            ),
          ],
        ),
      ),
    );
    if (!done && !skipped && _isSwipeSupported) {
      return Dismissible(
        key: ValueKey('drill_$key'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppColors.mutedGold.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Пропустить',
            style: unbounded(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ),
        confirmDismiss: (direction) async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.cardDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Пропустить упражнение?', style: unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
              content: Text(
                'Смайпните влево для пропуска. Нажмите на иконку, чтобы отменить.',
                style: unbounded(fontSize: 14, color: Colors.white70, height: 1.5),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Отмена', style: unbounded(color: Colors.white54))),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.mutedGold),
                  child: Text('Пропустить', style: unbounded(color: Colors.black87, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          );
          return ok == true;
        },
        onDismissed: (_) => _toggleExerciseSkipped(key, true, skipConfirmation: true),
        child: tile,
      );
    }
    if (!done && !skipped && !_isSwipeSupported) {
      return _wrapWithLongPressReveal(key, tile);
    }
    return tile;
  }

  void _onDrillApproachTap(TrainingDrill d, int approachIndex, int restSec) async {
    final key = d.exerciseId ?? d.name;
    final approaches = List<bool>.from(_approachDone[key] ?? List.filled(d.sets, false));
    approaches[approachIndex] = true;
    setState(() => _approachDone[key] = approaches);

    final allDone = approaches.every((a) => a);
    if (allDone) {
      await _toggleExerciseCompleted(
        key,
        true,
        setsDone: d.sets,
        weightKg: d.targetWeightKg,
      );
      if (mounted) setState(() => _approachDone.remove(key));
    } else {
      _startRestTimer(key, restSec);
    }
  }

  void _onOfpApproachTap(CatalogExercise e, int approachIndex) async {
    final key = e.id;
    final sets = e.defaultSets;
    final restSec = _parseRestSeconds(e.defaultRest);
    final approaches = List<bool>.from(_approachDone[key] ?? List.filled(sets, false));
    approaches[approachIndex] = true;
    setState(() => _approachDone[key] = approaches);

    final allDone = approaches.every((a) => a);
    if (allDone) {
      await _toggleOfpCompleted(e, true);
      if (mounted) setState(() => _approachDone.remove(key));
    } else {
      _startRestTimer(key, restSec);
    }
  }
}

/// Сворачиваемый блок пользы/описания на карточке упражнения.
class _CollapsibleBenefitRow extends StatefulWidget {
  final String text;
  final IconData icon;
  final String title;
  /// Цвет заголовка и иконки — по умолчанию linkMuted (зеленоватый); для «Польза для скалолазания» — mutedGold.
  final Color? titleColor;

  const _CollapsibleBenefitRow({
    required this.text,
    this.icon = Icons.lightbulb_outline,
    this.title = 'Польза для скалолазания',
    this.titleColor,
  });

  @override
  State<_CollapsibleBenefitRow> createState() => _CollapsibleBenefitRowState();
}

class _CollapsibleBenefitRowState extends State<_CollapsibleBenefitRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.titleColor ?? AppColors.linkMuted;
    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(widget.icon, size: 14, color: color.withOpacity(0.9)),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.title,
                        style: unbounded(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 16,
                        color: color,
                      ),
                    ],
                  ),
                  if (_expanded) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.text,
                      style: unbounded(
                        fontSize: 12,
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
