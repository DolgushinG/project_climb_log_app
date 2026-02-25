import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../CompetitionScreen.dart';
import '../main.dart';
import '../models/Gym.dart';
import '../services/GymService.dart';

class GymProfileScreen extends StatefulWidget {
  final int gymId;

  const GymProfileScreen({super.key, required this.gymId});

  @override
  State<GymProfileScreen> createState() => _GymProfileScreenState();
}

class _GymProfileScreenState extends State<GymProfileScreen> {
  bool _isLoading = true;
  bool _notFound = false;
  GymProfileData? _data;
  int _jobsPage = 1;
  static const int _jobsPerPage = 10;
  bool _loadingMoreJobs = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int jobsPage = 1}) async {
    setState(() {
      _isLoading = jobsPage == 1;
      if (jobsPage == 1) _notFound = false;
      _loadingMoreJobs = jobsPage > 1;
      _jobsPage = jobsPage;
    });
    final data = await fetchGymProfile(widget.gymId,
        page: jobsPage, perPage: _jobsPerPage);
    if (!mounted) return;
    if (data == null && jobsPage == 1) {
      setState(() {
        _isLoading = false;
        _notFound = true;
      });
    } else if (data != null) {
      setState(() {
        _isLoading = false;
        _loadingMoreJobs = false;
        if (jobsPage == 1) {
          _data = data;
        } else if (_data != null) {
          _data = GymProfileData(
            gym: data.gym,
            vacanciesCount: data.vacanciesCount,
            events: data.events,
            jobs: [..._data!.jobs, ...data.jobs],
            jobsPagination: data.jobsPagination,
          );
        }
      });
    } else {
      setState(() => _loadingMoreJobs = false);
    }
  }

  Future<void> _launchUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Скалодром', style: unbounded(fontWeight: FontWeight.w500, fontSize: 18, color: Colors.white)),
        backgroundColor: AppColors.cardDark,
      ),
      backgroundColor: AppColors.anthracite,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_notFound) {
      return _buildNotFound();
    }
    if (_data == null) return const SizedBox.shrink();
    return _buildGymProfile();
  }

  Widget _buildNotFound() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.business_rounded, size: 64, color: AppColors.mutedGold.withOpacity(0.5)),
              const SizedBox(height: 16),
              Text(
                'Скалодром не найден',
                style: unbounded(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mutedGold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Вернуться назад', style: unbounded(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGymProfile() {
    final gym = _data!.gym;
    final events = _data!.events;
    final jobs = _data!.jobs;
    final pagination = _data!.jobsPagination;
    final hasMoreJobs = pagination != null &&
        pagination.currentPage < pagination.lastPage &&
        pagination.total > jobs.length;

    return RefreshIndicator(
      onRefresh: () => _load(jobsPage: 1),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildGymHeader(gym),
          if (_data!.vacanciesCount > 0) ...[
            const SizedBox(height: 16),
            _buildStatsRow(gym),
          ],
          if (gym.address != null && gym.address!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildInfoBlock(
              icon: Icons.place_outlined,
              label: 'Адрес',
              value: gym.address!,
            ),
          ],
          if (gym.url != null && gym.url!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildLinkBlock(
              icon: Icons.language_outlined,
              label: 'Сайт',
              value: gym.url!,
              url: gym.url,
            ),
          ],
          if (gym.phone != null && gym.phone!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildLinkBlock(
              icon: Icons.phone_outlined,
              label: 'Телефон',
              value: gym.phone!,
              url: 'tel:${gym.phone}',
            ),
          ],
          if (gym.hours != null && gym.hours!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoBlock(
              icon: Icons.schedule_outlined,
              label: 'Часы работы',
              value: gym.hours!,
            ),
          ],
          if (gym.city != null && gym.city!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoBlock(
              icon: Icons.location_city_outlined,
              label: 'Город',
              value: gym.city!,
            ),
          ],
          if ((gym.address != null && gym.address!.isNotEmpty) ||
              (gym.lat != null && gym.long != null)) ...[
            const SizedBox(height: 20),
            _buildMapSection(gym),
          ],
          if (events.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSectionTitle('Соревнования'),
            const SizedBox(height: 12),
            ...events.map((e) => _buildEventCard(e)),
          ],
          if (jobs.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSectionTitle('Вакансии'),
            const SizedBox(height: 12),
            ...jobs.map((j) => _buildJobCard(j)),
            ...(hasMoreJobs
                ? [
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Center(
                        child: _loadingMoreJobs
                            ? const SizedBox(
                                height: 40,
                                width: 40,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : TextButton(
                                onPressed: () => _load(jobsPage: _jobsPage + 1),
                                child: Text('Загрузить ещё', style: unbounded(color: AppColors.mutedGold, fontWeight: FontWeight.w600)),
                              ),
                      ),
                    ),
                  ]
                : []),
          ],
        ],
      ),
    );
  }

  Widget _buildGymHeader(Gym gym) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.rowAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.sports,
              size: 36,
              color: AppColors.mutedGold,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gym.name,
                  style: unbounded(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (gym.city != null && gym.city!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    gym.city!,
                    style: unbounded(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(Gym gym) {
    return Row(
      children: [
        Expanded(
          child: _buildStatChip(
            Icons.work_outline,
            '${_data!.vacanciesCount}',
            'вакансий',
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: AppColors.mutedGold),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: unbounded(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                label,
                style: unbounded(
                  fontSize: 11,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBlock(
      {required IconData icon, required String label, required String value}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.mutedGold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: unbounded(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: unbounded(
                    fontSize: 14,
                    color: Colors.white,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkBlock({
    required IconData icon,
    required String label,
    required String value,
    String? url,
  }) {
    final effectiveUrl = url ?? value;
    final isTappable = effectiveUrl.startsWith('http') ||
        effectiveUrl.startsWith('tel:') ||
        effectiveUrl.startsWith('mailto:');

    return GestureDetector(
      onTap: isTappable ? () => _launchUrl(effectiveUrl) : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppColors.mutedGold),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: unbounded(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          value,
                          style: unbounded(
                            fontSize: 14,
                            color: isTappable
                                ? AppColors.mutedGold
                                : Colors.white,
                            height: 1.35,
                            decoration: isTappable
                                ? TextDecoration.underline
                                : null,
                          ),
                        ),
                      ),
                      if (isTappable)
                        const Icon(
                          Icons.open_in_new,
                          size: 16,
                          color: AppColors.mutedGold,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapSection(Gym gym) {
    String? url;
    if (gym.lat != null && gym.long != null) {
      url = 'https://www.google.com/maps?q=${gym.lat},${gym.long}';
    } else if (gym.address != null && gym.address!.isNotEmpty) {
      url =
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(gym.address!)}';
    }
    if (url == null || url.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => _launchUrl(url),
      child: Container(
        height: 100,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.rowAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.map_outlined,
                size: 28,
                color: AppColors.mutedGold,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Открыть в картах',
                    style: unbounded(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    gym.address ?? 'Скалодром на карте',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: unbounded(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.mutedGold,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: unbounded(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    );
  }

  Widget _buildEventCard(GymEvent e) {
    final posterUrl = (e.posterUrl != null && e.posterUrl!.startsWith('http'))
        ? e.posterUrl!
        : '$DOMAIN${e.posterUrl ?? e.image ?? ''}';
    final dateStr = _formatEventDates(e.startDate, e.endDate);
    final statusText = e.isFinished
        ? 'Завершено'
        : (e.isRegistrationState ? 'Регистрация открыта' : 'Регистрация закрыта');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (e.id > 0) _fetchAndNavigateToCompetition(e.id);
        },
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              SizedBox(
                width: 84,
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: CachedNetworkImage(
                    imageUrl: posterUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: AppColors.rowAlt,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.mutedGold),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.rowAlt,
                      child: const Icon(
                        Icons.landscape_rounded,
                        color: AppColors.mutedGold,
                        size: 32,
                      ),
                    ),
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
                        e.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: unbounded(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      if (dateStr.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          dateStr,
                          style: unbounded(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'Участников: ${e.countParticipant}',
                        style: unbounded(
                          fontSize: 11,
                          color: Colors.white60,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: e.isFinished
                              ? AppColors.graphite
                              : AppColors.successMuted.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          statusText,
                          style: unbounded(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: e.isFinished
                                ? Colors.white70
                                : Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            'Подробнее',
                            style: unbounded(
                              fontSize: 12,
                              color: AppColors.mutedGold,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 10,
                            color: AppColors.mutedGold,
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

  Widget _buildJobCard(GymJob j) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _launchUrl(j.url),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      j.title,
                      style: unbounded(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (j.url != null && j.url!.isNotEmpty)
                    const Icon(
                      Icons.open_in_new,
                      size: 16,
                      color: AppColors.mutedGold,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (j.city != null && j.city!.isNotEmpty)
                    _buildJobChip(j.city!),
                  if (j.salary != null && j.salary!.isNotEmpty)
                    _buildJobChip(j.salary!),
                  if (j.type != null && j.type!.isNotEmpty)
                    _buildJobChip(GymJob.typeLabel(j.type)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJobChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.rowAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: unbounded(
          fontSize: 11,
          color: Colors.white70,
        ),
      ),
    );
  }

  String _formatEventDates(String? start, String? end) {
    if (start == null || start.isEmpty) return '';
    try {
      final startDt = DateTime.parse(start);
      final startStr = DateFormat('dd.MM.yyyy').format(startDt);
      if (end != null && end.isNotEmpty) {
        final endDt = DateTime.parse(end);
        final endStr = DateFormat('dd.MM.yyyy').format(endDt);
        return '$startStr – $endStr';
      }
      return startStr;
    } catch (_) {
      return start;
    }
  }

  Future<void> _fetchAndNavigateToCompetition(int eventId) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$DOMAIN/api/competitions?event_id=$eventId');
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (!mounted) return;
      if (response.statusCode != 200) return;
      final decoded = jsonDecode(response.body);
      Competition? comp;
      if (decoded is List && decoded.isNotEmpty) {
        final first = decoded.first;
        if (first is Map) {
          comp = Competition.fromJson(Map<String, dynamic>.from(first));
        }
      } else if (decoded is Map) {
        final data = decoded['data'];
        if (data is List && data.isNotEmpty) {
          final first = data.first;
          if (first is Map) {
            comp = Competition.fromJson(Map<String, dynamic>.from(first));
          }
        } else if (decoded['id'] != null || decoded['title'] != null) {
          comp = Competition.fromJson(Map<String, dynamic>.from(decoded));
        }
      }
      if (comp != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CompetitionDetailScreen(comp!),
          ),
        );
      }
    } catch (_) {}
  }
}
