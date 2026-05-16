import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lesson.dart';
import '../models/teacher.dart';
import '../models/user_note.dart';
import '../models/teacher_review.dart';
import '../models/lesson_material.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Вспомогательный метод для очистки ключей документов от недопустимых символов (например, '/')
  String _sanitizeKey(String key) {
    return key.replaceAll('/', '_');
  }

  // ПОЛЬЗОВАТЕЛИ
  Future<void> createUserProfile(String uid, String email, String name, {String role = 'student', String? group, String? teacherName}) async {
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'name': name,
      'role': role,
      'group': group,
      'teacherName': teacherName,
      'isAdmin': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data();
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final snapshot = await _db.collection('users').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['uid'] = doc.id;
      return data;
    }).toList();
  }

  Future<void> updateUserRole(String uid, {required String role, String? group, String? teacherName}) async {
    await _db.collection('users').doc(uid).set({
      'role': role,
      'group': group,
      'teacherName': teacherName,
    }, SetOptions(merge: true));
  }

  Stream<List<Map<String, dynamic>>> getActiveChats(String currentUserId) {
    return _db.collection('chats')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .asyncMap((snapshot) async {
          List<Map<String, dynamic>> activeUsers = [];
          for (var doc in snapshot.docs) {
            List<dynamic> participants = doc.data()['participants'] ?? [];
            String otherUserId = participants.firstWhere((id) => id != currentUserId, orElse: () => "");
            if (otherUserId.isNotEmpty) {
              final userDoc = await _db.collection('users').doc(otherUserId).get();
              if (userDoc.exists) {
                final userData = userDoc.data()!;
                userData['uid'] = otherUserId;
                activeUsers.add(userData);
              }
            }
          }
          return activeUsers;
        });
  }

  // МАТЕРИАЛЫ
  Future<LessonMaterial?> getLessonMaterial(String lessonKey) async {
    final safeKey = _sanitizeKey(lessonKey);
    final doc = await _db.collection('materials').doc(safeKey).get();
    if (!doc.exists) return null;
    return LessonMaterial.fromMap(doc.data()!, doc.id);
  }

  Future<void> saveLessonMaterial(LessonMaterial material) async {
    final safeKey = _sanitizeKey(material.lessonKey);
    await _db.collection('materials').doc(safeKey).set(material.toMap());
  }

  // РАСПИСАНИЕ ПРЕПОДАВАТЕЛЯ
  Future<List<Map<String, dynamic>>> getTeacherSchedule(String teacherShortName) async {
    final doc = await _db.collection('teacher_schedules').doc(teacherShortName).get();
    if (!doc.exists) return [];

    List<dynamic> lessonsRaw = doc.data()?['lessons'] ?? [];
    List<Map<String, dynamic>> lessons = List<Map<String, dynamic>>.from(lessonsRaw);

    // Сортировка: сначала по дню недели, потом по времени
    lessons.sort((a, b) {
      // Сравниваем дни недели (1-6)
      int dayCompare = (a['dayOfWeek'] ?? 0).compareTo(b['dayOfWeek'] ?? 0);
      if (dayCompare != 0) return dayCompare;

      // Если день один и тот же, сравниваем время
      return (a['time'] ?? "").toString().compareTo(b['time'] ?? "");
    });

    return lessons;
  }

  Future<void> saveTeacherSchedule(String teacherShortName, List<Map<String, dynamic>> lessons) async {
    await _db.collection('teacher_schedules').doc(teacherShortName).set({
      'lessons': lessons,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // РАСПИСАНИЕ ГРУППЫ
  Future<List<Lesson>> getSchedule(String groupName) async {
    try {
      // Стандартный get() сам сходит на сервер, а при отсутствии интернета - отдаст кэш
      final doc = await _db.collection('schedules').doc(groupName).get();
      if (!doc.exists) return [];
      return _parseLessons(doc.data());
    } catch (e) {
      // Если интернета нет и в кэше тоже пусто
      print("Ошибка загрузки расписания: $e");
      return [];
    }
  }

  List<Lesson> _parseLessons(Map<String, dynamic>? data) {
    if (data == null) return [];
    return (data['lessons'] as List).map((item) => Lesson(
      name: item['name'], teacher: item['teacher'], room: item['room'], time: item['time'],
      dayOfWeek: item['dayOfWeek'], weekType: WeekType.values[item['weekType'] ?? 2], subgroup: 1, 
      weeks: item['weeks'] ?? "", rawText: item['rawText'] ?? "",
    )).toList();
  }

  Future<void> saveSchedule(String groupName, List<Lesson> lessons) async {
    List<Map<String, dynamic>> lessonsMap = lessons.map((l) => {
      'name': l.name, 'teacher': l.teacher, 'room': l.room, 'time': l.time,
      'dayOfWeek': l.dayOfWeek, 'weekType': l.weekType.index, 'subgroup': l.subgroup, 
      'weeks': l.weeks, 'rawText': l.rawText,
    }).toList();
    await _db.collection('schedules').doc(groupName).set({'lessons': lessonsMap, 'updatedAt': FieldValue.serverTimestamp()});
  }

  // ГРУППЫ И ПРЕПОДАВАТЕЛИ
  Future<List<String>> getGroupsList() async {
    final doc = await _db.collection('metadata').doc('groups').get();
    if (!doc.exists) return [];
    return List<String>.from(doc.data()?['list'] ?? []);
  }

  Future<void> saveGroupsList(List<String> groups) async {
    await _db.collection('metadata').doc('groups').set({'list': groups, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<DateTime?> getSemesterStart() async {
    final doc = await _db.collection('metadata').doc('settings').get();
    return (doc.data()?['semesterStart'] as Timestamp?)?.toDate();
  }

  Future<void> saveSemesterStart(DateTime date) async {
    await _db.collection('metadata').doc('settings').set({'semesterStart': Timestamp.fromDate(date)}, SetOptions(merge: true));
  }

  Future<List<Teacher>> getTeachers() async {
    final snapshot = await _db.collection('teachers').orderBy('shortName').get();
    return snapshot.docs.map((doc) => Teacher.fromMap(doc.data(), doc.id)).toList();
  }

  Future<void> saveTeacher(Teacher teacher) async {
    if (teacher.id.isEmpty) await _db.collection('teachers').add(teacher.toMap());
    else await _db.collection('teachers').doc(teacher.id).set(teacher.toMap(), SetOptions(merge: true));
  }

  Future<void> syncTeachersFromSchedules() async {
    final schedulesSnapshot = await _db.collection('schedules').get();
    Set<String> teacherNames = {};
    for (var doc in schedulesSnapshot.docs) {
      for (var lesson in (doc.data()['lessons'] as List)) {
        if (lesson['teacher'].toString().trim().isNotEmpty) teacherNames.add(lesson['teacher'].trim());
      }
    }
    final existing = await getTeachers();
    Set<String> existingNames = existing.map((t) => t.shortName).toSet();
    for (String name in teacherNames) {
      if (!existingNames.contains(name)) await _db.collection('teachers').add({'shortName': name, 'fullName': "", 'department': "", 'rating': 0.0});
    }
  }

  Stream<List<TeacherReview>> getTeacherReviews(String teacherId) {
    return _db.collection('teachers').doc(teacherId).collection('reviews').orderBy('timestamp', descending: true).snapshots().map((s) => s.docs.map((d) => TeacherReview.fromMap(d.data(), d.id)).toList());
  }

  Future<bool> hasUserReviewedTeacher(String teacherId, String userId) async {
    final s = await _db.collection('teachers').doc(teacherId).collection('reviews').where('userId', isEqualTo: userId).get();
    return s.docs.isNotEmpty;
  }

  Future<void> saveTeacherReview(String teacherId, TeacherReview review) async {
    await _db.collection('teachers').doc(teacherId).collection('reviews').add(review.toMap());
    await _updateTeacherRating(teacherId);
  }

  Future<void> deleteTeacherReview(String teacherId, String reviewId) async {
    await _db.collection('teachers').doc(teacherId).collection('reviews').doc(reviewId).delete();
    await _updateTeacherRating(teacherId);
  }

  Future<void> _updateTeacherRating(String teacherId) async {
    final s = await _db.collection('teachers').doc(teacherId).collection('reviews').get();
    if (s.docs.isEmpty) {
      await _db.collection('teachers').doc(teacherId).update({'rating': 0.0});
      return;
    }
    double avg = s.docs.fold(0.0, (prev, d) => prev + (d.data()['rating'] ?? 0.0)) / s.docs.length;
    await _db.collection('teachers').doc(teacherId).update({'rating': avg});
  }

  Future<UserNote?> getNote(String userId, String lessonKey) async {
    final safeKey = _sanitizeKey(lessonKey);
    final s = await _db.collection('notes').where('userId', isEqualTo: userId).where('lessonKey', isEqualTo: safeKey).get();
    return s.docs.isEmpty ? null : UserNote.fromMap(s.docs.first.data(), s.docs.first.id);
  }

  Future<void> saveNote(String userId, String lessonKey, String text) async {
    final safeKey = _sanitizeKey(lessonKey);
    final s = await _db.collection('notes').where('userId', isEqualTo: userId).where('lessonKey', isEqualTo: safeKey).get();
    if (s.docs.isEmpty) await _db.collection('notes').add({'userId': userId, 'lessonKey': safeKey, 'text': text, 'updatedAt': FieldValue.serverTimestamp()});
    else await _db.collection('notes').doc(s.docs.first.id).update({'text': text, 'updatedAt': FieldValue.serverTimestamp()});
  }
}
