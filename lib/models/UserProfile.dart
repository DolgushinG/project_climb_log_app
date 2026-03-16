class UserProfile {
  String firstName;
  String lastName;
  String team;
  String city;
  String contact;
  String birthday;
  String sportCategory;
  String gender;
  String email;
  /// Согласие на обработку данных AI-чата. null = не задано на сервере.
  bool? aiMemoryConsent;
  /// Режим тренера включён (добавление учеников, назначение упражнений, просмотр их данных).
  bool? trainerModeEnabled;

  UserProfile({
    required this.firstName,
    required this.lastName,
    required this.team,
    required this.city,
    required this.contact,
    required this.birthday,
    required this.sportCategory,
    required this.gender,
    required this.email,
    this.aiMemoryConsent,
    this.trainerModeEnabled,
  });

  // Метод для создания объекта UserProfile из JSON
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      firstName: json['firstname'],
      lastName: json['lastname'],
      team: json['team'] ?? '',
      city: json['city'] ?? '',
      contact: json['contact'] ?? '',
      birthday: json['birthday'] ?? '',
      sportCategory: json['sport_category'] ?? '',
      gender: json['gender'] ?? '',
      email: json['email'],
      aiMemoryConsent: json['ai_memory_consent'] as bool?,
      trainerModeEnabled: json['trainer_mode_enabled'] as bool?,
    );
  }

  // Метод для преобразования UserProfile в JSON
  Map<String, dynamic> toJson() {
    return {
      'firstname': firstName,
      'lastname': lastName,
      'team': team,
      'city': city,
      'contact': contact,
      'birthday': birthday,
      'sport_category': sportCategory,
      'gender': gender,
      'email': email,
      if (trainerModeEnabled != null) 'trainer_mode_enabled': trainerModeEnabled!,
    };
  }
}
