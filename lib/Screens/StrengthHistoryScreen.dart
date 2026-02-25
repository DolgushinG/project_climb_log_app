import 'package:flutter/material.dart';

import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/models/StrengthMeasurementSession.dart';
import 'package:login_app/services/StrengthTestApiService.dart';
import 'package:login_app/services/StrengthHistoryService.dart';

/// Экран истории замеров силы — все сохранённые замеры с датой и весом.
class StrengthHistoryScreen extends StatefulWidget {
  const StrengthHistoryScreen({super.key});

  @override
  State<StrengthHistoryScreen> createState() => _StrengthHistoryScreenState();
}

class _StrengthHistoryScreenState extends State<StrengthHistoryScreen> {
  List<StrengthMeasurementSession> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    var list = await StrengthTestApiService().getStrengthTestsHistory(periodDays: 365);
    if (list.isEmpty) {
      list = await StrengthHistoryService().getHistory();
    }
    list = List.from(list)..sort((a, b) => b.date.compareTo(a.date));
    if (mounted) {
      setState(() {
        _sessions = list;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.anthracite,
      appBar: AppBar(
        backgroundColor: AppColors.anthracite,
          title: Text(
          'Мои замеры',
          style: unbounded(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.mutedGold,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.mutedGold),
              )
            : _sessions.isEmpty
                ? CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.fitness_center_outlined,
                                size: 64,
                                color: Colors.white24,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Пока пусто',
                                style: unbounded(
                                  fontSize: 16,
                                  color: Colors.white54,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Сделай тест и нажми «Записать замер»',
                                style: unbounded(
                                  fontSize: 13,
                                  color: Colors.white38,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    itemCount: _sessions.length,
                    itemBuilder: (context, index) {
                      final s = _sessions[index];
                      return _buildSessionCard(s);
                    },
                  ),
      ),
    );
  }

  Widget _buildSessionCard(StrengthMeasurementSession s) {
    final m = s.metrics;
    final parts = <String>[];
    if (m.bodyWeightKg != null && m.bodyWeightKg! > 0) {
      parts.add('Вес: ${m.bodyWeightKg!.toStringAsFixed(1)} кг');
    }
    if (m.fingerLeftKg != null || m.fingerRightKg != null) {
      parts.add('Пальцы: Л ${m.fingerLeftKg?.toStringAsFixed(1) ?? '—'} / П ${m.fingerRightKg?.toStringAsFixed(1) ?? '—'} кг');
    }
    if (m.pinch40Kg != null || m.pinch60Kg != null || m.pinch80Kg != null) {
      final p = <String>[];
      if (m.pinch40Kg != null) p.add('40: ${m.pinch40Kg!.toStringAsFixed(1)}');
      if (m.pinch60Kg != null) p.add('60: ${m.pinch60Kg!.toStringAsFixed(1)}');
      if (m.pinch80Kg != null) p.add('80: ${m.pinch80Kg!.toStringAsFixed(1)}');
      parts.add('Щипок: ${p.join(' / ')} кг');
    }
    if (m.pullAddedKg != null) parts.add('Тяга: +${m.pullAddedKg!.toStringAsFixed(1)} кг');
    if (m.lockOffSec != null && m.lockOffSec! > 0) parts.add('Lock-off: ${m.lockOffSec} сек');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              Icon(Icons.calendar_today, color: AppColors.linkMuted, size: 18),
              const SizedBox(width: 8),
              Text(
                s.dateFormatted,
                style: unbounded(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          if (parts.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: parts.map((p) => Text(
                p,
                style: unbounded(fontSize: 13, color: Colors.white70),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
