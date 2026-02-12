import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:login_app/models/ClimbingLog.dart';
import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/services/ClimbingLogService.dart';
import 'package:login_app/utils/climbing_log_colors.dart';

/// Экран прогресса (статистика трасс).
class ClimbingLogProgressScreen extends StatefulWidget {
  const ClimbingLogProgressScreen({super.key});

  @override
  State<ClimbingLogProgressScreen> createState() =>
      _ClimbingLogProgressScreenState();
}

class _ClimbingLogProgressScreenState extends State<ClimbingLogProgressScreen> {
  final ClimbingLogService _service = ClimbingLogService();
  ClimbingProgress? _progress;
  bool _loading = true;
  String? _error;
  List<String> _orderedGrades = orderedGrades;

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
    final progress = await _service.getProgress();
    if (!mounted) return;
    setState(() {
      _progress = progress;
      _loading = false;
      if (progress == null && _progress == null) {
        _error = 'Нет данных. Добавьте первую тренировку.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.anthracite,
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
                    'Прогресс',
                    style: GoogleFonts.unbounded(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null && (_progress == null || _progress!.grades.isEmpty))
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.trending_up,
                            size: 64,
                            color: Colors.white24,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ..._buildContent(context),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildContent(BuildContext context) {
    final p = _progress;
    if (p == null) return [];

    final totalRoutes = p.grades.values.fold(0, (a, b) => a + b);

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (p.maxGrade != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.mutedGold.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Максимальный грейд',
                        style: GoogleFonts.unbounded(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.maxGrade!,
                        style: GoogleFonts.unbounded(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      _GradientProgressBar(
                        value: p.progressPercentage / 100,
                        height: 8,
                        borderRadius: 8,
                        colors: const [
                          Color(0xFF3B82F6),
                          Color(0xFF8B5CF6),
                          Color(0xFFD946EF),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${p.progressPercentage}% по шкале',
                        style: GoogleFonts.unbounded(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Text(
                'Всего трасс: $totalRoutes',
                style: GoogleFonts.unbounded(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final grade = _orderedGrades[index];
              final count = p.grades[grade] ?? 0;
              if (count == 0) return const SizedBox.shrink();
              final maxCount = p.grades.values.isEmpty
                  ? 1
                  : p.grades.values.reduce((a, b) => a > b ? a : b);
              final barWidth = maxCount > 0 ? count / maxCount : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      child:                       Text(
                        grade,
                        style: GoogleFonts.unbounded(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                    Expanded(
                      child: _GradientProgressBar(
                        value: barWidth,
                        height: 24,
                        borderRadius: 6,
                        colors: gradientForGrade(grade),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$count',
                      style: GoogleFonts.unbounded(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ],
                ),
              );
            },
            childCount: _orderedGrades.length,
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 32)),
    ];
  }
}

/// Прогресс-бар с градиентной заливкой.
class _GradientProgressBar extends StatelessWidget {
  final double value;
  final double height;
  final double borderRadius;
  final List<Color> colors;

  const _GradientProgressBar({
    required this.value,
    required this.height,
    required this.borderRadius,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Container(
                width: constraints.maxWidth,
                height: height,
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
              ),
              FractionallySizedBox(
                widthFactor: value.clamp(0.0, 1.0),
                child: Container(
                  height: height,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: colors,
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class FractionallySizedBox extends StatelessWidget {
  final double widthFactor;
  final Widget child;

  const FractionallySizedBox({
    super.key,
    required this.widthFactor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth * widthFactor;
        return SizedBox(
          width: width,
          child: child,
        );
      },
    );
  }
}
