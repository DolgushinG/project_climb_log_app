import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/TrainerStudent.dart';
import '../models/ClimbingLog.dart';
import '../theme/app_theme.dart';
import '../services/TrainerService.dart';
import '../utils/display_helper.dart';
import '../utils/app_snackbar.dart';
import 'TrainerAssignExerciseScreen.dart';

class TrainerStudentDetailScreen extends StatefulWidget {
  final TrainerStudent student;

  const TrainerStudentDetailScreen({super.key, required this.student});

  @override
  State<TrainerStudentDetailScreen> createState() => _TrainerStudentDetailScreenState();
}

class _TrainerStudentDetailScreenState extends State<TrainerStudentDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TrainerService _service = TrainerService(baseUrl: DOMAIN);

  List<HistorySession> _climbingSessions = [];
  List<Map<String, dynamic>> _completions = [];
  List<Map<String, dynamic>> _assignments = [];
  bool _loadingClimbing = false;
  bool _loadingCompletions = false;
  bool _loadingAssignments = false;
  int _periodDays = 30;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    _loadClimbing();
    _loadCompletions();
    _loadAssignments();
  }

  Future<void> _loadClimbing() async {
    if (!mounted) return;
    setState(() => _loadingClimbing = true);
    try {
      final raw = await _service.getStudentClimbingHistory(context, widget.student.id, periodDays: _periodDays);
      if (!mounted) return;
      setState(() {
        _climbingSessions = raw.map((e) => HistorySession.fromJson(e)).toList();
        _loadingClimbing = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingClimbing = false);
    }
  }

  Future<void> _loadCompletions() async {
    if (!mounted) return;
    setState(() => _loadingCompletions = true);
    try {
      final raw = await _service.getStudentExerciseCompletions(
        context,
        widget.student.id,
        periodDays: _periodDays,
      );
      if (!mounted) return;
      setState(() {
        _completions = raw;
        _loadingCompletions = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingCompletions = false);
    }
  }

  Future<void> _loadAssignments() async {
    if (!mounted) return;
    setState(() => _loadingAssignments = true);
    try {
      final raw = await _service.getAssignments(
        context,
        widget.student.id,
        periodDays: _periodDays,
      );
      if (!mounted) return;
      setState(() {
        _assignments = raw;
        _loadingAssignments = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingAssignments = false);
    }
  }

  String _formatDate(String? s) {
    if (s == null || s.isEmpty) return '';
    try {
      final dt = DateTime.tryParse(s);
      if (dt != null) return DateFormat('dd.MM.yyyy').format(dt);
    } catch (_) {}
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.student.displayName, style: unbounded(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white)),
        backgroundColor: AppColors.cardDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.mutedGold,
          unselectedLabelColor: Colors.white54,
          indicatorColor: AppColors.mutedGold,
          tabs: const [
            Tab(text: 'Тренировки'),
            Tab(text: 'Выполненные'),
            Tab(text: 'Упражнения'),
          ],
        ),
        actions: [
          PopupMenuButton<int>(
            icon: Icon(Icons.calendar_today, color: AppColors.mutedGold),
            color: AppColors.cardDark,
            onSelected: (v) {
              setState(() => _periodDays = v);
              _loadAll();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 7, child: Text('7 дней', style: unbounded(color: Colors.white))),
              PopupMenuItem(value: 30, child: Text('30 дней', style: unbounded(color: Colors.white))),
              PopupMenuItem(value: 90, child: Text('90 дней', style: unbounded(color: Colors.white))),
            ],
          ),
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: AppColors.mutedGold),
            onPressed: () => _openAssignExercise(),
            tooltip: 'Добавить упражнения',
          ),
        ],
      ),
      body: Container(
        color: AppColors.anthracite,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildClimbingTab(),
            _buildCompletionsTab(),
            _buildAssignmentsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildClimbingTab() {
    if (_loadingClimbing) {
      return const Center(child: CircularProgressIndicator(color: AppColors.mutedGold));
    }
    if (_climbingSessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route, size: 48, color: Colors.grey.shade600),
            const SizedBox(height: 12),
            Text(
              'Нет тренировок за период',
              style: unbounded(color: Colors.white70),
            ),
            Text(
              'Выберите другой период в меню',
              style: unbounded(fontSize: 12, color: Colors.white54),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadClimbing,
      color: AppColors.mutedGold,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _climbingSessions.length,
        itemBuilder: (context, i) {
          final s = _climbingSessions[i];
          final routesCount = s.routes.fold<int>(0, (sum, r) => sum + r.count);
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: AppColors.cardDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 18, color: AppColors.mutedGold),
                      const SizedBox(width: 8),
                      Text(_formatDate(s.date), style: unbounded(fontWeight: FontWeight.w600, color: Colors.white)),
                      const Spacer(),
                      Text(
                        '$routesCount трасс',
                        style: unbounded(fontSize: 13, color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.place, size: 16, color: Colors.white54),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          displayValue(s.gymName),
                          style: unbounded(fontSize: 14, color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                  if (s.routes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: s.routes
                          .take(5)
                          .map((r) => Chip(
                                label: Text('${r.grade} x${r.count}', style: unbounded(fontSize: 12)),
                                backgroundColor: AppColors.rowAlt,
                                padding: EdgeInsets.zero,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompletionsTab() {
    if (_loadingCompletions) {
      return const Center(child: CircularProgressIndicator(color: AppColors.mutedGold));
    }
    if (_completions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center, size: 48, color: Colors.grey.shade600),
            const SizedBox(height: 12),
            Text(
              'Нет выполненных упражнений',
              style: unbounded(color: Colors.white70),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadCompletions,
      color: AppColors.mutedGold,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _completions.length,
        itemBuilder: (context, i) {
          final c = _completions[i];
          final name = c['exercise_name_ru'] ?? c['exercise_name'] ?? c['exercise_id'] ?? '—';
          final date = c['date']?.toString();
          final sets = c['sets_done'] ?? 1;
          final weight = c['weight_kg'];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: AppColors.cardDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.successMuted, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name.toString(), style: unbounded(fontWeight: FontWeight.w600, color: Colors.white)),
                        Text(
                          _formatDate(date) + (weight != null ? ' · ${weight} кг' : ''),
                          style: unbounded(fontSize: 13, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  Text('$sets подх.', style: unbounded(fontSize: 13, color: AppColors.mutedGold)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAssignmentsTab() {
    if (_loadingAssignments) {
      return const Center(child: CircularProgressIndicator(color: AppColors.mutedGold));
    }
    if (_assignments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment, size: 48, color: Colors.grey.shade600),
            const SizedBox(height: 12),
            Text(
              'Нет упражнений',
              style: unbounded(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _openAssignExercise,
              icon: const Icon(Icons.add),
              label: Text('Добавить упражнения', style: unbounded(color: AppColors.mutedGold)),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAssignments,
      color: AppColors.mutedGold,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _assignments.length,
        itemBuilder: (context, i) {
          final a = _assignments[i];
          final name = a['exercise_name_ru'] ?? a['exercise_name'] ?? a['exercise_id'] ?? '—';
          final date = a['date']?.toString();
          final sets = a['sets'] ?? 3;
          final reps = a['reps']?.toString() ?? '?';
          final status = a['status']?.toString() ?? 'pending';
          final isCompleted = status == 'completed';
          final isSkipped = status == 'skipped';
          final assignmentId = a['id'];
          final statusLabel = isCompleted
              ? 'Выполнено'
              : isSkipped
                  ? 'Пропущено'
                  : 'Ожидает';
          final statusColor = isCompleted
              ? AppColors.successMuted
              : isSkipped
                  ? Colors.white54
                  : Colors.white54;
          final statusIcon = isCompleted
              ? Icons.check_circle
              : isSkipped
                  ? Icons.remove_circle_outline
                  : Icons.schedule;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: AppColors.cardDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    statusIcon,
                    color: statusColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name.toString(), style: unbounded(fontWeight: FontWeight.w600, color: Colors.white)),
                        Text(
                          '${_formatDate(date)} · $sets подх. × $reps',
                          style: unbounded(fontSize: 13, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    statusLabel,
                    style: unbounded(
                      fontSize: 12,
                      color: statusColor,
                    ),
                  ),
                  if (assignmentId != null)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: Colors.white54),
                      color: AppColors.cardDark,
                      onSelected: (v) async {
                        if (v == 'edit') {
                          await _openEditAssignment(a);
                        } else if (v == 'delete') {
                          await _deleteAssignment(assignmentId as int);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'edit', child: Text('Редактировать', style: unbounded(color: Colors.white))),
                        PopupMenuItem(value: 'delete', child: Text('Удалить', style: unbounded(color: Colors.white))),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openAssignExercise() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TrainerAssignExerciseScreen(
          student: widget.student,
          onAssigned: () => _loadAssignments(),
        ),
      ),
    );
    if (ok == true && mounted) _loadAssignments();
  }

  Future<void> _openEditAssignment(Map<String, dynamic> assignment) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TrainerAssignExerciseScreen(
          student: widget.student,
          onAssigned: () => _loadAssignments(),
          assignmentToEdit: assignment,
        ),
      ),
    );
    if (ok == true && mounted) _loadAssignments();
  }

  Future<void> _deleteAssignment(int assignmentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: Text('Удалить упражнение?', style: unbounded(color: Colors.white)),
        content: Text(
          'Упражнение будет удалено из списка ученика.',
          style: unbounded(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Отмена', style: unbounded(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Удалить', style: unbounded(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final ok = await _service.deleteAssignment(context, assignmentId);
    if (ok && mounted) {
      showAppSuccess(context, 'Упражнение удалено');
      _loadAssignments();
    }
  }
}
