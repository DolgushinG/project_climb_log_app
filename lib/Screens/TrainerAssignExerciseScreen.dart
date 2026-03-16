import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/TrainerStudent.dart';
import '../models/TrainerExercise.dart';
import '../theme/app_theme.dart';
import '../services/TrainerService.dart';
import '../services/StrengthTestApiService.dart';
import '../utils/app_snackbar.dart';
import 'TrainerCreateExerciseScreen.dart';

const _muscleLabels = {
  'back': 'Спина',
  'core': 'Кор',
  'forearms': 'Предплечья',
  'shoulders': 'Плечи',
  'chest': 'Грудь',
  'legs': 'Ноги',
};

/// Упражнение в списке для назначения (до сохранения).
class _PendingExercise {
  final String exerciseId;
  final String exerciseName;
  final String category;
  final int sets;
  final String reps;
  final int restSeconds;
  final int? holdSeconds;

  _PendingExercise({
    required this.exerciseId,
    required this.exerciseName,
    required this.category,
    required this.sets,
    required this.reps,
    required this.restSeconds,
    this.holdSeconds,
  });
}

/// Экран назначения упражнений ученику.
class TrainerAssignExerciseScreen extends StatefulWidget {
  final TrainerStudent student;
  final VoidCallback? onAssigned;
  /// Редактирование существующего — удаляем старое и создаём новое.
  final Map<String, dynamic>? assignmentToEdit;

  const TrainerAssignExerciseScreen({
    super.key,
    required this.student,
    this.onAssigned,
    this.assignmentToEdit,
  });

  @override
  State<TrainerAssignExerciseScreen> createState() => _TrainerAssignExerciseScreenState();
}

class _TrainerAssignExerciseScreenState extends State<TrainerAssignExerciseScreen> {
  final TrainerService _trainerService = TrainerService(baseUrl: DOMAIN);
  final StrengthTestApiService _strengthApi = StrengthTestApiService();

  DateTime _selectedDate = DateTime.now();
  List<CatalogExercise> _catalogExercises = [];
  List<TrainerExercise> _trainerExercises = [];
  List<_PendingExercise> _pendingExercises = [];
  /// Выбранное упражнение для добавления в список.
  Object? _selectedExercise;
  String? _selectedExerciseId;
  String? _selectedExerciseCategory;
  final TextEditingController _setsController = TextEditingController(text: '3');
  final TextEditingController _repsController = TextEditingController(text: '10');
  final TextEditingController _restController = TextEditingController(text: '90');
  final TextEditingController _holdController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;
  String? _error;
  bool _saving = false;
  Set<String> _filterCategories = {'ofp', 'sfp', 'stretching'};
  Set<String> _filterMuscles = {};

  bool get _isEditMode => widget.assignmentToEdit != null;

  @override
  void initState() {
    super.initState();
    _loadExercises();
    final edit = widget.assignmentToEdit;
    if (edit != null) {
      _selectedDate = DateTime.tryParse(edit['date']?.toString() ?? '') ?? DateTime.now();
      _selectedExerciseId = edit['exercise_id']?.toString();
      _setsController.text = (edit['sets'] ?? 3).toString();
      _repsController.text = edit['reps']?.toString() ?? '10';
      _restController.text = (edit['rest_seconds'] ?? 90).toString();
      final hold = edit['hold_seconds'];
      _holdController.text = hold != null ? hold.toString() : '';
      _selectedExerciseCategory = hold != null ? 'stretching' : (edit['exercise_category']?.toString() ?? 'ofp');
    }
  }

