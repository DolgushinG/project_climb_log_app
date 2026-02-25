import 'package:flutter/material.dart';

import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/services/StrengthTestApiService.dart';

/// Отдельный экран «Топ недели» — полный список участников с показателями.
/// Показывает: вес, % силы, пальцы (Л/П кг), щипок, тяга +кг при наличии от API.
class StrengthLeaderboardScreen extends StatefulWidget {
  final String? weightRangeKg;

  const StrengthLeaderboardScreen({super.key, this.weightRangeKg});

  @override
  State<StrengthLeaderboardScreen> createState() => _StrengthLeaderboardScreenState();
}

class _StrengthLeaderboardScreenState extends State<StrengthLeaderboardScreen> {
  StrengthLeaderboard? _leaderboard;
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
    final lb = await StrengthTestApiService().getLeaderboard(
      period: 'all',
      weightRangeKg: widget.weightRangeKg,
    );
    if (mounted) {
      setState(() {
        _leaderboard = lb;
        _loading = false;
        if (lb == null) _error = 'Не удалось загрузить рейтинг';
      });
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
          'Топ недели',
          style: unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white70),
            onPressed: _showHelp,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.mutedGold))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          style: unbounded(fontSize: 14, color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _load,
                          child: Text('Повторить', style: unbounded(color: AppColors.mutedGold)),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.mutedGold,
                  child: _buildList(),
                ),
    );
  }

  void _showHelp() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.mutedGold, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Что означают показатели',
                    style: unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _helpRow('% силы', 'Средний % от веса: вис на планке, щипок, тяга'),
              _helpRow('Пальцы', 'Вис на 8 мм планке, half-crimp. Л / П — левая и правая рука, кг'),
              _helpRow('Щипок', 'Щипок на блоке 40 мм, кг'),
              _helpRow('Тяга', 'Подтягивания с дополнительным весом, +кг к весу тела'),
              _helpRow('1RM', 'Разовый максимум в тяге (оценка), кг'),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Понятно', style: unbounded(color: AppColors.mutedGold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _helpRow(String term, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              term,
              style: unbounded(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.mutedGold),
            ),
          ),
          Expanded(
            child: Text(
              desc,
              style: unbounded(fontSize: 13, color: Colors.white70, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final lb = _leaderboard;
    if (lb == null || lb.leaderboard.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Center(
            child: Text(
              'Первый замер — и ты в топе. Сохрани результат в разделе Тест.',
              style: unbounded(fontSize: 14, color: Colors.white54),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      itemCount: lb.leaderboard.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              widget.weightRangeKg != null
                  ? 'Твоя весовая: ${widget.weightRangeKg} кг'
                  : 'Все участники',
              style: unbounded(fontSize: 13, color: Colors.white54),
            ),
          );
        }
        final e = lb.leaderboard[index - 1];
        return _buildEntryRow(e, lb.userPosition);
      },
    );
  }

  Widget _buildEntryRow(LeaderboardEntry e, int? userPosition) {
    final isUser = userPosition != null && e.rank == userPosition;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isUser ? AppColors.mutedGold.withOpacity(0.15) : AppColors.cardDark,
        borderRadius: BorderRadius.circular(10),
        border: isUser ? Border.all(color: AppColors.mutedGold.withOpacity(0.4)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: e.rank <= 3 ? AppColors.mutedGold.withOpacity(0.3) : AppColors.rowAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${e.rank}',
                  style: unbounded(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  e.displayName,
                  style: unbounded(
                    fontSize: 14,
                    fontWeight: isUser ? FontWeight.w600 : FontWeight.w500,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                e.weightKg != null ? '${e.weightKg!.toStringAsFixed(0)} кг' : '—',
                style: unbounded(fontSize: 13, color: Colors.white70),
              ),
              const SizedBox(width: 8),
              Text(
                '${e.averageStrengthPct.toStringAsFixed(1)}%',
                style: unbounded(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedGold,
                ),
              ),
            ],
          ),
          if (e.hasDetailedMetrics) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                if (e.fingerLeftKg != null || e.fingerRightKg != null)
                  _metricChip('Пальцы', '${_fmt(e.fingerLeftKg)} / ${_fmt(e.fingerRightKg)} кг'),
                if (e.pinchKg != null) _metricChip('Щипок', '${e.pinchKg!.toStringAsFixed(1)} кг'),
                if (e.pullAddedKg != null) _metricChip('Тяга', '+${e.pullAddedKg!.toStringAsFixed(1)} кг'),
                if (e.pull1RmKg != null) _metricChip('1RM', '${e.pull1RmKg!.toStringAsFixed(0)} кг'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _fmt(double? v) => v != null ? v.toStringAsFixed(1) : '—';

  Widget _metricChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.rowAlt,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $value',
        style: unbounded(fontSize: 11, color: Colors.white70),
      ),
    );
  }
}
