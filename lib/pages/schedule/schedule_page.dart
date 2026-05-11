import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project/design/icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_project/design/colors.dart';
import 'package:flutter_project/pages/schedule/lesson_materials_sheet.dart';
import '../../models/lesson.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';
import 'group_search_page.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final SettingsService _settings = SettingsService();
  final DatabaseService _db = DatabaseService();
  final ScrollController _weekScrollController = ScrollController();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  List<Lesson> _allLessons = [];
  List<Lesson> _filteredLessons = [];
  bool _isLoading = true;
  String _currentGroup = "09-332 (1)";
  String? _teacherName;
  bool _isTeacherMode = false;
  int _selectedWeek = 1;

  int _selectedDayIndex = DateTime.now().weekday == 7 ? 0 : DateTime.now().weekday - 1;
  final List<String> _weekDays = ["пн", "вт", "ср", "чт", "пт", "сб"];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _weekScrollController.dispose();
    super.dispose();
  }

  int _calculateCurrentWeek(DateTime start) {
    final now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime startDate = DateTime(start.year, start.month, start.day);
    if (today.isBefore(startDate)) return 1;
    final diffInDays = today.difference(startDate).inDays;
    return (diffInDays ~/ 7) + 1;
  }

  Future<void> _loadInitialData() async {
    try {
      final semesterStart = await _db.getSemesterStart().catchError((_) => DateTime(2026, 2, 9)) ?? DateTime(2026, 2, 9);
      final currentWeek = _calculateCurrentWeek(semesterStart);
      setState(() => _selectedWeek = currentWeek.clamp(1, 18));

      if (currentUser != null) {
        final userData = await _db.getUserData(currentUser!.uid);
        if (userData != null && userData['role'] == 'teacher') {
          setState(() {
            _isTeacherMode = true;
            _teacherName = userData['teacherName'];
          });
          _loadTeacherSchedule();
          return;
        }
      }

      final group = await _settings.getGroup() ?? "09-332 (1)";
      setState(() {
        _isTeacherMode = false;
        _currentGroup = group;
      });
      _loadGroupSchedule();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_weekScrollController.hasClients) {
          _weekScrollController.jumpTo((_selectedWeek - 1) * 105.0);
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadGroupSchedule() async {
    setState(() => _isLoading = true);
    try {
      final results = await _db.getSchedule(_currentGroup);
      setState(() {
        _allLessons = results;
        _filterLessons();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTeacherSchedule() async {
    if (_teacherName == null) return;
    setState(() => _isLoading = true);
    try {
      final rawData = await _db.getTeacherSchedule(_teacherName!);
      final results = rawData.map((item) => Lesson(
        name: item['name'],
        teacher: item['teacher'],
        room: item['room'],
        time: item['time'],
        dayOfWeek: item['dayOfWeek'],
        weekType: WeekType.values[item['weekType']],
        subgroup: item['subgroup'],
        weeks: item['weeks'] ?? "",
        rawText: item['rawText'] ?? "",
        targetGroups: List<String>.from(item['targetGroups'] ?? []),
      )).toList();
      setState(() {
        _allLessons = results;
        _filterLessons();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  bool _isWeekIncluded(String weeksStr, int currentWeek) {
    String cleanStr = weeksStr.replaceAll(RegExp(r'[^0-9,-]'), '');
    if (cleanStr.isEmpty) return true;
    try {
      List<String> parts = cleanStr.split(',');
      for (String part in parts) {
        if (part.isEmpty) continue;
        if (part.contains('-')) {
          List<String> range = part.split('-');
          if (range.length >= 2) {
            int? start = int.tryParse(range[0]);
            int? end = int.tryParse(range[1]);
            if (start != null && end != null && currentWeek >= start && currentWeek <= end) return true;
          }
        } else {
          if (int.tryParse(part) == currentWeek) return true;
        }
      }
    } catch (e) { return true; }
    return false;
  }

  void _filterLessons() {
    bool isSelectedWeekEven = _selectedWeek % 2 == 0;
    setState(() {
      _filteredLessons = _allLessons.where((lesson) {
        if (lesson.dayOfWeek != (_selectedDayIndex + 1)) return false;
        bool parityMatch = (lesson.weekType == WeekType.both) || 
                          (isSelectedWeekEven ? lesson.weekType == WeekType.even : lesson.weekType == WeekType.odd);
        if (!parityMatch) return false;
        if (lesson.weeks.trim().isNotEmpty) return _isWeekIncluded(lesson.weeks, _selectedWeek);
        return true;
      }).toList();
    });
  }

  void _showMaterials(Lesson lesson) {
    String groupKey = _isTeacherMode ? (lesson.targetGroups.isNotEmpty ? lesson.targetGroups.first : "Teacher") : _currentGroup;
    final lessonKey = "w${_selectedWeek}_${groupKey}_${lesson.dayOfWeek}_${lesson.name}_${lesson.time}";
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => LessonMaterialsSheet(
        lessonKey: lessonKey,
        lessonName: lesson.name,
        canEdit: _isTeacherMode,
      ),
    ).then((_) => _isTeacherMode ? _loadTeacherSchedule() : _loadGroupSchedule());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _isTeacherMode ? 'Моё расписание' : 'Расписание $_currentGroup', 
          style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)
        ),
        actions: [
          if (!_isTeacherMode)
            IconButton(icon: SvgPicture.asset(AppIcons.search), onPressed: () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (c) => const GroupSearchPage()));
              if (result == true) _loadInitialData();
            }),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildWeekSelector(),
          _buildDaySelector(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLessons.isEmpty
                    ? const Center(child: Text("Пар нет, отдыхайте!"))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _filteredLessons.length,
                        itemBuilder: (context, index) => _buildLessonCard(_filteredLessons[index]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekSelector() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        controller: _weekScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: 18,
        itemBuilder: (context, index) {
          final weekNum = index + 1;
          final isSelected = _selectedWeek == weekNum;
          return GestureDetector(
            onTap: () { setState(() => _selectedWeek = weekNum); _filterLessons(); },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? currentIcon : Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: isSelected ? currentIcon : Colors.grey.shade200),
              ),
              child: Center(child: Text('$weekNum неделя', style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontSize: 13))),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDaySelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(_weekDays.length, (index) {
          final isSelected = _selectedDayIndex == index;
          return GestureDetector(
            onTap: () { setState(() => _selectedDayIndex = index); _filterLessons(); },
            child: Container(
              width: (MediaQuery.of(context).size.width - 72) / 6,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: isSelected ? currentIcon : Colors.transparent, borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text(_weekDays[index].toUpperCase(), style: TextStyle(color: isSelected ? Colors.white : textColor, fontWeight: FontWeight.bold, fontSize: 12))),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLessonCard(Lesson lesson) {
    String groupKey = _isTeacherMode ? (lesson.targetGroups.isNotEmpty ? lesson.targetGroups.first : "Teacher") : _currentGroup;
    final lessonKey = "w${_selectedWeek}_${groupKey}_${lesson.dayOfWeek}_${lesson.name}_${lesson.time}";

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showMaterials(lesson),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lesson.time, style: const TextStyle(fontWeight: FontWeight.bold, color: currentIcon, fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (!_isTeacherMode && currentUser != null)
                          FutureBuilder(
                            future: _db.getNote(currentUser!.uid, lessonKey),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data!.text.isNotEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.only(right: 8.0),
                                  child: Icon(Icons.edit_note, color: Colors.brown, size: 20),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        FutureBuilder(
                          future: _db.getLessonMaterial(lessonKey),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data!.text.isNotEmpty) {
                              return const Padding(
                                padding: EdgeInsets.only(right: 8.0),
                                child: Icon(Icons.assignment_turned_in, color: Colors.orange, size: 18),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                        if (lesson.weeks.isNotEmpty)
                          Flexible(
                            child: Text(
                              lesson.weeks, 
                              textAlign: TextAlign.right, 
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 11)
                            )
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                lesson.name, 
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
              ),
              if (!_isTeacherMode && lesson.teacher.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  lesson.teacher, 
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 14)
                ),
              ],
              if (_isTeacherMode && lesson.targetGroups.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  "Группы: ${lesson.targetGroups.join(', ')}", 
                  style: const TextStyle(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.w500)
                ),
              ],
              if (lesson.room.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2.0), 
                      child: Icon(Icons.location_on_outlined, size: 14, color: Colors.grey)
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        lesson.room, 
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13)
                      )
                    ),
                  ],
                ),
              ],
              if (lesson.rawText.isNotEmpty) ...[
                const Divider(height: 24, thickness: 0.5),
                Text("Инфо:", style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  lesson.rawText, 
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontStyle: FontStyle.italic)
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
