import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:login_app/theme/app_theme.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'CompetitionScreen.dart';
import 'main.dart';
import 'utils/display_helper.dart';
import 'services/cache_service.dart';
import 'services/offline_queue_service.dart';
import 'utils/network_error_helper.dart';


Future<List<Routes>> getRoutesData({
  required final int eventId
}) async {
  final Uri url = Uri.parse('$DOMAIN/api/routes?event_id=$eventId');

  final response = await http.get(url);

  if (response.statusCode == 200) {
    List jsonResponse = json.decode(response.body);
    return jsonResponse.map((data) => Routes.fromJson(data)).toList();
  } else {
    throw Exception('Failed to load participants');
  }
}


class ResultEntryPage extends StatefulWidget {
  final int eventId;
  final bool isParticipantActive;

  ResultEntryPage({required this.eventId, this.isParticipantActive = false});

  @override
  _ResultEntryPageState createState() => _ResultEntryPageState();
}

class _ResultEntryPageState extends State<ResultEntryPage> {
  List<Routes> routes = [];
  List<Map<String, dynamic>> selectedAttempts = [];

  @override
  void initState() {
    super.initState();
    _getRoutesData();
  }
  void _showNotification(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: 2),
      ),
    );
  }
  void _submitResults() async {
    final String? token = await getToken();
    if (token == null) return;
    try {
      final response = await http.post(
        Uri.parse('$DOMAIN/api/event/${widget.eventId}/send/results'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'results': selectedAttempts}),
      );

      if (response.statusCode == 200) {
        await OfflineQueueService.removeByEventId(widget.eventId);
        _showNotification('Успешное внесение результатов', AppColors.successMuted);
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('results_draft_${widget.eventId}');
        } catch (_) {}
        if (mounted) Navigator.pop(context, true);
        return;
      }
      try {
        final Map<String, dynamic> body = jsonDecode(response.body);
        final String message =
            body['message']?.toString() ?? 'Ошибка при отправке результатов';
        _showNotification(message, Colors.red);
      } catch (_) {
        _showNotification('Ошибка при отправке результатов', Colors.red);
      }
    } catch (e) {
      if (isLikelyOfflineError(e)) {
        await OfflineQueueService.enqueueSendResults(widget.eventId, selectedAttempts);
        _showNotification(
          'Нет интернета. Результаты сохранены и будут отправлены при подключении.',
          Colors.orange,
        );
        if (mounted) Navigator.pop(context, true);
      } else {
        _showNotification(networkErrorMessage(e, 'Ошибка при отправке'), Colors.red);
      }
    }
  }

  void _getRoutesData() async {
    final int eventId = widget.eventId;
    final cacheKey = CacheService.keyRoutes(eventId);
    final cached = await CacheService.getStale(cacheKey);
    if (cached != null && cached.isNotEmpty && mounted) {
      try {
        final list = json.decode(cached) as List<dynamic>;
        final data = list
            .map((j) => Routes.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList();
        setState(() {
          routes = data;
          selectedAttempts = data
              .map((r) => {'route_id': r.routeId, 'attempt': r.attempt})
              .toList();
        });
        await _loadDraftResults();
        await _loadServerResultsIfNeeded();
      } catch (_) {}
    }
    try {
      final data = await getRoutesData(eventId: eventId);
      if (mounted) {
        await CacheService.set(
          cacheKey,
          jsonEncode(data.map((r) => {
                'route_id': r.routeId,
                'routeName': r.routeName,
                'grade': r.grade,
                'attempt': r.attempt,
                if (r.color != null)
                  'color': '#${r.color!.value.toRadixString(16).padLeft(8, '0')}',
              }).toList()),
          ttl: CacheService.ttlRoutes,
        );
        setState(() {
          routes = data;
          selectedAttempts = data
              .map((r) => {'route_id': r.routeId, 'attempt': r.attempt})
              .toList();
        });
        await _loadDraftResults();
        await _loadServerResultsIfNeeded();
      }
    } catch (e) {
      if (mounted && routes.isEmpty) {
        _showNotification(
          networkErrorMessage(e, 'Не удалось загрузить трассы'),
          Colors.red,
        );
      }
    }
    if (mounted) _flushPendingResults();
  }

  Future<void> _flushPendingResults() async {
    final sent = await OfflineQueueService.flush();
    if (sent > 0 && mounted) {
      _showNotification('Отправлены отложенные результаты ($sent)', Colors.green);
    }
  }

  // Функция для обновления выбранной попытки
  void _updateSelectedAttempts(int routeId, int attempt) {
    if (mounted) {
      setState(() {
        final index = selectedAttempts.indexWhere((a) => a['route_id'] == routeId);
        if (index != -1) {
          selectedAttempts[index]['attempt'] = attempt;
        } else {
          selectedAttempts.add({'route_id': routeId, 'attempt': attempt});
        }
        for (final r in routes) {
          if (r.routeId == routeId) {
            r.attempt = attempt;
            break;
          }
        }
      });

      _saveDraftResults();
    }
  }

  Future<void> _saveDraftResults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'results_draft_${widget.eventId}';
      await prefs.setString(key, jsonEncode(selectedAttempts));
    } catch (e) {
    }
  }

  Future<void> _loadDraftResults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'results_draft_${widget.eventId}';
      final stored = prefs.getString(key);
      if (stored == null) return;

      final List<dynamic> decoded = jsonDecode(stored);
      final List<Map<String, dynamic>> draft = decoded
          .whereType<Map<String, dynamic>>()
          .map((m) => {
                'route_id': m['route_id'],
                'attempt': m['attempt'] ?? 0,
              })
          .toList();

      if (!mounted) return;

      setState(() {
        selectedAttempts = draft;
        // Проставляем попытки в сами маршруты
        for (final r in routes) {
          final m = draft.firstWhere(
            (d) => d['route_id'] == r.routeId,
            orElse: () => {'attempt': r.attempt},
          );
          r.attempt = m['attempt'] ?? 0;
        }
      });
    } catch (e) {
    }
  }

  Future<void> _loadServerResultsIfNeeded() async {
    try {
      if (!widget.isParticipantActive) return;

      final hasAnyAttemptInRoutes = routes.any((r) => r.attempt != 0);
      final hasAnyAttemptInSelected = selectedAttempts.any(
        (m) => (m['attempt'] ?? 0) != 0,
      );
      if (hasAnyAttemptInRoutes || hasAnyAttemptInSelected) return;

      final String? token = await getToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse('$DOMAIN/api/event/${widget.eventId}/results/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        return;
      }

      final Map<String, dynamic> body = jsonDecode(response.body);
      final List<dynamic> results = body['results'] as List<dynamic>? ?? [];

      if (!mounted || results.isEmpty) return;

      setState(() {
        for (final item in results) {
          if (item is! Map) continue;
          final routeId = item['route_id'];
          final attempt = item['attempt'] ?? 0;
          if (routeId == null) continue;

          for (final r in routes) {
            if (r.routeId == routeId) {
              r.attempt = attempt;
            }
          }
        }

        // Обновляем selectedAttempts на основе актуальных попыток
        selectedAttempts = routes
            .map((r) => {
                  'route_id': r.routeId,
                  'attempt': r.attempt,
                })
            .toList();
      });
    } catch (_) {
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Внесение результата', style: unbounded(fontWeight: FontWeight.w500, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: routes.map((route) => RouteCard(
          route: route,
          selectedAttempts: selectedAttempts,
          onAttemptSelected: _updateSelectedAttempts,
        )).toList(),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.mutedGold,
            foregroundColor: AppColors.anthracite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: _submitResults,
          child: Text('Отправить результат',
            style: unbounded(
              color: AppColors.anthracite,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class RouteCard extends StatefulWidget {
  final Routes route;
  final List<Map<String, dynamic>> selectedAttempts;
  final Function(int routeId, int attempt) onAttemptSelected;

  const RouteCard({
    Key? key,
    required this.route,
    required this.selectedAttempts,
    required this.onAttemptSelected,
  }) : super(key: key);

  @override
  _RouteCardState createState() => _RouteCardState();
}

class _RouteCardState extends State<RouteCard> {
  int selectedAttempt = 0;

  @override
  void initState() {
    super.initState();
    // Инициализируем выбранную попытку из уже сохранённых результатов, если они есть
    selectedAttempt = widget.route.attempt;
  }

  int get _selectedAttempt {
    final found = widget.selectedAttempts
        .where((a) => (a['route_id'] ?? -1) == widget.route.routeId)
        .toList();
    if (found.isEmpty) return widget.route.attempt;
    final a = found.first['attempt'];
    if (a is int) return a;
    if (a is num) return a.toInt();
    return widget.route.attempt;
  }

  @override
  Widget build(BuildContext context) {
    selectedAttempt = _selectedAttempt;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Трасса ${widget.route.routeId}',
              style: unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Цвет: ', style: AppTypography.secondary()),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: widget.route.color ?? AppColors.graphite,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 16),
                Text('Категория: ${displayValue(widget.route.grade)}', style: AppTypography.secondary()),
              ],
            ),
            const SizedBox(height: 20),
            Text('Попытка:', style: AppTypography.secondary()),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildAttemptIcon(0, 'X', AppColors.graphite, widget.route.routeId),
                _buildAttemptIcon(1, 'Flash', AppColors.successMuted, widget.route.routeId),
                _buildAttemptIcon(2, 'Redpoint', AppColors.mutedGold, widget.route.routeId),
                _buildAttemptIcon(3, 'Zone', AppColors.graphite.withOpacity(0.8), widget.route.routeId),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttemptIcon(int index, String label, Color color, int routeId) {
    final isSelected = selectedAttempt == index;
    return GestureDetector(
      onTap: () {
        if (mounted) {
          setState(() {
            selectedAttempt = index;
            widget.onAttemptSelected(routeId, selectedAttempt);
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: isSelected ? null : Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(
          label,
          style: unbounded(
            color: isSelected && color == AppColors.mutedGold ? AppColors.anthracite : Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class Routes {
  final int routeId;
  final String? routeName;
  final Color? color;
  final String grade;
  int attempt = 0;

  Routes({
    required this.routeId,
    required this.routeName,
    required this.color,
    required this.grade,
  });

  factory Routes.fromJson(Map<String, dynamic> json) {
    final route = Routes(
      routeId: json['route_id'] ?? 0,
      routeName: json['routeName'] ?? '',
      color: json['color'] != null ? _colorFromHex(json['color']) : Colors.transparent,
      grade: json['grade'] ?? '',
    );
    if (json['attempt'] != null) {
      route.attempt = json['attempt'];
    }
    return route;
  }

  // Helper function to convert a hex color string to Color
  static Color _colorFromHex(String hexColor) {
    hexColor = hexColor.replaceFirst('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor'; // Add opacity if not provided
    }
    return Color(int.parse(hexColor, radix: 16));
  }
}
