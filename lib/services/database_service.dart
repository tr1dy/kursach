import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lesson.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Сохранение списка всех групп
  Future<void> saveGroupsList(List<String> groups) async {
    await _db.collection('metadata').doc('groups').set({
      'list': groups,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Получение списка всех групп из БД
  Future<List<String>> getGroupsList() async {
    final doc = await _db.collection('metadata').doc('groups').get();
    if (!doc.exists) return [];
    final List<dynamic> list = doc.data()?['list'] ?? [];
    return list.cast<String>();
  }

  // Сохранение расписания группы в базу
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

  // Получение расписания из базы
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
}
