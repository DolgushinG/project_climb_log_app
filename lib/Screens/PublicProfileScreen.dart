import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';

import '../CompetitionScreen.dart';
import '../main.dart';
import '../utils/display_helper.dart';

/// Модель ответа API публичного профиля
class PublicProfileData {
  final bool isPrivate;
  final String? message;
  final PublicProfileUser? user;
  final PublicProfileState? stateUser;
  final String? bestGrade;
  final List<PublicProfileEvent> events;

  PublicProfileData({
    required this.isPrivate,
    this.message,
    this.user,
    this.stateUser,
    this.bestGrade,
    required this.events,
  });

  factory PublicProfileData.fromJson(Map<String, dynamic> json) {
    return PublicProfileData(
      isPrivate: json['is_private'] == true,
      message: json['message'],
      user: json['user'] != null
          ? PublicProfileUser.fromJson(
              Map<String, dynamic>.from(json['user'] as Map))
          : null,
      stateUser: json['state_user'] != null
          ? PublicProfileState.fromJson(
              Map<String, dynamic>.from(json['state_user'] as Map))
          : null,
      bestGrade: json['best_grade']?.toString(),
      events: (json['events'] as List<dynamic>?)
              ?.map((e) => PublicProfileEvent.fromJson(
                  Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
    );
  }
}

class PublicProfileUser {
  final int id;
  final String middlename;
  final String city;
  final String? avatar;
  final String? avatarUrl;
  final String? emailVerifiedAt;
  final int countEvent;

  PublicProfileUser({
    required this.id,
    required this.middlename,
    required this.city,
    this.avatar,
    this.avatarUrl,
    this.emailVerifiedAt,
    required this.countEvent,
  });

  factory PublicProfileUser.fromJson(Map<String, dynamic> json) {
    return PublicProfileUser(
      id: json['id'] ?? 0,
      middlename: (json['middlename'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      avatar: json['avatar']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      emailVerifiedAt: json['email_verified_at']?.toString(),
      countEvent: json['count_event'] ?? 0,
    );
  }
}

class PublicProfileState {
  final double flash;
  final double redpoint;
  final int all;

  PublicProfileState({
    required this.flash,
    required this.redpoint,
    required this.all,
  });

  factory PublicProfileState.fromJson(Map<String, dynamic> json) {
    return PublicProfileState(
      flash: _toDouble(json['flash']),
      redpoint: _toDouble(json['redpoint']),
      all: _toInt(json['all']) ?? 0,
    );
  }
}

class PublicProfileEvent {
  final PublicProfileEventInfo event;
  final String category;
  final int? qualificationPlace;
  final int? semifinalPlace;
  final int? finalPlace;

  PublicProfileEvent({
    required this.event,
    required this.category,
    this.qualificationPlace,
    this.semifinalPlace,
    this.finalPlace,
  });

  factory PublicProfileEvent.fromJson(Map<String, dynamic> json) {
    final eventRaw = json['event'];
    return PublicProfileEvent(
      event: PublicProfileEventInfo.fromJson(
          Map<String, dynamic>.from((eventRaw is Map ? eventRaw : {}) as Map)),
      category: (json['category'] ?? '').toString(),
      qualificationPlace: _toInt(json['qualification_place']),
      semifinalPlace: _toInt(json['semifinal_place']),
      finalPlace: _toInt(json['final_place']),
    );
  }
}

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

class PublicProfileEventInfo {
  final int id;
  final String title;
  final String? image;
  final String? poster;
  final String? startDate;
  final String? endDate;
  final String? newLink;
  final bool isFinished;
  final bool isRegistrationState;
  final int countParticipant;

  PublicProfileEventInfo({
    required this.id,
    required this.title,
    this.image,
    this.poster,
    this.startDate,
    this.endDate,
    this.newLink,
    required this.isFinished,
    required this.isRegistrationState,
    required this.countParticipant,
  });

  factory PublicProfileEventInfo.fromJson(Map<String, dynamic> json) {
    return PublicProfileEventInfo(
      id: json['id'] ?? 0,
      title: (json['title'] ?? '').toString(),
      image: json['image']?.toString(),
      poster: json['poster']?.toString(),
      startDate: json['start_date']?.toString(),
      endDate: json['end_date']?.toString(),
      newLink: json['new_link']?.toString(),
      isFinished: json['is_finished'] == true,
      isRegistrationState: json['is_registration_state'] == true,
      countParticipant: json['count_participant'] ?? 0,
    );
  }
}

Future<PublicProfileData?> fetchPublicProfile(int userId) async {
  final url = Uri.parse('$DOMAIN/api/public-profile/$userId');
  try {
    final response = await http.get(
      url,
      headers: {'Accept': 'application/json'},
    );
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return PublicProfileData.fromJson(json);
    }
    return null;
  } catch (_) {
    return null;
  }
}

class PublicProfileScreen extends StatefulWidget {
  final int userId;

  const PublicProfileScreen({super.key, required this.userId});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  bool _isLoading = true;
  bool _notFound = false;
  PublicProfileData? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _notFound = false;
      _data = null;
    });
    final data = await fetchPublicProfile(widget.userId);
    if (!mounted) return;
    if (data == null) {
      setState(() {
        _isLoading = false;
        _notFound = true;
      });
    } else {
      setState(() {
        _isLoading = false;
        _data = data;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Публичный профиль', style: GoogleFonts.unbounded(fontWeight: FontWeight.w500, fontSize: 18, color: Colors.white)),
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
    if (_data!.isPrivate) {
      return _buildPrivateProfile();
    }
    return _buildPublicProfile();
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
              Icon(Icons.person_off_rounded, size: 64, color: AppColors.mutedGold.withOpacity(0.5)),
              const SizedBox(height: 16),
              Text(
                'Пользователь не найден',
                style: GoogleFonts.unbounded(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
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
                child: Text('Вернуться назад', style: GoogleFonts.unbounded(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrivateProfile() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded, size: 64, color: AppColors.mutedGold.withOpacity(0.5)),
              const SizedBox(height: 16),
              Text(
                'Профиль скрыт',
                style: GoogleFonts.unbounded(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Этот пользователь решил сделать свой профиль приватным',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.unbounded(color: Colors.white70, fontSize: 14),
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
                child: Text('Вернуться назад', style: GoogleFonts.unbounded(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPublicProfile() {
    final user = _data!.user!;
    final state = _data!.stateUser;
    final events = _data!.events;

    final avatarUrl = _resolveAvatarUrl(user.avatarUrl, user.avatar);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfileHeader(user, avatarUrl),
          if (state != null) ...[
            const SizedBox(height: 20),
            _buildStatsSection(state),
          ],
          if (events.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'История выступлений',
              style: GoogleFonts.unbounded(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const SizedBox(height: 12),
            ...events.map((e) => _buildEventCard(e)),
          ],
        ],
      ),
    );
  }

  String _resolveAvatarUrl(String? avatarUrl, String? avatar) {
    if (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.startsWith('http')) {
      return avatarUrl;
    }
    if (avatar != null && avatar.isNotEmpty) {
      final path = avatar.startsWith('/') ? avatar : '/storage/$avatar';
      return '$DOMAIN$path';
    }
    return '';
  }

  Widget _buildProfileHeader(PublicProfileUser user, String avatarUrl) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.rowAlt,
              backgroundImage: avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl.isEmpty
                  ? Text(
                      user.middlename.isNotEmpty ? user.middlename[0] : '?',
                      style: GoogleFonts.unbounded(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w600),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.middlename,
                          style: GoogleFonts.unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ),
                      if (user.emailVerifiedAt != null &&
                          user.emailVerifiedAt!.isNotEmpty)
                        const Icon(
                          Icons.verified_rounded,
                          size: 20,
                          color: AppColors.mutedGold,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Город: ${displayValue(user.city)}',
                    style: GoogleFonts.unbounded(fontSize: 13, color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.rowAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Кол-во участий: ${user.countEvent}',
                      style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Макс. категория: ${displayValue(_data!.bestGrade)}',
                    style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildStatsSection(PublicProfileState state) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard('Flash', '${state.flash.toStringAsFixed(1)}%', AppColors.cardDark),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard('Redpoint', '${state.redpoint.toStringAsFixed(1)}%', AppColors.cardDark),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard('Всего трасс', '${state.all}', AppColors.cardDark),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color bgColor) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.unbounded(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.unbounded(fontSize: 11, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(PublicProfileEvent item) {
    final e = item.event;
    final posterUrl = (e.poster != null && e.poster!.startsWith('http'))
        ? e.poster!
        : '$DOMAIN${e.poster ?? e.image ?? ''}';
    final dateStr = _formatEventDates(e.startDate, e.endDate);
    final statusText = e.isFinished
        ? 'Соревнование завершено'
        : (e.isRegistrationState ? 'Регистрация открыта' : 'Регистрация закрыта');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (e.id > 0) {
            _fetchAndNavigateToCompetition(e.id);
          }
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
                  child: Image.network(
                    posterUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.rowAlt,
                      child: const Icon(
                        Icons.landscape_rounded,
                        color: AppColors.mutedGold,
                        size: 32,
                      ),
                    ),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: AppColors.rowAlt,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.mutedGold),
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
                        e.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.unbounded(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      if (dateStr.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          dateStr,
                          style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'Участников: ${e.countParticipant}',
                        style: GoogleFonts.unbounded(fontSize: 11, color: Colors.white60),
                      ),
                      const SizedBox(height: 4),
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
                          style: GoogleFonts.unbounded(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: e.isFinished ? Colors.white70 : Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (item.category.isNotEmpty)
                            _buildResultChip(item.category, AppColors.rowAlt),
                          if (item.qualificationPlace != null)
                            _buildResultChip('Квалификация: ${item.qualificationPlace} место', AppColors.rowAlt),
                          if (item.semifinalPlace != null)
                            _buildResultChip('Полуфинал: ${item.semifinalPlace} место', AppColors.rowAlt),
                          if (item.finalPlace != null)
                            _buildResultChip('Финал: ${item.finalPlace} место', AppColors.rowAlt),
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

  Widget _buildResultChip(String text, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.unbounded(fontSize: 11, color: Colors.white70),
      ),
    );
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
      if (response.statusCode != 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Не удалось загрузить соревнование (${response.statusCode})')),
          );
        }
        return;
      }
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
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть соревнование')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }
}
