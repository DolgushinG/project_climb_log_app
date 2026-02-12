import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'main.dart';
import 'models/Category.dart';
import 'Screens/PublicProfileScreen.dart';
import 'theme/app_theme.dart';
import 'utils/display_helper.dart';


// Структура данных для результатов участников
class ParticipantResult {
  final int user_place;
  final String middlename;
  final String category;
  final num points;
  final String gender;
  final int? userId;

  ParticipantResult({
    required this.user_place,
    required this.middlename,
    required this.category,
    required this.points,
    required this.gender,
    this.userId,
  });

  // Фабричный метод для создания экземпляра из JSON
  factory ParticipantResult.fromJson(Map<String, dynamic> json) {
    // Бэкенд теперь отдаёт поле place (ранее было user_place) —
    // поддерживаем оба варианта для совместимости.
    final dynamic rawPlace = json['place'] ?? json['user_place'];
    int parsedPlace;
    if (rawPlace is int) {
      parsedPlace = rawPlace;
    } else if (rawPlace is String) {
      parsedPlace = int.tryParse(rawPlace) ?? 0;
    } else {
      parsedPlace = 0;
    }

    final dynamic rawPoints = json['points'];
    num parsedPoints;
    if (rawPoints is num) {
      parsedPoints = rawPoints;
    } else if (rawPoints is String) {
      parsedPoints = num.tryParse(rawPoints) ?? 0;
    } else {
      parsedPoints = 0;
    }

    int? parsedUserId;
    final uid = json['user_id'] ?? json['id'];
    if (uid is int && uid > 0) parsedUserId = uid;
    if (uid is num && uid.toInt() > 0) parsedUserId = uid.toInt();
    if (uid is String) {
      final p = int.tryParse(uid);
      if (p != null && p > 0) parsedUserId = p;
    }

    return ParticipantResult(
      user_place: parsedPlace,
      middlename: json['middlename'] ?? '',
      category: json['category'] ?? '',
      points: parsedPoints,
      gender: json['gender'] ?? '',
      userId: parsedUserId,
    );
  }
}



// Функция для получения данных участников фестиваля
Future<List<ParticipantResult>> fetchParticipants({
  required final int eventId,
  required final String uniqidCategoryId,
}) async {
  final Uri url = Uri.parse(
    '$DOMAIN/api/results/festival/?event_id=$eventId&uniqid_category_id=$uniqidCategoryId',
  );

  final response = await http.get(url);

  if (response.statusCode == 200) {
    List jsonResponse = json.decode(response.body);
    return jsonResponse.map((data) => ParticipantResult.fromJson(data)).toList();
  } else {

    throw Exception('Failed to load participants');
  }
}

class ResultScreen extends StatefulWidget {
  final int eventId;
  final int categoryId;
  // Уникальный идентификатор категории, ожидаемый бэкендом для festival-результатов
  final String uniqidCategoryId;
  final Category category;
  ResultScreen({
    required this.eventId,
    required this.categoryId,
    required this.category,
    required this.uniqidCategoryId,
  });

  @override
  _ResultScreenState createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ParticipantResult> results = [];
  List<ParticipantResult> filteredResults = [];
  String? searchQuery = '';
  Category? selectedCategory;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchResults();
  }



  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.category.category.split(' ').first,
          style: GoogleFonts.unbounded(fontWeight: FontWeight.w500, fontSize: 18),
        ),
        automaticallyImplyLeading: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(999),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: Colors.transparent,
                overlayColor:
                    MaterialStateProperty.all(Colors.transparent),
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: AppColors.mutedGold.withOpacity(0.25),
                ),
                labelStyle: GoogleFonts.unbounded(fontSize: 13, fontWeight: FontWeight.w500),
                unselectedLabelStyle: GoogleFonts.unbounded(fontSize: 13, fontWeight: FontWeight.w400),
                labelPadding:
                    const EdgeInsets.symmetric(horizontal: 8.0),
                tabs: const [
                  Tab(text: 'Мужчины'),
                  Tab(text: 'Женщины'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildResultList('male'),
          _buildResultList('female'),
        ],
      ),
    );
  }
  void _fetchResults() async {
    final int eventId = widget.eventId;
    final String uniqidCategoryId = widget.uniqidCategoryId;
    try {
      final data = await fetchParticipants(
        eventId: eventId,
        uniqidCategoryId: uniqidCategoryId,
      );
      if (mounted) {
        setState(() {
          results = data;
          filteredResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  Widget _buildResultList(String gender) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final genderResults = filteredResults.where((result) => result.gender == gender).toList();

    if (genderResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events_outlined, size: 64, color: AppColors.mutedGold.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text(
                'Нет результатов',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: genderResults.length,
      itemBuilder: (context, index) {
        final result = genderResults[index];
        final place = result.user_place;
        final isMedal = place >= 1 && place <= 3;
        final hasAlternateBg = index.isEven;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: result.userId != null
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PublicProfileScreen(userId: result.userId!),
                      ),
                    );
                  }
                : null,
            child: Container(
              decoration: BoxDecoration(
                color: hasAlternateBg ? AppColors.cardDark : AppColors.rowAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 16,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Text(
                        formatPlace(place),
                        style: AppTypography.rankNumber(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 36,
                          child: isMedal
                              ? Icon(
                                  Icons.emoji_events_outlined,
                                  size: 20,
                                  color: AppColors.mutedGold,
                                )
                              : Text(
                                  formatPlace(place),
                                  style: AppTypography.scoreBadge().copyWith(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.4),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            displayValue(result.middlename),
                            style: AppTypography.athleteName(),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${result.points}',
                            style: AppTypography.scoreBadge().copyWith(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
