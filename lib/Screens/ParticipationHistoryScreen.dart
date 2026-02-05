import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../CompetitionScreen.dart';
import '../main.dart';

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

  ParticipationHistoryItem({
    required this.competition,
    this.qualificationPlace,
    this.qualificationTotal,
    this.semifinalPlace,
    this.semifinalTotal,
    this.finalPlace,
    this.finalTotal,
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
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final token = await getToken();
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

      if (r.statusCode == 200) {
        final raw = json.decode(r.body);
        final list = raw is List ? raw : (raw is Map && raw['data'] is List ? raw['data'] : []);
        if (list is! List) {
          setState(() {
            _isLoading = false;
            _error = 'Неожиданный формат данных';
          });
          return;
        }
        final items = list
            .whereType<Map>()
            .map((e) => ParticipationHistoryItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        setState(() {
          _items = items;
          _isLoading = false;
        });
      } else if (r.statusCode == 401 || r.statusCode == 419) {
        setState(() {
          _isLoading = false;
          _error = 'Сессия истекла';
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Ошибка загрузки (${r.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Ошибка: $e';
      });
    }
  }

  Future<void> _onRefresh() async {
    await _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('История выступлений'),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: _buildBody(),
      ),
      backgroundColor: const Color(0xFF050816),
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
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loadHistory,
                  child: const Text('Повторить'),
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
        children: const [
          SizedBox(height: 80),
          Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Вы ещё не участвовали в соревнованиях.\nКогда вы примете участие, здесь появится история выступлений.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return _buildHistoryCard(item);
      },
    );
  }

  Widget _buildHistoryCard(ParticipationHistoryItem item) {
    final c = item.competition;
    final dateLabel = DateFormat('dd.MM.yyyy').format(c.start_date);
    final bool isCurrent = !c.isCompleted;

    String _buildPlaceText(int? place, int? total) {
      if (place == null) return '-';
      if (total == null || total <= 0) return '$place место';
      return '$place место из $total';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CompetitionDetailScreen(c),
            ),
          );
        },
        child: Card(
          color: const Color(0xFF0B1220),
          surfaceTintColor: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          child: Row(
              children: [
                // Постер с фиксированной шириной, чтобы избежать проблем с AspectRatio
                SizedBox(
                  width: 84,
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: Image.network(
                      '$DOMAIN${c.poster}',
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
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                c.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? Colors.green.withOpacity(0.18)
                                    : Colors.grey.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                isCurrent ? 'Идут' : 'Завершены',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: isCurrent ? Colors.green : Colors.grey[300],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${c.city} • $dateLabel',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Chip(
                              backgroundColor: Colors.blue.withOpacity(0.15),
                              label: Text(
                                'Квалификация: ${_buildPlaceText(item.qualificationPlace, item.qualificationTotal)}',
                                style: const TextStyle(fontSize: 11, color: Colors.white),
                              ),
                            ),
                            if (c.is_semifinal)
                              Chip(
                                backgroundColor: Colors.orange.withOpacity(0.15),
                                label: Text(
                                  'Полуфинал: ${_buildPlaceText(item.semifinalPlace, item.semifinalTotal)}',
                                  style: const TextStyle(fontSize: 11, color: Colors.white),
                                ),
                              ),
                            if (c.is_result_in_final_exists)
                              Chip(
                                backgroundColor: Colors.purple.withOpacity(0.2),
                                label: Text(
                                  'Финал: ${_buildPlaceText(item.finalPlace, item.finalTotal)}',
                                  style: const TextStyle(fontSize: 11, color: Colors.white),
                                ),
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
}

