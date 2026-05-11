import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project/design/colors.dart';
import 'package:flutter_project/services/database_service.dart';
import 'package:flutter_project/services/excel_parser.dart';
import 'package:flutter_project/pages/admin/teacher_editor_page.dart';
import 'package:flutter_project/pages/admin/user_management_page.dart';
import 'package:flutter_project/pages/admin/schedule_editor_page.dart';

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  final DatabaseService _db = DatabaseService();
  final ExcelParser _excelParser = ExcelParser();
  DateTime? _semesterStart;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final start = await _db.getSemesterStart();
    setState(() => _semesterStart = start);
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}";
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _semesterStart ?? DateTime(2026, 2, 8),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: currentIcon),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      await _db.saveSemesterStart(picked);
      setState(() => _semesterStart = picked);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Дата начала семестра сохранена")),
        );
      }
    }
  }

  Future<void> _pickAndImportSchedule() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    Uint8List? fileBytes = result.files.first.bytes;
    if (fileBytes == null) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text("Импорт расписания...", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 8),
                Text("Это займет около 10-20 секунд", style: TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      _excelParser.clearCache();
      // 1. Декодируем Excel ОДИН раз (самая тяжелая операция)
      final Excel excel = _excelParser.decode(fileBytes);
      
      // 2. Получаем список групп
      final groups = _excelParser.getGroupsFromExcel(excel);
      if (groups.isEmpty) throw "Список групп пуст или формат файла неверен";

      List<String> allGroupSubgroups = [];
      Map<String, List<Map<String, dynamic>>> teacherSchedules = {};
      
      // Список для сбора всех Future (задач на запись в БД)
      List<Future> dbTasks = [];

      // 3. Парсим данные (теперь это мгновенно, т.к. excel уже в памяти)
      for (String groupName in groups) {
        for (int subgroup in [1, 2]) {
          final lessons = _excelParser.parseScheduleFromExcel(excel, groupName, subgroup: subgroup);
          if (lessons.isNotEmpty) {
            final String fullId = "$groupName ($subgroup)";
            allGroupSubgroups.add(fullId);
            
            // Добавляем задачу сохранения группы
            dbTasks.add(_db.saveSchedule(fullId, lessons));

            // Собираем данные для преподавателей
            for (var l in lessons) {
              if (l.teacher.isNotEmpty) {
                final teacherName = l.teacher.trim();
                teacherSchedules.putIfAbsent(teacherName, () => []);
                
                var lessonMap = {
                  'name': l.name,
                  'teacher': l.teacher,
                  'room': l.room,
                  'time': l.time,
                  'dayOfWeek': l.dayOfWeek,
                  'weekType': l.weekType.index,
                  'weeks': l.weeks,
                  'targetGroups': [fullId],
                };
                
                var existing = teacherSchedules[teacherName]!.firstWhere(
                  (existingLesson) => 
                    existingLesson['time'] == lessonMap['time'] && 
                    existingLesson['dayOfWeek'] == lessonMap['dayOfWeek'] &&
                    existingLesson['name'] == lessonMap['name'] &&
                    existingLesson['weeks'] == lessonMap['weeks'],
                  orElse: () => {},
                );

                if (existing.isNotEmpty) {
                  if (!(existing['targetGroups'] as List).contains(fullId)) {
                    (existing['targetGroups'] as List).add(fullId);
                  }
                } else {
                  teacherSchedules[teacherName]!.add(lessonMap);
                }
              }
            }
          }
        }
      }

      // 4. Добавляем задачи сохранения расписаний преподавателей
      for (var teacherName in teacherSchedules.keys) {
        dbTasks.add(_db.saveTeacherSchedule(teacherName, teacherSchedules[teacherName]!));
      }

      // 5. Выполняем ВСЕ записи в базу параллельно
      await Future.wait(dbTasks);

      // 6. Финальные штрихи (метаданные)
      allGroupSubgroups.sort();
      await _db.saveGroupsList(allGroupSubgroups);
      await _db.syncTeachersFromSchedules();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Импорт завершен: ${allGroupSubgroups.length} групп")),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ошибка импорта: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Панель администратора", style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAdminCard(
            title: "Управление пользователями",
            subtitle: "Назначение ролей и прав доступа",
            icon: Icons.people_alt_outlined,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const UserManagementPage())),
          ),
          _buildAdminCard(
            title: "Редактор расписания",
            subtitle: "Ручная правка предметов и времени",
            icon: Icons.edit_calendar_outlined,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ScheduleEditorPage())),
          ),
          _buildAdminCard(
            title: "Настройки семестра",
            subtitle: _semesterStart != null 
                ? "Начало: ${_formatDate(_semesterStart!)}" 
                : "Дата не установлена",
            icon: Icons.calendar_today,
            onTap: () => _selectDate(context),
          ),
          _buildAdminCard(
            title: "Синхронизация преподавателей",
            subtitle: "Обновить базу преподавателей",
            icon: Icons.sync,
            onTap: () async {
              showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
              await _db.syncTeachersFromSchedules();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Синхронизация завершена")));
              }
            },
          ),
          _buildAdminCard(
            title: "Редактор преподавателей",
            subtitle: "Правка ФИО и данных кафедр",
            icon: Icons.person_search,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const TeacherEditorPage())),
          ),
          _buildAdminCard(
            title: "Загрузка расписания",
            subtitle: "Выбрать .xlsx файл и обновить базу",
            icon: Icons.cloud_upload_outlined,
            onTap: _pickAndImportSchedule,
          ),
        ],
      ),
    );
  }

  Widget _buildAdminCard({required String title, required String subtitle, required IconData icon, required VoidCallback onTap}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: currentIcon.withOpacity(0.1),
          child: Icon(icon, color: currentIcon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }
}
