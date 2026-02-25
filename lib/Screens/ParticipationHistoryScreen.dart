import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../CompetitionScreen.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../services/cache_service.dart';
import '../utils/network_error_helper.dart';
import '../utils/session_error_helper.dart';

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) {
    final parsed = int.tryParse(v);
    return parsed;
  }
  return null;
}

class ParticipationHistoryItem {
  final Competition competition;
  final int? qualificationPlace;
  final int? qualificationTotal;
  final int? semifinalPlace;
  final int? semifinalTotal;
  final int? finalPlace;
  final int? finalTotal;
  final int? countParticipant;
  final String? endDate;

  ParticipationHistoryItem({
    required this.competition,
    this.qualificationPlace,
    this.qualificationTotal,
    this.semifinalPlace,
    this.semifinalTotal,
    this.finalPlace,
    this.finalTotal,
    this.countParticipant,
    this.endDate,
  });

  factory ParticipationHistoryItem.fromJson(Map<String, dynamic> json) {
    final eventRaw = json['event'];
    final eventMap = eventRaw is Map ? Map<String, dynamic>.from(eventRaw) : json;
    return ParticipationHistoryItem(
      competition: Competition.fromJson(eventMap),
      qualificationPlace: _toInt(json['qualification_place']),
      qualificationTotal: _toInt(json['qualification_total']),
      semifinalPlace: _toInt(json['semifinal_place']),
      semifinalTotal: _toInt(json['semifinal_total']),
      finalPlace: _toInt(json['final_place']),
      finalTotal: _toInt(json['final_total']),
      countParticipant: _toInt(eventMap['count_participant']),
      endDate: eventMap['end_date']?.toString(),
    );
  }
}

class ParticipationHistoryScreen extends StatefulWidget {
  const ParticipationHistoryScreen({super.key});

  @override
  State<ParticipationHistoryScreen> createState() => _ParticipationHistoryScreenState();
}

class _ParticipationHistoryScreenState extends State<ParticipationHistoryScreen> {
  bool _isLoading = true;
  String? _error;
  List<ParticipationHistoryItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final cached = await CacheService.getStale(CacheService.keyHistory);
    if (cached != null && cached.isNotEmpty && mounted) {
      try {
        final raw = json.decode(cached);
        final list = raw is List ? raw : (raw is Map && raw['data'] is List ? raw['data'] : []);
        if (list is List) {
          final items = list
              .whereType<Map>()
              .map((e) => ParticipationHistoryItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          setState(() {
            _items = items;
            _isLoading = false;
            _error = null;
          });
        }
      } catch (_) {}
    }

    if (!mounted) return;
    if (_items.isEmpty) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final token = await getToken();
      if (!mounted) return;
      if (token == null) {
        setState(() {
          _isLoading = false;
          _error = 'Требуется авторизация';
        });
        return;
      }

      final r = await http.get(
        Uri.parse('$DOMAIN/api/profile/history'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (!mounted) return;
      if (r.statusCode == 200) {
        final raw = json.decode(r.body);
        final list = raw is List ? raw : (raw is Map && raw['data'] is List ? raw['data'] : []);
        if (list is! List) {
          setState(() {
            _isLoading = false;
            if (_items.isEmpty) _error = 'Не удалось загрузить данные';
          });
          return;
        }
        await CacheService.set(
          CacheService.keyHistory,
          r.body,
          ttl: CacheService.ttlHistory,
        );
        final items = list
            .whereType<Map>()
            .map((e) => ParticipationHistoryItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        setState(() {
          _items = items;
          _isLoading = false;
          _error = null;
        });
      } else if (r.statusCode == 401) {
        if (mounted) {
          setState(() => _isLoading = false);
          redirectToLoginOnSessionError(context);
        }
      } else {
        setState(() {
          _isLoading = false;
          if (_items.isEmpty) _error = 'Не удалось загрузить данные';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_items.isEmpty) _error = networkErrorMessage(e, 'Не удалось загрузить данные');
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    await _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('История выступлений', style: unbounded(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: _buildBody(),
      ),
      backgroundColor: AppColors.anthracite,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, style: unbounded(color: Colors.red.shade300)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loadHistory,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.mutedGold, foregroundColor: AppColors.anthracite),
                  child: Text('Повторить', style: unbounded(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Вы ещё не участвовали в соревнованиях.\nКогда вы примете участие, здесь появится история выступлений.',
                style: unbounded(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return _buildHistoryCard(item);
      },
    );
  }

  String _formatEventDates(DateTime start, String? endDateStr) {
    final startStr = formatDatePremium(start);
    if (endDateStr != null && endDateStr.isNotEmpty) {
      try {
        final endDt = DateTime.parse(endDateStr);
        final endStr = formatDatePremium(endDt);
        return '$startStr – $endStr';
      } catch (_) {}
    }
    return startStr;
  }

  Widget _buildHistoryCard(ParticipationHistoryItem item) {
    final c = item.competition;
    final dateStr = _formatEventDates(c.start_date, item.endDate);
    final bool isCurrent = !c.isCompleted;
    final statusText = isCurrent
        ? 'Регистрация открыта'
        : 'Соревнование завершено';

    String buildPlaceText(int? place, int? total) {
      if (place == null) return 'Нет данных';
      if (total == null || total <= 0) return '$place место';
      return '$place место';
    }

    final posterUrl = c.poster.startsWith('http')
        ? c.poster
        : '$DOMAIN${c.poster}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CompetitionDetailScreen(c),
            ),
          );
        },
        child: Card(
          color: AppColors.cardDark,
          surfaceTintColor: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 84,
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: Image.network(
                    posterUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.black26,
                      child: const Icon(
                        Icons.landscape_rounded,
                        color: Colors.white38,
                      ),
                    ),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.black12,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        c.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: unbounded(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${c.city} • $dateStr',
                        style: unbounded(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                      if (item.countParticipant != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Участников: ${item.countParticipant}',
                          style: unbounded(fontSize: 11, color: Colors.white60),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? AppColors.successMuted
                              : AppColors.rowAlt,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          statusText,
                          style: unbounded(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isCurrent
                                ? Colors.green.shade200
                                : Colors.white70,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _buildResultChip(
                            'Квалификация: ${buildPlaceText(item.qualificationPlace, item.qualificationTotal)}',
                            Colors.green.withOpacity(0.15),
                          ),
                          if (c.is_semifinal)
                            _buildResultChip(
                              'Полуфинал: ${buildPlaceText(item.semifinalPlace, item.semifinalTotal)}',
                              Colors.orange.withOpacity(0.15),
                            ),
                          if (c.is_result_in_final_exists)
                            _buildResultChip(
                              'Финал: ${buildPlaceText(item.finalPlace, item.finalTotal)}',
                              Colors.purple.withOpacity(0.2),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultChip(String text, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: unbounded(fontSize: 11, color: Colors.white),
      ),
    );
  }
}

