import 'package:flutter/material.dart';
import 'package:flutter_project/design/colors.dart';
import 'package:flutter_project/models/teacher.dart';
import 'package:flutter_project/services/database_service.dart';

class TeacherEditorPage extends StatefulWidget {
  const TeacherEditorPage({super.key});

  @override
  State<TeacherEditorPage> createState() => _TeacherEditorPageState();
}

class _TeacherEditorPageState extends State<TeacherEditorPage> {
  final DatabaseService _db = DatabaseService();
  List<Teacher> _teachers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    final list = await _db.getTeachers();
    setState(() {
      _teachers = list;
      _isLoading = false;
    });
  }

  void _editTeacher(Teacher teacher) {
    final nameController = TextEditingController(text: teacher.fullName);
    final deptController = TextEditingController(text: teacher.department);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Редактировать: ${teacher.shortName}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Полное ФИО"),
              textCapitalization: TextCapitalization.words,
            ),
            TextField(
              controller: deptController,
              decoration: const InputDecoration(labelText: "Кафедра"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Отмена")),
          ElevatedButton(
            onPressed: () async {
              final updated = Teacher(
                id: teacher.id,
                shortName: teacher.shortName,
                fullName: nameController.text.trim(),
                department: deptController.text.trim(),
                rating: teacher.rating,
              );
              await _db.saveTeacher(updated);
              Navigator.pop(context);
              _loadTeachers();
            },
            child: const Text("Сохранить"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text("Редактор преподавателей"),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            itemCount: _teachers.length,
            itemBuilder: (context, index) {
              final t = _teachers[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  title: Text(t.fullName.isEmpty ? t.shortName : t.fullName),
                  subtitle: Text(t.fullName.isEmpty ? "ФИО не заполнено" : "Код: ${t.shortName}"),
                  trailing: const Icon(Icons.edit, size: 20),
                  onTap: () => _editTeacher(t),
                ),
              );
            },
          ),
    );
  }
}
