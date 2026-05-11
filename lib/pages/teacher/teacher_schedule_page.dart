import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project/design/colors.dart';
import 'package:flutter_project/models/lesson.dart';
import 'package:flutter_project/models/teacher.dart';
import 'package:flutter_project/services/database_service.dart';

class TeacherSchedulePage extends StatefulWidget {
  final Teacher teacher;

  const TeacherSchedulePage({super.key, required this.teacher});

  @override
  State<TeacherSchedulePage> createState() => _TeacherSchedulePageState();
}

class _TeacherSchedulePageState extends State<TeacherSchedulePage> {
  final DatabaseService _db = DatabaseService();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  
  List<Map<String, dynamic>> _allLessons = [];
  List<Map<String, dynamic>> _filteredLessons = [];
  bool _isLoading = true;
  int _selectedDayIndex = DateTime.now().weekday == 7 ? 0 : DateTime.now().weekday - 1;
  final List<String> _weekDays = ["пн", "вт", "ср", "чт", "пт", "сб"];

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() => _isLoading = true);
    final results = await _db.getTeacherSchedule(widget.teacher.shortName);
    setState(() {
      _allLessons = results;
      _filterLessons();
      _isLoading = false;
    });
  }

  void _filterLessons() {
    setState(() {
      _filteredLessons = _allLessons.where((lesson) {
        return lesson['dayOfWeek'] == (_selectedDayIndex + 1);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Расписание преподавателя", style: TextStyle(fontSize: 12, color: Colors.grey)),
            Text(
              widget.teacher.shortName, 
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(_weekDays.length, (index) {
                final isSelected = _selectedDayIndex == index;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedDayIndex = index);
                    _filterLessons();
                  },
                  child: Container(
                    width: (MediaQuery.of(context).size.width - 72) / 6,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? currentIcon : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        _weekDays[index].toUpperCase(),
                        style: TextStyle(
                          color: isSelected ? Colors.white : textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLessons.isEmpty
                    ? const Center(child: Text("Пар на этот день нет"))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _filteredLessons.length,
                        itemBuilder: (context, index) {
                          final lesson = _filteredLessons[index];
                          final groups = List<String>.from(lesson['targetGroups'] ?? []);
                          
                          // Получаем информацию о неделях
                          final weekTypeIndex = lesson['weekType'] ?? 0;
                          final weekType = WeekType.values[weekTypeIndex];
                          final String weeksInfo = lesson['weeks'] ?? "";
                          
                          String weekLabel = "";
                          if (weekType == WeekType.even) weekLabel = " (четная)";
                          if (weekType == WeekType.odd) weekLabel = " (нечетная)";

                          return Card(
                            elevation: 0,
                            color: Colors.white,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(lesson['time'], style: const TextStyle(fontWeight: FontWeight.bold, color: currentIcon)),
                                      if (weeksInfo.isNotEmpty)
                                        Flexible(
                                          child: Container(
                                            margin: const EdgeInsets.only(left: 8),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: backgroundColor,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              weeksInfo,
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "${lesson['name']}$weekLabel", 
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.people_outline, size: 16, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          "Группы: ${groups.join(', ')}", 
                                          style: const TextStyle(color: Colors.grey, fontSize: 13)
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (lesson['room'] != null && lesson['room'].toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              "Аудитория: ${lesson['room']}", 
                                              style: const TextStyle(color: Colors.grey, fontSize: 13)
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
