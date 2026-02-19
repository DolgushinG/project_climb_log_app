import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/models/PlanModels.dart';
import 'package:login_app/services/TrainingPlanApiService.dart';
import 'package:login_app/services/TrainingDisclaimerService.dart';

/// Экран выбора плана: уровень, шаблон, длительность, дата старта.
/// При [existingPlan] форма предзаполняется текущими настройками (обновление плана).
/// [catalogOnly] = true — только готовые планы, минимальная кастомизация (ОФП/СФП уже заданы шаблоном).
class PlanSelectionScreen extends StatefulWidget {
  final void Function(ActivePlan plan)? onPlanCreated;
  final ActivePlan? existingPlan;
  final bool catalogOnly;

  const PlanSelectionScreen({super.key, this.onPlanCreated, this.existingPlan, this.catalogOnly = false});

  @override
  State<PlanSelectionScreen> createState() => _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends State<PlanSelectionScreen> {
  final TrainingPlanApiService _api = TrainingPlanApiService();
  final TrainingDisclaimerService _disclaimerService = TrainingDisclaimerService();

  PlanTemplateResponse? _data;
  bool _loading = true;
  String? _error;

  String _selectedAudience = 'beginner';
  /// Фильтр по цели: null = все, иначе только планы с plan_goal === selectedGoal.
  String? _selectedGoal;
  PlanTemplate? _selectedTemplate;
  int _durationWeeks = 2;
  DateTime _startDate = DateTime.now();
  /// Ключ шаблона текущего плана — для предзаполнения при обновлении.
  String? _initialTemplateKey;

  // Персонализация (onboarding)
  int _daysPerWeek = 3;
  int _availableMinutes = 45;
  List<int> _scheduledWeekdays = [1, 3, 5];
  bool _hasFingerboard = true;
  final List<String> _injuries = [];
  String _preferredStyle = 'both';
  int _experienceMonths = 12;
  bool _includeClimbingInDays = true;
  /// Фокус ОФП/СФП: balanced | sfp | ofp. По умолчанию balanced.
  String _ofpSfpFocus = 'balanced';
  /// auto = бэк сам распределяет; manual = пользователь назначает ОФП/СФП по дням.
  String _ofpSfpScheduleMode = 'auto';
  /// Дни с ОФП (только при manual).
  List<int> _ofpWeekdays = [];
  /// Дни с СФП (только при manual).
  List<int> _sfpWeekdays = [];
  bool _disclaimerAcknowledged = false;
  bool _disclaimerChecked = false;

  static const _ofpSfpFocusOptions = [
    ('balanced', 'Сбалансировано', 'Стандартное соотношение ОФП и СФП'),
    ('sfp', 'Больше СФП', 'Акцент на хват, пальцы, тягу. Пример при 4 днях: 2 СФП + 1 ОФП + 1 лазание'),
    ('ofp', 'Больше ОФП', 'Акцент на общую силу. Пример при 4 днях: 2 ОФП + 1 СФП + 1 лазание'),
  ];

  static const _injuryOptions = [
    ('elbow_pain', 'Локти'),
    ('finger_pain', 'Пальцы'),
    ('shoulder_pain', 'Плечи'),
    ('wrist_pain', 'Запястья'),
    ('knee_pain', 'Колени'),
    ('lower_back_pain', 'Поясница'),
    ('neck_pain', 'Шея'),
  ];
  static const _styleOptions = [
    ('boulder', 'Болдер'),
    ('lead', 'Труд'),
    ('both', 'Оба'),
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.existingPlan;
    if (p != null) {
      _scheduledWeekdays = p.scheduledWeekdays != null && p.scheduledWeekdays!.isNotEmpty
          ? List.from(p.scheduledWeekdays!)
          : [1, 3, 5];
      _daysPerWeek = _scheduledWeekdays.length;
      _includeClimbingInDays = p.includeClimbingInDays;
      _startDate = _parseDate(p.startDate);
      _durationWeeks = _weeksBetween(p.startDate, p.endDate);
      _initialTemplateKey = p.templateKey.isNotEmpty ? p.templateKey : null;
      _selectedAudience = _inferAudienceFromTemplate(p.templateKey);
      final focus = p.ofpSfpFocus;
      if (focus != null && ['balanced', 'sfp', 'ofp'].contains(focus)) _ofpSfpFocus = focus;
    }
    _load();
    _loadDisclaimerStatus();
  }

  Future<void> _loadDisclaimerStatus() async {
    final ack = await _disclaimerService.isAcknowledged();
    if (mounted) setState(() => _disclaimerAcknowledged = ack);
  }

  bool get _canCreatePlan {
    if (_selectedTemplate == null || _loading || _scheduledWeekdays.isEmpty) return false;
    if (widget.existingPlan != null) return true;
    if (widget.catalogOnly) return true;
    return _disclaimerAcknowledged || _disclaimerChecked;
  }

  DateTime _parseDate(String s) {
    final parts = s.split('-');
    if (parts.length >= 3) {
      return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    }
    return DateTime.now();
  }

  int _weeksBetween(String start, String end) {
    final s = _parseDate(start);
    final e = _parseDate(end);
    final days = e.difference(s).inDays;
    return (days / 7).round().clamp(1, 52);
  }

  String _inferAudienceFromTemplate(String key) {
    final k = key.toLowerCase();
    if (k.contains('novice') || k.contains('beginner') || k.contains('zero') || k.contains('sport')) return 'beginner';
    if (k.contains('amateur') || k.contains('любитель')) return 'amateur';
    if (k.contains('advanced') || k.contains('pro')) return 'advanced';
    return 'beginner';
  }

  /// Фильтр шаблонов по выбранной цели.
  List<PlanTemplate> _getFilteredTemplates() {
    if (_data == null) return [];
    final templates = _data!.templates;
    if (_selectedGoal == null || _selectedGoal!.isEmpty) return templates;
    return templates.where((t) => t.planGoal == _selectedGoal).toList();
  }

  static List<PlanTemplate> _filterTemplates(PlanTemplateResponse data, String? goal) {
    if (goal == null || goal.isEmpty) return data.templates;
    return data.templates.where((t) => t.planGoal == goal).toList();
  }

  void _ensureSelectedTemplateInFilteredList(PlanTemplateResponse data) {
    final filtered = _filterTemplates(data, _selectedGoal);
    if (filtered.isEmpty) return;
    if (_selectedTemplate == null || !filtered.any((t) => t.key == _selectedTemplate!.key)) {
      _selectedTemplate = filtered.first;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    var data = await _api.getPlanTemplates(audience: _selectedAudience);
    if (data == null && _selectedAudience.isNotEmpty) {
      data = await _api.getPlanTemplates(audience: null);
    }
    if (mounted) {
      final isUpdate = widget.existingPlan != null;
      setState(() {
        _data = data;
        _loading = false;
        if (data != null && data.templates.isNotEmpty) {
          if (_initialTemplateKey != null) {
            final matches = data.templates.where((t) => t.key == _initialTemplateKey).toList();
            final match = matches.isNotEmpty ? matches.first : null;
            if (match != null) {
              _selectedTemplate = match;
              _initialTemplateKey = null;
            } else {
              _selectedTemplate = data.templates.first;
            }
          } else if (_selectedTemplate == null || !data.templates.any((t) => t.key == _selectedTemplate!.key)) {
            _selectedTemplate = data.templates.first;
          }
          if (data.audiences.isNotEmpty && !data.audiences.any((a) => a.key == _selectedAudience)) {
            _selectedAudience = data.audiences.first.key;
          }
          _ensureSelectedTemplateInFilteredList(data);
          if (!isUpdate) {
            _durationWeeks = data.defaultDurationWeeks.clamp(data.minDurationWeeks, data.maxDurationWeeks);
          }
          if (widget.catalogOnly && _scheduledWeekdays.isEmpty && _selectedTemplate != null) {
            final n = (_selectedTemplate!.ofpPerWeek + _selectedTemplate!.sfpPerWeek).clamp(1, 7);
            _scheduledWeekdays = List.generate(n, (i) => [1, 3, 5, 6, 2, 4, 7][i]);
            _daysPerWeek = _scheduledWeekdays.length;
          }
          if (!data.availableMinutesOptions.contains(_availableMinutes)) {
            _availableMinutes = data.availableMinutesOptions.contains(45) ? 45 : data.availableMinutesOptions.first;
          }
        }
      });
    }
  }

  Future<void> _createPlan() async {
    if (_selectedTemplate == null) return;
    setState(() => _error = null);
    final existing = widget.existingPlan;
    if (existing == null && !_disclaimerAcknowledged) {
      await _disclaimerService.acknowledge();
      if (mounted) setState(() => _disclaimerAcknowledged = true);
    }
    final startStr = '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}';
    final sw = _scheduledWeekdays.isEmpty ? null : List<int>.from(_scheduledWeekdays);
    final ofpSw = _ofpSfpScheduleMode == 'manual' ? List<int>.from(_ofpWeekdays) : null;
    final sfpSw = _ofpSfpScheduleMode == 'manual' ? List<int>.from(_sfpWeekdays) : null;

    ActivePlan? plan;
    if (existing != null) {
      plan = await _api.patchPlan(
        planId: existing.id,
        templateKey: _selectedTemplate!.key,
        durationWeeks: _durationWeeks,
        startDate: startStr,
        daysPerWeek: _daysPerWeek,
        scheduledWeekdays: sw,
        ofpWeekdays: ofpSw,
        sfpWeekdays: sfpSw,
        hasFingerboard: _hasFingerboard,
        injuries: _injuries.isEmpty ? null : List.from(_injuries),
        preferredStyle: _preferredStyle,
        experienceMonths: _experienceMonths,
        includeClimbingInDays: _includeClimbingInDays,
        availableMinutes: _availableMinutes,
        ofpSfpFocus: _ofpSfpScheduleMode == 'auto' ? _ofpSfpFocus : null,
      );
    } else {
      if (widget.catalogOnly) {
        plan = await _api.createPlan(
          templateKey: _selectedTemplate!.key,
          durationWeeks: _durationWeeks,
          startDate: startStr,
          daysPerWeek: _daysPerWeek,
          scheduledWeekdays: sw,
        );
      } else {
        plan = await _api.createPlan(
          templateKey: _selectedTemplate!.key,
          durationWeeks: _durationWeeks,
          startDate: startStr,
          daysPerWeek: _daysPerWeek,
          scheduledWeekdays: sw,
          ofpWeekdays: ofpSw,
          sfpWeekdays: sfpSw,
          hasFingerboard: _hasFingerboard,
          injuries: _injuries.isEmpty ? null : List.from(_injuries),
          preferredStyle: _preferredStyle,
          experienceMonths: _experienceMonths,
          includeClimbingInDays: _includeClimbingInDays,
          availableMinutes: _availableMinutes,
          ofpSfpFocus: _ofpSfpScheduleMode == 'auto' ? _ofpSfpFocus : null,
        );
      }
    }

    if (!mounted) return;
    if (plan != null) {
      final planToReturn = (plan.scheduledWeekdays == null || plan.scheduledWeekdays!.isEmpty) && _scheduledWeekdays.isNotEmpty
          ? ActivePlan(
              id: plan.id,
              templateKey: plan.templateKey,
              startDate: plan.startDate,
              endDate: plan.endDate,
              scheduledWeekdays: List.from(_scheduledWeekdays),
              scheduledWeekdaysLabels: _scheduledWeekdays.map((w) => _weekdayNames[w]).toList(),
              includeClimbingInDays: _includeClimbingInDays,
              ofpSfpFocus: _ofpSfpFocus,
            )
          : plan;
      widget.onPlanCreated?.call(planToReturn);
      Navigator.pop(context, planToReturn);
    } else {
      setState(() => _error = existing != null ? 'Не удалось обновить план' : 'Не удалось создать план');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.anthracite,
      appBar: AppBar(
        backgroundColor: AppColors.anthracite,
        title: Text(
          widget.existingPlan != null
              ? 'Обновить план'
              : (widget.catalogOnly ? 'Готовые планы' : 'Создать план'),
          style: GoogleFonts.unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.mutedGold),
                  const SizedBox(height: 16),
                  Text(
                    'Загрузка шаблонов...',
                    style: GoogleFonts.unbounded(fontSize: 14, color: Colors.white54),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_data == null) ...[
                    Text(
                      'Шаблоны недоступны',
                      style: GoogleFonts.unbounded(fontSize: 16, color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Проверьте интернет и войдите в аккаунт. Затем нажмите «Повторить».',
                      style: GoogleFonts.unbounded(fontSize: 13, color: Colors.white54),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh, size: 20),
                      label: Text('Повторить', style: GoogleFonts.unbounded(fontSize: 14)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.mutedGold,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ] else ...[
                    _buildAudienceSection(),
                    if (_data!.planGoals.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildGoalSection(),
                    ],
                    const SizedBox(height: 20),
                    _buildTemplateSection(),
                    const SizedBox(height: 20),
                    _buildDurationSection(),
                    const SizedBox(height: 20),
                    _buildStartDateSection(),
                    const SizedBox(height: 20),
                    if (widget.catalogOnly) _buildCatalogWeekdaysSection() else _buildPersonalizationSection(),
                    if (!widget.catalogOnly && _data!.generalRecommendations.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildRecommendations(),
                    ],
                    if (!widget.catalogOnly && _data!.planGuide != null) ...[
                      const SizedBox(height: 20),
                      _buildPlanGuideBlock(),
                    ],
                    if (widget.existingPlan == null && !_disclaimerAcknowledged && !widget.catalogOnly) ...[
                      const SizedBox(height: 20),
                      _buildDisclaimerBlock(),
                    ],
                    const SizedBox(height: 24),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_error!, style: GoogleFonts.unbounded(color: Colors.orange, fontSize: 13)),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _canCreatePlan ? _createPlan : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.mutedGold,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          widget.existingPlan != null
                              ? 'Сохранить изменения'
                              : (widget.catalogOnly ? 'Начать план' : 'Создать план'),
                          style: GoogleFonts.unbounded(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildGoalSection() {
    if (_data == null || _data!.planGoals.isEmpty) return const SizedBox.shrink();
    // Показываем только цели, для которых есть хотя бы один план.
    final goals = _data!.planGoals
        .where((g) => _data!.templates.any((t) => t.planGoal == g.key))
        .toList();
    if (goals.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Что хочешь улучшить?', style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white54)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text('Все цели', style: GoogleFonts.unbounded(fontSize: 13)),
              selected: _selectedGoal == null,
              onSelected: (_) {
                setState(() {
                  _selectedGoal = null;
                  final filtered = _getFilteredTemplates();
                  if (filtered.isNotEmpty && (_selectedTemplate == null || !filtered.any((t) => t.key == _selectedTemplate!.key))) {
                    _selectedTemplate = filtered.first;
                  }
                });
              },
              selectedColor: AppColors.mutedGold.withOpacity(0.4),
              backgroundColor: AppColors.rowAlt,
              labelStyle: TextStyle(color: _selectedGoal == null ? AppColors.mutedGold : Colors.white70),
            ),
            ...goals.map((g) {
              final selected = _selectedGoal == g.key;
              return ChoiceChip(
                label: Text(g.labelRu, style: GoogleFonts.unbounded(fontSize: 13)),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    _selectedGoal = g.key;
                    final filtered = _getFilteredTemplates();
                    if (filtered.isNotEmpty) {
                      if (_selectedTemplate == null || !filtered.any((t) => t.key == _selectedTemplate!.key)) {
                        _selectedTemplate = filtered.first;
                      }
                    } else {
                      _selectedTemplate = null;
                    }
                  });
                },
                selectedColor: AppColors.mutedGold.withOpacity(0.4),
                backgroundColor: AppColors.rowAlt,
                labelStyle: TextStyle(color: selected ? AppColors.mutedGold : Colors.white70),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildAudienceSection() {
    if (_data == null || _data!.audiences.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Уровень', style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white54)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _data!.audiences.map((a) {
            final selected = _selectedAudience == a.key;
            return ChoiceChip(
              label: Text(a.nameRu, style: GoogleFonts.unbounded(fontSize: 13)),
              selected: selected,
              onSelected: (_) {
                setState(() => _selectedAudience = a.key);
                _load();
              },
              selectedColor: AppColors.mutedGold.withOpacity(0.4),
              backgroundColor: AppColors.rowAlt,
              labelStyle: TextStyle(color: selected ? AppColors.mutedGold : Colors.white70),
            );
          }).toList(),
        ),
      ],
    );
  }

  List<PlanTemplate> get _filteredTemplates {
    if (_data == null) return [];
    final templates = _data!.templates;
    if (_selectedGoal == null) return templates;
    return templates.where((t) => t.planGoal == _selectedGoal).toList();
  }

  String? _goalLabel(String? goalKey) {
    if (goalKey == null || _data == null) return null;
    final g = _data!.planGoals.where((x) => x.key == goalKey).firstOrNull;
    return g?.labelRu;
  }

  Widget _buildEmptyTemplatesState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.graphite),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.inbox_outlined, color: Colors.white38, size: 40),
          const SizedBox(height: 12),
          Text(
            'Планов с этой целью пока нет. Выбери другую цель или аудиторию.',
            style: GoogleFonts.unbounded(fontSize: 14, color: Colors.white70, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateSection() {
    final filtered = _filteredTemplates;
    if (_data == null) return const SizedBox.shrink();
    if (filtered.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Шаблон плана', style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white54)),
          const SizedBox(height: 8),
          _buildEmptyTemplatesState(),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Шаблон плана', style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white54)),
        const SizedBox(height: 8),
        ...filtered.map((t) {
          final selected = _selectedTemplate?.key == t.key;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _selectedTemplate = t),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.mutedGold.withOpacity(0.2) : AppColors.cardDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? AppColors.mutedGold : AppColors.graphite,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            selected ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: selected ? AppColors.mutedGold : Colors.white54,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.nameRu,
                                  style: GoogleFonts.unbounded(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                if (t.planGoal != null && _goalLabel(t.planGoal) != null) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.mutedGold.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _goalLabel(t.planGoal)!,
                                      style: GoogleFonts.unbounded(fontSize: 11, color: AppColors.mutedGold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (t.description != null && t.description!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          t.description!,
                          style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white54, height: 1.4),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'ОФП ${t.ofpPerWeek}× в неделю, СФП ${t.sfpPerWeek}×',
                        style: GoogleFonts.unbounded(fontSize: 11, color: Colors.white38),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDurationSection() {
    if (_data == null) return const SizedBox.shrink();
    final min = _data!.minDurationWeeks;
    final max = _data!.maxDurationWeeks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Длительность', style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white54)),
        Slider(
          value: _durationWeeks.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          activeColor: AppColors.mutedGold,
          onChanged: (v) => setState(() => _durationWeeks = v.round()),
        ),
        Text(
          '$_durationWeeks ${_weeksLabel(_durationWeeks)}',
          style: GoogleFonts.unbounded(fontSize: 16, color: Colors.white),
        ),
      ],
    );
  }

  String _weeksLabel(int n) {
    if (n == 1) return 'неделя';
    if (n >= 2 && n <= 4) return 'недели';
    return 'недель';
  }

  Widget _buildStartDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Дата старта', style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white54)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _startDate,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: AppColors.mutedGold,
                    surface: AppColors.cardDark,
                  ),
                ),
                child: child!,
              ),
            );
            if (picked != null) setState(() => _startDate = picked);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.graphite),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: AppColors.mutedGold, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${_startDate.day.toString().padLeft(2, '0')}.${_startDate.month.toString().padLeft(2, '0')}.${_startDate.year}',
                    style: GoogleFonts.unbounded(fontSize: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Для готовых планов — только выбор дней. ОФП/СФП уже заданы шаблоном.
  Widget _buildCatalogWeekdaysSection() {
    final t = _selectedTemplate;
    final needed = (t != null) ? (t.ofpPerWeek + t.sfpPerWeek) : 4;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t != null
              ? 'В плане ОФП ${
                  t.ofpPerWeek}× и СФП ${t.sfpPerWeek}× в неделю — выбери $needed дня'
              : 'Дни недели',
          style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white54),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (int w = 1; w <= 7; w++) _buildWeekdayChip(w),
          ],
        ),
        if (_scheduledWeekdays.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Выберите минимум $needed ${_daysLabel(needed)}',
              style: GoogleFonts.unbounded(fontSize: 12, color: Colors.orange),
            ),
          ),
      ],
    );
  }

  Widget _buildPersonalizationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.mutedGold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, color: AppColors.mutedGold, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Персонализация',
                  style: GoogleFonts.unbounded(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPersonalizationLabel('Дни недели', 'В какие дни можете тренироваться'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int w = 1; w <= 7; w++) ...[
                _buildWeekdayChip(w),
              ],
            ],
          ),
          if (_scheduledWeekdays.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Выберите минимум один день',
                style: GoogleFonts.unbounded(fontSize: 12, color: Colors.orange),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${_scheduledWeekdays.length} ${_daysLabel(_scheduledWeekdays.length)}',
                style: GoogleFonts.unbounded(fontSize: 13, color: Colors.white54),
              ),
            ),
          const SizedBox(height: 16),
          _buildOfpSfpDaysSection(),
          const SizedBox(height: 16),
          _buildPersonalizationLabel('День = лазание + ОФП/СФП', 'Типичный порядок: 1–2 часа лазания, затем силовая'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text('Да', style: GoogleFonts.unbounded(fontSize: 12)),
                selected: _includeClimbingInDays,
                onSelected: (_) => setState(() => _includeClimbingInDays = true),
                selectedColor: AppColors.mutedGold.withOpacity(0.4),
                backgroundColor: AppColors.rowAlt,
                labelStyle: TextStyle(color: _includeClimbingInDays ? AppColors.mutedGold : Colors.white70),
              ),
              ChoiceChip(
                label: Text('Нет, только ОФП/СФП', style: GoogleFonts.unbounded(fontSize: 12)),
                selected: !_includeClimbingInDays,
                onSelected: (_) => setState(() => _includeClimbingInDays = false),
                selectedColor: AppColors.mutedGold.withOpacity(0.4),
                backgroundColor: AppColors.rowAlt,
                labelStyle: TextStyle(color: !_includeClimbingInDays ? AppColors.mutedGold : Colors.white70),
              ),
            ],
          ),
          if (_ofpSfpScheduleMode == 'auto') ...[
            const SizedBox(height: 16),
            _buildPersonalizationLabel('Фокус ОФП / СФП', 'Соотношение общей силы и специфической (хват, пальцы, тяга)'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _ofpSfpFocusOptions.map((e) {
                final selected = _ofpSfpFocus == e.$1;
                return GestureDetector(
                  onTap: () => setState(() => _ofpSfpFocus = e.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.mutedGold.withOpacity(0.4) : AppColors.rowAlt,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? AppColors.mutedGold : AppColors.graphite),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(e.$2, style: GoogleFonts.unbounded(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? AppColors.mutedGold : Colors.white70)),
                        const SizedBox(height: 2),
                        SizedBox(
                          width: 220,
                          child: Text(e.$3, style: GoogleFonts.unbounded(fontSize: 10, color: Colors.white54, height: 1.3)),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
          _buildPersonalizationLabel('Сколько времени на ОФП/СФП + растяжку?', 'Объём упражнений подстроится под выбранное время'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (_data?.availableMinutesOptions ?? [15, 30, 45, 60, 90]).map((mins) {
              final selected = _availableMinutes == mins;
              return ChoiceChip(
                label: Text('~$mins мин', style: GoogleFonts.unbounded(fontSize: 12)),
                selected: selected,
                onSelected: (_) => setState(() => _availableMinutes = mins),
                selectedColor: AppColors.mutedGold.withOpacity(0.4),
                backgroundColor: AppColors.rowAlt,
                labelStyle: TextStyle(color: selected ? AppColors.mutedGold : Colors.white70),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _buildPersonalizationLabel('Фингерборд', 'Есть доступ к фингерборду?'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text('Да', style: GoogleFonts.unbounded(fontSize: 12)),
                selected: _hasFingerboard,
                onSelected: (_) => setState(() => _hasFingerboard = true),
                selectedColor: AppColors.mutedGold.withOpacity(0.4),
                backgroundColor: AppColors.rowAlt,
                labelStyle: TextStyle(color: _hasFingerboard ? AppColors.mutedGold : Colors.white70),
              ),
              ChoiceChip(
                label: Text('Нет', style: GoogleFonts.unbounded(fontSize: 12)),
                selected: !_hasFingerboard,
                onSelected: (_) => setState(() => _hasFingerboard = false),
                selectedColor: AppColors.mutedGold.withOpacity(0.4),
                backgroundColor: AppColors.rowAlt,
                labelStyle: TextStyle(color: !_hasFingerboard ? AppColors.mutedGold : Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPersonalizationLabel('Стиль лазания', 'Основной формат'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _styleOptions.map((e) {
              final selected = _preferredStyle == e.$1;
              return ChoiceChip(
                label: Text(e.$2, style: GoogleFonts.unbounded(fontSize: 12)),
                selected: selected,
                onSelected: (_) => setState(() => _preferredStyle = e.$1),
                selectedColor: AppColors.mutedGold.withOpacity(0.4),
                backgroundColor: AppColors.rowAlt,
                labelStyle: TextStyle(color: selected ? AppColors.mutedGold : Colors.white70),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _buildPersonalizationLabel('Опыт (месяцев)', 'Стаж систематических тренировок'),
          Slider(
            value: _experienceMonths.toDouble(),
            min: 1,
            max: 60,
            divisions: 59,
            activeColor: AppColors.mutedGold,
            onChanged: (v) => setState(() => _experienceMonths = v.round()),
          ),
          Text(
            '$_experienceMonths мес',
            style: GoogleFonts.unbounded(fontSize: 14, color: Colors.white),
          ),
          const SizedBox(height: 16),
          _buildPersonalizationLabel('Травмы / ограничения', 'Отметьте при необходимости'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _injuryOptions.map((e) {
              final selected = _injuries.contains(e.$1);
              return FilterChip(
                label: Text(e.$2, style: GoogleFonts.unbounded(fontSize: 12)),
                selected: selected,
                onSelected: (v) {
                  setState(() {
                    if (v) _injuries.add(e.$1);
                    else _injuries.remove(e.$1);
                  });
                },
                selectedColor: AppColors.mutedGold.withOpacity(0.3),
                backgroundColor: AppColors.rowAlt,
                checkmarkColor: AppColors.mutedGold,
                labelStyle: TextStyle(color: selected ? AppColors.mutedGold : Colors.white70),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Возвращает 'ofp' | 'sfp' | 'climbing' для дня (только при manual).
  String _sessionTypeForWeekday(int weekday) {
    if (_ofpWeekdays.contains(weekday)) return 'ofp';
    if (_sfpWeekdays.contains(weekday)) return 'sfp';
    return 'climbing';
  }

  Widget _buildOfpSfpDaysSection() {
    if (_scheduledWeekdays.isEmpty) return const SizedBox.shrink();
    final neededOfp = _selectedTemplate?.ofpPerWeek ?? 2;
    final neededSfp = _selectedTemplate?.sfpPerWeek ?? 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPersonalizationLabel(
          'Назначение дней: ОФП / СФП',
          'Авто — бэк распределяет сам. Вручную — вы назначаете, в какой день ОФП, в какой СФП, в какой только лазание',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text('Автоматически', style: GoogleFonts.unbounded(fontSize: 12)),
              selected: _ofpSfpScheduleMode == 'auto',
              onSelected: (_) => setState(() => _ofpSfpScheduleMode = 'auto'),
              selectedColor: AppColors.mutedGold.withOpacity(0.4),
              backgroundColor: AppColors.rowAlt,
              labelStyle: TextStyle(color: _ofpSfpScheduleMode == 'auto' ? AppColors.mutedGold : Colors.white70),
            ),
            ChoiceChip(
              label: Text('Указать вручную', style: GoogleFonts.unbounded(fontSize: 12)),
              selected: _ofpSfpScheduleMode == 'manual',
              onSelected: (_) => setState(() {
                _ofpSfpScheduleMode = 'manual';
                _ofpWeekdays = [];
                _sfpWeekdays = [];
                final days = List<int>.from(_scheduledWeekdays);
                for (var i = 0; i < days.length; i++) {
                  if (i < neededOfp) {
                    _ofpWeekdays.add(days[i]);
                  } else if (i < neededOfp + neededSfp) {
                    _sfpWeekdays.add(days[i]);
                  }
                }
                _ofpWeekdays.sort();
                _sfpWeekdays.sort();
              }),
              selectedColor: AppColors.mutedGold.withOpacity(0.4),
              backgroundColor: AppColors.rowAlt,
              labelStyle: TextStyle(color: _ofpSfpScheduleMode == 'manual' ? AppColors.mutedGold : Colors.white70),
            ),
          ],
        ),
        if (_ofpSfpScheduleMode == 'manual') ...[
          const SizedBox(height: 12),
          ..._scheduledWeekdays.map((w) => _buildDayAssignmentRow(w)),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'ОФП: ${_ofpWeekdays.length}×, СФП: ${_sfpWeekdays.length}×, только лазание: ${_scheduledWeekdays.length - _ofpWeekdays.length - _sfpWeekdays.length}×',
              style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white54),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDayAssignmentRow(int weekday) {
    final current = _sessionTypeForWeekday(weekday);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              _weekdayNames[weekday],
              style: GoogleFonts.unbounded(fontSize: 13, color: Colors.white70),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _buildSessionTypeChip(weekday, 'ofp', 'ОФП', current),
              _buildSessionTypeChip(weekday, 'sfp', 'СФП', current),
              _buildSessionTypeChip(weekday, 'climbing', 'Лазание', current),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTypeChip(int weekday, String type, String label, String current) {
    final selected = current == type;
    return ChoiceChip(
      label: Text(label, style: GoogleFonts.unbounded(fontSize: 11)),
      selected: selected,
      onSelected: (_) => setState(() {
        _ofpWeekdays.remove(weekday);
        _sfpWeekdays.remove(weekday);
        if (type == 'ofp') {
          _ofpWeekdays.add(weekday);
          _ofpWeekdays.sort();
        } else if (type == 'sfp') {
          _sfpWeekdays.add(weekday);
          _sfpWeekdays.sort();
        }
      }),
      selectedColor: type == 'ofp'
          ? AppColors.mutedGold.withOpacity(0.4)
          : type == 'sfp'
              ? Colors.orange.shade700.withOpacity(0.3)
              : AppColors.graphite,
      backgroundColor: AppColors.rowAlt,
      labelStyle: TextStyle(
        color: selected ? (type == 'ofp' ? AppColors.mutedGold : type == 'sfp' ? Colors.orange : Colors.white70) : Colors.white54,
      ),
    );
  }

  Widget _buildPersonalizationLabel(String label, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.unbounded(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white70)),
          Text(hint, style: GoogleFonts.unbounded(fontSize: 11, color: Colors.white38)),
        ],
      ),
    );
  }

  String _daysLabel(int n) {
    if (n == 1) return 'день';
    if (n >= 2 && n <= 4) return 'дня';
    return 'дней';
  }

  static const _weekdayNames = ['', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  Widget _buildWeekdayChip(int weekday) {
    final selected = _scheduledWeekdays.contains(weekday);
    return FilterChip(
      label: Text(_weekdayNames[weekday], style: GoogleFonts.unbounded(fontSize: 13)),
      selected: selected,
      onSelected: (v) {
        setState(() {
          if (v) {
            _scheduledWeekdays.add(weekday);
            _scheduledWeekdays.sort();
            if (_ofpSfpScheduleMode == 'manual') {
              _ofpWeekdays.add(weekday);
              _ofpWeekdays.sort();
            }
          } else {
            _scheduledWeekdays.remove(weekday);
            if (_ofpSfpScheduleMode == 'manual') {
              _ofpWeekdays.remove(weekday);
              _sfpWeekdays.remove(weekday);
            }
          }
          _daysPerWeek = _scheduledWeekdays.length;
        });
      },
      selectedColor: AppColors.mutedGold.withOpacity(0.4),
      backgroundColor: AppColors.rowAlt,
      checkmarkColor: AppColors.mutedGold,
      labelStyle: TextStyle(color: selected ? AppColors.mutedGold : Colors.white70),
    );
  }

  Widget _buildDisclaimerBlock() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.graphite),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange.shade300, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Важная информация',
                  style: GoogleFonts.unbounded(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'План и рекомендации носят исключительно информационный характер и не являются медицинской или профессиональной консультацией. '
            'При травмах, болях или сомнениях проконсультируйтесь с врачом или тренером. '
            'Вы самостоятельно несёте ответственность за нагрузку и технику выполнения. Лазание и силовые тренировки несут риск травм.',
            style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white70, height: 1.5),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _disclaimerChecked,
            onChanged: (v) => setState(() => _disclaimerChecked = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.mutedGold,
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              'Ознакомлен(а), принимаю',
              style: GoogleFonts.unbounded(fontSize: 13, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanGuideBlock() {
    final guide = _data!.planGuide!;
    final shortDesc = guide.shortDescription;
    if (shortDesc == null || shortDesc.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.mutedGold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.mutedGold, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'О плане',
                  style: GoogleFonts.unbounded(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            shortDesc,
            style: GoogleFonts.unbounded(fontSize: 13, color: Colors.white70, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendations() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.graphite),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: AppColors.mutedGold, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Рекомендации',
                  style: GoogleFonts.unbounded(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._data!.generalRecommendations.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $r', style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white54, height: 1.4)),
              )),
        ],
      ),
    );
  }
}
