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
    };
  }
}
