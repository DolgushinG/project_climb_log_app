import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/models/StrengthTier.dart';
import 'package:login_app/models/StrengthAchievement.dart';
import 'package:login_app/Screens/StrengthLeaderboardScreen.dart';
import 'package:login_app/Screens/StrengthMeasurementsScreen.dart';
import 'package:login_app/services/StrengthDashboardService.dart';
import 'package:login_app/services/TrainingGamificationService.dart';
import 'package:login_app/services/StrengthHistoryService.dart';
import 'package:login_app/services/StrengthTestApiService.dart';
import 'package:login_app/services/MeasurementReminderService.dart';
import 'package:login_app/models/StrengthMeasurementSession.dart';

/// Экран «Тестирование» — замеры силы: тяга пальцами, щипок, подтягивания.
/// Вес тела — ключевая переменная. Ранги (Climbing Archetypes) и ачивки.
class ClimbingLogTestingScreen extends StatefulWidget {
  const ClimbingLogTestingScreen({super.key});

  @override
  State<ClimbingLogTestingScreen> createState() => _ClimbingLogTestingScreenState();
}

class _ClimbingLogTestingScreenState extends State<ClimbingLogTestingScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  static const String _keyBodyWeight = 'climbing_test_body_weight';
  static const String _keyLastRank = 'climbing_test_last_rank';
  static const String _keyDraft = 'climbing_test_draft';

  final TextEditingController _bodyWeightController = TextEditingController();
  final TextEditingController _fingerLeftController = TextEditingController();
  final TextEditingController _fingerRightController = TextEditingController();
  final TextEditingController _pinchWeightController = TextEditingController();
  final TextEditingController _pullWeightController = TextEditingController();
  final TextEditingController _pullRepsController = TextEditingController(text: '1');
  final TextEditingController _lockOffSecController = TextEditingController();

  int _pinchBlockWidth = 40;

  OverlayEntry? _levelUpOverlay;
  AnimationController? _levelUpController;
  int? _lastKnownRankIndex;
  StrengthMeasurementSession? _lastSession;
  List<StrengthMeasurementSession> _allSessions = [];

  Timer? _draftSaveTimer;
  DateTime? _lockOffStart;
  Timer? _lockOffTimer;
  int _lockOffElapsedSec = 0;

  @override
  void initState() {
    super.initState();
    _loadBodyWeight().then((_) {
      _loadDraft();
    });
    _loadLastRank();
    _loadLastSession();
    _pullRepsController.addListener(_onMetricsChanged);
    _fingerLeftController.addListener(_onMetricsChanged);
    _fingerRightController.addListener(_onMetricsChanged);
    _pinchWeightController.addListener(_onMetricsChanged);
    _pullWeightController.addListener(_onMetricsChanged);
    _lockOffSecController.addListener(_onMetricsChanged);
    _bodyWeightController.addListener(_onMetricsChanged);
  }

  void _onMetricsChanged() {
    setState(() {});
    _saveDraftLocally();
  }

  @override
  void dispose() {
    _draftSaveTimer?.cancel();
    _lockOffTimer?.cancel();
    _levelUpController?.dispose();
    _removeLevelUpOverlay();
    _bodyWeightController.removeListener(_onMetricsChanged);
    _fingerLeftController.removeListener(_onMetricsChanged);
    _fingerRightController.removeListener(_onMetricsChanged);
    _pinchWeightController.removeListener(_onMetricsChanged);
    _pullWeightController.removeListener(_onMetricsChanged);
    _pullRepsController.removeListener(_onMetricsChanged);
    _lockOffSecController.removeListener(_onMetricsChanged);
    _bodyWeightController.dispose();
    _fingerLeftController.dispose();
    _fingerRightController.dispose();
    _pinchWeightController.dispose();
    _pullWeightController.dispose();
    _pullRepsController.dispose();
    _lockOffSecController.dispose();
    super.dispose();
  }

  Future<void> _loadBodyWeight() async {
    final api = StrengthTestApiService();
    var bw = await api.getBodyWeight();
    if (bw == null) {
      final prefs = await SharedPreferences.getInstance();
      final local = prefs.getString(_keyBodyWeight);
      bw = local != null ? double.tryParse(local.replaceAll(',', '.')) : null;
    }
    if (bw != null && bw > 0 && mounted) {
      _bodyWeightController.text = bw.toStringAsFixed(bw == bw.roundToDouble() ? 0 : 1);
      setState(() {});
    }
  }

  Future<void> _loadLastRank() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_keyLastRank);
    if (mounted) setState(() => _lastKnownRankIndex = last);
  }

  bool _hasUnsentDraft = false;

  Future<void> _saveDraftLocally() async {
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(milliseconds: 500), () async {
      final prefs = await SharedPreferences.getInstance();
      var pinch40 = prefs.getString('${_keyDraft}_pinch_40') ?? '';
      var pinch60 = prefs.getString('${_keyDraft}_pinch_60') ?? '';
      var pinch80 = prefs.getString('${_keyDraft}_pinch_80') ?? '';
      final currentPinch = _pinchWeightController.text.trim();
      switch (_pinchBlockWidth) {
        case 40: pinch40 = currentPinch; break;
        case 60: pinch60 = currentPinch; break;
        case 80: pinch80 = currentPinch; break;
      }
      await prefs.setString('${_keyDraft}_finger_left', _fingerLeftController.text.trim());
      await prefs.setString('${_keyDraft}_finger_right', _fingerRightController.text.trim());
      await prefs.setString('${_keyDraft}_pinch_40', pinch40);
      await prefs.setString('${_keyDraft}_pinch_60', pinch60);
      await prefs.setString('${_keyDraft}_pinch_80', pinch80);
      await prefs.setString('${_keyDraft}_pull_added', _pullWeightController.text.trim());
      await prefs.setString('${_keyDraft}_pull_reps', _pullRepsController.text.trim());
      await prefs.setString('${_keyDraft}_lock_sec', _lockOffSecController.text.trim());
      await prefs.setInt('${_keyDraft}_pinch_block', _pinchBlockWidth);
      final hasMeasurementData = _fingerLeftController.text.trim().isNotEmpty ||
          _fingerRightController.text.trim().isNotEmpty ||
          currentPinch.isNotEmpty ||
          _pullWeightController.text.trim().isNotEmpty ||
          _lockOffSecController.text.trim().isNotEmpty;
      if (mounted) setState(() => _hasUnsentDraft = hasMeasurementData);
    });
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final fingerLeft = prefs.getString('${_keyDraft}_finger_left');
    final fingerRight = prefs.getString('${_keyDraft}_finger_right');
    final pullAdded = prefs.getString('${_keyDraft}_pull_added');
    final pullReps = prefs.getString('${_keyDraft}_pull_reps');
    final lockSec = prefs.getString('${_keyDraft}_lock_sec');
    var pinchBlock = prefs.getInt('${_keyDraft}_pinch_block');
    if (pinchBlock == null || ![40, 60, 80].contains(pinchBlock)) pinchBlock = 40;
    var pinch40 = prefs.getString('${_keyDraft}_pinch_40');
    var pinch60 = prefs.getString('${_keyDraft}_pinch_60');
    var pinch80 = prefs.getString('${_keyDraft}_pinch_80');
    final oldPinch = prefs.getString('${_keyDraft}_pinch');
    if (oldPinch != null && pinch40 == null && pinch60 == null && pinch80 == null) {
      await prefs.setString('${_keyDraft}_pinch_$pinchBlock', oldPinch);
      pinch40 = pinchBlock == 40 ? oldPinch : null;
      pinch60 = pinchBlock == 60 ? oldPinch : null;
      pinch80 = pinchBlock == 80 ? oldPinch : null;
    }
    final pinch = pinchBlock == 40 ? pinch40 : (pinchBlock == 60 ? pinch60 : pinch80);
    final hasAny = fingerLeft != null || fingerRight != null || pinch40 != null || pinch60 != null || pinch80 != null ||
        pullAdded != null || pullReps != null || lockSec != null || pinchBlock != null;
    if (!hasAny || !mounted) return;
    setState(() {
      if (fingerLeft != null) _fingerLeftController.text = fingerLeft;
      if (fingerRight != null) _fingerRightController.text = fingerRight;
      if (pinch != null && pinch.isNotEmpty) _pinchWeightController.text = pinch;
      if (pullAdded != null) _pullWeightController.text = pullAdded;
      if (pullReps != null && pullReps.isNotEmpty) _pullRepsController.text = pullReps;
      if (lockSec != null) _lockOffSecController.text = lockSec;
      if (pinchBlock != null && [40, 60, 80].contains(pinchBlock)) _pinchBlockWidth = pinchBlock;
      _hasUnsentDraft = true;
    });
  }

  Future<void> _switchPinchBlock(int newBlock) async {
    if (newBlock == _pinchBlockWidth) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_keyDraft}_pinch_$_pinchBlockWidth', _pinchWeightController.text.trim());
    await prefs.setInt('${_keyDraft}_pinch_block', newBlock);
    final newPinch = prefs.getString('${_keyDraft}_pinch_$newBlock') ?? '';
    if (mounted) {
      setState(() {
        _pinchBlockWidth = newBlock;
        _pinchWeightController.text = newPinch;
      });
    }
  }

  void _resetForm() {
    _fingerLeftController.clear();
    _fingerRightController.clear();
    _pinchWeightController.clear();
    _pullWeightController.text = '1';
    _pullRepsController.text = '1';
    _lockOffSecController.clear();
    _pinchBlockWidth = 40;
    _lockOffTimer?.cancel();
    _lockOffStart = null;
    _lockOffElapsedSec = 0;
    _clearDraft();
    setState(() => _hasUnsentDraft = false);
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in ['finger_left', 'finger_right', 'pinch', 'pinch_40', 'pinch_60', 'pinch_80', 'pull_added', 'pull_reps', 'lock_sec']) {
      await prefs.remove('${_keyDraft}_$k');
    }
    await prefs.remove('${_keyDraft}_pinch_block');
    if (mounted) setState(() => _hasUnsentDraft = false);
  }

  Future<void> _loadLastSession() async {
    final api = StrengthTestApiService();
    var history = await api.getStrengthTestsHistory(periodDays: 365);
    if (history.isEmpty) {
      history = await StrengthHistoryService().getHistory();
    }
    history = List.from(history)..sort((a, b) => b.date.compareTo(a.date));
    final session = history.isNotEmpty ? history.first : null;
    if (mounted) setState(() {
      _lastSession = session;
      _allSessions = history;
    });
  }

  Future<Map<int, double>> _getPinchValuesForSave() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_keyDraft}_pinch_$_pinchBlockWidth', _pinchWeightController.text.trim());
    return {
      40: double.tryParse((prefs.getString('${_keyDraft}_pinch_40') ?? '').replaceAll(',', '.')) ?? 0,
      60: double.tryParse((prefs.getString('${_keyDraft}_pinch_60') ?? '').replaceAll(',', '.')) ?? 0,
      80: double.tryParse((prefs.getString('${_keyDraft}_pinch_80') ?? '').replaceAll(',', '.')) ?? 0,
    };
  }

  Future<void> _saveMeasurement({bool silent = false}) async {
    final pinches = await _getPinchValuesForSave();
    final m = _buildMetrics(pinches: pinches);
    if (m.bodyWeightKg == null || m.bodyWeightKg! <= 0) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Сначала введи свой вес'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final api = StrengthTestApiService();
    final rank = _currentRank;
    final badges = strengthAchievements.where((a) => a.check(m)).map((a) => a.id).toList();
    final body = api.buildStrengthTestBody(
      m,
      currentRank: rank?.titleEn,
      unlockedBadges: badges.isNotEmpty ? badges : null,
    );
    await api.saveStrengthTest(body);
    await StrengthHistoryService().saveSession(m);
    await StrengthDashboardService().saveMetrics(m);
    await TrainingGamificationService().recordMeasurement();
    await _clearDraft();
    if (mounted) {
      final prevSession = _lastSession;
      final newSession = StrengthMeasurementSession(date: dateStr, metrics: m);
      setState(() {
        _lastSession = newSession;
        _allSessions = [newSession, ..._allSessions.where((s) => s.date != dateStr)];
        _showAddForm = false;
      });
      _checkLevelUp();
      MeasurementReminderService.scheduleReminder();
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Замер сохранён'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.successMuted,
            duration: const Duration(seconds: 2),
          ),
        );
        if (prevSession != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showComparisonDialog(prev: prevSession, current: newSession);
          });
        }
      }
    }
  }

  void _showComparisonDialog({
    required StrengthMeasurementSession prev,
    required StrengthMeasurementSession current,
  }) {
    final lines = <String>[];
    final pm = prev.metrics;
    final cm = current.metrics;

    void addLine(String label, double? oldVal, double? newVal, String suffix) {
      if (oldVal == null && newVal == null) return;
      final o = oldVal ?? 0.0;
      final n = newVal ?? 0.0;
      final diff = n - o;
      final sign = diff >= 0 ? '+' : '';
      lines.add('$label: ${o.toStringAsFixed(1)} → ${n.toStringAsFixed(1)} ($sign${diff.toStringAsFixed(1)}$suffix)');
    }

    void addLineInt(String label, int? oldVal, int? newVal, String suffix) {
      if (oldVal == null && newVal == null) return;
      final diff = (newVal ?? 0) - (oldVal ?? 0);
      final sign = diff >= 0 ? '+' : '';
      lines.add('$label: $oldVal → $newVal ($sign$diff$suffix)');
    }

    addLine('Пальцы Л', pm.fingerLeftKg, cm.fingerLeftKg, ' кг');
    addLine('Пальцы П', pm.fingerRightKg, cm.fingerRightKg, ' кг');
    addLine('Щипок 40 мм', pm.pinch40Kg, cm.pinch40Kg, ' кг');
    addLine('Щипок 60 мм', pm.pinch60Kg, cm.pinch60Kg, ' кг');
    addLine('Щипок 80 мм', pm.pinch80Kg, cm.pinch80Kg, ' кг');
    addLine('Тяга (+кг)', pm.pullAddedKg, cm.pullAddedKg, ' кг');
    addLine('Тяга (% от веса)', pm.pull1RmPct, cm.pull1RmPct, '%');
    addLineInt('Lock-off', pm.lockOffSec, cm.lockOffSec, ' сек');

    if (lines.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Сравнение с предыдущим замером',
          style: unbounded(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lines.map((line) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                line,
                style: unbounded(color: Colors.white70, fontSize: 13),
              ),
            )).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Ок', style: unbounded(color: AppColors.mutedGold)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveBodyWeight(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBodyWeight, value);
    final kg = double.tryParse(value.replaceAll(',', '.'));
    if (kg != null && kg >= 30 && kg <= 200) {
      await StrengthTestApiService().saveBodyWeight(kg);
    }
  }

  StrengthMetrics _buildMetrics({Map<int, double>? pinches}) {
    final bw = _bodyWeight;
    final left = _parseNum(_fingerLeftController);
    final right = _parseNum(_fingerRightController);
    final addW = _parseNum(_pullWeightController);
    final reps = _parseInt(_pullRepsController) ?? 1;
    double? pull1RmPct;
    if (addW != null && bw != null && bw > 0) {
      final total = bw + addW;
      final oneRm = reps == 1 ? total : total * (1 + reps / 30);
      pull1RmPct = (oneRm / bw) * 100;
    }
    final lockSec = _parseInt(_lockOffSecController);
    double? pinch40;
    double? pinch60;
    double? pinch80;
    if (pinches != null) {
      if (pinches[40] != null && pinches[40]! > 0) pinch40 = pinches[40];
      if (pinches[60] != null && pinches[60]! > 0) pinch60 = pinches[60];
      if (pinches[80] != null && pinches[80]! > 0) pinch80 = pinches[80];
    } else {
      final p = _parseNum(_pinchWeightController);
      if (p != null && p > 0) {
        switch (_pinchBlockWidth) {
          case 40: pinch40 = p; break;
          case 60: pinch60 = p; break;
          case 80: pinch80 = p; break;
        }
      }
    }
    return StrengthMetrics(
      fingerLeftKg: left,
      fingerRightKg: right,
      pinch40Kg: pinch40,
      pinch60Kg: pinch60,
      pinch80Kg: pinch80,
      pullAddedKg: addW,
      pull1RmPct: pull1RmPct,
      lockOffSec: lockSec,
      bodyWeightKg: bw,
    );
  }

  double? get _averageStrengthPct {
    final m = _buildMetrics();
    final bw = m.bodyWeightKg;
    if (bw == null || bw <= 0) return null;
    final list = <double>[];
    final finger = m.fingerBestPct;
    if (finger != null) list.add(finger);
    if (m.pinchPct != null) list.add(m.pinchPct!);
    if (m.pull1RmPct != null) list.add(m.pull1RmPct!);
    if (m.lockOffSec != null && m.lockOffSec! > 0) {
      list.add((m.lockOffSec! / 30.0) * 100);
    }
    if (list.isEmpty) return null;
    return list.reduce((a, b) => a + b) / list.length;
  }

  StrengthTier? get _currentRank {
    final avg = _averageStrengthPct;
    if (avg == null) return null;
    return StrengthTierExt.fromAveragePct(avg);
  }

  void _checkLevelUp() {
    final rank = _currentRank;
    if (rank == null) return;
    final last = _lastKnownRankIndex;
    if (last != null && last < rank.index && mounted) {
      _lastKnownRankIndex = rank.index;
      SharedPreferences.getInstance().then((p) => p.setInt(_keyLastRank, rank.index));
      _showLevelUpOverlay(rank);
    } else if (last == null && mounted) {
      _lastKnownRankIndex = rank.index;
      SharedPreferences.getInstance().then((p) => p.setInt(_keyLastRank, rank.index));
    }
  }

  void _showLevelUpOverlay(StrengthTier tier) {
    _removeLevelUpOverlay();
    _levelUpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _levelUpController!.forward();
    _levelUpOverlay = OverlayEntry(
      builder: (ctx) => _LevelUpOverlay(
        tier: tier,
        controller: _levelUpController!,
        onDismiss: _removeLevelUpOverlay,
      ),
    );
    Overlay.of(context).insert(_levelUpOverlay!);
    Future.delayed(const Duration(milliseconds: 4000), () {
      if (mounted) _removeLevelUpOverlay();
    });
  }

  void _removeLevelUpOverlay() {
    _levelUpOverlay?.remove();
    _levelUpOverlay = null;
    _levelUpController?.dispose();
    _levelUpController = null;
  }

  double? get _bodyWeight {
    final v = double.tryParse(_bodyWeightController.text.replaceAll(',', '.'));
    return v != null && v > 0 ? v : null;
  }

  double? _parseNum(TextEditingController c) {
    final v = double.tryParse(c.text.replaceAll(',', '.'));
    return v != null && v >= 0 ? v : null;
  }

  int? _parseInt(TextEditingController c) {
    final v = int.tryParse(c.text);
    return v != null && v >= 1 ? v : null;
  }

  void _showInstruction(String title, String text, {String? proTip}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: unbounded(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: unbounded(color: Colors.white70, fontSize: 14),
              ),
              if (proTip != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.mutedGold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.mutedGold.withOpacity(0.4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline, color: AppColors.mutedGold, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Подсказка: $proTip',
                          style: unbounded(
                            color: AppColors.mutedGold,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Ок', style: unbounded(color: AppColors.mutedGold)),
          ),
        ],
      ),
    );
  }

  void _showAsymmetryAlert() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Асимметрия',
          style: unbounded(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Разрыв больше 10% между руками — риск травмы на долгих кримпах. Добавь эксцентрику на слабую руку.',
          style: unbounded(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Ок', style: unbounded(color: AppColors.mutedGold)),
          ),
        ],
      ),
    );
  }

  bool _showAddForm = false;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_showAddForm) {
      return _buildAddFormScreen();
    }
    return _buildMainScreen();
  }

  /// Главный экран: 3 отдельные кнопки
  Widget _buildMainScreen() {
    return Scaffold(
      backgroundColor: AppColors.anthracite,
      body: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Text(
                  'Замеры',
                  style: unbounded(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            if (MeasurementReminderService.shouldShowHint(_lastSession?.date))
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.mutedGold.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.mutedGold.withOpacity(0.35)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule, color: AppColors.mutedGold, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Рекомендуем замериться раз в 2–4 недели для отслеживания прогресса.',
                            style: unbounded(
                              fontSize: 13,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            if (_lastSession == null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildEmptyPlaceholder(),
                ),
              ),
            if (_lastSession != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildLastMeasurementBlocks(),
                ),
              ),
            if (_lastSession != null) const SliverToBoxAdapter(child: SizedBox(height: 16)),
            if (_lastSession != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildRankCard(metricsForDisplay: _lastSession!.metrics),
                ),
              ),
            if (_lastSession != null) const SliverToBoxAdapter(child: SizedBox(height: 16)),
            if (_lastSession != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildBadgesCard(allSessions: _allSessions),
                ),
              ),
            if (_lastSession != null) const SliverToBoxAdapter(child: SizedBox(height: 24)),
            if (_lastSession == null) const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildActionButton(
                      icon: Icons.fitness_center,
                      label: 'Наши замеры',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StrengthMeasurementsScreen(),
                        ),
                      ).then((_) {
                        if (mounted) _loadLastSession();
                      }),
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton(
                      icon: Icons.leaderboard_outlined,
                      label: 'Посмотреть рейтинг',
                      onPressed: () {
                        final bw = _bodyWeight;
                        final range = bw != null && bw >= 30 && bw <= 200
                            ? '${(bw - 5).clamp(30.0, 195.0).round()}-${(bw + 5).clamp(35.0, 200.0).round()}'
                            : null;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StrengthLeaderboardScreen(weightRangeKg: range),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton(
                      icon: Icons.add_circle_outline,
                      label: 'Добавить замер',
                      onPressed: () {
                        _resetForm();
                        setState(() => _showAddForm = true);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  /// Блоки с информацией о последнем замере
  Widget _buildLastMeasurementBlocks() {
    final s = _lastSession!;
    final m = s.metrics;
    final blocks = <Widget>[];

    if (m.bodyWeightKg != null && m.bodyWeightKg! > 0) {
      blocks.add(_buildMetricBlock(
        icon: Icons.monitor_weight_outlined,
        label: 'Вес',
        value: '${m.bodyWeightKg!.toStringAsFixed(1)} кг',
      ));
    }
    if (m.fingerLeftKg != null || m.fingerRightKg != null) {
      blocks.add(_buildMetricBlock(
        icon: Icons.back_hand_outlined,
        label: 'Пальцы',
        value: 'Л ${m.fingerLeftKg?.toStringAsFixed(1) ?? '—'} / П ${m.fingerRightKg?.toStringAsFixed(1) ?? '—'} кг',
      ));
    }
    if (m.pinch40Kg != null || m.pinch60Kg != null || m.pinch80Kg != null) {
      final parts = <String>[];
      if (m.pinch40Kg != null) parts.add('40: ${m.pinch40Kg!.toStringAsFixed(1)}');
      if (m.pinch60Kg != null) parts.add('60: ${m.pinch60Kg!.toStringAsFixed(1)}');
      if (m.pinch80Kg != null) parts.add('80: ${m.pinch80Kg!.toStringAsFixed(1)}');
      blocks.add(_buildMetricBlock(
        icon: Icons.pan_tool_outlined,
        label: 'Щипок (мм)',
        value: parts.join(' / ') + ' кг',
      ));
    }
    if (m.pullAddedKg != null) {
      blocks.add(_buildMetricBlock(
        icon: Icons.fitness_center,
        label: 'Тяга',
        value: '+${m.pullAddedKg!.toStringAsFixed(1)} кг',
      ));
    }
    if (m.lockOffSec != null && m.lockOffSec! > 0) {
      blocks.add(_buildMetricBlock(
        icon: Icons.lock,
        label: 'Lock-off',
        value: '${m.lockOffSec} сек',
      ));
    }
    if (blocks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_today, color: AppColors.linkMuted, size: 18),
            const SizedBox(width: 8),
            Text(
              'Последний замер: ${s.dateFormatted}',
              style: unbounded(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: blocks,
        ),
      ],
    );
  }

  Widget _buildMetricBlock({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.graphite),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.mutedGold, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: unbounded(fontSize: 11, color: Colors.white54),
              ),
              Text(
                value,
                style: unbounded(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.graphite),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fitness_center_outlined, size: 56, color: AppColors.mutedGold.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'Пока нет замеров',
            style: unbounded(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Добавь первый замер, чтобы отслеживать прогресс',
            textAlign: TextAlign.center,
            style: unbounded(
              fontSize: 14,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22, color: AppColors.mutedGold),
        label: Text(
          label,
          style: unbounded(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.mutedGold),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.mutedGold,
          side: BorderSide(color: AppColors.mutedGold.withOpacity(0.6)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        ),
      ),
    );
  }

  /// Экран формы добавления замера (после клика «Добавить замер»)
  Widget _buildAddFormScreen() {
    return Scaffold(
      backgroundColor: AppColors.anthracite,
      appBar: AppBar(
        backgroundColor: AppColors.anthracite,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => setState(() => _showAddForm = false),
        ),
        title: Text(
          'Добавить замер',
          style: unbounded(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildBodyWeightCard(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildFingerIsometricsCard(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildPinchGripCard(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildPullingPowerCard(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildLockOffCard(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildAsymmetryCard(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildSaveMeasurementButton(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyWeightCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.mutedGold.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.monitor_weight_outlined, color: AppColors.mutedGold, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Твой вес (кг)',
                  style: unbounded(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _bodyWeightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: unbounded(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: '70',
                    hintStyle: unbounded(color: Colors.white38),
                    filled: true,
                    fillColor: AppColors.rowAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (v) {
                    setState(() {});
                    _saveBodyWeight(v);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveMeasurementButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _hasUnsentDraft ? AppColors.successMuted.withOpacity(0.6) : AppColors.graphite,
          width: _hasUnsentDraft ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_hasUnsentDraft)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.save_outlined, color: AppColors.successMuted, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Черновик сохранён локально',
                    style: unbounded(fontSize: 13, color: AppColors.successMuted),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _saveMeasurement(silent: false),
              icon: const Icon(Icons.check_circle_outline, size: 22),
              label: Text(
                'Закончить замер',
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
        ],
      ),
    );
  }

  static double? _averageStrengthPctFromMetrics(StrengthMetrics m) {
    final bw = m.bodyWeightKg;
    if (bw == null || bw <= 0) return null;
    final list = <double>[];
    final finger = m.fingerBestPct;
    if (finger != null) list.add(finger);
    if (m.pinchPct != null) list.add(m.pinchPct!);
    if (m.pull1RmPct != null) list.add(m.pull1RmPct!);
    if (m.lockOffSec != null && m.lockOffSec! > 0) {
      list.add((m.lockOffSec! / 30.0) * 100);
    }
    if (list.isEmpty) return null;
    return list.reduce((a, b) => a + b) / list.length;
  }

  Widget _buildRankCard({StrengthMetrics? metricsForDisplay}) {
    final avg = metricsForDisplay != null
        ? _averageStrengthPctFromMetrics(metricsForDisplay)
        : _averageStrengthPct;
    final rank = avg != null ? StrengthTierExt.fromAveragePct(avg) : null;
    if (rank == null || avg == null) {
      if (_lastSession != null) return const SizedBox.shrink();
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.graphite),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.emoji_events_outlined, color: Colors.white38, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Сделай хотя бы один тест — и узнаешь свой уровень',
                style: unbounded(fontSize: 14, color: Colors.white54),
                softWrap: true,
              ),
            ),
          ],
        ),
      );
    }
    final next = rank.nextTier;
    final gap = rank.gapToNext(avg);
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
        border: Border.all(color: AppColors.mutedGold.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(rank.icon, color: AppColors.mutedGold, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ур. ${rank.level} — ${rank.titleRu}',
                      style: unbounded(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${avg.toStringAsFixed(1)}% от веса — твоя средняя',
                      style: unbounded(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (next != null && gap > 0) ...[
            const SizedBox(height: 12),
            Text(
              'До ${next.titleRu} ещё +${gap.toStringAsFixed(1)}%',
              style: unbounded(
                fontSize: 13,
                color: AppColors.mutedGold.withOpacity(0.9),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadgesCard({StrengthMetrics? metricsForDisplay, List<StrengthMeasurementSession>? allSessions}) {
    final sessions = allSessions ?? (_lastSession != null ? [_lastSession!] : []);
    final unlocked = strengthAchievements.where((a) => sessions.any((s) => a.check(s.metrics))).toList();
    final locked = strengthAchievements.where((a) => !sessions.any((s) => a.check(s.metrics))).toList();
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
              Icon(Icons.workspace_premium, color: AppColors.mutedGold, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ачивки',
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
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ...unlocked.map((a) => _buildBadgeChip(a, true)),
              ...locked.map((a) => _buildBadgeChip(a, false)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeChip(StrengthAchievement a, bool unlocked) {
    final message = unlocked
        ? '${a.titleRu}\n${a.descriptionRu}'
        : '${a.titleRu}\n${a.descriptionRu}\n\nКак получить: ${a.hintRu ?? "Выполни замеры в разделе «Тест»."}';
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: unlocked
            ? AppColors.mutedGold.withOpacity(0.25)
            : AppColors.rowAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unlocked ? AppColors.mutedGold : Colors.white12,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            a.icon,
            size: 18,
            color: unlocked ? AppColors.mutedGold : Colors.white38,
          ),
          const SizedBox(width: 6),
          Text(
            a.titleRu,
            style: unbounded(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: unlocked ? Colors.white : Colors.white54,
            ),
          ),
        ],
      ),
    );
    return Tooltip(
      message: message,
      child: InkWell(
        onTap: unlocked ? null : () => _showAchievementHint(a),
        borderRadius: BorderRadius.circular(12),
        child: chip,
      ),
    );
  }

  void _showAchievementHint(StrengthAchievement a) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(a.icon, color: AppColors.mutedGold, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                a.titleRu,
                style: unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              a.descriptionRu,
              style: unbounded(fontSize: 14, color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Как получить:',
              style: unbounded(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.mutedGold),
            ),
            const SizedBox(height: 4),
            Text(
              a.hintRu ?? 'Выполни замеры в разделе «Тест».',
              style: unbounded(fontSize: 13, color: Colors.white70, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Понятно', style: unbounded(color: AppColors.mutedGold)),
          ),
        ],
      ),
    );
  }

  void _startLockOffTimer() {
    _lockOffTimer?.cancel();
    _lockOffStart = DateTime.now();
    _lockOffElapsedSec = 0;
    setState(() {});
    _lockOffTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final sec = DateTime.now().difference(_lockOffStart!).inSeconds;
      setState(() => _lockOffElapsedSec = sec);
    });
  }

  void _stopLockOffTimer() {
    _lockOffTimer?.cancel();
    _lockOffTimer = null;
    if (_lockOffStart != null) {
      final sec = DateTime.now().difference(_lockOffStart!).inSeconds;
      _lockOffSecController.text = sec.toString();
    }
    _lockOffStart = null;
    _lockOffElapsedSec = 0;
    if (mounted) setState(() {});
  }

  Widget _buildLockOffCard() {
    const instruction = 'Вис на одной руке, локоть 90°. Засекай время до отказа. '
        'Без раскачки и киппинга — чистый lock-off.';
    final isRunning = _lockOffStart != null;
    return _buildTestCard(
      title: 'Lock-off 90° (одна рука)',
      icon: Icons.lock,
      instruction: instruction,
      onHelpTap: () => _showInstruction('Lock-off', instruction),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _buildInputField(
                  'Секунды',
                  _lockOffSecController,
                ),
              ),
              const SizedBox(width: 12),
              if (isRunning) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.successMuted.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.successMuted),
                  ),
                  child: Text(
                    '$_lockOffElapsedSec сек',
                    style: unbounded(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.successMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 44,
                  child: FilledButton(
                    onPressed: _stopLockOffTimer,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Стоп', style: unbounded(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ] else ...[
                SizedBox(
                  height: 44,
                  child: FilledButton.icon(
                    onPressed: _startLockOffTimer,
                    icon: const Icon(Icons.timer, size: 16),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.mutedGold,
                      foregroundColor: AppColors.anthracite,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    label: Text('Старт', style: unbounded(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTestCard({
    required String title,
    required IconData icon,
    required String instruction,
    required VoidCallback onHelpTap,
    required Widget child,
  }) {
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
              Icon(icon, color: AppColors.mutedGold, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: unbounded(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onHelpTap,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.mutedGold.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '?',
                    style: unbounded(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mutedGold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildFingerIsometricsCard() {
    const instruction = 'Планка 8 мм на грузовой ленте. Встань ровно, рука чуток согнута в локте. '
        'Плавно тяни вес вверх 5 секунд, без читинга корпусом.';
    const proTip = 'Если на блоке тянешь на 20% больше, чем в висе на финге — '
        'слабое звено не пальцы, а плечо или кор. Качай стабильность!';

    final left = _parseNum(_fingerLeftController);
    final right = _parseNum(_fingerRightController);
    final bw = _bodyWeight;
    final m = _buildMetrics();
    final asym = m.asymmetryPct;
    final asymWarning = asym != null && asym > 10;
    final leftWeak = asymWarning && left != null && right != null && left < right;
    final rightWeak = asymWarning && left != null && right != null && right < left;
    double? leftPct;
    double? rightPct;
    if (bw != null && bw > 0) {
      if (left != null) leftPct = (left / bw) * 100;
      if (right != null) rightPct = (right / bw) * 100;
    }

    return _buildTestCard(
      title: 'Подъём веса на 8 мм планке',
      icon: Icons.back_hand_outlined,
      instruction: instruction,
      onHelpTap: () => _showInstruction('Подъём веса 8 мм', instruction, proTip: proTip),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leftWeak)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Левая тянет слабее — долгий crimp грозит травмой. Качай эксцентрику.',
                style: unbounded(
                  fontSize: 12,
                  color: Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (rightWeak && !leftWeak)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Правая тянет слабее — долгий crimp грозит травмой. Качай эксцентрику.',
                style: unbounded(
                  fontSize: 12,
                  color: Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  'Левая (кг)',
                  _fingerLeftController,
                  hasWarning: leftWeak,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInputField(
                  'Правая (кг)',
                  _fingerRightController,
                  hasWarning: rightWeak,
                ),
              ),
            ],
          ),
          if ((leftPct != null || rightPct != null) && bw != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              children: [
                if (leftPct != null)
                  Text(
                    'Левая: ${leftPct.toStringAsFixed(1)}%',
                    style: unbounded(
                      fontSize: 13,
                      color: AppColors.mutedGold,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (rightPct != null)
                  Text(
                    'Правая: ${rightPct.toStringAsFixed(1)}%',
                    style: unbounded(
                      fontSize: 13,
                      color: AppColors.mutedGold,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPinchGripCard() {
    const instruction = 'Щипковый блок — большой палец напротив остальных. '
        'Подними вес вертикально и держи 3–5 сек. Без помощи ноги и корпуса — только кисть и предплечье.';

    return _buildTestCard(
      title: 'Подъём веса щипка ${_pinchBlockWidth} мм',
      icon: Icons.pan_tool_outlined,
      instruction: instruction,
      onHelpTap: () => _showInstruction('Подъём веса щипка', instruction),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ширина блока',
            style: unbounded(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildChip('40 мм', _pinchBlockWidth == 40, () => _switchPinchBlock(40)),
              const SizedBox(width: 8),
              _buildChip('60 мм', _pinchBlockWidth == 60, () => _switchPinchBlock(60)),
              const SizedBox(width: 8),
              _buildChip('80 мм', _pinchBlockWidth == 80, () => _switchPinchBlock(80)),
            ],
          ),
          const SizedBox(height: 16),
          _buildInputField(
            'Макс. (кг)',
            _pinchWeightController,
          ),
        ],
      ),
    );
  }

  Widget _buildPullingPowerCard() {
    const instruction = 'Подтягивание с доп. весом. Подбородок над перекладиной — считаем. '
        'С Tindeq — взрывной рывок из виса на прямых. Читинг не считается.';

    final addWeight = _parseNum(_pullWeightController);
    final reps = _parseInt(_pullRepsController) ?? 1;
    final bw = _bodyWeight ?? 0;

    double? oneRm;
    if (addWeight != null && addWeight >= 0 && bw > 0) {
      final total = bw + addWeight;
      if (reps == 1) {
        oneRm = total;
      } else {
        // Epley formula: 1RM = weight * (1 + reps/30)
        oneRm = total * (1 + reps / 30);
      }
    }

    double? relStrength;
    String? level;
    if (oneRm != null && bw > 0) {
      relStrength = (oneRm / bw) * 100;
      if (relStrength >= 180) {
        level = 'Элита (8c+)';
      } else if (relStrength >= 150) {
        level = 'Продвинутый (7c+)';
      } else if (relStrength >= 120) {
        level = 'Средний (6c)';
      } else if (relStrength >= 100) {
        level = 'Старт';
      } else {
        level = 'Есть куда растить';
      }
    }

    return _buildTestCard(
      title: 'Тяга (подтяг с весом)',
      icon: Icons.fitness_center,
      instruction: instruction,
      onHelpTap: () => _showInstruction('Тяга', instruction),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  'Доп. вес (кг)',
                  _pullWeightController,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 90,
                child: _buildInputField(
                  'Повторения',
                  _pullRepsController,
                ),
              ),
            ],
          ),
          if (relStrength != null && level != null) ...[
            const SizedBox(height: 16),
            _buildScoreBar(relStrength, level),
          ],
        ],
      ),
    );
  }

  Widget _buildScoreBar(double relativeStrength, String level) {
    // 100% bar = Elite ~180% BW, 50% = Intermediate ~120%
    final clamped = relativeStrength.clamp(80.0, 200.0);
    final progress = (clamped - 80) / 120;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                '${relativeStrength.toStringAsFixed(0)}% от веса',
                style: unbounded(
                  fontSize: 14,
                  color: AppColors.mutedGold,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                level,
                style: unbounded(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: AppColors.rowAlt,
            valueColor: AlwaysStoppedAnimation<Color>(
              progress >= 0.8
                  ? AppColors.successMuted
                  : progress >= 0.5
                      ? AppColors.mutedGold
                      : Colors.white54,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAsymmetryCard() {
    final left = _parseNum(_fingerLeftController);
    final right = _parseNum(_fingerRightController);
    double? diffPct;
    if (left != null && right != null && (left + right) > 0) {
      final maxVal = left > right ? left : right;
      final minVal = left < right ? left : right;
      diffPct = ((maxVal - minVal) / maxVal) * 100;
    }

    return _buildTestCard(
      title: 'Асимметрия (Л vs П)',
      icon: Icons.balance_outlined,
      instruction: 'Сравни левую и правую — разница больше 10% уже тревожный звоночек.',
      onHelpTap: _showAsymmetryAlert,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (diffPct != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Разница: ${diffPct.toStringAsFixed(1)}%',
                    style: unbounded(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: diffPct > 10 ? Colors.orange : Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (diffPct > 10) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _showAsymmetryAlert,
                    child: Text(
                      'Как исправить',
                      style: unbounded(color: AppColors.mutedGold, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
            if (diffPct > 10)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Эксцентрика на слабую — Offset, однорукие висы',
                  style: unbounded(fontSize: 12, color: Colors.white54),
                ),
              ),
          ] else ...[
            Text(
              'Введи левую и правую в блоке «Вис на пальцах»',
              style: unbounded(fontSize: 13, color: Colors.white54),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.mutedGold.withOpacity(0.3) : AppColors.rowAlt,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.mutedGold : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: unbounded(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? AppColors.mutedGold : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller, {
    VoidCallback? onChanged,
    bool hasWarning = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: unbounded(fontSize: 12, color: Colors.white70),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: unbounded(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: unbounded(color: Colors.white38),
            filled: true,
            fillColor: hasWarning ? Colors.orange.withOpacity(0.12) : AppColors.rowAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasWarning ? Colors.orange : Colors.transparent,
                width: hasWarning ? 1.5 : 0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasWarning ? Colors.orange : AppColors.mutedGold,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          onChanged: (_) {
            setState(() {});
            onChanged?.call();
          },
        ),
      ],
    );
  }
}

/// Overlay для анимации Level Up.
class _LevelUpOverlay extends StatefulWidget {
  final StrengthTier tier;
  final AnimationController controller;
  final VoidCallback onDismiss;

  const _LevelUpOverlay({
    required this.tier,
    required this.controller,
    required this.onDismiss,
  });

  @override
  State<_LevelUpOverlay> createState() => _LevelUpOverlayState();
}

class _LevelUpOverlayState extends State<_LevelUpOverlay> {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: GestureDetector(
        onTap: widget.onDismiss,
        child: Center(
          child: AnimatedBuilder(
            animation: widget.controller,
            builder: (context, child) {
              final scale = Tween<double>(begin: 0.5, end: 1.2)
                  .animate(CurvedAnimation(
                    parent: widget.controller,
                    curve: Curves.elasticOut,
                  ))
                  .value;
              final opacity = Tween<double>(begin: 0, end: 1)
                  .animate(CurvedAnimation(
                    parent: widget.controller,
                    curve: const Interval(0, 0.5, curve: Curves.easeOut),
                  ))
                  .value;
              return Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    margin: const EdgeInsets.all(32),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.mutedGold.withOpacity(0.4),
                          AppColors.cardDark,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.mutedGold, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.mutedGold.withOpacity(0.3),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.tier.icon,
                          size: 64,
                          color: AppColors.mutedGold,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'НОВЫЙ УРОВЕНЬ!',
                          style: unbounded(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.tier.titleRu,
                          style: unbounded(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mutedGold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            12,
                            (i) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: [
                                  AppColors.mutedGold,
                                  Colors.orange,
                                  Colors.amber,
                                ][i % 3],
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
