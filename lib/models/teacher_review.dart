import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherReview {
  final String id;
  final String teacherId;
  final String userId;
  final String userName;
  final double rating;
  final String text;
  final DateTime timestamp;

  TeacherReview({
    required this.id,
    required this.teacherId,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'teacherId': teacherId,
      'userId': userId,
      'userName': userName,
      'rating': rating,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory TeacherReview.fromMap(Map<String, dynamic> map, String id) {
    return TeacherReview(
      id: id,
      teacherId: map['teacherId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'Студент',
      rating: (map['rating'] ?? 0.0).toDouble(),
      text: map['text'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }
}