  @override
  void dispose() {
    _setsController.dispose();
    _repsController.dispose();
    _restController.dispose();
    _holdController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExercises() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        Future.wait([
          _strengthApi.getExercises(category: 'ofp', limit: 40),
          _strengthApi.getExercises(category: 'sfp', limit: 40),
          _strengthApi.getExercises(category: 'stretching', limit: 30),
        ]),
        _trainerService.getTrainerExercises(context),
      ]);
      final catLists = results[0] as List<dynamic>;
      final ofp = catLists[0] as List<CatalogExercise>;
      final sfp = catLists[1] as List<CatalogExercise>;
      final stretch = catLists[2] as List<CatalogExercise>;
      final seen = <String>{};
      final catalog = <CatalogExercise>[];
      for (final e in [...ofp, ...sfp, ...stretch]) {
        if (seen.add(e.id)) catalog.add(e);
      }
      final trainer = results[1] as List<TrainerExercise>;
      if (mounted) {
        setState(() {
          _catalogExercises = catalog;
          _trainerExercises = trainer;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Ошибка загрузки: $e';
          _loading = false;
        });
      }
    }
  }

  bool _passesCategoryFilter(String cat) {
    if (_filterCategories.isEmpty) return true;
    if (cat == 'ofp') return _filterCategories.contains('ofp');
    if (cat == 'sfp') return _filterCategories.contains('sfp');
    if (cat == 'stretching') return _filterCategories.contains('stretching');
    return _filterCategories.contains('other');
  }

  List<TrainerExercise> get _filteredTrainerExercises {
    var list = _trainerExercises.where((e) => _passesCategoryFilter(e.category)).toList();
    final q = _searchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((e) {
        final n = e.displayName.toLowerCase();
        return n.contains(q) || e.name.toLowerCase().contains(q);
      }).toList();
    }
    return list;
  }

  List<CatalogExercise> get _filteredCatalogExercises {
    var list = _catalogExercises.where((e) => _passesCategoryFilter(e.category)).toList();
    if (_filterMuscles.isNotEmpty) {
      list = list.where((e) =>
          e.muscleGroups.isEmpty || e.muscleGroups.any((m) => _filterMuscles.contains(m))).toList();
    }
    final q = _searchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((e) {
        final n = (e.nameRu ?? e.name).toLowerCase();
        return n.contains(q) || e.name.toLowerCase().contains(q);
      }).toList();
    }
    return list;
  }

  void _pickCatalogExercise(CatalogExercise ex) {
    setState(() {
      _selectedExercise = ex;
      _selectedExerciseId = ex.id;
      _selectedExerciseCategory = ex.category;
      _setsController.text = ex.defaultSets.toString();
      _repsController.text = ex.defaultReps;
      final restMatch = RegExp(r'(\d+)').firstMatch(ex.defaultRest);
      _restController.text = restMatch != null ? restMatch.group(1)! : '90';
      if (ex.category == 'stretching' && ex.dosage != null) {
        final holdMatch = RegExp(r'(\d+)\s*сек|(\d+)\s*s').firstMatch(ex.dosage!);
        if (holdMatch != null) {
          _holdController.text = (holdMatch.group(1) ?? holdMatch.group(2) ?? '30')!;
        }
      } else {
        _holdController.clear();
      }
    });
  }

  void _pickTrainerExercise(TrainerExercise ex) {
    setState(() {
      _selectedExercise = ex;
      _selectedExerciseId = ex.id;
      _selectedExerciseCategory = ex.category;
      _setsController.text = ex.defaultSets.toString();
      _repsController.text = ex.defaultReps;
      final restMatch = RegExp(r'(\d+)').firstMatch(ex.defaultRest);
      _restController.text = restMatch != null ? restMatch.group(1)! : '90';
      if (ex.category == 'stretching' && ex.holdSeconds != null) {
        _holdController.text = ex.holdSeconds.toString();
      } else {
        _holdController.clear();
      }
    });
  }

  void _applyCreatedExercise(TrainerExercise ex) {
    setState(() {
      if (!_trainerExercises.any((e) => e.id == ex.id)) {
        _trainerExercises = [ex, ..._trainerExercises];
      }
      _pickTrainerExercise(ex);
    });
  }

  void _unfocusKeyboard() => FocusScope.of(context).unfocus();

  double _getExerciseListMaxHeight() {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final keyboardVisible = viewInsets.bottom > 0;
    if (!keyboardVisible) return 180;
    final screenH = MediaQuery.of(context).size.height;
    final available = screenH - viewInsets.bottom - 240;
    return (available / 2).clamp(160.0, 380.0);
  }

  double _getUnifiedListMaxHeight() {
    final viewInsets = MediaQuery.of(context).viewInsets;
    if (viewInsets.bottom <= 0) return 0;
    final screenH = MediaQuery.of(context).size.height;
    final available = screenH - viewInsets.bottom - 200;
    return available.clamp(220.0, 450.0);
  }

  Future<void> _showFiltersSheet() async {
    var categories = Set<String>.from(_filterCategories);
    var muscles = Set<String>.from(_filterMuscles);
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Фильтры',
                    style: unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Категории',
                    style: unbounded(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.mutedGold),
                  ),
                  const SizedBox(height: 8),
                  _buildFilterCheckbox(ctx, setModalState, 'ofp', 'ОФП', categories, (v) {
                    if (v) categories.add('ofp'); else categories.remove('ofp');
                  }),
                  _buildFilterCheckbox(ctx, setModalState, 'sfp', 'СФП', categories, (v) {
                    if (v) categories.add('sfp'); else categories.remove('sfp');
                  }),
                  _buildFilterCheckbox(ctx, setModalState, 'stretching', 'Растяжка', categories, (v) {
                    if (v) categories.add('stretching'); else categories.remove('stretching');
                  }),
                  const SizedBox(height: 20),
                  Text(
                    'Мышцы',
                    style: unbounded(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.mutedGold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _muscleLabels.entries.map((e) {
                      final selected = muscles.contains(e.key);
                      return FilterChip(
                        label: Text(e.value, style: unbounded(fontSize: 12)),
                        selected: selected,
                        onSelected: (v) {
                          setModalState(() {
                            if (v) muscles.add(e.key); else muscles.remove(e.key);
                          });
                        },
                        selectedColor: AppColors.mutedGold.withOpacity(0.4),
                        backgroundColor: AppColors.rowAlt,
                        checkmarkColor: AppColors.mutedGold,
                        labelStyle: TextStyle(color: selected ? AppColors.mutedGold : Colors.white70),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _filterCategories = categories;
                        _filterMuscles = muscles;
                        if (_filterCategories.isEmpty) _filterCategories = {'ofp', 'sfp', 'stretching'};
                      });
                      Navigator.pop(ctx);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.mutedGold,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Применить'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterCheckbox(
    BuildContext ctx,
    StateSetter setModalState,
    String key,
    String label,
    Set<String> values,
    void Function(bool) onToggle,
  ) {
    final selected = values.contains(key);
    return CheckboxListTile(
      value: selected,
      onChanged: (v) {
        setModalState(() => onToggle(v ?? false));
      },
      title: Text(label, style: unbounded(fontSize: 15, color: Colors.white)),
      activeColor: AppColors.mutedGold,
      checkColor: Colors.white,
    );
  }

  Widget _buildUnifiedExerciseList() {
    final maxH = _getUnifiedListMaxHeight();
    final trainer = _filteredTrainerExercises;
    final catalog = _filteredCatalogExercises;
    final hasTrainer = trainer.isNotEmpty;
    final hasCatalog = catalog.isNotEmpty;
    if (!hasTrainer && !hasCatalog) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Нет результатов',
              style: unbounded(color: Colors.white54, fontSize: 14),
            ),
          ),
        ),
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: ListView(
        shrinkWrap: true,
        children: [
          if (hasTrainer) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.star, size: 16, color: AppColors.mutedGold),
                  const SizedBox(width: 6),
                  Text('Мои упражнения', style: unbounded(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedGold)),
                ],
              ),
            ),
            ...trainer.map((e) => ListTile(
              dense: true,
              selected: _selectedExerciseId == e.id,
              selectedTileColor: AppColors.mutedGold.withOpacity(0.2),
              title: Text(e.displayName, style: unbounded(color: Colors.white, fontSize: 14)),
              subtitle: Text(e.category == 'ofp' ? 'ОФП' : e.category == 'sfp' ? 'СФП' : 'Растяжка', style: unbounded(fontSize: 12, color: Colors.white54)),
              trailing: _selectedExerciseId == e.id ? Icon(Icons.check, color: AppColors.mutedGold, size: 20) : null,
              onTap: () { _pickTrainerExercise(e); _unfocusKeyboard(); },
            )),
            const SizedBox(height: 8),
          ],
          if (hasCatalog) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.list, size: 16, color: Colors.white54),
                  const SizedBox(width: 6),
                  Text('Каталог', style: unbounded(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white54)),
                ],
              ),
            ),
            ...catalog.map((e) => ListTile(
              dense: true,
              selected: _selectedExerciseId == e.id,
              selectedTileColor: AppColors.mutedGold.withOpacity(0.2),
              title: Text(e.displayName, style: unbounded(color: Colors.white, fontSize: 14)),
              subtitle: Text(e.category == 'ofp' ? 'ОФП' : e.category == 'sfp' ? 'СФП' : 'Растяжка', style: unbounded(fontSize: 12, color: Colors.white54)),
              trailing: _selectedExerciseId == e.id ? Icon(Icons.check, color: AppColors.mutedGold, size: 20) : null,
              onTap: () { _pickCatalogExercise(e); _unfocusKeyboard(); },
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildExerciseList<T>({
    required List<T> items,
    required String Function(T) displayName,
    required String Function(T) categoryLabel,
    required String Function(T) getId,
    required void Function(T) onTap,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = _getExerciseListMaxHeight();
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (_, i) {
              final ex = items[i];
              final isSelected = _selectedExerciseId == getId(ex);
              return ListTile(
                dense: true,
                selected: isSelected,
                selectedTileColor: AppColors.mutedGold.withOpacity(0.2),
                title: Text(displayName(ex), style: unbounded(color: Colors.white, fontSize: 14)),
                subtitle: Text(categoryLabel(ex), style: unbounded(fontSize: 12, color: Colors.white54)),
                trailing: isSelected ? Icon(Icons.check, color: AppColors.mutedGold, size: 20) : null,
                onTap: () {
                  onTap(ex);
                  FocusScope.of(context).unfocus();
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openCreateExercise() async {
    final created = await Navigator.push<TrainerExercise>(
      context,
      MaterialPageRoute(
        builder: (_) => TrainerCreateExerciseScreen(
          onCreated: _applyCreatedExercise,
        ),
      ),
    );
    if (created != null && mounted) {
      _applyCreatedExercise(created);
    }
  }

  void _addToPending() {
    final exId = _selectedExerciseId;
    if (exId == null || exId.isEmpty) {
      showAppError(context, 'Выберите упражнение');
      return;
    }
    final sets = int.tryParse(_setsController.text.trim());
    if (sets == null || sets < 1) {
      showAppError(context, 'Укажите количество подходов');
      return;
    }
    final reps = _repsController.text.trim();
    if (reps.isEmpty) {
      showAppError(context, 'Укажите повторения');
      return;
    }
    final rest = int.tryParse(_restController.text.trim()) ?? 90;
    final hold = _holdController.text.trim().isNotEmpty ? int.tryParse(_holdController.text.trim()) : null;
    String displayName = '';
    if (_selectedExercise is CatalogExercise) {
      displayName = (_selectedExercise! as CatalogExercise).displayName;
    } else if (_selectedExercise is TrainerExercise) {
      displayName = (_selectedExercise! as TrainerExercise).displayName;
    } else {
      final ce = _catalogExercises.where((e) => e.id == exId).firstOrNull;
      if (ce != null) {
        displayName = ce.displayName;
      } else {
        final te = _trainerExercises.where((e) => e.id == exId).firstOrNull;
        displayName = te?.displayName ?? exId;
      }
    }
    setState(() {
      _pendingExercises.add(_PendingExercise(
        exerciseId: exId,
        exerciseName: displayName,
        category: _selectedExerciseCategory ?? 'ofp',
        sets: sets,
        reps: reps,
        restSeconds: rest,
        holdSeconds: hold,
      ));
      _selectedExercise = null;
      _selectedExerciseId = null;
      _selectedExerciseCategory = null;
      _setsController.text = '3';
      _repsController.text = '10';
      _restController.text = '90';
      _holdController.clear();
    });
  }

  void _removePending(int index) {
    setState(() => _pendingExercises.removeAt(index));
  }

  void _editPending(int index) {
    final p = _pendingExercises[index];
    setState(() {
      _selectedExerciseId = p.exerciseId;
      _selectedExerciseCategory = p.category;
      _setsController.text = p.sets.toString();
      _repsController.text = p.reps;
      _restController.text = p.restSeconds.toString();
      _holdController.text = p.holdSeconds?.toString() ?? '';
      _pendingExercises.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (_isEditMode) {
      final edit = widget.assignmentToEdit!;
      final assignmentId = edit['id'];
      if (assignmentId == null) return;
      final exId = _selectedExerciseId;
      if (exId == null || exId.isEmpty) {
        showAppError(context, 'Выберите упражнение');
        return;
      }
      final sets = int.tryParse(_setsController.text.trim());
      if (sets == null || sets < 1) {
        showAppError(context, 'Укажите количество подходов');
        return;
      }
      final reps = _repsController.text.trim();
      if (reps.isEmpty) {
        showAppError(context, 'Укажите повторения');
        return;
      }
      final rest = int.tryParse(_restController.text.trim()) ?? 90;
      final hold = _holdController.text.trim().isNotEmpty ? int.tryParse(_holdController.text.trim()) : null;
      setState(() => _saving = true);
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final deleted = await _trainerService.deleteAssignment(context, assignmentId as int);
      if (!mounted) return;
      if (!deleted) {
        setState(() => _saving = false);
        showAppError(context, 'Не удалось обновить');
        return;
      }
      final ok = await _trainerService.createAssignment(
        context,
        studentId: widget.student.id,
        exerciseId: exId,
        date: dateStr,
        sets: sets,
        reps: reps,
        restSeconds: rest,
        holdSeconds: hold,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      if (ok) {
        widget.onAssigned?.call();
        showAppSuccess(context, 'Упражнение обновлено');
        Navigator.pop(context, true);
      }
      return;
    }
    if (_pendingExercises.isEmpty) {
      showAppError(context, 'Добавьте хотя бы одно упражнение');
      return;
    }
    setState(() => _saving = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    var successCount = 0;
    for (final p in _pendingExercises) {
      final ok = await _trainerService.createAssignment(
        context,
        studentId: widget.student.id,
        exerciseId: p.exerciseId,
        date: dateStr,
        sets: p.sets,
        reps: p.reps,
        restSeconds: p.restSeconds,
        holdSeconds: p.holdSeconds,
      );
      if (ok) successCount++;
      if (!mounted) break;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onAssigned?.call();
    showAppSuccess(context, successCount == _pendingExercises.length
        ? 'Добавлено ${successCount} ${_plural(successCount, 'упражнение', 'упражнения', 'упражнений')}'
        : 'Добавлено $successCount из ${_pendingExercises.length}');
    Navigator.pop(context, true);
  }

  String _plural(int n, String one, String few, String many) {
    if (n % 10 == 1 && n % 100 != 11) return one;
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) return few;
    return many;
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(_isEditMode ? 'Редактировать упражнение' : 'Упражнения', style: unbounded(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white)),
        backgroundColor: AppColors.cardDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        color: AppColors.anthracite,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.mutedGold))
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_error!, textAlign: TextAlign.center, style: unbounded(color: Colors.white70)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadExercises,
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.mutedGold, foregroundColor: AppColors.anthracite),
                            child: Text('Повторить', style: unbounded(fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Ученик и дата в одной компактной строке
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Ученик: ${widget.student.displayName}',
                                style: unbounded(fontSize: 14, color: Colors.white70),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            InkWell(
                              onTap: _selectDate,
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.calendar_today, size: 16, color: AppColors.mutedGold),
                                    const SizedBox(width: 6),
                                    Text(
                                      DateFormat('d MMM yyyy', 'ru').format(_selectedDate),
                                      style: unbounded(fontSize: 13, color: Colors.white70),
                                    ),
                                    const SizedBox(width: 2),
                                    Icon(Icons.chevron_right, size: 18, color: Colors.white54),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Выбор упражнения
                        Text('Упражнение', style: unbounded(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: (_) => setState(() {}),
                                style: unbounded(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Поиск...',
                                  hintStyle: unbounded(color: Colors.white38),
                                  prefixIcon: Icon(Icons.search, color: AppColors.mutedGold),
                                  filled: true,
                                  fillColor: AppColors.cardDark,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _showFiltersSheet,
                              icon: Icon(
                                _filterMuscles.isNotEmpty || _filterCategories.length < 3 ? Icons.filter_alt : Icons.filter_alt_outlined,
                                color: _filterMuscles.isNotEmpty || _filterCategories.length < 3 ? AppColors.mutedGold : Colors.white54,
                              ),
                              tooltip: 'Фильтры',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // При открытой клавиатуре — объединённый список для экономии места
                        if (MediaQuery.of(context).viewInsets.bottom > 0 && _getUnifiedListMaxHeight() > 0) ...[
                          _buildUnifiedExerciseList(),
                        ] else ...[
                          if (_filteredTrainerExercises.isNotEmpty) ...[
                            Row(
                              children: [
                                Icon(Icons.star, size: 16, color: AppColors.mutedGold),
                                const SizedBox(width: 6),
                                Text('Мои упражнения', style: unbounded(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedGold)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _buildExerciseList<TrainerExercise>(
                              items: _filteredTrainerExercises,
                              displayName: (e) => e.displayName,
                              categoryLabel: (e) => e.category == 'ofp' ? 'ОФП' : e.category == 'sfp' ? 'СФП' : 'Растяжка',
                              getId: (e) => e.id,
                              onTap: _pickTrainerExercise,
                            ),
                            const SizedBox(height: 12),
                          ],
                          Row(
                            children: [
                              Icon(Icons.list, size: 16, color: Colors.white54),
                              const SizedBox(width: 6),
                              Text('Каталог', style: unbounded(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white54)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _buildExerciseList<CatalogExercise>(
                            items: _filteredCatalogExercises,
                            displayName: (e) => e.displayName,
                            categoryLabel: (e) => e.category == 'ofp' ? 'ОФП' : e.category == 'sfp' ? 'СФП' : 'Растяжка',
                            getId: (e) => e.id,
                            onTap: _pickCatalogExercise,
                          ),
                        ],
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _openCreateExercise,
                          icon: const Icon(Icons.add, size: 20),
                          label: Text('Создать своё упражнение', style: unbounded(color: AppColors.mutedGold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.mutedGold,
                            side: BorderSide(color: AppColors.mutedGold.withOpacity(0.6)),
                          ),
                        ),
                        if (!_isEditMode && _pendingExercises.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Text('Добавленные', style: unbounded(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                          const SizedBox(height: 8),
                          ..._pendingExercises.asMap().entries.map((e) {
                            final i = e.key;
                            final p = e.value;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.cardDark,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(p.exerciseName, style: unbounded(fontWeight: FontWeight.w600, color: Colors.white)),
                                        Text('${p.sets} подх. × ${p.reps}', style: unbounded(fontSize: 12, color: Colors.white54)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.edit, size: 20, color: AppColors.mutedGold),
                                    onPressed: () => _editPending(i),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade300),
                                    onPressed: () => _removePending(i),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                        if (_selectedExerciseId != null) ...[
                          const SizedBox(height: 20),
                          Text('Параметры', style: unbounded(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _setsController,
                                  keyboardType: TextInputType.number,
                                  style: unbounded(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Подходы',
                                    labelStyle: unbounded(color: AppColors.graphite),
                                    filled: true,
                                    fillColor: AppColors.cardDark,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _repsController,
                                  style: unbounded(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Повторения',
                                    labelStyle: unbounded(color: AppColors.graphite),
                                    filled: true,
                                    fillColor: AppColors.cardDark,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _restController,
                                  keyboardType: TextInputType.number,
                                  style: unbounded(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Отдых (сек)',
                                    labelStyle: unbounded(color: AppColors.graphite),
                                    filled: true,
                                    fillColor: AppColors.cardDark,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                  ),
                                ),
                              ),
                              if (_selectedExerciseCategory == 'stretching') ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _holdController,
                                    keyboardType: TextInputType.number,
                                    style: unbounded(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'Удержание (сек)',
                                      labelStyle: unbounded(color: AppColors.graphite),
                                      filled: true,
                                      fillColor: AppColors.cardDark,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                        const SizedBox(height: 24),
                        if (!_isEditMode && _selectedExerciseId != null)
                          OutlinedButton.icon(
                            onPressed: _saving ? null : _addToPending,
                            icon: const Icon(Icons.add, size: 20),
                            label: Text('Добавить в список', style: unbounded(color: AppColors.mutedGold)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.mutedGold,
                              side: BorderSide(color: AppColors.mutedGold),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        if (!_isEditMode && _selectedExerciseId != null) const SizedBox(height: 12),
                        if ((!_isEditMode && _pendingExercises.isNotEmpty) || _isEditMode)
                          FilledButton(
                            onPressed: _saving ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.mutedGold,
                              foregroundColor: AppColors.anthracite,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _saving
                                ? SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.anthracite),
                                  )
                                : Text(_isEditMode ? 'Сохранить' : 'Добавить упражнения', style: unbounded(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
