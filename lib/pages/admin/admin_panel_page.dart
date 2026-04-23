import 'package:flutter/material.dart';
import 'package:flutter_project/design/colors.dart';
import 'package:flutter_project/services/database_service.dart';
import 'package:flutter_project/pages/admin/teacher_editor_page.dart';

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  final DatabaseService _db = DatabaseService();
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

  // Вспомогательный метод для форматирования даты
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text("Панель администратора", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
            subtitle: "Найти новые имена в расписании",
            icon: Icons.sync,
            onTap: () async {
              showDialog(
                context: context, 
                barrierDismissible: false,
                builder: (c) => const Center(child: CircularProgressIndicator())
              );
              await _db.syncTeachersFromSchedules();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Синхронизация завершена")),
                );
              }
            },
          ),
          _buildAdminCard(
            title: "Редактор преподавателей",
            subtitle: "Добавление полных ФИО и данных",
            icon: Icons.person_search,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => const TeacherEditorPage()),
              );
            },
          ),
          _buildAdminCard(
            title: "Управление расписанием",
            subtitle: "Загрузка Excel (в разработке)",
            icon: Icons.table_chart,
            onTap: () {
              // Здесь позже будет кнопка для импорта Excel
            },
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
