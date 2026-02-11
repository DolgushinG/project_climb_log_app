/// Модели данных для трекера трасс Climbing Log

class RouteEntry {
  final String grade;
  final int count;

  RouteEntry({required this.grade, required this.count});

  Map<String, dynamic> toJson() => {'grade': grade, 'count': count};
}

class ClimbingSessionRequest {
  final List<RouteEntry> routes;
  final String? date; // YYYY-MM-DD
  final int? gymId;

  ClimbingSessionRequest({
    required this.routes,
    this.date,
    this.gymId,
  });

  Map<String, dynamic> toJson() => {
        'routes': routes.map((e) => e.toJson()).toList(),
        if (date != null) 'date': date!,
        if (gymId != null) 'gym_id': gymId!,
      };
}

class ClimbingProgress {
  final String? maxGrade;
  final int progressPercentage;
  final Map<String, int> grades;

  ClimbingProgress({
    this.maxGrade,
    required this.progressPercentage,
    required this.grades,
  });

  factory ClimbingProgress.fromJson(Map<String, dynamic> json) =>
      ClimbingProgress(
        maxGrade: json['maxGrade'] as String?,
        progressPercentage: _toInt(json['progressPercentage']) ?? 0,
        grades: (json['grades'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, _toInt(v) ?? 0),
            ) ??
            {},
      );

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}

class HistoryRoute {
  final String grade;
  final int count;

  HistoryRoute({required this.grade, required this.count});

  factory HistoryRoute.fromJson(Map<String, dynamic> json) {
    final count = json['count'];
    final c = count is int
        ? count
        : count is num
            ? count.toInt()
            : int.tryParse(count?.toString() ?? '') ?? 0;
    return HistoryRoute(
      grade: json['grade'] as String,
      count: c,
    );
  }
}

class HistorySession {
  final int? id;
  final String date;
  final String gymName;
  final int? gymId;
  final List<HistoryRoute> routes;

  HistorySession({
    this.id,
    required this.date,
    required this.gymName,
    this.gymId,
    required this.routes,
  });

  factory HistorySession.fromJson(Map<String, dynamic> json) =>
      HistorySession(
        id: _toInt(json['id']),
        date: json['date'] as String,
        gymName: json['gym_name'] as String? ?? 'Не указан',
        gymId: _toInt(json['gym_id']),
        routes: (json['routes'] as List<dynamic>?)
                ?.map((e) =>
                    HistoryRoute.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}

/// Зал, на котором пользователь уже тренировался (для подсказок).
class UsedGym {
  final int id;
  final String name;
  final String? city;
  final String? lastUsed; // YYYY-MM-DD, опционально

  UsedGym({required this.id, required this.name, this.city, this.lastUsed});

  factory UsedGym.fromJson(Map<String, dynamic> json) => UsedGym(
        id: (json['id'] as num).toInt(),
        name: (json['name'] ?? '').toString(),
        city: json['city']?.toString(),
        lastUsed: json['last_used']?.toString(),
      );
}

class GradesResponse {
  final List<String> grades;
  final Map<String, List<String>> gradeGroups;

  GradesResponse({
    required this.grades,
    required this.gradeGroups,
  });

  factory GradesResponse.fromJson(Map<String, dynamic> json) {
    final gradesRaw = json['grades'];
    final groupsRaw = json['grade_groups'] as Map<String, dynamic>? ?? {};
    return GradesResponse(
      grades: gradesRaw is List
          ? (gradesRaw).map((e) => e.toString()).toList()
          : ['5', '6A', '6A+', '6B', '6B+', '6C', '6C+', '7A', '7A+', '7B', '7B+', '7C', '7C+', '8A+'],
      gradeGroups: groupsRaw.map(
        (k, v) => MapEntry(
          k,
          (v as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        ),
      ),
    );
  }
}
