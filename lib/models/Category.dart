class Category {
  final String category;
  final int id;
  final String toGrade;
  final String fromGrade;
   // Уникальный идентификатор категории (используется, например, для festival-результатов)
  final String uniqidCategoryId;

  Category({
    required this.category,
    required this.id,
    required this.toGrade,
    required this.fromGrade,
    this.uniqidCategoryId = '',
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    final dynamic rawId = json['id'] ?? json['category_id'];
    int parsedId;
    if (rawId is int) {
      parsedId = rawId;
    } else if (rawId is String) {
      parsedId = int.tryParse(rawId) ?? 0;
    } else {
      parsedId = 0;
    }

    return Category(
      category: json['category'],
      id: parsedId,
      toGrade: json['to_grade'] ?? '',
      fromGrade: json['from_grade'] ?? '',
      uniqidCategoryId:
          (json['uniqid_category_id'] ?? json['uniqid'] ?? '').toString(),
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