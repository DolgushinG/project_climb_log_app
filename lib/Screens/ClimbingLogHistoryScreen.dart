import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

import 'package:login_app/models/ClimbingLog.dart';
import 'package:login_app/utils/climbing_log_colors.dart';
import 'package:login_app/Screens/ClimbingLogAddScreen.dart';
import 'package:login_app/services/ClimbingLogService.dart';

/// Экран истории сессий (тренировок).
class ClimbingLogHistoryScreen extends StatefulWidget {
  const ClimbingLogHistoryScreen({super.key});

  @override
  State<ClimbingLogHistoryScreen> createState() =>
      _ClimbingLogHistoryScreenState();
}

class _ClimbingLogHistoryScreenState extends State<ClimbingLogHistoryScreen> {
  final ClimbingLogService _service = ClimbingLogService();
  List<HistorySession> _sessions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sessions = await _service.getHistory();
      if (mounted) {
        setState(() {
          _sessions = sessions;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Ошибка загрузки';
        });
      }
    }
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.tryParse(dateStr);
      if (dt != null) {
        return DateFormat('dd.MM.yyyy').format(dt);
      }
    } catch (_) {}
    return dateStr;
  }

  void _openEdit(HistorySession session) {
    if (session.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Редактирование пока недоступно. Обновите приложение после обновления бэкенда.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClimbingLogAddScreen(
          session: session,
          onSaved: _load,
        ),
      ),
    );
  }

  Future<void> _deleteSession(HistorySession session) async {
    if (session.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Удаление пока недоступно. Обновите приложение после обновления бэкенда.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить тренировку?'),
        content: Text(
          'Тренировка ${_formatDate(session.date)}${session.gymName != 'Не указан' ? ' (${session.gymName})' : ''} будет удалена безвозвратно.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final ok = await _service.deleteSession(session.id!);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Тренировка удалена'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF22C55E),
        ),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка удаления'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Text(
                    'История тренировок',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                  ),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _load,
                            child: const Text('Повторить'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (_sessions.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.history,
                          size: 64,
                          color: Colors.white24,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Пока нет тренировок',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Добавьте первую тренировку в разделе «Тренировка»',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final session = _sessions[index];
                        return _SessionCard(
                          session: session,
                          date: _formatDate(session.date),
                          gymName: session.gymName,
                          routes: session.routes,
                          onEdit: () => _openEdit(session),
                          onDelete: () => _deleteSession(session),
                          onRefresh: _load,
                        );
                      },
                      childCount: _sessions.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final HistorySession session;
  final String date;
  final String gymName;
  final List<HistoryRoute> routes;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRefresh;

  const _SessionCard({
    required this.session,
    required this.date,
    required this.gymName,
    required this.routes,
    required this.onEdit,
    required this.onDelete,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final totalCount = routes.fold(0, (a, r) => a + r.count);
    final canEditDelete = session.id != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    date,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (canEditDelete)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: onEdit,
                        tooltip: 'Редактировать',
                        style: IconButton.styleFrom(
                          foregroundColor: Colors.white54,
                          padding: const EdgeInsets.all(6),
                          minimumSize: const Size(36, 36),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: onDelete,
                        tooltip: 'Удалить',
                        style: IconButton.styleFrom(
                          foregroundColor: Colors.red.withOpacity(0.8),
                          padding: const EdgeInsets.all(6),
                          minimumSize: const Size(36, 36),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            if (gymName.isNotEmpty && gymName != 'Не указан') ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.place, size: 16, color: Colors.white54),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      gymName,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ...routes.map((r) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientForGrade(r.grade)
                              .map((c) => c.withOpacity(0.4))
                              .toList(),
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: gradientForGrade(r.grade).first.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${r.grade} × ${r.count}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Всего: $totalCount трасс',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
