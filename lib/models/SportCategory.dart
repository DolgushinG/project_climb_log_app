class SportCategory {
  final String sport_category;
  final int id;
  SportCategory({
    required this.sport_category,
    required this.id,
  });

  factory SportCategory.fromJson(Map<String, dynamic> json) {
    return SportCategory(
      sport_category: json['category'],
      id: json['id'],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SportCategory && other.sport_category == sport_category;
  }

  @override
  int get hashCode => sport_category.hashCode;
}