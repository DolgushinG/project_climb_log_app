import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/models/PlanModels.dart';
import 'package:login_app/services/TrainingPlanApiService.dart';

/// Экран выбора плана: аудитория, шаблон, длительность, дата старта.
class PlanSelectionScreen extends StatefulWidget {
  final void Function(ActivePlan plan)? onPlanCreated;

  const PlanSelectionScreen({super.key, this.onPlanCreated});

  @override
  State<PlanSelectionScreen> createState() => _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends State<PlanSelectionScreen> {
  final TrainingPlanApiService _api = TrainingPlanApiService();

  PlanTemplateResponse? _data;
  bool _loading = true;
  String? _error;

  String _selectedAudience = 'beginner';
  PlanTemplate? _selectedTemplate;
  int _durationWeeks = 2;
  DateTime _startDate = DateTime.now();

  // Персонализация (onboarding)
  int _daysPerWeek = 3;
  final List<int> _scheduledWeekdays = [1, 3, 5];
  bool _hasFingerboard = true;
  final List<String> _injuries = [];
  String _preferredStyle = 'both';
  int _experienceMonths = 12;
  bool _includeClimbingInDays = true;

  static const _injuryOptions = [
    ('elbow_pain', 'Локти'),
    ('finger_pain', 'Пальцы'),
    ('shoulder_pain', 'Плечи'),
    ('wrist_pain', 'Запястья'),
  ];
  static const _styleOptions = [
    ('boulder', 'Болдер'),
    ('lead', 'Труд'),
    ('both', 'Оба'),
  ];

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
    final data = await _api.getPlanTemplates(audience: _selectedAudience);
    if (mounted) {
      setState(() {
        _data = data;
        _loading = false;
        if (data != null && data.templates.isNotEmpty) {
          if (_selectedTemplate == null || !data.templates.any((t) => t.key == _selectedTemplate!.key)) {
            _selectedTemplate = data.templates.first;
          }
          if (data.audiences.isNotEmpty && !data.audiences.any((a) => a.key == _selectedAudience)) {
            _selectedAudience = data.audiences.first.key;
          }
          _durationWeeks = data.defaultDurationWeeks.clamp(data.minDurationWeeks, data.maxDurationWeeks);
        }
      });
    }
  }

  Future<void> _createPlan() async {
    if (_selectedTemplate == null) return;
    setState(() => _error = null);
    final startStr = '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}';
    final plan = await _api.createPlan(
      templateKey: _selectedTemplate!.key,
      durationWeeks: _durationWeeks,
      startDate: startStr,
      daysPerWeek: _daysPerWeek,
      scheduledWeekdays: _scheduledWeekdays.isEmpty ? null : List.from(_scheduledWeekdays),
      hasFingerboard: _hasFingerboard,
      injuries: _injuries.isEmpty ? null : List.from(_injuries),
      preferredStyle: _preferredStyle,
      experienceMonths: _experienceMonths,
      includeClimbingInDays: _includeClimbingInDays,
    );
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
            )
          : plan;
      widget.onPlanCreated?.call(planToReturn);
      Navigator.pop(context, planToReturn);
    } else {
      setState(() => _error = 'Не удалось создать план');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.anthracite,
      appBar: AppBar(
        backgroundColor: AppColors.anthracite,
        title: Text(
          'Создать план',
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
                  ] else ...[
                    _buildAudienceSection(),
                    const SizedBox(height: 20),
                    _buildTemplateSection(),
                    const SizedBox(height: 20),
                    _buildDurationSection(),
                    const SizedBox(height: 20),
                    _buildStartDateSection(),
                    const SizedBox(height: 20),
                    _buildPersonalizationSection(),
                    if (_data!.generalRecommendations.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildRecommendations(),
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
                        onPressed: _selectedTemplate != null && !_loading && _scheduledWeekdays.isNotEmpty ? _createPlan : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.mutedGold,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Создать план', style: GoogleFonts.unbounded(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildAudienceSection() {
    if (_data == null || _data!.audiences.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Аудитория', style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white54)),
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

  Widget _buildTemplateSection() {
    if (_data == null || _data!.templates.isEmpty) return const SizedBox.shrink();
    final filtered = _data!.templates;
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
                            child: Text(
                              t.nameRu,
                              style: GoogleFonts.unbounded(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (t.description != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          t.description!,
                          style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white54, height: 1.4),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'ОФП: ${t.ofpPerWeek}×/нед, СФП: ${t.sfpPerWeek}×/нед',
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
                Text(
                  '${_startDate.day.toString().padLeft(2, '0')}.${_startDate.month.toString().padLeft(2, '0')}.${_startDate.year}',
                  style: GoogleFonts.unbounded(fontSize: 16, color: Colors.white),
                ),
              ],
            ),
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
              Text(
                'Персонализация',
                style: GoogleFonts.unbounded(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
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
          _buildPersonalizationLabel('День = лазание + ОФП/СФП', 'Типичный порядок: 1–2 часа лазания, затем силовая'),
          Row(
            children: [
              ChoiceChip(
                label: Text('Да', style: GoogleFonts.unbounded(fontSize: 12)),
                selected: _includeClimbingInDays,
                onSelected: (_) => setState(() => _includeClimbingInDays = true),
                selectedColor: AppColors.mutedGold.withOpacity(0.4),
                backgroundColor: AppColors.rowAlt,
                labelStyle: TextStyle(color: _includeClimbingInDays ? AppColors.mutedGold : Colors.white70),
              ),
              const SizedBox(width: 8),
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
          const SizedBox(height: 16),
          _buildPersonalizationLabel('Фингерборд', 'Есть доступ к фингерборду?'),
          Row(
            children: [
              ChoiceChip(
                label: Text('Да', style: GoogleFonts.unbounded(fontSize: 12)),
                selected: _hasFingerboard,
                onSelected: (_) => setState(() => _hasFingerboard = true),
                selectedColor: AppColors.mutedGold.withOpacity(0.4),
                backgroundColor: AppColors.rowAlt,
                labelStyle: TextStyle(color: _hasFingerboard ? AppColors.mutedGold : Colors.white70),
              ),
              const SizedBox(width: 8),
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
          } else {
            _scheduledWeekdays.remove(weekday);
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
              Text(
                'Рекомендации',
                style: GoogleFonts.unbounded(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
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
