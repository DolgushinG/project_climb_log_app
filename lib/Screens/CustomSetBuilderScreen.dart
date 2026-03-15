import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/models/CustomSetExercise.dart';
import 'package:login_app/models/SavedCustomSet.dart';
import 'package:login_app/services/StrengthTestApiService.dart';
import 'package:login_app/services/CustomExerciseSetService.dart';
import 'package:login_app/Screens/CustomSetCustomizationScreen.dart';
import 'package:login_app/Screens/SavedSetsScreen.dart';

const _muscleLabels = {
  'back': 'Спина',
  'core': 'Кор',
  'forearms': 'Предплечья',
  'shoulders': 'Плечи',
  'chest': 'Грудь',
  'legs': 'Ноги',
};

const _levelLabels = {
  'novice': 'Новичок',
  'novice_plus': 'Новичок+',
  'intermediate': 'Продвинутый',
  'intermediate_plus': 'Продвинутый+',
  'pro': 'Профи',
};

/// Экран создания собственного сета упражнений на сегодня.
/// [popOnReturn] — при true после возврата из экрана выполнения закрываем этот экран (для pushed).
/// При false (вкладка) — не закрываем, чтобы не оставить чёрный экран.
class CustomSetBuilderScreen extends StatefulWidget {
  final DateTime? date;
  final SavedCustomSet? initialSet;
  final bool popOnReturn;

  const CustomSetBuilderScreen({super.key, this.date, this.initialSet, this.popOnReturn = false});

  @override
  State<CustomSetBuilderScreen> createState() => _CustomSetBuilderScreenState();
}

class _CustomSetBuilderScreenState extends State<CustomSetBuilderScreen> {
  final StrengthTestApiService _strengthApi = StrengthTestApiService();
  final CustomExerciseSetService _customSetService = CustomExerciseSetService();
  final TextEditingController _searchController = TextEditingController();

