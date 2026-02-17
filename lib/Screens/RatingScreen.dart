import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../main.dart';
import '../services/cache_service.dart';
import '../theme/app_theme.dart';
import 'PublicProfileScreen.dart';

/// Элемент рейтинга с бэкенда GET /api/rating
class RatingEntry {
  final int id;
  final String gender;
  final String team;
  final String name;
  final double flashPercent;
  final double redpointPercent;
  final int totalRoutes;
  final int performances;
  final int points;
  final int rank;

  RatingEntry({
    required this.id,
    required this.gender,
    required this.team,
    required this.name,
    required this.flashPercent,
    required this.redpointPercent,
    required this.totalRoutes,
    required this.performances,
    required this.points,
    required this.rank,
  });

  factory RatingEntry.fromJson(Map<String, dynamic> json) {
    return RatingEntry(
      id: (json['id'] is int) ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      gender: (json['gender'] ?? 'male').toString(),
      team: (json['team'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      flashPercent: _toDouble(json['flash_percent']),
      redpointPercent: _toDouble(json['redpoint_percent']),
      totalRoutes: _toInt(json['total_routes']),
      performances: _toInt(json['performances']),
      points: _toInt(json['points']),
      rank: _toInt(json['rank']),
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  bool get isMale => gender == 'male';
}

/// Экран общего рейтинга (топ-10 мужчин, топ-10 женщин). Публичный API, без авторизации.
class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  bool _loading = true;
  String? _error;
  List<RatingEntry> _list = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cached = await CacheService.getStale(CacheService.keyRating);
    if (cached != null && cached.isNotEmpty) {
      try {
        final json = jsonDecode(cached) as Map<String, dynamic>?;
        final data = json?['data'] as List<dynamic>?;
        final list = (data ?? [])
            .whereType<Map<String, dynamic>>()
            .map((e) => RatingEntry.fromJson(e))
            .toList();
        if (mounted) {
          setState(() {
            _list = list;
            _loading = false;
            _error = null;
          });
        }
      } catch (_) {}
    } else if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final url = Uri.parse('$DOMAIN/api/rating');
      final response = await http.get(url, headers: {'Accept': 'application/json'});
      if (!mounted) return;
      if (response.statusCode != 200) {
        if (_list.isEmpty && mounted) {
          setState(() {
            _loading = false;
            _error = 'Ошибка загрузки: ${response.statusCode}';
          });
        }
        return;
      }
      await CacheService.set(
        CacheService.keyRating,
        response.body,
        ttl: CacheService.ttlRating,
      );
      final json = jsonDecode(response.body) as Map<String, dynamic>?;
      final data = json?['data'] as List<dynamic>?;
      final list = (data ?? [])
          .whereType<Map<String, dynamic>>()
          .map((e) => RatingEntry.fromJson(e))
          .toList();
      if (mounted) {
        setState(() {
          _list = list;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && _list.isEmpty) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  List<RatingEntry> _byGender(String gender) {
    return _list.where((e) => e.gender == gender).toList();
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
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Text(
                    'Рейтинг',
                    style: GoogleFonts.unbounded(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.unbounded(color: Colors.white70),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _load,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.mutedGold,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Повторить', style: GoogleFonts.unbounded(fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ..._buildSections(context),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSections(BuildContext context) {
    final men = _byGender('male');
    final women = _byGender('female');
    return [
      _Section(
        title: 'Мужчины',
        entries: men,
        onTap: (e) => _openProfile(context, e.id),
      ),
      _Section(
        title: 'Женщины',
        entries: women,
        onTap: (e) => _openProfile(context, e.id),
      ),
    ];
  }

  void _openProfile(BuildContext context, int userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PublicProfileScreen(userId: userId),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<RatingEntry> entries;
  final void Function(RatingEntry) onTap;

  const _Section({
    required this.title,
    required this.entries,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              title,
              style: GoogleFonts.unbounded(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
          ...entries.map((e) => _RatingTile(entry: e, onTap: () => onTap(e))),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

class _RatingTile extends StatelessWidget {
  final RatingEntry entry;
  final VoidCallback onTap;

  const _RatingTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '${entry.rank}',
                  style: GoogleFonts.unbounded(fontWeight: FontWeight.w700, color: _rankColor(entry.rank)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: GoogleFonts.unbounded(fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    if (entry.team.isNotEmpty)
                      Text(
                        entry.team,
                        style: GoogleFonts.unbounded(color: Colors.white60, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _chip(context, '${entry.points} очк.', Colors.white24),
                        _chip(context, '${entry.flashPercent.toStringAsFixed(1)}% флеш', Colors.white24),
                        if (entry.totalRoutes > 0)
                          _chip(context, '${entry.totalRoutes} трасс', Colors.white24),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.mutedGold, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Color _rankColor(int rank) {
    if (rank == 1) return AppColors.mutedGold;
    if (rank == 2) return const Color(0xFF9CA3AF);
    if (rank == 3) return const Color(0xFF92400E);
    return Colors.white70;
  }

  Widget _chip(BuildContext context, String text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.unbounded(fontSize: 11, color: Colors.white70),
      ),
    );
  }
}
