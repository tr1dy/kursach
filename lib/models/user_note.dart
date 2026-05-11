import 'package:cloud_firestore/cloud_firestore.dart';

class UserNote {
  final String id;
  final String userId;
  final String lessonKey; // Уникальный ключ занятия (напр. "группа_название_день_время")
  final String text;
  final DateTime updatedAt;

  UserNote({
    required this.id,
    required this.userId,
    required this.lessonKey,
    required this.text,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'lessonKey': lessonKey,
      'text': text,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory UserNote.fromMap(Map<String, dynamic> map, String id) {
    return UserNote(
      id: id,
      userId: map['userId'] ?? '',
      lessonKey: map['lessonKey'] ?? '',
      text: map['text'] ?? '',
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }
}
