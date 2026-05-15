import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project/design/colors.dart';
import 'package:flutter_project/models/lesson.dart';
import 'package:flutter_project/models/teacher.dart';
import 'package:flutter_project/pages/schedule/lesson_materials_sheet.dart';
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
  
  Map<String, dynamic>? _userProfile;
  List<Map<String, dynamic>> _allLessons = [];
  List<Map<String, dynamic>> _filteredLessons = [];
  bool _isLoading = true;
  int _selectedDayIndex = DateTime.now().weekday == 7 ? 0 : DateTime.now().weekday - 1;
  final List<String> _weekDays = ["пн", "вт", "ср", "чт", "пт", "сб"];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (currentUser != null) {
      _userProfile = await _db.getUserData(currentUser!.uid);
    }
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

  void _openMaterials(Map<String, dynamic> lessonData) {
    final List<String> groups = List<String>.from(lessonData['targetGroups'] ?? []);
    if (groups.isEmpty) return;
    
    // Ключ для материалов. Мы используем w1 как префикс для общего расписания препода,
    // так как это сводное отображение.
    final lessonKey = "w1_${groups.first}_${lessonData['dayOfWeek']}_${lessonData['name']}_${lessonData['time']}";
    
    final bool canEdit = _userProfile?['role'] == 'teacher' && 
                         _userProfile?['teacherName'] == widget.teacher.shortName;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => LessonMaterialsSheet(
        lessonKey: lessonKey,
        lessonName: lessonData['name'],
        canEdit: canEdit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        centerTitle: true,
        title: Column(
          children: [
            const Text("Расписание", style: TextStyle(fontSize: 12, color: Colors.grey)),
            Text(widget.teacher.shortName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
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
                          
                          final weekTypeIndex = lesson['weekType'] ?? 0;
                          final weekType = WeekType.values[weekTypeIndex];
                          final String weeksInfo = lesson['weeks'] ?? "";
                          final String rawText = lesson['rawText'] ?? "";
                          
                          String weekLabel = "";
                          if (weekType == WeekType.even) weekLabel = " (четная)";
                          if (weekType == WeekType.odd) weekLabel = " (нечетная)";

                          bool isUnknown = lesson['name'].toString().contains("Неизвестный предмет");

                          return Card(
                            elevation: 0,
                            color: Colors.white,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: InkWell(
                              onTap: () => _openMaterials(lesson),
                              borderRadius: BorderRadius.circular(12),
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
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: backgroundColor,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              weeksInfo,
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "${lesson['name']}$weekLabel", 
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                                    ),
                                    
                                    if (isUnknown && rawText.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text("Инфо:", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                                            Text(
                                              rawText,
                                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontStyle: FontStyle.italic),
                                            ),
                                          ],
                                        ),
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
