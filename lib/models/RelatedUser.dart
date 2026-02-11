class RelatedUser {
  final int id;
  final String firstname;
  final String lastname;
  final String? middlename;
  final String? email;
  final String? birthday;
  final String? city;
  final String? sportCategory;
  final String? gender;
  final String? team;
  final String? contact;

  RelatedUser({
    required this.id,
    required this.firstname,
    required this.lastname,
    this.middlename,
    this.email,
    this.birthday,
    this.city,
    this.sportCategory,
    this.gender,
    this.team,
    this.contact,
  });

  factory RelatedUser.fromJson(Map<String, dynamic> json) {
    return RelatedUser(
      id: _toInt(json['id']) ?? 0,
      firstname: json['firstname']?.toString() ?? '',
      lastname: json['lastname']?.toString() ?? '',
      middlename: json['middlename']?.toString(),
      email: json['email']?.toString(),
      birthday: json['birthday']?.toString(),
      city: json['city']?.toString(),
      sportCategory: json['sport_category']?.toString(),
      gender: json['gender']?.toString(),
      team: json['team']?.toString(),
      contact: json['contact']?.toString(),
    );
  }

  Map<String, dynamic> toEditJson() {
    return {
      'user_id': id,
      'firstname': firstname,
      'lastname': lastname,
      'email': email ?? '',
      if (birthday != null && birthday!.isNotEmpty) 'birthday': birthday,
      if (city != null && city!.isNotEmpty) 'city': city,
      if (sportCategory != null && sportCategory!.isNotEmpty) 'sport_category': sportCategory,
      if (gender != null && gender!.isNotEmpty) 'gender': gender,
      if (team != null && team!.isNotEmpty) 'team': team,
      if (contact != null && contact!.isNotEmpty) 'contact': contact,
    };
  }

  RelatedUser copyWith({
    int? id,
    String? firstname,
    String? lastname,
    String? middlename,
    String? email,
    String? birthday,
    String? city,
    String? sportCategory,
    String? gender,
    String? team,
    String? contact,
  }) {
    return RelatedUser(
      id: id ?? this.id,
      firstname: firstname ?? this.firstname,
      lastname: lastname ?? this.lastname,
      middlename: middlename ?? this.middlename,
      email: email ?? this.email,
      birthday: birthday ?? this.birthday,
      city: city ?? this.city,
      sportCategory: sportCategory ?? this.sportCategory,
      gender: gender ?? this.gender,
      team: team ?? this.team,
      contact: contact ?? this.contact,
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
