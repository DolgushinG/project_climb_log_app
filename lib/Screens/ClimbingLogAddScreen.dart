import 'package:flutter/material.dart';

import 'package:login_app/main.dart';
import 'package:login_app/models/ClimbingLog.dart';
import 'package:login_app/utils/climbing_log_colors.dart';
import 'package:login_app/models/Gym.dart';
import 'package:login_app/services/ClimbingLogService.dart';
import 'package:login_app/services/GymService.dart';

/// Экран добавления/редактирования тренировки (сессии трасс).
class ClimbingLogAddScreen extends StatefulWidget {
  final HistorySession? session;
  final VoidCallback? onSaved;

  const ClimbingLogAddScreen({super.key, this.session, this.onSaved});

  @override
  State<ClimbingLogAddScreen> createState() => _ClimbingLogAddScreenState();
}

class _ClimbingLogAddScreenState extends State<ClimbingLogAddScreen> {
  final ClimbingLogService _service = ClimbingLogService();
  final Map<String, int> _routes = {};
  List<String> _grades = [];
  bool _loadingGrades = true;
  bool _saving = false;
  DateTime _selectedDate = DateTime.now();
  GymSearchItem? _selectedGym;
  final TextEditingController _gymQueryController = TextEditingController();
  List<GymSearchItem> _gymResults = [];
  List<UsedGym> _usedGyms = [];
  bool _searchingGyms = false;

  bool get _isEditMode => widget.session != null;

  @override
  void initState() {
    super.initState();
    _loadGrades();
    _loadUsedGyms();
    if (widget.session != null) _applySession(widget.session!);
  }

