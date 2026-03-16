import 'package:flutter/material.dart';

import '../main.dart';
import '../models/TrainerExercise.dart';
import '../theme/app_theme.dart';
import '../services/TrainerService.dart';
import '../utils/app_snackbar.dart';

/// Экран создания собственного упражнения тренером.
class TrainerCreateExerciseScreen extends StatefulWidget {
  /// После создания — вернёт TrainerExercise для быстрого назначения.
  final ValueChanged<TrainerExercise>? onCreated;

  const TrainerCreateExerciseScreen({super.key, this.onCreated});

  @override
  State<TrainerCreateExerciseScreen> createState() => _TrainerCreateExerciseScreenState();
}

class _TrainerCreateExerciseScreenState extends State<TrainerCreateExerciseScreen> {
  final TrainerService _service = TrainerService(baseUrl: DOMAIN);
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _howToPerformController = TextEditingController();
  final TextEditingController _climbingBenefitsController = TextEditingController();
  final TextEditingController _setsController = TextEditingController(text: '3');
  final TextEditingController _repsController = TextEditingController(text: '6');
  final TextEditingController _restController = TextEditingController(text: '90');
  final TextEditingController _holdController = TextEditingController();
  String _category = 'ofp';
  bool _saving = false;
  bool _generating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _howToPerformController.dispose();
    _climbingBenefitsController.dispose();
    _setsController.dispose();
    _repsController.dispose();
    _restController.dispose();
    _holdController.dispose();
    super.dispose();
  }

  Future<void> _generateAI() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showAppError(context, 'Сначала введите название упражнения');
      return;
    }
    setState(() => _generating = true);
    final result = await _service.generateExerciseAI(context, name);
    if (!mounted) return;
    setState(() => _generating = false);
    if (result != null) {
      _howToPerformController.text = result.howToPerform;
      _climbingBenefitsController.text = result.climbingBenefits;
      showAppSuccess(context, 'Сгенерировано');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showAppError(context, 'Введите название');
      return;
    }
    final howTo = _howToPerformController.text.trim();
    if (howTo.isEmpty) {
      showAppError(context, 'Заполните «Как выполнять»');
      return;
    }
    final benefits = _climbingBenefitsController.text.trim();
    if (benefits.isEmpty) {
      showAppError(context, 'Заполните «Польза для скалолазания»');
      return;
    }
    final sets = int.tryParse(_setsController.text.trim()) ?? 3;
    final reps = _repsController.text.trim().isEmpty ? '6' : _repsController.text.trim();
    final rest = _restController.text.trim();
    final restStr = rest.contains('s') || rest.contains('с') ? rest : '${int.tryParse(rest) ?? 90}s';
    final hold = _holdController.text.trim().isNotEmpty ? int.tryParse(_holdController.text.trim()) : null;

    setState(() => _saving = true);
    final exercise = TrainerExercise(
      id: '',
      name: name,
      nameRu: name,
      category: _category,
      howToPerform: howTo,
      climbingBenefits: benefits,
      defaultSets: sets,
      defaultReps: reps,
      defaultRest: restStr,
      holdSeconds: hold,
    );
    final created = await _service.createTrainerExercise(context, exercise);
    if (!mounted) return;
    setState(() => _saving = false);
    if (created != null) {
      widget.onCreated?.call(created);
      showAppSuccess(context, 'Упражнение создано');
      Navigator.pop(context, created);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Создать упражнение', style: unbounded(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white)),
        backgroundColor: AppColors.cardDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        color: AppColors.anthracite,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Созданное упражнение будет видно только вам и вашим ученикам',
                  style: unbounded(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _nameController,
                  style: unbounded(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Название упражнения *',
                    labelStyle: unbounded(color: AppColors.graphite),
                    filled: true,
                    fillColor: AppColors.cardDark,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Обязательное поле' : null,
                ),
                const SizedBox(height: 12),

                OutlinedButton.icon(
                  onPressed: _generating ? null : _generateAI,
                  icon: _generating
                      ? SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.mutedGold),
                        )
                      : Icon(Icons.auto_awesome, size: 18, color: AppColors.mutedGold),
                  label: Text(
                    _generating ? 'Генерация…' : 'Сгенерировать AI',
                    style: unbounded(color: AppColors.mutedGold, fontSize: 14),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.mutedGold.withOpacity(0.6)),
                    foregroundColor: AppColors.mutedGold,
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _howToPerformController,
                  style: unbounded(color: Colors.white),
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Как выполнять *',
                    hintText: 'Опишите технику выполнения',
                    labelStyle: unbounded(color: AppColors.graphite),
                    hintStyle: unbounded(color: Colors.white38),
                    filled: true,
                    fillColor: AppColors.cardDark,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Обязательное поле' : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _climbingBenefitsController,
                  style: unbounded(color: Colors.white),
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Польза для скалолазания *',
                    hintText: 'Чем полезно упражнение для скалолаза',
                    labelStyle: unbounded(color: AppColors.graphite),
                    hintStyle: unbounded(color: Colors.white38),
                    filled: true,
                    fillColor: AppColors.cardDark,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Обязательное поле' : null,
                ),
                const SizedBox(height: 16),

                Text('Категория', style: unbounded(fontSize: 12, color: Colors.white54)),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'ofp', label: Text('ОФП'), icon: Icon(Icons.fitness_center, size: 18)),
                    ButtonSegment(value: 'sfp', label: Text('СФП'), icon: Icon(Icons.handyman, size: 18)),
                    ButtonSegment(value: 'stretching', label: Text('Растяжка'), icon: Icon(Icons.self_improvement, size: 18)),
                  ],
                  selected: {_category},
                  onSelectionChanged: (s) => setState(() => _category = s.first),
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) return AppColors.mutedGold.withOpacity(0.3);
                      return AppColors.cardDark;
                    }),
                    foregroundColor: WidgetStateProperty.all(Colors.white),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
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
                      child: TextFormField(
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
                      child: TextFormField(
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
                    if (_category == 'stretching') ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
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
                const SizedBox(height: 28),
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
                      : Text('Создать упражнение', style: unbounded(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
