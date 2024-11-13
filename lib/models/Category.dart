class Category {
  final String category;
  final int id;
  final String toGrade;
  final String fromGrade;

  Category({
    required this.category,
    required this.id,
    required this.toGrade,
    required this.fromGrade,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      category: json['category'],
      id: json['id'],
      toGrade: json['to_grade'],
      fromGrade: json['from_grade'],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Category && other.category == category;
  }

  @override
  int get hashCode => category.hashCode;
}