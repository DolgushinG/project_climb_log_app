import 'package:flutter/material.dart';

import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/models/SavedCustomSet.dart';
import 'package:login_app/services/CustomExerciseSetService.dart';

/// Экран списка сохранённых сетов — нажать, чтобы загрузить и повторить.
class SavedSetsScreen extends StatefulWidget {
  const SavedSetsScreen({super.key});

  @override
  State<SavedSetsScreen> createState() => _SavedSetsScreenState();
}

class _SavedSetsScreenState extends State<SavedSetsScreen> {
  final CustomExerciseSetService _service = CustomExerciseSetService();
  List<SavedCustomSet> _sets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _service.getSets();
    if (mounted) {
      setState(() {
        _sets = list;
        _loading = false;
      });
    }
  }

  Future<void> _confirmAndDelete(SavedCustomSet s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Удалить сет?',
          style: unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        content: Text(
          '«${s.name}» будет удалён без возможности восстановления.',
          style: unbounded(fontSize: 14, color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Отмена', style: unbounded(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Удалить', style: unbounded(color: Colors.red.shade400)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) await _deleteSet(s.id);
  }

  Future<void> _deleteSet(int id) async {
    final ok = await _service.deleteSet(id);
    if (mounted) {
      if (ok) {
        setState(() => _sets = _sets.where((s) => s.id != id).toList());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Сет удалён'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.graphite,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось удалить сет'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
          'Мои сеты',
          style: unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.mutedGold))
          : _sets.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fitness_center, size: 48, color: Colors.white38),
                      const SizedBox(height: 16),
                      Text(
                        'Нет сохранённых сетов',
                        style: unbounded(fontSize: 16, color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Создайте сет и нажмите «Начать» — он сохранится автоматически',
                        style: unbounded(fontSize: 14, color: Colors.white54),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.mutedGold,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    itemCount: _sets.length,
                    itemBuilder: (_, i) {
                      final s = _sets[i];
                      final count = s.exercisesCount ?? s.exercises.length;
                      return Dismissible(
                        key: ValueKey(s.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.delete_outline, color: Colors.white, size: 28),
                        ),
                        confirmDismiss: (dir) async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: AppColors.cardDark,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: Text(
                                'Удалить сет?',
                                style: unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                              content: Text(
                                '«${s.name}» будет удалён без возможности восстановления.',
                                style: unbounded(fontSize: 14, color: Colors.white70),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text('Отмена', style: unbounded(color: Colors.white70)),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text('Удалить', style: unbounded(color: Colors.red.shade400)),
                                ),
                              ],
                            ),
                          );
                          return confirm == true;
                        },
                        onDismissed: (dir) => _deleteSet(s.id),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: AppColors.cardDark,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: AppColors.graphite),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            leading: CircleAvatar(
                              backgroundColor: AppColors.graphite,
                              child: Icon(Icons.fitness_center, color: AppColors.mutedGold),
                            ),
                            title: Text(
                              s.name,
                              style: unbounded(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                            subtitle: Text(
                              '$count упражнений',
                              style: unbounded(fontSize: 13, color: Colors.white54),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.delete_outline, color: Colors.white38, size: 22),
                                  onPressed: () => _confirmAndDelete(s),
                                  tooltip: 'Удалить',
                                ),
                                const Icon(Icons.chevron_right, color: AppColors.mutedGold),
                              ],
                            ),
                            onTap: () => Navigator.pop(context, s),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
