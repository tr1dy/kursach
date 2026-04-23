import 'package:flutter/material.dart';
import 'package:flutter_project/design/icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_project/design/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/teacher.dart';
import '../../services/database_service.dart';

class TeachersPage extends StatefulWidget {
  const TeachersPage({super.key});

  @override
  State<TeachersPage> createState() => _TeachersPageState();
}

class _TeachersPageState extends State<TeachersPage> {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Teacher> _allTeachers = [];
  List<Teacher> _filteredTeachers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    setState(() => _isLoading = true);
    try {
      final teachers = await _db.getTeachers();
      setState(() {
        _allTeachers = teachers;
        _filteredTeachers = teachers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _filterTeachers(String query) {
    setState(() {
      _filteredTeachers = _allTeachers
          .where((t) => 
            t.fullName.toLowerCase().contains(query.toLowerCase()) || 
            t.shortName.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  // Временная функция для запуска синхронизации
  Future<void> _showSyncDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Синхронизация"),
        content: const Text("Найти новых преподавателей в расписаниях и добавить их в список?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Отмена")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              await _db.syncTeachersFromSchedules();
              await _loadTeachers();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("База преподавателей обновлена")),
              );
            },
            child: const Text("Синхронизировать"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: const Center(child: Text('Для просмотра требуется пройти авторизацию :)')),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Преподаватели',
          style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: SvgPicture.asset(AppIcons.menu),
            onPressed: _showSyncDialog, // Временно вызываем синхронизацию здесь
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _filterTeachers,
              decoration: InputDecoration(
                hintText: "Поиск преподавателя...",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadTeachers,
                    child: _filteredTeachers.isEmpty
                        ? ListView( // Используем ListView чтобы RefreshIndicator работал
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                              const Center(child: Text("Преподаватели не найдены")),
                              if (_allTeachers.isEmpty)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.only(top: 8.0),
                                    child: Text("Нажмите на иконку меню для синхронизации", style: TextStyle(color: Colors.grey)),
                                  ),
                                ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: _filteredTeachers.length,
                            itemBuilder: (context, index) {
                              final teacher = _filteredTeachers[index];
                              return _buildTeacherCard(teacher);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherCard(Teacher teacher) {
    // Отображаем полное имя, если оно есть, иначе короткое
    String displayName = teacher.fullName.isNotEmpty ? teacher.fullName : teacher.shortName;
    
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: currentIcon.withOpacity(0.1),
          child: Text(
            displayName.isNotEmpty ? displayName[0].toUpperCase() : "?",
            style: const TextStyle(color: currentIcon, fontWeight: FontWeight.bold, fontSize: 20),
          ),
        ),
        title: Text(
          displayName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (teacher.department.isNotEmpty)
              Text(teacher.department, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text(
                  teacher.rating > 0 ? teacher.rating.toStringAsFixed(1) : "Нет оценок",
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {
          // Скоро добавим страницу деталей
        },
      ),
    );
  }
}
