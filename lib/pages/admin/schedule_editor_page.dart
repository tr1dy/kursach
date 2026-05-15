import 'package:flutter/material.dart';
import 'package:flutter_project/design/colors.dart';
import 'package:flutter_project/models/lesson.dart';
import 'package:flutter_project/services/database_service.dart';

class ScheduleEditorPage extends StatefulWidget {
  const ScheduleEditorPage({super.key});

  @override
  State<ScheduleEditorPage> createState() => _ScheduleEditorPageState();
}

class _ScheduleEditorPageState extends State<ScheduleEditorPage> {
  final DatabaseService _db = DatabaseService();
  String? _selectedGroup;
  List<String> _groups = [];
  List<Lesson> _lessons = [];
  bool _isLoadingGroups = true;
  bool _isLoadingSchedule = false;

  final List<String> _weekDays = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб"];

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final list = await _db.getGroupsList();
    if (mounted) {
      setState(() {
        _groups = list;
        _isLoadingGroups = false;
      });
    }
  }

  Future<void> _loadSchedule(String groupName) async {
    setState(() => _isLoadingSchedule = true);
    final lessons = await _db.getSchedule(groupName);
    if (mounted) {
      setState(() {
        _lessons = lessons;
        _isLoadingSchedule = false;
      });
    }
  }

  void _editLesson(int index) {
    final lesson = _lessons[index];
    final nameController = TextEditingController(text: lesson.name);
    final teacherController = TextEditingController(text: lesson.teacher);
    final roomController = TextEditingController(text: lesson.room);
    final weeksController = TextEditingController(text: lesson.weeks);
    final rawTextController = TextEditingController(text: lesson.rawText);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Редактировать пару"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: "Предмет")),
              TextField(controller: teacherController, decoration: const InputDecoration(labelText: "Преподаватель")),
              TextField(controller: roomController, decoration: const InputDecoration(labelText: "Аудитория")),
              TextField(controller: weeksController, decoration: const InputDecoration(labelText: "Конкретные недели (напр. 1-8)")),
              TextField(controller: rawTextController, decoration: const InputDecoration(labelText: "Нераспознанный текст")),
              const SizedBox(height: 10),
              Text("Время: ${lesson.time}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Отмена")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _lessons[index] = Lesson(
                  name: nameController.text.trim(),
                  teacher: teacherController.text.trim(),
                  room: roomController.text.trim(),
                  time: lesson.time,
                  dayOfWeek: lesson.dayOfWeek,
                  weekType: lesson.weekType,
                  subgroup: lesson.subgroup,
                  weeks: weeksController.text.trim(),
                  rawText: rawTextController.text.trim(),
                );
              });
              Navigator.pop(context);
            },
            child: const Text("Обновить"),
          ),
        ],
      ),
    );
  }

  void _deleteLesson(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Удалить пару?"),
        content: Text("Вы уверены, что хотите удалить ${_lessons[index].name}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Отмена")),
          TextButton(
            onPressed: () {
              setState(() {
                _lessons.removeAt(index);
              });
              Navigator.pop(context);
            },
            child: const Text("Удалить", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAll() async {
    if (_selectedGroup == null) return;
    
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
    try {
      await _db.saveSchedule(_selectedGroup!, _lessons);
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Расписание группы успешно сохранено")),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ошибка при сохранении: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text("Редактор расписания", style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        centerTitle: true,
        actions: [
          if (_selectedGroup != null)
            IconButton(
              onPressed: _saveAll,
              icon: const Icon(Icons.save, color: currentIcon),
            ),
        ],
      ),
      body: Column(
        children: [
          // ВЫБОР ГРУППЫ
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _isLoadingGroups 
              ? const Center(child: CircularProgressIndicator())
              : DropdownButtonFormField<String>(
                  isExpanded: true, // Исправление overflow
                  value: _selectedGroup,
                  decoration: const InputDecoration(
                    labelText: "Выберите группу", 
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: _groups.map((g) => DropdownMenuItem(
                    value: g, 
                    child: Text(g, overflow: TextOverflow.ellipsis) // Исправление overflow
                  )).toList(),
                  onChanged: (val) {
                    setState(() => _selectedGroup = val);
                    if (val != null) _loadSchedule(val);
                  },
                ),
          ),

          Expanded(
            child: _isLoadingSchedule 
              ? const Center(child: CircularProgressIndicator())
              : _selectedGroup == null 
                  ? const Center(child: Text("Сначала выберите группу"))
                  : ListView.builder(
                      itemCount: _lessons.length,
                      itemBuilder: (context, index) {
                        final lesson = _lessons[index];
                        final dayName = _weekDays[lesson.dayOfWeek - 1];
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: backgroundColor,
                              child: Text(dayName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: currentIcon)),
                            ),
                            title: Text(lesson.name, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                            subtitle: Text("${lesson.time} | ${lesson.room}\n${lesson.teacher}", maxLines: 2),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blueGrey),
                                  onPressed: () => _editLesson(index),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                  onPressed: () => _deleteLesson(index),
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
