class Teacher {
  final String id;
  final String shortName; // Например, "Иванов И.И."
  final String fullName;  // Например, "Иванов Иван Иванович"
  final String department; // Кафедра
  final double rating;

  Teacher({
    required this.id,
    required this.shortName,
    required this.fullName,
    this.department = "",
    this.rating = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shortName': shortName,
      'fullName': fullName,
      'department': department,
      'rating': rating,
    };
  }

  factory Teacher.fromMap(Map<String, dynamic> map, String documentId) {
    return Teacher(
      id: documentId,
      shortName: map['shortName'] ?? "",
      fullName: map['fullName'] ?? "",
      department: map['department'] ?? "",
      rating: (map['rating'] ?? 0.0).toDouble(),
    );
  }
}