  void _applySession(HistorySession s) {
    final dt = DateTime.tryParse(s.date);
    if (dt != null) _selectedDate = dt;
    if (s.gymId != null && s.gymName.isNotEmpty && s.gymName != 'Не указан') {
      _selectedGym = GymSearchItem(
        id: s.gymId!,
        name: s.gymName.replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '').trim(),
        city: null,
      );
      _gymQueryController.text = _selectedGym!.name;
    }
    for (final r in s.routes) _routes[r.grade] = r.count;
  }

  Future<void> _loadUsedGyms() async {
    final list = await _service.getUsedGyms();
    if (mounted) setState(() => _usedGyms = list);
  }

  @override
  void dispose() {
    _gymQueryController.dispose();
    super.dispose();
  }

  Future<void> _loadGrades() async {
    setState(() => _loadingGrades = true);
    final grades = await _service.getGrades();
    if (mounted) {
      setState(() {
        _grades = grades;
        _loadingGrades = false;
      });
    }
  }

  void _increment(String grade) {
    setState(() => _routes[grade] = (_routes[grade] ?? 0) + 1);
  }

  void _decrement(String grade) {
    final current = _routes[grade] ?? 0;
    if (current <= 1) {
      setState(() => _routes.remove(grade));
    } else {
      setState(() => _routes[grade] = current - 1);
    }
  }

  Future<void> _searchGyms(String query) async {
    if (query.length < 2) {
      setState(() => _gymResults = []);
      return;
    }
    setState(() => _searchingGyms = true);
    final results = await searchGyms(query);
    if (mounted) {
      setState(() {
        _gymResults = results;
        _searchingGyms = false;
      });
    }
  }

  Future<void> _saveSession() async {
    final routesList = _routes.entries
        .where((e) => e.value > 0)
        .map((e) => RouteEntry(grade: e.key, count: e.value))
        .toList();

    if (routesList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Добавьте хотя бы одну трассу'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final request = ClimbingSessionRequest(
      routes: routesList,
      date: dateStr,
      gymId: _selectedGym?.id,
    );
    final ok = _isEditMode && widget.session?.id != null
        ? await _service.updateSession(widget.session!.id!, request)
        : await _service.saveSession(request);
    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditMode ? 'Изменения сохранены!' : 'Тренировка сохранена!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF22C55E),
        ),
      );
      widget.onSaved?.call();
      if (_isEditMode) {
        Navigator.of(context).pop();
      } else {
        setState(() => _routes.clear());
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка сохранения. Проверьте интернет и авторизацию.'),
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
          onRefresh: () async {
            await _loadGrades();
            await _loadUsedGyms();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Text(
                    _isEditMode ? 'Редактировать тренировку' : 'Добавить тренировку',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Дата',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Colors.white70,
                            ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 1)),
                          );
                          if (date != null && mounted) {
                            setState(() => _selectedDate = date);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF0F172A),
                                Color(0xFF1E293B),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF3B82F6).withOpacity(0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today,
                                  color: const Color(0xFF38BDF8).withOpacity(0.9), size: 20),
                              const SizedBox(width: 12),
                              Text(
                                '${_selectedDate.day.toString().padLeft(2, '0')}.${_selectedDate.month.toString().padLeft(2, '0')}.${_selectedDate.year}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Скалодром (по желанию)',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Colors.white70,
                            ),
                      ),
                      if (_usedGyms.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _usedGyms.map((ug) {
                            final isSelected = _selectedGym?.id == ug.id;
                            return Container(
                              decoration: isSelected
                                  ? BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF3B82F6),
                                          Color(0xFF6366F1),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    )
                                  : null,
                              child: ActionChip(
                                label: Text(
                                  '${ug.name}${ug.city != null ? ', ${ug.city}' : ''}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isSelected ? Colors.white : Colors.white70,
                                  ),
                                ),
                                backgroundColor: isSelected ? Colors.transparent : const Color(0xFF0B1220),
                                side: BorderSide(
                                  color: isSelected
                                      ? const Color(0xFF6366F1).withOpacity(0.6)
                                      : Colors.white24,
                                ),
                              onPressed: () {
                                setState(() {
                                  _selectedGym = GymSearchItem(
                                    id: ug.id,
                                    name: ug.name,
                                    city: ug.city,
                                  );
                                  _gymQueryController.text =
                                      '${ug.name}${ug.city != null ? ', ${ug.city}' : ''}';
                                  _gymResults = [];
                                });
                              },
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 8),
                      TextField(
                        controller: _gymQueryController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Поиск по названию или городу',
                          hintStyle: TextStyle(color: Colors.white38),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.white54,
                            size: 22,
                          ),
                          suffixIcon: _selectedGym != null
                              ? IconButton(
                                  icon: Icon(Icons.close, color: Colors.white54),
                                  onPressed: () {
                                    setState(() {
                                      _selectedGym = null;
                                      _gymQueryController.clear();
                                      _gymResults = [];
                                    });
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFF0B1220),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.15),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: const Color(0xFF3B82F6).withOpacity(0.25),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF3B82F6),
                              width: 1.5,
                            ),
                          ),
                        ),
                        onChanged: (v) {
                          if (v.isEmpty) {
                            setState(() => _gymResults = []);
                            return;
                          }
                          _searchGyms(v);
                        },
                      ),
                      if (_selectedGym != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF1E3A5F),
                                Color(0xFF312E81),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF6366F1).withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.place,
                                  size: 18, color: const Color(0xFF38BDF8)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${_selectedGym!.name}${_selectedGym!.city != null ? ', ${_selectedGym!.city}' : ''}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_gymResults.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ..._gymResults.take(5).map((g) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                '${g.name}${g.city != null ? ', ${g.city}' : ''}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              onTap: () {
                                setState(() {
                                  _selectedGym = g;
                                  _gymQueryController.text =
                                      '${g.name}${g.city != null ? ', ${g.city}' : ''}';
                                  _gymResults = [];
                                });
                                FocusScope.of(context).unfocus();
                              },
                            )),
                      ],
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Icon(
                            Icons.route,
                            size: 20,
                            color: const Color(0xFF38BDF8).withOpacity(0.9),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Трассы по грейду',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_loadingGrades)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.6,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final grade = _grades[index];
                        final count = _routes[grade] ?? 0;
                        return Container(
                          decoration: BoxDecoration(
                            gradient: count > 0
                                ? LinearGradient(
                                    colors: gradientForGrade(grade)
                                        .map((c) => c.withOpacity(0.35))
                                        .toList(),
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: count > 0 ? null : const Color(0xFF0B1220),
                            borderRadius: BorderRadius.circular(12),
                            border: count > 0
                                ? Border.all(
                                    color: gradientForGrade(grade).first.withOpacity(0.5),
                                    width: 1,
                                  )
                                : null,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _increment(grade),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    grade,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (count > 0)
                                        GestureDetector(
                                          onTap: () {
                                            _decrement(grade);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.white24,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.remove,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      if (count > 0) const SizedBox(width: 8),
                                      Text(
                                        '$count',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      if (count > 0) const SizedBox(width: 8),
                                      if (count > 0)
                                        GestureDetector(
                                          onTap: () => _increment(grade),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.white24,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.add,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                      },
                      childCount: _grades.length,
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: _saving
                          ? null
                          : const LinearGradient(
                              colors: [
                                Color(0xFF3B82F6),
                                Color(0xFF6366F1),
                                Color(0xFF8B5CF6),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: _saving
                          ? null
                          : [
                              BoxShadow(
                                color: const Color(0xFF6366F1).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: FilledButton(
                      onPressed: _saving
                          ? null
                          : () => _saveSession(),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    child: _saving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_isEditMode ? 'Сохранить изменения' : 'Сохранить тренировку'),
                    ),
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