  List<CatalogExercise> _allExercises = [];
  List<CustomSetExercise> _selected = [];
  Set<String> _filterCategories = {'ofp', 'sfp', 'stretching', 'other'};
  Set<String> _filterMuscles = {};
  String? _filterLevel; // null = авто (уровень пользователя)
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Выбранные упражнения показываем без фильтра по уровню — загружаем каталог целиком.
      var levelStr = _filterLevel;
      var ofp = await _strengthApi.getExercises(level: levelStr, category: 'ofp', limit: 50);
      var sfp = await _strengthApi.getExercises(level: levelStr, category: 'sfp', limit: 50);
      var stretching = await _strengthApi.getExercises(level: levelStr, category: 'stretching', limit: 50);
      var other = await _strengthApi.getExercises(level: levelStr, category: 'other', limit: 50);
      if (ofp.isEmpty && sfp.isEmpty && stretching.isEmpty && other.isEmpty && levelStr == null) {
        levelStr = 'intermediate';
        ofp = await _strengthApi.getExercises(level: levelStr, category: 'ofp', limit: 50);
        sfp = await _strengthApi.getExercises(level: levelStr, category: 'sfp', limit: 50);
        stretching = await _strengthApi.getExercises(level: levelStr, category: 'stretching', limit: 50);
        other = await _strengthApi.getExercises(level: levelStr, category: 'other', limit: 50);
      }
      final seen = <String>{};
      final all = <CatalogExercise>[];
      for (final e in [...ofp, ...sfp, ...stretching, ...other]) {
        if (seen.add(e.id)) all.add(e);
      }
      if (mounted) {
        setState(() {
          _allExercises = all;
          _loading = false;
        });
        if (widget.initialSet != null) _applySavedSet(widget.initialSet!);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Ошибка загрузки: $e';
        });
      }
    }
  }

  void _applySavedSet(SavedCustomSet set) {
    final catalogById = {for (final e in _allExercises) e.id: e};
    final list = <CustomSetExercise>[];
    for (final ex in set.exercises) {
      var catalog = catalogById[ex.exerciseId];
      if (catalog == null) {
        catalog = ex.toCatalogExerciseIfEnriched();
      }
      if (catalog != null) {
        final cse = CustomSetExercise(
          catalog: catalog,
          sets: ex.sets,
          reps: ex.reps,
          holdSeconds: ex.holdSeconds,
          restSeconds: ex.restSeconds,
        );
        list.add(cse);
      }
    }
    setState(() => _selected = list);
  }

  List<CatalogExercise> get _filteredCatalog {
    var list = _allExercises;
    if (_filterCategories.isNotEmpty) {
      list = list.where((e) {
        if (e.category == 'ofp') return _filterCategories.contains('ofp');
        if (e.category == 'sfp') return _filterCategories.contains('sfp');
        if (e.category == 'stretching') return _filterCategories.contains('stretching');
        return _filterCategories.contains('other');
      }).toList();
    }
    if (_filterMuscles.isNotEmpty) {
      list = list.where((e) =>
          e.muscleGroups.isEmpty || e.muscleGroups.any((m) => _filterMuscles.contains(m))).toList();
    }
    // Поиск: от 2 букв — фильтруем по названию
    final query = _searchController.text.trim().toLowerCase();
    if (query.length >= 2) {
      list = list.where((e) {
        final name = e.displayName.toLowerCase();
        final nameEn = e.name.toLowerCase();
        return name.contains(query) || nameEn.contains(query);
      }).toList();
    }
    return list;
  }

  void _toggleExercise(CatalogExercise c) {
    final idx = _selected.indexWhere((e) => e.catalog.id == c.id);
    if (idx >= 0) {
      setState(() => _selected.removeAt(idx));
    } else {
      setState(() => _selected.add(CustomSetExercise.fromCatalog(c)));
    }
  }

  void _removeExercise(int index) {
    setState(() => _selected.removeAt(index));
  }

  void _reorderExercises(int oldIndex, int newIndex) {
    setState(() {
      final item = _selected.removeAt(oldIndex);
      _selected.insert(newIndex.clamp(0, _selected.length), item);
    });
  }

  Future<void> _goToCustomization() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Добавьте хотя бы одно упражнение'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomSetCustomizationScreen(
          exercises: _selected,
          date: widget.date ?? DateTime.now(),
          popOnReturn: widget.popOnReturn,
        ),
      ),
    );
    if (mounted && result == true && widget.popOnReturn) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final nav = Navigator.maybeOf(context);
        if (nav != null && nav.canPop()) {
          nav.pop(true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.anthracite,
      appBar: AppBar(
        backgroundColor: AppColors.anthracite,
        automaticallyImplyLeading: false,
        title: Text(
          'Собственный сет упражнений',
          style: unbounded(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.list, color: AppColors.mutedGold),
            tooltip: 'Мои сеты',
            onPressed: () async {
              final picked = await Navigator.push<SavedCustomSet>(
                context,
                MaterialPageRoute(builder: (_) => const SavedSetsScreen()),
              );
              if (picked != null && mounted) {
                final full = await _customSetService.getSet(picked.id);
                if (full != null && mounted) _applySavedSet(full);
              }
            },
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
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: unbounded(color: Colors.white70)),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _load,
                        style: FilledButton.styleFrom(backgroundColor: AppColors.mutedGold),
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _buildFilterButton(),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Каталог',
                              style: unbounded(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.mutedGold),
                            ),
                            const SizedBox(height: 8),
                            _buildSearchField(),
                            const SizedBox(height: 12),
                            _buildCatalogList(),
                            const SizedBox(height: 24),
                            Text(
                              'Мой сет (${_selected.length})',
                              style: unbounded(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.mutedGold),
                            ),
                            const SizedBox(height: 8),
                            _buildSelectedList(),
                          ],
                        ),
                      ),
                    ),
                    _buildBottomBar(),
                  ],
                ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      style: unbounded(fontSize: 14, color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Поиск упражнений (от 2 букв)',
        hintStyle: unbounded(fontSize: 14, color: Colors.white38),
        prefixIcon: const Icon(Icons.search, color: AppColors.mutedGold, size: 22),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.white54, size: 20),
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
              )
            : null,
        filled: true,
        fillColor: AppColors.cardDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildFilterButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: _showFiltersSheet,
          icon: const Icon(Icons.tune, size: 18),
          label: Text(
            'Фильтры',
            style: unbounded(fontSize: 14),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.mutedGold,
            side: const BorderSide(color: AppColors.mutedGold),
          ),
        ),
      ),
    );
  }

  Future<void> _showFiltersSheet() async {
    var categories = Set<String>.from(_filterCategories);
    var muscles = Set<String>.from(_filterMuscles);
    var level = _filterLevel;
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
                    'Уровень',
                    style: unbounded(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.mutedGold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildLevelChip(ctx, setModalState, null, 'Авто', level, (v) => level = v),
                      ..._levelLabels.entries.map((e) =>
                          _buildLevelChip(ctx, setModalState, e.key, e.value, level, (v) => level = v)),
                    ],
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
                  _buildFilterCheckbox(ctx, setModalState, 'other', 'Прочее', categories, (v) {
                    if (v) categories.add('other'); else categories.remove('other');
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
                      final levelChanged = _filterLevel != level;
                      setState(() {
                        _filterCategories = categories;
                        _filterMuscles = muscles;
                        _filterLevel = level;
                      });
                      Navigator.pop(ctx);
                      if (levelChanged) _load();
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

  Widget _buildLevelChip(
    BuildContext ctx,
    StateSetter setModalState,
    String? levelKey,
    String label,
    String? current,
    void Function(String?) onSelect,
  ) {
    final selected = current == levelKey;
    return FilterChip(
      label: Text(label, style: unbounded(fontSize: 12)),
      selected: selected,
      onSelected: (_) {
        setModalState(() => onSelect(levelKey));
      },
      selectedColor: AppColors.mutedGold.withOpacity(0.4),
      backgroundColor: AppColors.rowAlt,
      checkmarkColor: AppColors.mutedGold,
      labelStyle: TextStyle(color: selected ? AppColors.mutedGold : Colors.white70),
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

  Widget _buildCatalogList() {
    final list = _filteredCatalog;
    final searchActive = _searchController.text.trim().length >= 2;
    if (searchActive && list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'Ничего не найдено по запросу «${_searchController.text.trim()}»',
          style: unbounded(fontSize: 14, color: Colors.white54),
          textAlign: TextAlign.center,
        ),
      );
    }
    return Column(
      children: list.map((e) {
        final added = _selected.any((s) => s.catalog.id == e.id);
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: AppColors.graphite,
            child: Icon(
              e.category == 'stretching' ? Icons.self_improvement : Icons.fitness_center,
              color: AppColors.mutedGold,
              size: 22,
            ),
          ),
          title: Text(
            e.displayName,
            style: unbounded(fontSize: 14, color: Colors.white),
          ),
          subtitle: Text(
            e.dosageDisplay,
            style: unbounded(fontSize: 12, color: Colors.white54),
          ),
          trailing: IconButton(
            icon: Icon(
              added ? Icons.remove_circle_outline : Icons.add_circle_outline,
              color: added ? Colors.white54 : AppColors.mutedGold,
              size: 26,
            ),
            onPressed: () => _toggleExercise(e),
            splashRadius: 22,
          ),
          onTap: () => _toggleExercise(e),
        );
      }).toList(),
    );
  }

  Widget _buildSelectedList() {
    if (_selected.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Добавьте упражнения из каталога',
          style: unbounded(fontSize: 14, color: Colors.white38),
        ),
      );
    }
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _selected.length,
      onReorder: _reorderExercises,
      itemBuilder: (_, i) {
        final ex = _selected[i];
        return _buildSelectedItem(ex, i);
      },
    );
  }

  Widget _buildSelectedItem(CustomSetExercise ex, int index) {
    final catLabels = {'ofp': 'ОФП', 'sfp': 'СФП', 'stretching': 'Растяжка', 'other': 'Прочее'};
    final catLabel = catLabels[ex.catalog.category] ?? ex.catalog.category;
    final dosage = ex.holdSeconds != null ? '${ex.sets}×${ex.holdSeconds}с' : '${ex.sets}×${ex.reps}';
    return ReorderableDelayedDragStartListener(
      key: ValueKey('${ex.catalog.id}_$index'),
      index: index,
      child: Card(
        margin: const EdgeInsets.only(bottom: 6),
        color: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.drag_handle, color: Colors.white38, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ex.catalog.displayName,
                      style: unbounded(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    Text(
                      dosage,
                      style: unbounded(fontSize: 12, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text(catLabel, style: unbounded(fontSize: 10, color: Colors.white70)),
                backgroundColor: AppColors.graphite,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                onPressed: () => _removeExercise(index),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      color: AppColors.surfaceDark,
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _goToCustomization,
        icon: const Icon(Icons.arrow_forward, size: 24),
        label: Text(
          'Настроить сет (${_selected.length})',
          style: unbounded(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.mutedGold,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
