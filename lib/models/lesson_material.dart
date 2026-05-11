import 'package:cloud_firestore/cloud_firestore.dart';

class LessonMaterial {
  final String id;
  final String lessonKey;
  final String text;
  final List<String> fileUrls;
  final DateTime updatedAt;

  LessonMaterial({
    required this.id,
    required this.lessonKey,
    required this.text,
    this.fileUrls = const [],
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'lessonKey': lessonKey,
      'text': text,
      'fileUrls': fileUrls,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory LessonMaterial.fromMap(Map<String, dynamic> map, String id) {
    return LessonMaterial(
      id: id,
      lessonKey: map['lessonKey'] ?? '',
      text: map['text'] ?? '',
      fileUrls: List<String>.from(map['fileUrls'] ?? []),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
