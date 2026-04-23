import 'package:flutter/material.dart';
import 'package:flutter_project/design/icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_project/design/colors.dart';
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

  List<Lesson> _allLessons = [];
  List<Lesson> _filteredLessons = [];
  bool _isLoading = true;
  String _currentGroup = "09-332 (1)";
  int _currentSubgroup = 1;
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
    if (now.isBefore(start)) return 1;
    
    // Находим разницу в днях
    final diffInDays = now.difference(start).inDays;
    // (дни / 7) + 1
    int week = (diffInDays / 7).floor() + 1;
    
    // Ограничим разумными пределами для семестра
    if (week < 1) return 1;
    if (week > 18) return 18;
    return week;
  }

  Future<void> _loadInitialData() async {
    final group = await _settings.getGroup() ?? "09-332 (1)";
    final subgroup = await _settings.getSubgroup();
    
    // Получаем дату начала семестра из БД или используем 09.02.2026 по умолчанию
    final semesterStart = await _db.getSemesterStart() ?? DateTime(2026, 2, 9);
    final currentWeek = _calculateCurrentWeek(semesterStart);

    setState(() {
      _currentGroup = group;
      _currentSubgroup = subgroup;
      _selectedWeek = currentWeek;
    });

    // Авто-скролл к текущей неделе после отрисовки
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_weekScrollController.hasClients) {
        // Примерная ширина одного элемента "X неделя" ~ 100-110 пикселей с отступами
        double offset = (_selectedWeek - 1) * 105.0; 
        _weekScrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });

    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() => _isLoading = true);
    
    // Загружаем данные из Firestore
    final results = await _db.getSchedule(_currentGroup);

    setState(() {
      _allLessons = results;
      _filterLessons();
      _isLoading = false;
    });
  }

  void _filterLessons() {
    bool isSelectedWeekEven = _selectedWeek % 2 == 0;
    setState(() {
      _filteredLessons = _allLessons.where((lesson) {
        // Фильтр по неделе (четная/нечетная)
        bool weekMatch = false;
        if (lesson.weekType == WeekType.both) {
          weekMatch = true;
        } else if (isSelectedWeekEven) {
          weekMatch = (lesson.weekType == WeekType.even);
        } else {
          weekMatch = (lesson.weekType == WeekType.odd);
        }
        
        // Фильтр по дню недели (1-6)
        bool dayMatch = (lesson.dayOfWeek == (_selectedDayIndex + 1));
        
        return weekMatch && dayMatch;
      }).toList();
    });
  }

  Future<void> _openSearch() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GroupSearchPage()),
    );
    if (result == true) {
      _loadInitialData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Расписание $_currentGroup',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: SvgPicture.asset(AppIcons.search),
            onPressed: _openSearch,
          ),
          IconButton(
            icon: SvgPicture.asset(AppIcons.menu),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Селектор недель
          SizedBox(
            height: 50,
            child: ListView.builder(
              controller: _weekScrollController, // Привязали контроллер
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: 18, // Увеличил до 18 недель
              itemBuilder: (context, index) {
                final weekNum = index + 1;
                final isSelected = _selectedWeek == weekNum;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedWeek = weekNum);
                    _filterLessons();
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? currentIcon : Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: isSelected ? currentIcon : Colors.grey.shade200),
                    ),
                    child: Center(
                      child: Text(
                        '$weekNum неделя',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Селектор дней недели
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
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
                    width: (MediaQuery.of(context).size.width - 32 - 40) / 6,
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

          const SizedBox(height: 8),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLessons.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Пар на этот день нет"),
                            const SizedBox(height: 8),
                            Text(
                              "Хорошего отдыха!",
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _filteredLessons.length,
                        itemBuilder: (context, index) {
                          final lesson = _filteredLessons[index];
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
                                      Text(
                                        lesson.time,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold, 
                                          color: currentIcon,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (lesson.weeks.isNotEmpty)
                                        Text(
                                          lesson.weeks,
                                          style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    lesson.name,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  if (lesson.teacher.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      lesson.teacher,
                                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                    ),
                                  ],
                                  if (lesson.room.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            lesson.room,
                                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
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
