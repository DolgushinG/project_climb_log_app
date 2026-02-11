/// Модели данных для страницы скалодрома (API /api/gyms/{gym_id})

class Gym {
  final int id;
  final String name;
  final String? address;
  final String? url;
  final String? phone;
  final String? hours;
  final String? city;
  final int sumLikes;
  final double? lat;
  final double? long;
  final String? mapIframeUrl;

  Gym({
    required this.id,
    required this.name,
    this.address,
    this.url,
    this.phone,
    this.hours,
    this.city,
    this.sumLikes = 0,
    this.lat,
    this.long,
    this.mapIframeUrl,
  });

  factory Gym.fromJson(Map<String, dynamic> json) => Gym(
        id: json['id'] as int,
        name: (json['name'] ?? '').toString(),
        address: json['address']?.toString(),
        url: json['url']?.toString(),
        phone: json['phone']?.toString(),
        hours: json['hours']?.toString(),
        city: json['city']?.toString(),
        sumLikes: json['sum_likes'] as int? ?? 0,
        lat: (json['lat'] as num?)?.toDouble(),
        long: (json['long'] as num?)?.toDouble(),
        mapIframeUrl: json['map_iframe_url']?.toString(),
      );
}

class GymEvent {
  final int id;
  final String title;
  final String? image;
  final String? posterUrl;
  final String? startDate;
  final String? endDate;
  final String? newLink;
  final String? url;
  final int countParticipant;
  final bool isFinished;
  final bool isRegistrationState;

  GymEvent({
    required this.id,
    required this.title,
    this.image,
    this.posterUrl,
    this.startDate,
    this.endDate,
    this.newLink,
    this.url,
    this.countParticipant = 0,
    this.isFinished = false,
    this.isRegistrationState = false,
  });

  factory GymEvent.fromJson(Map<String, dynamic> json) => GymEvent(
        id: json['id'] as int,
        title: (json['title'] ?? '').toString(),
        image: json['image']?.toString(),
        posterUrl: json['poster_url']?.toString(),
        startDate: json['start_date']?.toString(),
        endDate: json['end_date']?.toString(),
        newLink: json['new_link']?.toString(),
        url: json['url']?.toString(),
        countParticipant: json['count_participant'] as int? ?? 0,
        isFinished: json['is_finished'] == true,
        isRegistrationState: json['is_registration_state'] == true,
      );
}

class GymJob {
  final int id;
  final String title;
  final String? city;
  final String? experience;
  final String? salary;
  final String? type;
  final String? publishedAt;
  final String? url;

  GymJob({
    required this.id,
    required this.title,
    this.city,
    this.experience,
    this.salary,
    this.type,
    this.publishedAt,
    this.url,
  });

  factory GymJob.fromJson(Map<String, dynamic> json) => GymJob(
        id: json['id'] as int,
        title: (json['title'] ?? '').toString(),
        city: json['city']?.toString(),
        experience: json['experience']?.toString(),
        salary: json['salary']?.toString(),
        type: json['type']?.toString(),
        publishedAt: json['published_at']?.toString(),
        url: json['url']?.toString(),
      );

  static String typeLabel(String? type) {
    switch (type) {
      case 'full-time':
        return 'Полный день';
      case 'part-time':
        return 'Частичная занятость';
      case 'remote':
        return 'Удалённая работа';
      case 'contract':
        return 'Сдельная работа';
      case 'freelance':
        return 'Фриланс';
      default:
        return type ?? '';
    }
  }
}

/// Результат поиска скалодромов (GET /api/search-gyms)
class GymSearchItem {
  final int id;
  final String name;
  final String? city;

  GymSearchItem({required this.id, required this.name, this.city});

  factory GymSearchItem.fromJson(Map<String, dynamic> json) => GymSearchItem(
        id: json['id'] as int,
        name: (json['name'] ?? '').toString(),
        city: json['city']?.toString(),
      );
}
