import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lesson.dart';
import '../models/teacher.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // СОХРАНЕНИЕ ПОЛЬЗОВАТЕЛЯ
  Future<void> createUserProfile(String uid, String email) async {
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'name': email.split('@')[0],
      'isAdmin': email == "lvov.dima2018@yandex.ru",
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> isUserAdmin(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['isAdmin'] ?? false;
  }

  // ПОЛУЧЕНИЕ ВСЕХ ПОЛЬЗОВАТЕЛЕЙ (для поиска собеседника)
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final snapshot = await _db.collection('users').get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // МЕТАДАННЫЕ (Группы и Настройки семестра)
  Future<void> saveGroupsList(List<String> groups) async {
    await _db.collection('metadata').doc('groups').set({
      'list': groups,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<String>> getGroupsList() async {
    final doc = await _db.collection('metadata').doc('groups').get();
    if (!doc.exists) return [];
    final List<dynamic> list = doc.data()?['list'] ?? [];
    return list.cast<String>();
  }

  Future<DateTime?> getSemesterStart() async {
    final doc = await _db.collection('metadata').doc('settings').get();
    if (!doc.exists) return null;
    final Timestamp? timestamp = doc.data()?['semesterStart'];
    return timestamp?.toDate();
  }

  Future<void> saveSemesterStart(DateTime date) async {
    await _db.collection('metadata').doc('settings').set({
      'semesterStart': Timestamp.fromDate(date),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // РАСПИСАНИЕ
  Future<void> saveSchedule(String groupName, List<Lesson> lessons) async {
    final docRef = _db.collection('schedules').doc(groupName);
    List<Map<String, dynamic>> lessonsMap = lessons.map((lesson) => {
      'name': lesson.name,
      'teacher': lesson.teacher,
      'room': lesson.room,
      'time': lesson.time,
      'dayOfWeek': lesson.dayOfWeek,
      'weekType': lesson.weekType.index,
      'subgroup': lesson.subgroup,
      'weeks': lesson.weeks,
    }).toList();
    await docRef.set({
      'updatedAt': FieldValue.serverTimestamp(),
      'lessons': lessonsMap,
    });
  }

  Future<List<Lesson>> getSchedule(String groupName) async {
    final doc = await _db.collection('schedules').doc(groupName).get();
    if (!doc.exists) return [];
    final List<dynamic> lessonsData = doc.data()?['lessons'] ?? [];
    return lessonsData.map((item) => Lesson(
      name: item['name'],
      teacher: item['teacher'],
      room: item['room'],
      time: item['time'],
      dayOfWeek: item['dayOfWeek'],
      weekType: WeekType.values[item['weekType']],
      subgroup: item['subgroup'],
      weeks: item['weeks'] ?? "",
    )).toList();
  }

  // ПРЕПОДАВАТЕЛИ
  Future<List<Teacher>> getTeachers() async {
    final snapshot = await _db.collection('teachers').orderBy('shortName').get();
    return snapshot.docs.map((doc) => Teacher.fromMap(doc.data(), doc.id)).toList();
  }

  Future<void> saveTeacher(Teacher teacher) async {
    final docData = teacher.toMap();
    if (teacher.id.isEmpty) {
      await _db.collection('teachers').add(docData);
    } else {
      await _db.collection('teachers').doc(teacher.id).set(docData, SetOptions(merge: true));
    }
  }

  // СИНХРОНИЗАЦИЯ ПРЕПОДАВАТЕЛЕЙ ИЗ РАСПИСАНИЙ
  Future<void> syncTeachersFromSchedules() async {
    final schedulesSnapshot = await _db.collection('schedules').get();
    Set<String> teacherNames = {};

    for (var doc in schedulesSnapshot.docs) {
      final List<dynamic> lessons = doc.data()['lessons'] ?? [];
      for (var lesson in lessons) {
        String name = lesson['teacher'] ?? "";
        if (name.trim().isNotEmpty) {
          teacherNames.add(name.trim());
        }
      }
    }

    final existingTeachersSnapshot = await _db.collection('teachers').get();
    Set<String> existingShortNames = existingTeachersSnapshot.docs
        .map((doc) => doc.data()['shortName'] as String)
        .toSet();

    for (String name in teacherNames) {
      if (!existingShortNames.contains(name)) {
        await _db.collection('teachers').add({
          'shortName': name,
          'fullName': "",
          'department': "",
          'rating': 0.0,
        });
      }
    }
  }
}
